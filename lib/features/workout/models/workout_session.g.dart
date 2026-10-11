// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'workout_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkoutSession _$WorkoutSessionFromJson(Map<String, dynamic> json) =>
    _WorkoutSession(
      id: json['id'] as String,
      routineId: json['routineId'] as String,
      dayId: json['dayId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      exercises:
          (json['exercises'] as List<dynamic>?)
              ?.map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      routineName: json['routineName'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      totalVolume: (json['totalVolume'] as num?)?.toDouble(),
      totalReps: (json['totalReps'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WorkoutSessionToJson(_WorkoutSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'routineId': instance.routineId,
      'dayId': instance.dayId,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'exercises': instance.exercises.map((e) => e.toJson()).toList(),
      'routineName': instance.routineName,
      'durationSeconds': instance.durationSeconds,
      'totalVolume': instance.totalVolume,
      'totalReps': instance.totalReps,
    };

_SessionExercise _$SessionExerciseFromJson(Map<String, dynamic> json) =>
    _SessionExercise(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      sets:
          (json['sets'] as List<dynamic>?)
              ?.map((e) => ExerciseSet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isSkipped: json['isSkipped'] as bool? ?? false,
    );

Map<String, dynamic> _$SessionExerciseToJson(_SessionExercise instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exerciseId': instance.exerciseId,
      'sets': instance.sets.map((e) => e.toJson()).toList(),
      'isSkipped': instance.isSkipped,
    };

_ExerciseSet _$ExerciseSetFromJson(Map<String, dynamic> json) => _ExerciseSet(
  id: json['id'] as String,
  targetReps: (json['targetReps'] as num).toInt(),
  targetWeight: (json['targetWeight'] as num).toDouble(),
  completedReps: (json['completedReps'] as num?)?.toInt(),
  completedWeight: (json['completedWeight'] as num?)?.toDouble(),
  isCompleted: json['isCompleted'] as bool? ?? false,
);

Map<String, dynamic> _$ExerciseSetToJson(_ExerciseSet instance) =>
    <String, dynamic>{
      'id': instance.id,
      'targetReps': instance.targetReps,
      'targetWeight': instance.targetWeight,
      'completedReps': instance.completedReps,
      'completedWeight': instance.completedWeight,
      'isCompleted': instance.isCompleted,
    };
