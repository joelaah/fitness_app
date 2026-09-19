import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles background syncing of completed workout sessions to Supabase.
/// Never interrupts or blocks local offline persistence.
class SupabaseWorkoutService {
  static Future<void> syncWorkoutSession(WorkoutSession session) async {
    if (!SupabaseConfig.isInitialized) {
      return;
    }
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('Supabase not authenticated, skipping cloud workout sync.');
        return;
      }

      // 1. Insert or update workout_sessions
      await client.from('workout_sessions').upsert({
        'id': session.id,
        'user_id': userId,
        'routine_id': session.routineId,
        'routine_name': session.routineName,
        'day_id': session.dayId,
        'started_at': session.startTime.toIso8601String(),
        'completed_at': session.endTime?.toIso8601String(),
        'duration_seconds': session.durationSeconds,
        'total_volume': session.totalVolume,
        'total_reps': session.totalReps,
      });

      // 2. Insert exercises & sets
      var orderIndex = 0;
      for (final ex in session.exercises) {
        if (ex.isSkipped) continue;

        await client.from('workout_exercises').upsert({
          'id': ex.id,
          'workout_session_id': session.id,
          'exercise_id': ex.exerciseId,
          'exercise_name': ex.exerciseId, // Can be matched with library
          'order_index': orderIndex++,
          'primary_muscle_group': 'General',
          'is_skipped': ex.isSkipped,
        });

        var setNum = 1;
        for (final st in ex.sets) {
          if (!st.isCompleted) continue;
          await client.from('workout_sets').upsert({
            'id': st.id,
            'workout_exercise_id': ex.id,
            'set_number': setNum++,
            'target_reps': st.targetReps,
            'completed_reps': st.completedReps ?? st.targetReps,
            'target_weight': st.targetWeight,
            'completed_weight': st.completedWeight ?? st.targetWeight,
            'is_completed': st.isCompleted,
          });
        }
      }

      debugPrint('Successfully synced session ${session.id} to Supabase.');
    } catch (e) {
      debugPrint('Supabase sync notice (non-fatal, local copy safe): $e');
    }
  }
}
