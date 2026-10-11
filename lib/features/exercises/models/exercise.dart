import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

@freezed
abstract class Exercise with _$Exercise {
  const factory Exercise({
    @Default('') String id,
    @Default('') String name,
    @Default('') String category,
    @JsonKey(name: 'body_part') @Default('') String bodyPart,
    @Default('') String equipment,
    @Default(<String, dynamic>{}) Map<String, dynamic> instructions,
    @JsonKey(name: 'instruction_steps')
    @Default(<String, dynamic>{})
    Map<String, dynamic> instructionSteps,
    @JsonKey(name: 'muscle_group') @Default('') String muscleGroup,
    @JsonKey(name: 'secondary_muscles')
    @Default(<String>[])
    List<String> secondaryMuscles,
    @Default('') String target,
    @Default('') String image,
    @JsonKey(name: 'gif_url') @Default('') String gifUrl,
    @Default('') String attribution,
  }) = _Exercise;
  const Exercise._();

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);

  String get englishInstructions {
    return instructions['en'] as String? ?? '';
  }

  List<String> get englishSteps {
    final steps = instructionSteps['en'];
    if (steps == null) return [];
    if (steps is List) {
      return steps.map((e) => e.toString()).toList();
    }
    return [];
  }
}
