// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Exercise _$ExerciseFromJson(Map<String, dynamic> json) => _Exercise(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  category: json['category'] as String? ?? '',
  bodyPart: json['body_part'] as String? ?? '',
  equipment: json['equipment'] as String? ?? '',
  instructions:
      json['instructions'] as Map<String, dynamic>? ??
      const <String, dynamic>{},
  instructionSteps:
      json['instruction_steps'] as Map<String, dynamic>? ??
      const <String, dynamic>{},
  muscleGroup: json['muscle_group'] as String? ?? '',
  secondaryMuscles:
      (json['secondary_muscles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  target: json['target'] as String? ?? '',
  image: json['image'] as String? ?? '',
  gifUrl: json['gif_url'] as String? ?? '',
  attribution: json['attribution'] as String? ?? '',
);

Map<String, dynamic> _$ExerciseToJson(_Exercise instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'category': instance.category,
  'body_part': instance.bodyPart,
  'equipment': instance.equipment,
  'instructions': instance.instructions,
  'instruction_steps': instance.instructionSteps,
  'muscle_group': instance.muscleGroup,
  'secondary_muscles': instance.secondaryMuscles,
  'target': instance.target,
  'image': instance.image,
  'gif_url': instance.gifUrl,
  'attribution': instance.attribution,
};
