import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/routines/widgets/workout_balance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'WorkoutBalanceCard warns of high tension when 5 upper back exercises exist',
    (tester) async {
      final exercises = List.generate(
        5,
        (i) => Exercise(
          id: 'row_$i',
          name: 'Barbell Row $i',
          bodyPart: 'back',
          target: 'upper back',
        ),
      );

      final exerciseMap = {for (final ex in exercises) ex.id: ex};
      final dayExercises = exercises
          .map(
            (ex) => RoutineExercise(
              exerciseId: ex.id,
              restSeconds: 90,
            ),
          )
          .toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutBalanceCard(
              dayExercises: dayExercises,
              exerciseMap: exerciseMap,
            ),
          ),
        ),
      );

      // Verify the status badge says 'High tension'
      expect(find.text('High tension'), findsOneWidget);

      // Verify warning message is present
      expect(
        find.textContaining('High Upper Back volume (5 exercises)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Too much cumulative tension on traps & rhomboids'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'WorkoutBalanceCard shows balanced when vertical and horizontal back are balanced',
    (tester) async {
      const latEx = Exercise(
        id: 'lat_pulldown',
        name: 'Lat Pulldown',
        bodyPart: 'back',
        target: 'lats',
      );
      const rowEx = Exercise(
        id: 'barbell_row',
        name: 'Barbell Bent Over Row',
        bodyPart: 'back',
        target: 'upper back',
      );

      final exerciseMap = {latEx.id: latEx, rowEx.id: rowEx};
      final dayExercises = [
        RoutineExercise(
          exerciseId: latEx.id,
          restSeconds: 90,
        ),
        RoutineExercise(
          exerciseId: rowEx.id,
          restSeconds: 90,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutBalanceCard(
              dayExercises: dayExercises,
              exerciseMap: exerciseMap,
            ),
          ),
        ),
      );

      expect(find.text('Balanced'), findsOneWidget);
      expect(
        find.textContaining(
          'Balanced back day! Vertical (Lats) and horizontal',
        ),
        findsOneWidget,
      );
    },
  );
}
