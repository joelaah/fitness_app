import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';

/// Trainer Profile model matching PROJECT.md and Supabase schema.
class TrainerProfile extends Equatable implements FilterableTrainer {
  const TrainerProfile({
    required this.id,
    required this.userId,
    required this.hourlyRate,
    this.bio = '',
    this.certifications = const <String>[],
    this.specialties = const <String>[],
    this.experienceYears = 0,
    this.rating = 5.0,
    this.platformFeePct = 10.0,
    this.verified = true,
    this.displayName,
    this.availability = const <String, dynamic>{
      'schedule': <dynamic>[],
      'active': true,
    },
    this.createdAt,
    this.updatedAt,
  });

  factory TrainerProfile.fromJson(Map<String, dynamic> json) {
    String? resolvedName;
    if (json['display_name'] is String &&
        (json['display_name'] as String).isNotEmpty) {
      resolvedName = json['display_name'] as String;
    } else if (json['profiles'] is Map) {
      resolvedName = (json['profiles'] as Map)['display_name'] as String?;
    }

    return TrainerProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      bio: (json['bio'] as String?) ?? '',
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      specialties: (json['specialties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      experienceYears: (json['experience_years'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      platformFeePct: (json['platform_fee_pct'] as num?)?.toDouble() ?? 10.0,
      verified: (json['verified'] as bool?) ??
          (json['is_verified'] as bool?) ??
          true,
      displayName: resolvedName,
      availability: json['availability'] is Map<String, dynamic>
          ? json['availability'] as Map<String, dynamic>
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String userId;
  @override
  final String bio;
  final List<String> certifications;
  @override
  final List<String> specialties;
  final int experienceYears;
  @override
  final double hourlyRate;
  @override
  final double rating;
  final double platformFeePct;
  final bool verified;
  @override
  final String? displayName;
  final Map<String, dynamic>? availability;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Platform fee amount in currency units (rounded to 2 decimal places)
  double get platformFeeAmountPerHour {
    final cut = platformFeePct / 100.0;
    return double.parse((hourlyRate * cut).toStringAsFixed(2));
  }

  /// True trainer payout after platform fee cut.
  /// Derived via exact subtraction to strictly enforce the
  /// mathematical invariant:
  /// hourlyRate == platformFeeAmountPerHour + trainerPayoutPerHour
  double get trainerPayoutPerHour {
    return double.parse(
      (hourlyRate - platformFeeAmountPerHour).toStringAsFixed(2),
    );
  }

  /// Formatted price string for UI
  String get displayPrice => '₹${hourlyRate.toStringAsFixed(0)}/hr';

  /// Trainer initials for avatar placeholders
  String get initials {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return 'TR';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Returns only text-based credentials (excluding uploaded document URLs)
  List<String> get textCertifications =>
      certifications.where((c) => !isAttachmentUrl(c)).toList();

  /// Returns uploaded certification document URLs
  List<String> get certificationUrls =>
      certifications.where(isAttachmentUrl).toList();

  /// Identifies whether a credential string is an attached file URL/data URI
  static bool isAttachmentUrl(String c) {
    final lower = c.trim().toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('mock://') ||
        lower.startsWith('trainer-certifications/') ||
        lower.contains('/trainer-certifications/');
  }


  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'bio': bio,
        'certifications': certifications,
        'specialties': specialties,
        'experience_years': experienceYears,
        'hourly_rate': hourlyRate,
        'rating': rating,
        'platform_fee_pct': platformFeePct,
        'verified': verified,
        'is_verified': verified,
        if (availability != null) 'availability': availability,
        if (displayName != null) 'display_name': displayName,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  TrainerProfile copyWith({
    String? id,
    String? userId,
    String? bio,
    List<String>? certifications,
    List<String>? specialties,
    int? experienceYears,
    double? hourlyRate,
    double? rating,
    double? platformFeePct,
    bool? verified,
    String? displayName,
    Map<String, dynamic>? availability,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainerProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      bio: bio ?? this.bio,
      certifications: certifications ?? this.certifications,
      specialties: specialties ?? this.specialties,
      experienceYears: experienceYears ?? this.experienceYears,
      rating: rating ?? this.rating,
      platformFeePct: platformFeePct ?? this.platformFeePct,
      verified: verified ?? this.verified,
      displayName: displayName ?? this.displayName,
      availability: availability ?? this.availability,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        userId,
        bio,
        certifications,
        specialties,
        experienceYears,
        hourlyRate,
        rating,
        platformFeePct,
        verified,
        displayName,
        availability,
      ];
}
