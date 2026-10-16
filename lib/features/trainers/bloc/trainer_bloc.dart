import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_event.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_state.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';

/// Business Logic Component managing trainer discovery, multi-criteria
/// filtering, profile registration, and profile updates.
class TrainerBloc extends Bloc<TrainerEvent, TrainerState> {
  TrainerBloc({TrainerService? trainerService})
      : _trainerService = trainerService ?? TrainerService(),
        super(const TrainerInitial()) {
    on<LoadTrainers>(_onLoadTrainers);
    on<FilterTrainers>(_onFilterTrainers);
    on<ResetTrainerFilter>(_onResetTrainerFilter);
    on<SelectTrainer>(_onSelectTrainer);
    on<RegisterTrainer>(_onRegisterTrainer);
    on<UpdateTrainerProfile>(_onUpdateTrainerProfile);
  }

  final TrainerService _trainerService;

  TrainerService get service => _trainerService;

  /// Internal state cache preserving filter and selection across operations
  /// and in-flight reloads.
  TrainerFilterCriteria _activeFilter = const TrainerFilterCriteria();
  TrainerProfile? _selectedTrainer;
  List<TrainerProfile> _cachedTrainers = const <TrainerProfile>[];

  TrainerFilterCriteria get activeFilter => _activeFilter;
  TrainerProfile? get selectedTrainer => _selectedTrainer;
  List<TrainerProfile> get cachedTrainers => _cachedTrainers;

  /// Handles fetching the list of trainers and the current user's profile.
  /// Catches both [Exception] and [Error] (e.g. [TypeError]) to guarantee
  /// the BLoC never stalls in [TrainerLoading].
  Future<void> _onLoadTrainers(
    LoadTrainers event,
    Emitter<TrainerState> emit,
  ) async {
    // If state is already TrainerLoaded, synchronize internal tracking fields
    if (state is TrainerLoaded) {
      final loaded = state as TrainerLoaded;
      _activeFilter = loaded.currentFilter;
      _selectedTrainer = loaded.selectedTrainer;
      _cachedTrainers = loaded.allTrainers;
    }

    emit(const TrainerLoading());

    try {
      final trainers = await _trainerService.getTrainers(
        forceRefresh: event.forceRefresh,
      );
      _cachedTrainers = trainers;

      TrainerProfile? myProfile;
      try {
        myProfile = await _trainerService.getMyTrainerProfile();
      } on Object catch (_) {
        myProfile = null;
      }

      // Dynamically evaluate against _activeFilter, which may have been
      // updated while getTrainers() was in-flight
      final filtered = trainers.where(_activeFilter.matches).toList();

      emit(
        TrainerLoaded(
          allTrainers: trainers,
          filteredTrainers: filtered,
          currentFilter: _activeFilter,
          selectedTrainer: _selectedTrainer,
          myProfile: myProfile,
        ),
      );
    } on Object catch (e) {
      emit(
        TrainerError(
          'Failed to load trainers: $e',
          previousTrainers: _cachedTrainers.isNotEmpty ? _cachedTrainers : null,
        ),
      );
    }
  }

  /// Handles search query, specialty chip, price slider, and rating filters.
  void _onFilterTrainers(
    FilterTrainers event,
    Emitter<TrainerState> emit,
  ) {
    _activeFilter = event.criteria;
    if (state is TrainerLoaded) {
      final currentState = state as TrainerLoaded;
      try {
        final filtered =
            currentState.allTrainers.where(event.criteria.matches).toList();

        emit(
          currentState.copyWith(
            filteredTrainers: filtered,
            currentFilter: event.criteria,
          ),
        );
      } on Object catch (e) {
        emit(TrainerError('Filter failed: $e'));
      }
    }
  }

  /// Resets all filters back to default.
  void _onResetTrainerFilter(
    ResetTrainerFilter event,
    Emitter<TrainerState> emit,
  ) {
    _activeFilter = const TrainerFilterCriteria();
    if (state is TrainerLoaded) {
      final currentState = state as TrainerLoaded;
      emit(
        currentState.copyWith(
          filteredTrainers: currentState.allTrainers,
          currentFilter: const TrainerFilterCriteria(),
        ),
      );
    }
  }

  /// Selects a trainer for detail view navigation.
  void _onSelectTrainer(
    SelectTrainer event,
    Emitter<TrainerState> emit,
  ) {
    _selectedTrainer = event.trainer;
    if (state is TrainerLoaded) {
      final currentState = state as TrainerLoaded;
      emit(
        currentState.copyWith(
          selectedTrainer: () => event.trainer,
        ),
      );
    }
  }

  /// Registers an authenticated user as a trainer.
  /// Catches all errors and preserves filter state across reload.
  Future<void> _onRegisterTrainer(
    RegisterTrainer event,
    Emitter<TrainerState> emit,
  ) async {
    if (state is TrainerLoaded) {
      _activeFilter = (state as TrainerLoaded).currentFilter;
      _selectedTrainer = (state as TrainerLoaded).selectedTrainer;
    }

    emit(const TrainerLoading(message: 'Registering trainer profile...'));

    try {
      final profile = await _trainerService.registerTrainer(
        bio: event.bio,
        certifications: event.certifications,
        specialties: event.specialties,
        experienceYears: event.experienceYears,
        hourlyRate: event.hourlyRate,
        availability: event.availability,
      );

      emit(
        TrainerOperationSuccess(
          'Trainer profile registered successfully!',
          profile: profile,
        ),
      );

      add(const LoadTrainers(forceRefresh: true));
    } on Object catch (e) {
      emit(TrainerError('Registration failed: $e'));
    }
  }

  /// Updates an existing trainer profile.
  /// Catches all errors and preserves filter state across reload.
  Future<void> _onUpdateTrainerProfile(
    UpdateTrainerProfile event,
    Emitter<TrainerState> emit,
  ) async {
    if (state is TrainerLoaded) {
      _activeFilter = (state as TrainerLoaded).currentFilter;
      _selectedTrainer = (state as TrainerLoaded).selectedTrainer;
    }

    emit(const TrainerLoading(message: 'Updating profile...'));

    try {
      final updated = await _trainerService.updateTrainerProfile(event.profile);

      emit(
        TrainerOperationSuccess(
          'Profile updated successfully!',
          profile: updated,
        ),
      );

      add(const LoadTrainers(forceRefresh: true));
    } on Object catch (e) {
      emit(TrainerError('Update failed: $e'));
    }
  }
}
