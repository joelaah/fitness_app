import 'dart:convert';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal repository for saving and retrieving completed workout sessions.
/// Used primarily to power "last-performed" autofill.
class WorkoutHistoryRepository {
  WorkoutHistoryRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'workout_history';

  /// Returns all saved sessions, newest first.
  List<WorkoutSession> getAll() {
    final raw = _prefs.getStringList(_key) ?? [];
    return raw
        .map(
          (json) =>
              WorkoutSession.fromJson(jsonDecode(json) as Map<String, dynamic>),
        )
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Save a completed session.
  Future<void> save(WorkoutSession session) async {
    final all = _prefs.getStringList(_key) ?? [];
    all.add(jsonEncode(session.toJson()));
    await _prefs.setStringList(_key, all);
  }

  /// Find the most recent completed session for a given routine + day.
  /// Returns null if the user has never done this workout before.
  WorkoutSession? getLastSession({
    required String routineId,
    required String dayId,
  }) {
    final all = getAll(); // Already sorted newest-first
    for (final session in all) {
      if (session.routineId == routineId &&
          session.dayId == dayId &&
          session.endTime != null) {
        return session;
      }
    }
    return null;
  }

  /// For a specific exercise, find the last completed sets across ALL sessions.
  /// Useful for exercises that appear in multiple routines.
  List<ExerciseSet>? getLastSetsForExercise(String exerciseId) {
    final all = getAll();
    for (final session in all) {
      for (final ex in session.exercises) {
        if (ex.exerciseId == exerciseId && !ex.isSkipped) {
          final completedSets = ex.sets.where((s) => s.isCompleted).toList();
          if (completedSets.isNotEmpty) return completedSets;
        }
      }
    }
    return null;
  }
}
