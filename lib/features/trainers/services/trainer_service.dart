import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrainerService {
  TrainerService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const List<TrainerProfile> _defaultMockTrainers = <TrainerProfile>[
    TrainerProfile(
      id: 'trainer-1',
      userId: 'user-coach-bob',
      displayName: 'Bob Trainer',
      bio: 'Elite strength & conditioning coach specializing in powerlifting',
      certifications: <String>['CSCS', 'USAPL-Coach'],
      specialties: <String>['Strength', 'Powerlifting'],
      experienceYears: 7,
      hourlyRate: 1500,
      rating: 4.95,
    ),
    TrainerProfile(
      id: 'trainer-2',
      userId: 'user-coach-charlie',
      displayName: 'Charlie Yoga',
      bio: 'Registered yoga instructor and mobility specialist',
      certifications: <String>['RYT-500'],
      specialties: <String>['Yoga', 'Mobility'],
      experienceYears: 4,
      hourlyRate: 800,
      rating: 4.80,
    ),
    TrainerProfile(
      id: 'trainer-3',
      userId: 'user-coach-diana',
      displayName: 'Diana Vance',
      bio: 'Bodybuilding & hypertrophy specialist with nutrition focus',
      certifications: <String>['NASM-CPT', 'CISSN'],
      specialties: <String>['Hypertrophy', 'Nutrition'],
      experienceYears: 6,
      hourlyRate: 2500,
      rating: 4.90,
    ),
  ];

  /// Static in-memory mock catalog for preview & testing
  static List<TrainerProfile> mockTrainers =
      List<TrainerProfile>.of(_defaultMockTrainers);

  /// Resets mock trainers catalog to initial baseline
  static void resetMockTrainers() {
    mockTrainers = List<TrainerProfile>.of(_defaultMockTrainers);
  }

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    if (SupabaseConfig.isInitialized) {
      return Supabase.instance.client;
    }
    return null;
  }

  /// Fetches all verified trainers with PostgREST join on profiles.
  Future<List<TrainerProfile>> getTrainers({
    TrainerFilterCriteria? filter,
    bool forceRefresh = false,
  }) async {
    final client = _supabase;
    if (client == null) {
      debugPrint(
        'TrainerService: Supabase uninitialized, using mock trainers.',
      );
      return _filterLocal(List<TrainerProfile>.of(mockTrainers), filter);
    }

    try {
      final response = await client
          .from('trainer_profiles')
          .select('*, profiles:user_id(display_name)')
          .eq('verified', true)
          .order('rating', ascending: false);

      final list = (response as List<dynamic>)
          .map(
            (e) => TrainerProfile.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      return _filterLocal(list, filter);
    } on Object catch (e) {
      debugPrint(
        'TrainerService getTrainers error: $e. Falling back to mock data.',
      );
      return _filterLocal(List<TrainerProfile>.of(mockTrainers), filter);
    }
  }

  /// Fetches a single trainer profile by profile UUID
  Future<TrainerProfile?> getTrainerById(String trainerId) async {
    final client = _supabase;
    if (client == null) {
      return mockTrainers.cast<TrainerProfile?>().firstWhere(
            (t) => t?.id == trainerId,
            orElse: () => null,
          );
    }

    try {
      final response = await client
          .from('trainer_profiles')
          .select('*, profiles:user_id(display_name)')
          .eq('id', trainerId)
          .maybeSingle();

      if (response == null) return null;
      return TrainerProfile.fromJson(response);
    } on Object catch (e) {
      debugPrint('TrainerService getTrainerById error: $e');
      return null;
    }
  }

  /// Fetches the trainer profile for a specific auth user_id
  Future<TrainerProfile?> getTrainerByUserId(String userId) async {
    final client = _supabase;
    if (client == null) {
      return mockTrainers.cast<TrainerProfile?>().firstWhere(
            (t) => t?.userId == userId,
            orElse: () => null,
          );
    }

    try {
      final response = await client
          .from('trainer_profiles')
          .select('*, profiles:user_id(display_name)')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return TrainerProfile.fromJson(response);
    } on Object catch (e) {
      debugPrint('TrainerService getTrainerByUserId error: $e');
      return null;
    }
  }

  /// Fetches the current authenticated user's trainer profile
  Future<TrainerProfile?> getMyTrainerProfile() async {
    final client = _supabase;
    final currentUserId = client?.auth.currentUser?.id;
    if (currentUserId == null) return null;
    return getTrainerByUserId(currentUserId);
  }

  /// Registers a new trainer profile with exact parameters
  Future<TrainerProfile> registerTrainerProfile({
    required String userId,
    required String displayName,
    required String bio,
    required List<String> certifications,
    required List<String> specialties,
    required int experienceYears,
    required double hourlyRate,
    Map<String, dynamic>? availability,
  }) async {
    final client = _supabase;
    if (client == null) {
      final created = TrainerProfile(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        displayName: displayName,
        bio: bio,
        certifications: certifications,
        specialties: specialties,
        experienceYears: experienceYears,
        hourlyRate: hourlyRate,
        availability: availability,
      );
      mockTrainers.add(created);
      return created;
    }

    try {
      // Step 1: Ensure public.profiles has user_id to satisfy FK
      await client.from('profiles').upsert(<String, dynamic>{
        'id': userId,
        'display_name': displayName,
      });

      // Step 2: Insert into trainer_profiles (triggers protect rating/fee)
      final insertData = <String, dynamic>{
        'user_id': userId,
        'bio': bio,
        'certifications': certifications,
        'specialties': specialties,
        'experience_years': experienceYears,
        'hourly_rate': hourlyRate,
        'availability': availability ??
            <String, dynamic>{'schedule': <dynamic>[], 'active': true},
      };

      final response = await client
          .from('trainer_profiles')
          .insert(insertData)
          .select('*, profiles:user_id(display_name)')
          .single();

      return TrainerProfile.fromJson(response);
    } on Object catch (e) {
      debugPrint('TrainerService registerTrainerProfile error: $e');
      rethrow;
    }
  }

  /// Flexible registerTrainer method matching BLoC invocations
  Future<TrainerProfile> registerTrainer({
    required String bio,
    required List<String> certifications,
    required List<String> specialties,
    required int experienceYears,
    required double hourlyRate,
    String? userId,
    String? displayName,
    Map<String, dynamic>? availability,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolvedUserId =
        userId ?? _supabase?.auth.currentUser?.id ?? 'user-$now';
    final resolvedDisplayName = displayName ??
        _supabase?.auth.currentUser?.userMetadata?['display_name'] as String? ??
        'Coach';

    return registerTrainerProfile(
      userId: resolvedUserId,
      displayName: resolvedDisplayName,
      bio: bio,
      certifications: certifications,
      specialties: specialties,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
      availability: availability,
    );
  }

  /// Updates an existing trainer profile.
  Future<TrainerProfile> updateTrainerProfile(
    dynamic profileOrUserId, {
    String? displayName,
    String? bio,
    List<String>? certifications,
    List<String>? specialties,
    int? experienceYears,
    double? hourlyRate,
    Map<String, dynamic>? availability,
  }) async {
    String userId;
    var resolvedDisplayName = displayName;
    var resolvedBio = bio;
    var resolvedCertifications = certifications;
    var resolvedSpecialties = specialties;
    var resolvedExperienceYears = experienceYears;
    var resolvedHourlyRate = hourlyRate;
    var resolvedAvailability = availability;

    if (profileOrUserId is TrainerProfile) {
      userId = profileOrUserId.userId;
      resolvedDisplayName ??= profileOrUserId.displayName;
      resolvedBio ??= profileOrUserId.bio;
      resolvedCertifications ??= profileOrUserId.certifications;
      resolvedSpecialties ??= profileOrUserId.specialties;
      resolvedExperienceYears ??= profileOrUserId.experienceYears;
      resolvedHourlyRate ??= profileOrUserId.hourlyRate;
      resolvedAvailability ??= profileOrUserId.availability;
    } else {
      userId = profileOrUserId.toString();
    }

    final client = _supabase;
    if (client == null) {
      final idx = mockTrainers.indexWhere((t) => t.userId == userId);
      if (idx >= 0) {
        final existing = mockTrainers[idx];
        final updated = existing.copyWith(
          displayName: resolvedDisplayName ?? existing.displayName,
          bio: resolvedBio ?? existing.bio,
          certifications: resolvedCertifications ?? existing.certifications,
          specialties: resolvedSpecialties ?? existing.specialties,
          experienceYears: resolvedExperienceYears ?? existing.experienceYears,
          hourlyRate: resolvedHourlyRate ?? existing.hourlyRate,
          availability: resolvedAvailability ?? existing.availability,
        );
        mockTrainers[idx] = updated;
        return updated;
      }
      final created = TrainerProfile(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        displayName: resolvedDisplayName ?? 'Coach',
        bio: resolvedBio ?? '',
        certifications: resolvedCertifications ?? const <String>[],
        specialties: resolvedSpecialties ?? const <String>[],
        experienceYears: resolvedExperienceYears ?? 0,
        hourlyRate: resolvedHourlyRate ?? 1000.0,
        availability: resolvedAvailability,
      );
      mockTrainers.add(created);
      return created;
    }

    try {
      // Step 1: Update display_name in profiles if provided
      if (resolvedDisplayName != null &&
          resolvedDisplayName.trim().isNotEmpty) {
        await client.from('profiles').update(<String, dynamic>{
          'display_name': resolvedDisplayName.trim(),
        }).eq('id', userId);
      }

      // Step 2: Update only allowed mutable columns in trainer_profiles
      final updatePayload = <String, dynamic>{
        if (resolvedBio != null) 'bio': resolvedBio,
        if (resolvedCertifications != null)
          'certifications': resolvedCertifications,
        if (resolvedSpecialties != null) 'specialties': resolvedSpecialties,
        if (resolvedExperienceYears != null)
          'experience_years': resolvedExperienceYears,
        if (resolvedHourlyRate != null) 'hourly_rate': resolvedHourlyRate,
        if (resolvedAvailability != null) 'availability': resolvedAvailability,
      };

      final response = await client
          .from('trainer_profiles')
          .update(updatePayload)
          .eq('user_id', userId)
          .select('*, profiles:user_id(display_name)')
          .single();

      return TrainerProfile.fromJson(response);
    } on Object catch (e) {
      debugPrint('TrainerService updateTrainerProfile error: $e');
      rethrow;
    }
  }

  List<TrainerProfile> _filterLocal(
    List<TrainerProfile> list,
    TrainerFilterCriteria? filter,
  ) {
    if (filter == null) return list;
    return list.where(filter.matches).toList();
  }
}
