import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/routine_repository.dart';
import 'package:fitness_app/features/routines/screens/routine_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeRoutineRepository implements RoutineRepository {
  final Map<String, WorkoutRoutine> _store = {};

  @override
  Future<List<WorkoutRoutine>> getRoutines() async => _store.values.toList();

  @override
  Future<void> saveRoutine(WorkoutRoutine routine) async {
    _store[routine.id] = routine;
  }

  @override
  Future<void> deleteRoutine(String id) async {
    _store.remove(id);
  }

  @override
  Future<WorkoutRoutine?> getRoutineById(String id) async => _store[id];
}

void main() {
  testWidgets('RoutineDetailScreen renders routine title and workout days', (tester) async {
    final fakeRepo = _FakeRoutineRepository();
    final routineProvider = RoutineProvider(repository: fakeRepo);

    final routine = WorkoutRoutine(
      id: 'routine-101',
      name: 'Push Pull Legs Mastery',
      description: 'Science-based hypertrophy split',
      days: [
        WorkoutDay(
          id: 'day-1',
          name: 'Heavy Push A',
          exercises: [
            RoutineExercise(
              exerciseId: 'bench-press',
              sets: 4,
              reps: 8,
              restSeconds: 120,
            ),
          ],
        ),
        WorkoutDay(
          id: 'day-2',
          name: 'Heavy Pull A',
          exercises: [
            RoutineExercise(
              exerciseId: 'barbell-row',
              sets: 4,
              reps: 8,
              restSeconds: 120,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<RoutineProvider>.value(
        value: routineProvider,
        child: MaterialApp(
          home: RoutineDetailScreen(routine: routine),
        ),
      ),
    );
    await tester.pump();

    // Verify title and days are rendered
    expect(find.text('Push Pull Legs Mastery'), findsOneWidget);
    expect(find.text('Heavy Push A'), findsOneWidget);
    expect(find.text('Heavy Pull A'), findsOneWidget);
    expect(find.text('1 Exercises'), findsNWidgets(2));

    routineProvider.dispose();
  });
}
