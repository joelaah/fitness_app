import 'dart:convert';

import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/routines/repositories/routine_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SharedPrefsRoutineRepository implements RoutineRepository {
  SharedPrefsRoutineRepository(this._prefs);
  static const String _storageKey = 'saved_routines';
  final SharedPreferences _prefs;

  @override
  Future<List<WorkoutRoutine>> getRoutines() async {
    try {
      final jsonString = _prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final list = <WorkoutRoutine>[];
      final seenIds = <String>{};
      for (final json in jsonList) {
        final routine = WorkoutRoutine.fromJson(json as Map<String, dynamic>);
        if (routine.id.isNotEmpty && !seenIds.contains(routine.id)) {
          seenIds.add(routine.id);
          list.add(routine);
        }
      }
      return list;
    } catch (e) {
      // In case of corrupted JSON, return empty list rather than crashing
      print('Error parsing saved routines: $e');
      return [];
    }
  }

  @override
  Future<void> saveRoutine(WorkoutRoutine routine) async {
    if (routine.id.isEmpty) {
      routine.id = const Uuid().v4();
    }
    final routines = await getRoutines();

    final index = routines.indexWhere((r) => r.id == routine.id);
    if (index >= 0) {
      routines[index] = routine.clone();
    } else {
      routines.add(routine.clone());
    }

    await _persistRoutines(routines);
  }

  @override
  Future<void> deleteRoutine(String routineId) async {
    final routines = await getRoutines();
    routines.removeWhere((r) => r.id == routineId);
    await _persistRoutines(routines);
  }

  Future<void> _persistRoutines(List<WorkoutRoutine> routines) async {
    final jsonList = routines.map((r) => r.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_storageKey, jsonString);
  }
}
