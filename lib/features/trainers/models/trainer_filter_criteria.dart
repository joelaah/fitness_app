import 'package:equatable/equatable.dart';

/// Abstract interface for any trainer entity that can be filtered.
abstract class FilterableTrainer {
  String get bio;
  List<String> get specialties;
  double get hourlyRate;
  double get rating;
  String? get displayName;
}

/// Filter criteria for Trainer Discovery Screen.
class TrainerFilterCriteria extends Equatable {
  const TrainerFilterCriteria({
    this.searchQuery,
    this.selectedSpecialty,
    this.maxHourlyRate,
    this.minRating,
  });

  final String? searchQuery;
  final String? selectedSpecialty;
  final double? maxHourlyRate;
  final double? minRating;

  /// True if no filters are active.
  bool get isEmpty =>
      (searchQuery == null || searchQuery!.trim().isEmpty) &&
      (selectedSpecialty == null ||
          selectedSpecialty!.isEmpty ||
          selectedSpecialty == 'All') &&
      maxHourlyRate == null &&
      minRating == null;

  /// Returns a copy of this criteria with updated fields.
  TrainerFilterCriteria copyWith({
    String? searchQuery,
    String? selectedSpecialty,
    double? maxHourlyRate,
    double? minRating,
    bool clearSearchQuery = false,
    bool clearSpecialty = false,
    bool clearMaxHourlyRate = false,
    bool clearMinRating = false,
  }) {
    return TrainerFilterCriteria(
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      selectedSpecialty:
          clearSpecialty ? null : (selectedSpecialty ?? this.selectedSpecialty),
      maxHourlyRate:
          clearMaxHourlyRate ? null : (maxHourlyRate ?? this.maxHourlyRate),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
    );
  }

  /// Evaluates whether a given trainer matches this filter criteria.
  bool matches(FilterableTrainer trainer) {
    final bio = trainer.bio;
    final specialties = trainer.specialties;
    final hourlyRate = trainer.hourlyRate;
    final rating = trainer.rating;
    final displayName = trainer.displayName ?? '';

    // 1. Keyword search (case-insensitive across bio, specialties,
    // display name)
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) {
      final q = searchQuery!.trim().toLowerCase();
      final bioMatch = bio.toLowerCase().contains(q);
      final specialtyMatch =
          specialties.any((s) => s.toLowerCase().contains(q));
      final nameMatch = displayName.toLowerCase().contains(q);
      if (!bioMatch && !specialtyMatch && !nameMatch) return false;
    }

    // 2. Specialty chip filter
    if (selectedSpecialty != null &&
        selectedSpecialty!.isNotEmpty &&
        selectedSpecialty != 'All') {
      if (!specialties.contains(selectedSpecialty)) return false;
    }

    // 3. Hourly rate ceiling slider
    if (maxHourlyRate != null) {
      if (hourlyRate > maxHourlyRate!) return false;
    }

    // 4. Minimum rating threshold
    if (minRating != null) {
      if (rating < minRating!) return false;
    }

    return true;
  }

  @override
  List<Object?> get props => <Object?>[
        searchQuery,
        selectedSpecialty,
        maxHourlyRate,
        minRating,
      ];
}
