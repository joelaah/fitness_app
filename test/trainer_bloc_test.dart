import 'dart:convert';
import 'package:fitness_app/features/trainers/bloc/trainer_bloc.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_event.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_state.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trainer Profile model matching PROJECT.md and Freezed specifications (preserved for backward compatibility).
class TrainerProfileData implements FilterableTrainer {
  final String id;
  final String userId;
  final String bio;
  final List<String> certifications;
  final List<String> specialties;
  final double hourlyRate;
  final double rating;
  final double platformFeePct;
  final bool verified;

  @override
  String? get displayName => null;

  const TrainerProfileData({
    required this.id,
    required this.userId,
    this.bio = '',
    this.certifications = const [],
    this.specialties = const [],
    required this.hourlyRate,
    this.rating = 5.0,
    this.platformFeePct = 10.0,
    this.verified = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'bio': bio,
        'certifications': certifications,
        'specialties': specialties,
        'hourly_rate': hourlyRate,
        'rating': rating,
        'platform_fee_pct': platformFeePct,
        'verified': verified,
      };

  factory TrainerProfileData.fromJson(Map<String, dynamic> json) =>
      TrainerProfileData(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        bio: (json['bio'] as String?) ?? '',
        certifications: (json['certifications'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        specialties: (json['specialties'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        hourlyRate: (json['hourly_rate'] as num).toDouble(),
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        platformFeePct: (json['platform_fee_pct'] as num?)?.toDouble() ?? 10.0,
        verified: (json['verified'] as bool?) ?? true,
      );
}

class _ErrorTrainerService extends TrainerService {
  @override
  Future<List<TrainerProfile>> getTrainers({
    TrainerFilterCriteria? filter,
    bool forceRefresh = false,
  }) async {
    throw Exception('Database query failed: connection refused');
  }

  @override
  Future<TrainerProfile> registerTrainer({
    String? userId,
    String? displayName,
    required String bio,
    required List<String> certifications,
    required List<String> specialties,
    required int experienceYears,
    required double hourlyRate,
    Map<String, dynamic>? availability,
  }) async {
    throw Exception('Registration rejected: permission denied');
  }

  @override
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
    throw Exception('Update rejected: trigger constraint violation');
  }
}

void main() {
  final sampleTrainers = [
    const TrainerProfileData(
      id: 'trainer-1',
      userId: 'user-1',
      bio: 'Elite strength & conditioning coach specializing in powerlifting',
      certifications: ['CSCS', 'USAPL-Coach'],
      specialties: ['Strength', 'Powerlifting'],
      hourlyRate: 1500.0,
      rating: 4.95,
      verified: true,
    ),
    const TrainerProfileData(
      id: 'trainer-2',
      userId: 'user-2',
      bio: 'Registered yoga instructor and mobility specialist',
      certifications: ['RYT-500'],
      specialties: ['Yoga', 'Mobility'],
      hourlyRate: 800.0,
      rating: 4.80,
      verified: true,
    ),
    const TrainerProfileData(
      id: 'trainer-3',
      userId: 'user-3',
      bio: 'Bodybuilding & hypertrophy specialist with nutrition focus',
      certifications: ['NASM-CPT', 'CISSN'],
      specialties: ['Hypertrophy', 'Nutrition'],
      hourlyRate: 2500.0,
      rating: 4.90,
      verified: true,
    ),
  ];

  final prodTrainers = [
    const TrainerProfile(
      id: 'trainer-1',
      userId: 'user-1',
      displayName: 'Marcus Vance',
      bio: 'Elite strength & conditioning coach specializing in powerlifting',
      certifications: ['CSCS', 'USAPL-Coach'],
      specialties: ['Strength', 'Powerlifting'],
      experienceYears: 7,
      hourlyRate: 1500.0,
      rating: 4.95,
      platformFeePct: 10.0,
      verified: true,
    ),
    const TrainerProfile(
      id: 'trainer-2',
      userId: 'user-2',
      displayName: 'Elena Rostova',
      bio: 'Registered yoga instructor and mobility specialist',
      certifications: ['RYT-500'],
      specialties: ['Yoga', 'Mobility'],
      experienceYears: 4,
      hourlyRate: 800.0,
      rating: 4.80,
      platformFeePct: 10.0,
      verified: true,
    ),
    const TrainerProfile(
      id: 'trainer-3',
      userId: 'user-3',
      displayName: 'Devon Hayes',
      bio: 'Bodybuilding & hypertrophy specialist with nutrition focus',
      certifications: ['NASM-CPT', 'CISSN'],
      specialties: ['Hypertrophy', 'Nutrition'],
      experienceYears: 6,
      hourlyRate: 2500.0,
      rating: 4.90,
      platformFeePct: 10.0,
      verified: true,
    ),
  ];

  setUp(TrainerService.resetMockTrainers);

  group('TrainerProfile Model Serialization Tests', () {
    test('serializes and deserializes TrainerProfileData faithfully', () {
      final trainer = sampleTrainers[0];
      final jsonMap = trainer.toJson();

      expect(jsonMap['id'], 'trainer-1');
      expect(jsonMap['hourly_rate'], 1500.0);
      expect(jsonMap['specialties'], contains('Strength'));
      expect(jsonMap['platform_fee_pct'], 10.0);

      final reconstructed = TrainerProfileData.fromJson(jsonMap);
      expect(reconstructed.id, trainer.id);
      expect(reconstructed.hourlyRate, trainer.hourlyRate);
      expect(reconstructed.rating, trainer.rating);
      expect(reconstructed.specialties, trainer.specialties);
    });

    test('serializes and deserializes production TrainerProfile faithfully', () {
      final trainer = prodTrainers[0];
      final jsonMap = trainer.toJson();

      expect(jsonMap['id'], 'trainer-1');
      expect(jsonMap['user_id'], 'user-1');
      expect(jsonMap['hourly_rate'], 1500.0);
      expect(jsonMap['display_name'], 'Marcus Vance');
      expect(jsonMap['platform_fee_pct'], 10.0);
      expect(jsonMap['verified'], true);

      final reconstructed = TrainerProfile.fromJson(jsonMap);
      expect(reconstructed.id, trainer.id);
      expect(reconstructed.userId, trainer.userId);
      expect(reconstructed.displayName, trainer.displayName);
      expect(reconstructed.hourlyRate, trainer.hourlyRate);
      expect(reconstructed.rating, trainer.rating);
      expect(reconstructed.specialties, trainer.specialties);
      expect(reconstructed.experienceYears, 7);
    });

    test('extracts joined profile display_name from PostgREST map', () {
      final postgrestJson = {
        'id': 'trainer-joined-1',
        'user_id': 'user-joined-1',
        'bio': 'PostgREST join test bio',
        'certifications': ['CSCS'],
        'specialties': ['Strength'],
        'experience_years': 5,
        'hourly_rate': 1200.0,
        'rating': 4.9,
        'platform_fee_pct': 10.0,
        'verified': true,
        'profiles': {'display_name': 'Coach Joined Name'},
      };

      final profile = TrainerProfile.fromJson(postgrestJson);
      expect(profile.displayName, 'Coach Joined Name');
      expect(profile.initials, 'CJ');
    });

    test('computes accurate platform fee amount and net trainer payout', () {
      // 10% fee on 1500
      final trainer1 = prodTrainers[0];
      expect(trainer1.platformFeeAmountPerHour, 150.0);
      expect(trainer1.trainerPayoutPerHour, 1350.0);
      expect(
        trainer1.hourlyRate,
        trainer1.platformFeeAmountPerHour + trainer1.trainerPayoutPerHour,
      );

      // Custom 15% fee on 2500
      final customTrainer = prodTrainers[2].copyWith(platformFeePct: 15.0);
      expect(customTrainer.platformFeeAmountPerHour, 375.0);
      expect(customTrainer.trainerPayoutPerHour, 2125.0);
      expect(
        customTrainer.hourlyRate,
        customTrainer.platformFeeAmountPerHour + customTrainer.trainerPayoutPerHour,
      );

      // Fractional rate rounding check
      const fractionalTrainer = TrainerProfile(
        id: 'frac-1',
        userId: 'frac-user',
        hourlyRate: 199.99,
        platformFeePct: 10.0,
      );
      expect(fractionalTrainer.platformFeeAmountPerHour, 20.00);
      expect(fractionalTrainer.trainerPayoutPerHour, 179.99);
    });

    test('formats displayPrice and extracts initials correctly', () {
      final t1 = prodTrainers[0];
      expect(t1.displayPrice, '₹1500/hr');
      expect(t1.initials, 'MV');

      // Single word name
      final singleName = t1.copyWith(displayName: 'Vance');
      expect(singleName.initials, 'VA');

      // Empty / null name fallback
      final nullName = t1.copyWith(displayName: '');
      expect(nullName.initials, 'TR');
    });
  });

  group('Trainer Discovery & Filter Criteria Tests', () {
    test('returns all trainers when no filters are applied', () {
      const criteria = TrainerFilterCriteria();
      final filtered = sampleTrainers.where(criteria.matches).toList();
      expect(filtered.length, 3);
    });

    test('filters trainers by specialty chip', () {
      const criteria = TrainerFilterCriteria(selectedSpecialty: 'Yoga');
      final filtered = sampleTrainers.where(criteria.matches).toList();
      expect(filtered.length, 1);
      expect(filtered[0].id, 'trainer-2');
    });

    test('filters trainers by price range ceiling', () {
      const criteria = TrainerFilterCriteria(maxHourlyRate: 1000.0);
      final filtered = sampleTrainers.where(criteria.matches).toList();
      expect(filtered.length, 1);
      expect(filtered[0].id, 'trainer-2');
      expect(filtered[0].hourlyRate, 800.0);
    });

    test('filters trainers by search query keyword', () {
      const criteria = TrainerFilterCriteria(searchQuery: 'powerlifting');
      final filtered = sampleTrainers.where(criteria.matches).toList();
      expect(filtered.length, 1);
      expect(filtered[0].id, 'trainer-1');
    });

    test('filters trainers by minimum rating threshold', () {
      const criteria = TrainerFilterCriteria(minRating: 4.92);
      final filtered = sampleTrainers.where(criteria.matches).toList();
      expect(filtered.length, 1);
      expect(filtered[0].id, 'trainer-1');
      expect(filtered[0].rating, 4.95);
    });

    test('combines multiple filter criteria (specialty + max rate)', () {
      const criteria = TrainerFilterCriteria(
        selectedSpecialty: 'Strength',
        maxHourlyRate: 1200.0, // trainer 1 is 1500
      );
      final filtered = sampleTrainers.where(criteria.matches).toList();
      expect(filtered.isEmpty, isTrue);
    });

    test('filters production TrainerProfile instances by display name keyword', () {
      const criteria = TrainerFilterCriteria(searchQuery: 'Elena');
      final filtered = prodTrainers.where(criteria.matches).toList();
      expect(filtered.length, 1);
      expect(filtered[0].displayName, 'Elena Rostova');
    });

    test('treats selectedSpecialty All as non-filtering', () {
      const criteria = TrainerFilterCriteria(selectedSpecialty: 'All');
      final filtered = prodTrainers.where(criteria.matches).toList();
      expect(filtered.length, 3);
    });

    test('copyWith allows clearing criteria values', () {
      const criteria = TrainerFilterCriteria(
        searchQuery: 'Strength',
        selectedSpecialty: 'Strength',
        maxHourlyRate: 2000.0,
        minRating: 4.5,
      );
      expect(criteria.isEmpty, isFalse);

      final cleared = criteria.copyWith(
        clearSearchQuery: true,
        clearSpecialty: true,
        clearMaxHourlyRate: true,
        clearMinRating: true,
      );
      expect(cleared.isEmpty, isTrue);
    });
  });

  group('TrainerBloc State Management & Transitions Tests', () {
    test('initial state is TrainerInitial', () {
      final bloc = TrainerBloc();
      expect(bloc.state, const TrainerInitial());
      bloc.close();
    });

    test('emits [TrainerLoading, TrainerLoaded] when LoadTrainers succeeds', () async {
      final bloc = TrainerBloc();
      expectLater(
        bloc.stream,
        emitsInOrder([
          const TrainerLoading(),
          isA<TrainerLoaded>().having(
            (s) => s.allTrainers.length,
            'allTrainers count',
            greaterThanOrEqualTo(3),
          ),
        ]),
      );

      bloc.add(const LoadTrainers());
      await pumpEventQueue();
      await bloc.close();
    });

    test('emits [TrainerLoading, TrainerError] when LoadTrainers service throws', () async {
      final bloc = TrainerBloc(trainerService: _ErrorTrainerService());
      expectLater(
        bloc.stream,
        emitsInOrder([
          const TrainerLoading(),
          isA<TrainerError>().having(
            (s) => s.message,
            'error message',
            contains('Database query failed'),
          ),
        ]),
      );

      bloc.add(const LoadTrainers());
      await pumpEventQueue();
      await bloc.close();
    });

    test('FilterTrainers updates filteredTrainers without modifying allTrainers', () async {
      final bloc = TrainerBloc();
      bloc.add(const LoadTrainers());
      await pumpEventQueue();

      expect(bloc.state, isA<TrainerLoaded>());
      final loadedBefore = bloc.state as TrainerLoaded;
      final totalCount = loadedBefore.allTrainers.length;

      // Filter by Yoga specialty
      bloc.add(const FilterTrainers(
        TrainerFilterCriteria(selectedSpecialty: 'Yoga'),
      ));
      await pumpEventQueue();

      final loadedAfter = bloc.state as TrainerLoaded;
      expect(loadedAfter.allTrainers.length, totalCount);
      expect(loadedAfter.filteredTrainers.length, 1);
      expect(loadedAfter.filteredTrainers[0].specialties, contains('Yoga'));
      expect(loadedAfter.hasActiveFilter, isTrue);

      await bloc.close();
    });

    test('FilterTrainers filters by hourly rate ceiling', () async {
      final bloc = TrainerBloc();
      bloc.add(const LoadTrainers());
      await pumpEventQueue();

      bloc.add(const FilterTrainers(
        TrainerFilterCriteria(maxHourlyRate: 1000.0),
      ));
      await pumpEventQueue();

      final state = bloc.state as TrainerLoaded;
      expect(state.filteredTrainers.every((t) => t.hourlyRate <= 1000.0), isTrue);

      await bloc.close();
    });

    test('ResetTrainerFilter restores all trainers to filtered list', () async {
      final bloc = TrainerBloc();
      bloc.add(const LoadTrainers());
      await pumpEventQueue();

      // Apply a narrow filter
      bloc.add(const FilterTrainers(
        TrainerFilterCriteria(selectedSpecialty: 'Yoga'),
      ));
      await pumpEventQueue();
      expect((bloc.state as TrainerLoaded).filteredTrainers.length, 1);

      // Reset
      bloc.add(const ResetTrainerFilter());
      await pumpEventQueue();

      final state = bloc.state as TrainerLoaded;
      expect(state.filteredTrainers.length, state.allTrainers.length);
      expect(state.hasActiveFilter, isFalse);

      await bloc.close();
    });

    test('SelectTrainer updates selectedTrainer in TrainerLoaded state', () async {
      final bloc = TrainerBloc();
      bloc.add(const LoadTrainers());
      await pumpEventQueue();

      final trainer = (bloc.state as TrainerLoaded).allTrainers.first;
      bloc.add(SelectTrainer(trainer));
      await pumpEventQueue();

      final state = bloc.state as TrainerLoaded;
      expect(state.selectedTrainer, trainer);

      // Deselect
      bloc.add(const SelectTrainer(null));
      await pumpEventQueue();
      final deselectedState = bloc.state as TrainerLoaded;
      expect(deselectedState.selectedTrainer, isNull);

      await bloc.close();
    });

    test('RegisterTrainer emits [TrainerLoading, TrainerOperationSuccess] and reloads', () async {
      final bloc = TrainerBloc();
      bloc.add(const LoadTrainers());
      await pumpEventQueue();

      bloc.add(const RegisterTrainer(
        bio: 'Certified powerlifter coaching high-level strength athletes.',
        certifications: ['USAPL-L2'],
        specialties: ['Powerlifting', 'Strength'],
        experienceYears: 5,
        hourlyRate: 1800.0,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<TrainerLoading>(),
          isA<TrainerOperationSuccess>().having(
            (s) => s.message,
            'success message',
            contains('successfully'),
          ),
          isA<TrainerLoading>(),
          isA<TrainerLoaded>(),
        ]),
      );

      await bloc.close();
    });

    test('RegisterTrainer emits TrainerError when registration fails', () async {
      final bloc = TrainerBloc(trainerService: _ErrorTrainerService());

      bloc.add(const RegisterTrainer(
        bio: 'Some bio description here',
        certifications: ['CSCS'],
        specialties: ['Strength'],
        experienceYears: 2,
        hourlyRate: 1000.0,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<TrainerLoading>(),
          isA<TrainerError>().having(
            (s) => s.message,
            'error message',
            contains('permission denied'),
          ),
        ]),
      );

      await bloc.close();
    });

    test('UpdateTrainerProfile emits [TrainerLoading, TrainerOperationSuccess] and reloads', () async {
      final bloc = TrainerBloc();
      bloc.add(const LoadTrainers());
      await pumpEventQueue();

      final existing = (bloc.state as TrainerLoaded).allTrainers.first;
      final updated = existing.copyWith(
        bio: 'Updated bio information with more coaching details.',
        hourlyRate: 1600.0,
      );

      bloc.add(UpdateTrainerProfile(updated));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<TrainerLoading>(),
          isA<TrainerOperationSuccess>().having(
            (s) => s.message,
            'success message',
            contains('updated successfully'),
          ),
          isA<TrainerLoading>(),
          isA<TrainerLoaded>(),
        ]),
      );

      await bloc.close();
    });

    test('UpdateTrainerProfile emits TrainerError when update fails', () async {
      final bloc = TrainerBloc(trainerService: _ErrorTrainerService());

      bloc.add(UpdateTrainerProfile(prodTrainers[0]));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<TrainerLoading>(),
          isA<TrainerError>().having(
            (s) => s.message,
            'error message',
            contains('trigger constraint violation'),
          ),
        ]),
      );

