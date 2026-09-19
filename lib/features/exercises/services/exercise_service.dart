import 'dart:convert';

import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:flutter/services.dart';

class ExerciseService {
  static List<Exercise>? _cachedExercises;

  static Future<List<Exercise>> loadExercises() async {
    if (_cachedExercises != null) return _cachedExercises!;

    final jsonString = await rootBundle.loadString(
      'assets/data/exercises.json',
    );
    final jsonData = jsonDecode(jsonString) as List<dynamic>;
    _cachedExercises = jsonData
        .map((json) => Exercise.fromJson(json as Map<String, dynamic>))
        .toList();
    return _cachedExercises!;
  }
}
