import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'package:collection/collection.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/services/exercise_service.dart';
import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/workout/services/supabase_workout_service.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider({required WorkoutHistoryRepository historyRepository})
    : _historyRepository = historyRepository;

  final WorkoutHistoryRepository _historyRepository;

  WorkoutSession? _activeSession;
  Timer? _workoutTimer;
  Duration _workoutDuration = Duration.zero;
  bool _isPaused = false;

  // Rest Timer State
  Timer? _restTimer;
  bool _isResting = false;
  int _currentRestSeconds = 0;
  final int _restTimerDuration = 90; // Default 90 seconds

  WorkoutHistoryRepository get historyRepository => _historyRepository;

  // Last-performed data for display in UI
  // Maps exerciseId → list of completed sets from last session
  Map<String, List<ExerciseSet>> _previousSets = {};

  WorkoutSession? get activeSession => _activeSession;
  bool get hasActiveWorkout => _activeSession != null;
  Duration get workoutDuration => _workoutDuration;
  bool get isPaused => _isPaused;

  bool get isResting => _isResting;
  int get currentRestSeconds => _currentRestSeconds;
  Map<String, List<ExerciseSet>> get previousSets => _previousSets;

  void startWorkout(WorkoutRoutine routine, WorkoutDay day) {
    if (_activeSession != null) return;

    // Look up last session for this routine+day to autofill
    final lastSession = _historyRepository.getLastSession(
      routineId: routine.id,
      dayId: day.id,
    );

    // Build a map of exerciseId → last completed sets
    _previousSets = {};
    if (lastSession != null) {
      for (final ex in lastSession.exercises) {
        if (!ex.isSkipped) {
          final completed = ex.sets.where((s) => s.isCompleted).toList();
          if (completed.isNotEmpty) {
            _previousSets[ex.exerciseId] = completed;
          }
        }
      }
    }

    final sessionExercises = day.exercises.map((routineEx) {
      // Get previous sets for this exercise (from last session)
      final prevSets = _previousSets[routineEx.exerciseId];

      final sets = List.generate(
        routineEx.sets,
        (index) {
          // Autofill: use last session's weight/reps if available
          final prevSet = (prevSets != null && index < prevSets.length)
              ? prevSets[index]
              : null;

          return ExerciseSet(
            id: const Uuid().v4(),
            targetReps: prevSet?.completedReps ?? routineEx.reps,
            targetWeight: prevSet?.completedWeight ?? 0,
          );
        },
      );

      return SessionExercise(
        id: const Uuid().v4(),
        exerciseId: routineEx.exerciseId,
        sets: sets,
      );
    }).toList();

    _activeSession = WorkoutSession(
      id: const Uuid().v4(),
      routineId: routine.id,
      dayId: day.id,
      startTime: DateTime.now(),
      exercises: sessionExercises,
      routineName: routine.name,
    );

    _workoutDuration = Duration.zero;

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _workoutTimer?.cancel();
    _isPaused = false;
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _workoutDuration = _workoutDuration + const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  void pauseWorkout() {
    _isPaused = true;
    notifyListeners();
  }

  void resumeWorkout() {
    _isPaused = false;
    notifyListeners();
  }

  /// Finish the workout and save it to history.
  Future<void> finishWorkout() async {
    _workoutTimer?.cancel();
    _stopRestTimer();
    if (_activeSession != null) {
      final now = DateTime.now();
      // Compute durationSeconds and totalVolume based on completed sets
      final duration = now.difference(_activeSession!.startTime).inSeconds;
      double totalVol = 0;
      var totalReps = 0;
      for (final ex in _activeSession!.exercises) {
        if (ex.isSkipped) continue;
        for (final set in ex.sets) {
          if (set.isCompleted && set.completedReps != null) {
            totalReps += set.completedReps!;
            if (set.completedWeight != null) {
              totalVol += set.completedReps! * set.completedWeight!;
            }
          }
        }
      }
      final finishedSession = WorkoutSession(
        id: _activeSession!.id,
        routineId: _activeSession!.routineId,
        dayId: _activeSession!.dayId,
        routineName: _activeSession!.routineName,
        startTime: _activeSession!.startTime,
        endTime: now,
        exercises: _activeSession!.exercises,
        durationSeconds: duration,
        totalVolume: totalVol,
        totalReps: totalReps,
      );
      // Save to local history for autofill and future stats
      await _historyRepository.save(finishedSession);
      // Background sync to Supabase if configured
      unawaited(SupabaseWorkoutService.syncWorkoutSession(finishedSession));
      // After persisting, compute the volume distribution for the chart
      await _computeMuscleVolume();
    }
    _activeSession = null;
    _workoutDuration = Duration.zero;
    _isPaused = false;
    _previousSets = {};
    notifyListeners();
  }

  /// Cancel the workout without saving.
  void cancelWorkout() {
    _workoutTimer?.cancel();
    _stopRestTimer();

    _activeSession = null;
    _workoutDuration = Duration.zero;
    _isPaused = false;
    _previousSets = {};
    notifyListeners();
  }

  void toggleSetComplete(String sessionExerciseId, String setId) {
    if (_activeSession == null) return;

    final exercises = _activeSession!.exercises.map((ex) {
      if (ex.id != sessionExerciseId) return ex;

      final updatedSets = ex.sets.map((set) {
        if (set.id != setId) return set;
        return set.copyWith(
          isCompleted: !set.isCompleted,
          completedReps: set.isCompleted
              ? null
              : (set.completedReps ?? set.targetReps),
          completedWeight: set.isCompleted
              ? null
              : (set.completedWeight ?? set.targetWeight),
        );
      }).toList();

      return ex.copyWith(sets: updatedSets);
    }).toList();

    _activeSession = _activeSession!.copyWith(exercises: exercises);

    // Check if we just completed a set, and start rest timer if so
    final wasCompleted = exercises
        .firstWhere((e) => e.id == sessionExerciseId)
        .sets
        .firstWhere((s) => s.id == setId)
        .isCompleted;

    if (wasCompleted) {
      _startRestTimer();
    } else {
      _stopRestTimer();
    }

    notifyListeners();
  }

  void updateSetValues(
    String sessionExerciseId,
    String setId, {
    int? reps,
    double? weight,
  }) {
    if (_activeSession == null) return;

    final exercises = _activeSession!.exercises.map((ex) {
      if (ex.id != sessionExerciseId) return ex;

      final updatedSets = ex.sets.map((set) {
        if (set.id != setId) return set;
        return set.copyWith(
          completedReps: reps ?? set.completedReps,
          completedWeight: weight ?? set.completedWeight,
        );
      }).toList();

      return ex.copyWith(sets: updatedSets);
    }).toList();

    _activeSession = _activeSession!.copyWith(exercises: exercises);
    notifyListeners();
  }

  void skipExercise(String sessionExerciseId) {
    if (_activeSession == null) return;

    final exercises = _activeSession!.exercises.map((ex) {
      if (ex.id != sessionExerciseId) return ex;
      return ex.copyWith(isSkipped: true);
    }).toList();

    _activeSession = _activeSession!.copyWith(exercises: exercises);
    notifyListeners();
  }

  void unskipExercise(String sessionExerciseId) {
    if (_activeSession == null) return;

    final exercises = _activeSession!.exercises.map((ex) {
      if (ex.id != sessionExerciseId) return ex;
      return ex.copyWith(isSkipped: false);
    }).toList();

    _activeSession = _activeSession!.copyWith(exercises: exercises);
    notifyListeners();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _isResting = true;
    _currentRestSeconds = _restTimerDuration;

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRestSeconds > 0) {
        _currentRestSeconds--;
        notifyListeners();
      } else {
        _stopRestTimer();
      }
    });
    notifyListeners();
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _isResting = false;
    _currentRestSeconds = 0;
    notifyListeners();
  }

  void skipRest() {
    _stopRestTimer();
  }

  void adjustRestTime(int seconds) {
    if (!_isResting) return;
    _currentRestSeconds += seconds;
    if (_currentRestSeconds <= 0) {
      _stopRestTimer();
    } else {
      notifyListeners();
    }
  }

  // Compute muscle volume for the last session
  Future<void> _computeMuscleVolume() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final exercises = await ExerciseService.loadExercises()
          .timeout(const Duration(milliseconds: 500));
      final volumeMap = <String, double>{};
      _previousSets.forEach((exerciseId, sets) {
        final Exercise? exercise = exercises.firstWhereOrNull((e) => e.id == exerciseId);
        if (exercise == null) return;
        final muscle = exercise.muscleGroup;
        double total = 0;
        for (final set in sets) {
          final reps = set.completedReps ?? set.targetReps;
          final weight = set.completedWeight ?? set.targetWeight ?? 0;
          total += reps * weight;
        }
        volumeMap.update(muscle, (v) => v + total, ifAbsent: () => total);
      });
      _muscleVolume = volumeMap;
    } catch (_) {
      // Safe fallback if exercises asset is unavailable in test environment
    }
  }

  Map<String, double> get muscleVolume => _muscleVolume;
  Map<String, double> _muscleVolume = {};

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // ---------- New grouping getters ----------

  /// Sessions grouped by the date they finished (or started if endTime is null).
  /// The map keys are midnight UTC DateTime values, ordered newest first.
  Map<DateTime, List<WorkoutSession>> get sessionsByDay {
    final map = SplayTreeMap<DateTime, List<WorkoutSession>>(
      (a, b) => b.compareTo(a), // descending order
    );
    for (final s in _historyRepository.getAll()) {
      final dt = s.endTime ?? s.startTime;
      final day = DateTime(dt.year, dt.month, dt.day);
      map.putIfAbsent(day, () => []).add(s);
    }
    return map;
  }

  /// Sessions grouped by routine identifier (fallback to routine name).
  Map<String, List<WorkoutSession>> get sessionsByRoutine {
    final map = <String, List<WorkoutSession>>{};
    for (final s in _historyRepository.getAll()) {
      final key = s.routineId.isNotEmpty ? s.routineId : (s.routineName ?? 'Unnamed');
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }
}
