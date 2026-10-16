import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';

/// Base event class for TrainerBloc.
abstract class TrainerEvent extends Equatable {
  const TrainerEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Dispatched to load the initial or refreshed list of trainers.
class LoadTrainers extends TrainerEvent {
  const LoadTrainers({this.forceRefresh = false});

  final bool forceRefresh;

  @override
  List<Object?> get props => <Object?>[forceRefresh];
}

/// Dispatched when search keyword, specialty chip, price slider, or rating
/// filter changes.
class FilterTrainers extends TrainerEvent {
  const FilterTrainers(this.criteria);

  final TrainerFilterCriteria criteria;

  @override
  List<Object?> get props => <Object?>[criteria];
}

/// Dispatched to reset all active filters to default.
class ResetTrainerFilter extends TrainerEvent {
  const ResetTrainerFilter();
}

/// Dispatched when a user taps a trainer to view details.
class SelectTrainer extends TrainerEvent {
  const SelectTrainer(this.trainer);

  final TrainerProfile? trainer;

  @override
  List<Object?> get props => <Object?>[trainer];
}

/// Dispatched when an authenticated user registers as a new personal trainer.
class RegisterTrainer extends TrainerEvent {
  const RegisterTrainer({
    required this.bio,
    required this.certifications,
    required this.specialties,
    required this.experienceYears,
    required this.hourlyRate,
    this.availability,
  });

  final String bio;
  final List<String> certifications;
  final List<String> specialties;
  final int experienceYears;
  final double hourlyRate;
  final Map<String, dynamic>? availability;

  @override
  List<Object?> get props => <Object?>[
        bio,
        certifications,
        specialties,
        experienceYears,
        hourlyRate,
        availability,
      ];
}

/// Dispatched when a trainer updates their existing profile details.
class UpdateTrainerProfile extends TrainerEvent {
  const UpdateTrainerProfile(this.profile);

  final dynamic profile;

  @override
  List<Object?> get props => <Object?>[profile];
}
