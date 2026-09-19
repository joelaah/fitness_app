import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/workout/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'HistoryScreen updates reactively when workout finishes and formats UI correctly',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final historyRepo = WorkoutHistoryRepository(prefs);
      final workoutProvider = WorkoutProvider(historyRepository: historyRepo);

      await tester.pumpWidget(
        ChangeNotifierProvider<WorkoutProvider>.value(
          value: workoutProvider,
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      // Initially empty state
      expect(find.text('No Workouts Yet'), findsOneWidget);

      // Start and finish a workout
      final routine = WorkoutRoutine(
        id: 'r1',
        name: 'Hypertrophy Upper',
        days: [],
      );
      final day = WorkoutDay(
        id: 'd1',
        name: 'Push Day',
        exercises: [
          RoutineExercise(
            exerciseId: 'bench_press',
            restSeconds: 90,
          ),
        ],
      );

      workoutProvider.startWorkout(routine, day);

      // Complete the first set
      final exId = workoutProvider.activeSession!.exercises.first.id;
      final setId =
          workoutProvider.activeSession!.exercises.first.sets.first.id;
      workoutProvider.updateSetValues(exId, setId, reps: 10, weight: 80);
      workoutProvider.toggleSetComplete(exId, setId);

      // Finish workout
      await workoutProvider.finishWorkout();

      // Pump to trigger rebuild from Provider notification
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Reactivity check: Empty state is gone, workout card is rendered immediately
      expect(find.text('No Workouts Yet'), findsNothing);
      expect(find.text('Hypertrophy Upper'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('800 kg'), findsOneWidget); // 10 reps * 80 kg
      expect(find.text('1 sets'), findsOneWidget);
      expect(find.text('1 exercise'), findsOneWidget);

      workoutProvider.dispose();
    },
  );
}
