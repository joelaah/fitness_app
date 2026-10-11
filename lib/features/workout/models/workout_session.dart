import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_session.freezed.dart';
part 'workout_session.g.dart';

@freezed
abstract class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required String routineId,
    required String dayId,
    required DateTime startTime,
    DateTime? endTime,
    @Default([]) List<SessionExercise> exercises,
    String? routineName,
    int? durationSeconds,
    double? totalVolume,
    int? totalReps,
  }) = _WorkoutSession;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSessionFromJson(json);
}

@freezed
abstract class SessionExercise with _$SessionExercise {
  const factory SessionExercise({
    required String id,
    required String exerciseId,
    @Default([]) List<ExerciseSet> sets,
    @Default(false) bool isSkipped,
  }) = _SessionExercise;

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      _$SessionExerciseFromJson(json);
}

@freezed
abstract class ExerciseSet with _$ExerciseSet {
  const factory ExerciseSet({
    required String id,
    required int targetReps,
    required double targetWeight,
    int? completedReps,
    double? completedWeight,
    @Default(false) bool isCompleted,
  }) = _ExerciseSet;

  factory ExerciseSet.fromJson(Map<String, dynamic> json) =>
      _$ExerciseSetFromJson(json);
}