      await bloc.close();
    });
  });

  group('TrainerService CRUD & Resilience Tests', () {
    test('getTrainers returns mock data when Supabase is uninitialized', () async {
      final service = TrainerService();
      final trainers = await service.getTrainers();

      expect(trainers.isNotEmpty, isTrue);
      expect(trainers.any((t) => t.specialties.contains('Strength')), isTrue);
    });

    test('getTrainerById finds trainer by UUID in mock catalog', () async {
      final service = TrainerService();
      final trainer = await service.getTrainerById('trainer-1');

      expect(trainer, isNotNull);
      expect(trainer!.id, 'trainer-1');
      expect(trainer.hourlyRate, 1500.0);
    });

    test('registerTrainerProfile creates trainer and updates mock catalog', () async {
      final service = TrainerService();
      final created = await service.registerTrainerProfile(
        userId: 'new-coach-user',
        displayName: 'Coach Taylor',
        bio: 'Track and field coach specializing in athletic sprint development.',
        certifications: const ['USATF-L1'],
        specialties: const ['HIIT', 'Mobility'],
        experienceYears: 4,
        hourlyRate: 1400.0,
      );

      expect(created.id, startsWith('local-'));
      expect(created.userId, 'new-coach-user');
      expect(created.displayName, 'Coach Taylor');
      expect(created.hourlyRate, 1400.0);
      expect(created.platformFeeAmountPerHour, 140.0);
      expect(created.trainerPayoutPerHour, 1260.0);

      // Verify searchable via getTrainerByUserId
      final retrieved = await service.getTrainerByUserId('new-coach-user');
      expect(retrieved, isNotNull);
      expect(retrieved!.displayName, 'Coach Taylor');
    });

    test('updateTrainerProfile updates mutable properties in mock catalog', () async {
      final service = TrainerService();
      final updated = await service.updateTrainerProfile(
        'user-coach-bob',
        displayName: 'Bob Senior Coach',
        hourlyRate: 1750.0,
        bio: 'Updated bio description for Bob',
      );

      expect(updated.displayName, 'Bob Senior Coach');
      expect(updated.hourlyRate, 1750.0);
      expect(updated.rating, 4.95); // Rating preserved!
      expect(updated.platformFeePct, 10.0); // Fee percentage preserved!
    });
  });
}
