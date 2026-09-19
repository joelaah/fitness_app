import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'routine.freezed.dart';
part 'routine.g.dart';

@unfreezed
abstract class RoutineExercise with _$RoutineExercise {
  factory RoutineExercise({
    @Default('') String id,
    @Default('') String exerciseId,
    @Default(3) int sets,
    @Default(10) int reps,
    double? weight,
    int? restSeconds,
  }) = _RoutineExercise;
  RoutineExercise._();

  factory RoutineExercise.fromJson(Map<String, dynamic> json) =>
      _$RoutineExerciseFromJson(json);

  RoutineExercise clone({bool newId = false}) {
    return RoutineExercise(
      id: (newId || id.isEmpty) ? const Uuid().v4() : id,
      exerciseId: exerciseId,
      sets: sets,
      reps: reps,
      weight: weight,
      restSeconds: restSeconds,
    );
  }
}

@unfreezed
abstract class WorkoutDay with _$WorkoutDay {
  factory WorkoutDay({
    @Default('') String id,
    @Default('') String name,
    @Default([]) List<RoutineExercise> exercises,
  }) = _WorkoutDay;
  WorkoutDay._();

  factory WorkoutDay.fromJson(Map<String, dynamic> json) =>
      _$WorkoutDayFromJson(json);

  WorkoutDay clone({bool newId = false}) {
    return WorkoutDay(
      id: (newId || id.isEmpty) ? const Uuid().v4() : id,
      name: name,
      exercises: exercises.map((e) => e.clone(newId: newId)).toList(),
    );
  }
}

@unfreezed
abstract class WorkoutRoutine with _$WorkoutRoutine {
  factory WorkoutRoutine({
    @Default('') String id,
    @Default('') String name,
    String? description,
    @Default([]) List<WorkoutDay> days,
  }) = _WorkoutRoutine;
  WorkoutRoutine._();

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) =>
      _$WorkoutRoutineFromJson(json);

  WorkoutRoutine clone({bool newId = false}) {
    return WorkoutRoutine(
      id: (newId || id.isEmpty) ? const Uuid().v4() : id,
      name: name,
      description: description,
      days: days.map((d) => d.clone(newId: newId)).toList(),
    );
  }
}
