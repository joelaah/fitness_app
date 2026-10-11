// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'routine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoutineExercise _$RoutineExerciseFromJson(Map<String, dynamic> json) =>
    _RoutineExercise(
      id: json['id'] as String? ?? '',
      exerciseId: json['exerciseId'] as String? ?? '',
      sets: (json['sets'] as num?)?.toInt() ?? 3,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      weight: (json['weight'] as num?)?.toDouble(),
      restSeconds: (json['restSeconds'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RoutineExerciseToJson(_RoutineExercise instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exerciseId': instance.exerciseId,
      'sets': instance.sets,
      'reps': instance.reps,
      'weight': instance.weight,
      'restSeconds': instance.restSeconds,
    };

_WorkoutDay _$WorkoutDayFromJson(Map<String, dynamic> json) => _WorkoutDay(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  exercises:
      (json['exercises'] as List<dynamic>?)
          ?.map((e) => RoutineExercise.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$WorkoutDayToJson(_WorkoutDay instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'exercises': instance.exercises.map((e) => e.toJson()).toList(),
    };

_WorkoutRoutine _$WorkoutRoutineFromJson(Map<String, dynamic> json) =>
    _WorkoutRoutine(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      days:
          (json['days'] as List<dynamic>?)
              ?.map((e) => WorkoutDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$WorkoutRoutineToJson(_WorkoutRoutine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'days': instance.days.map((e) => e.toJson()).toList(),
    };
