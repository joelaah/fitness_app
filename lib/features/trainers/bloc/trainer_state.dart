import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';

/// Base state class for TrainerBloc.
abstract class TrainerState extends Equatable {
  const TrainerState();

  @override
  List<Object?> get props => <Object?>[];
}

/// Initial state before any trainer data has been loaded.
class TrainerInitial extends TrainerState {
  const TrainerInitial();
}

/// State emitted while fetching trainers or executing a profile operation.
class TrainerLoading extends TrainerState {
  const TrainerLoading({this.message});

  final String? message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// State emitted when trainers have loaded successfully.
class TrainerLoaded extends TrainerState {
  const TrainerLoaded({
    required this.allTrainers,
    required this.filteredTrainers,
    this.currentFilter = const TrainerFilterCriteria(),
    this.selectedTrainer,
    this.myProfile,
  });

  final List<TrainerProfile> allTrainers;
  final List<TrainerProfile> filteredTrainers;
  final TrainerFilterCriteria currentFilter;
  final TrainerProfile? selectedTrainer;
  final TrainerProfile? myProfile;

  bool get hasActiveFilter => !currentFilter.isEmpty;

  TrainerLoaded copyWith({
    List<TrainerProfile>? allTrainers,
    List<TrainerProfile>? filteredTrainers,
    TrainerFilterCriteria? currentFilter,
    TrainerProfile? Function()? selectedTrainer,
    TrainerProfile? Function()? myProfile,
  }) {
    return TrainerLoaded(
      allTrainers: allTrainers ?? this.allTrainers,
      filteredTrainers: filteredTrainers ?? this.filteredTrainers,
      currentFilter: currentFilter ?? this.currentFilter,
      selectedTrainer:
          selectedTrainer != null ? selectedTrainer() : this.selectedTrainer,
      myProfile: myProfile != null ? myProfile() : this.myProfile,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        allTrainers,
        filteredTrainers,
        currentFilter,
        selectedTrainer,
        myProfile,
      ];
}

/// State emitted when an operation fails.
class TrainerError extends TrainerState {
  const TrainerError(this.message, {this.previousTrainers});

  final String message;
  final List<TrainerProfile>? previousTrainers;

  @override
  List<Object?> get props => <Object?>[message, previousTrainers];
}

/// State emitted when an asynchronous operation (register or update) succeeds.
class TrainerOperationSuccess extends TrainerState {
  const TrainerOperationSuccess(this.message, {this.profile});

  final String message;
  final TrainerProfile? profile;

  @override
  List<Object?> get props => <Object?>[message, profile];
}
