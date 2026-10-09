import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/workout/screens/workout_active_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('WorkoutActiveScreen renders active routine session controls and set inputs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final historyRepo = WorkoutHistoryRepository(prefs);
    final workoutProvider = WorkoutProvider(historyRepository: historyRepo);

    final routine = WorkoutRoutine(
      id: 'routine-active-1',
      name: 'Upper Hypertrophy A',
      days: [],
    );
    final day = WorkoutDay(
      id: 'day-active-1',
      name: 'Push & Arms',
      exercises: [
        RoutineExercise(
          exerciseId: 'incline-bench',
          sets: 3,
          reps: 10,
          restSeconds: 90,
        ),
      ],
    );

    // Start active session
    workoutProvider.startWorkout(routine, day);

    await tester.pumpWidget(
      ChangeNotifierProvider<WorkoutProvider>.value(
        value: workoutProvider,
        child: const MaterialApp(
          home: WorkoutActiveScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify header title and finish button
    expect(find.text('Active Workout'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);

    workoutProvider.dispose();
  });
}
