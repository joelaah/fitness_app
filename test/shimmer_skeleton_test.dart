import 'package:fitness_app/core/widgets/shimmer_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PulseShimmer & Skeleton Loaders Tests', () {
    testWidgets('renders PulseShimmer and settles cleanly in test environment',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseShimmer(
              child: ShimmerBox(width: 100, height: 20),
            ),
          ),
        ),
      );

      expect(find.byType(PulseShimmer), findsOneWidget);
      expect(find.byType(ShimmerBox), findsOneWidget);

      // Verify that animation doesn't cause pumpAndSettle timeout
      await tester.pumpAndSettle();
      expect(find.byType(ShimmerBox), findsOneWidget);
    });

    testWidgets('renders ShimmerRoutinesSkeleton cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerRoutinesSkeleton(),
          ),
        ),
      );

      expect(find.byType(ShimmerRoutinesSkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(ShimmerRoutinesSkeleton), findsOneWidget);
    });

    testWidgets('renders ShimmerTrainerDiscoverySkeleton cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerTrainerDiscoverySkeleton(),
          ),
        ),
      );

      expect(find.byType(ShimmerTrainerDiscoverySkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(ShimmerTrainerDiscoverySkeleton), findsOneWidget);
    });

    testWidgets('renders ShimmerTrainerDashboardSkeleton cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerTrainerDashboardSkeleton(),
          ),
        ),
      );

      expect(find.byType(ShimmerTrainerDashboardSkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(ShimmerTrainerDashboardSkeleton), findsOneWidget);
    });

    testWidgets('renders ShimmerWorkoutActiveSkeleton cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerWorkoutActiveSkeleton(),
          ),
        ),
      );

      expect(find.byType(ShimmerWorkoutActiveSkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(ShimmerWorkoutActiveSkeleton), findsOneWidget);
    });

    testWidgets('renders ShimmerExerciseLibrarySkeleton cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerExerciseLibrarySkeleton(),
          ),
        ),
      );

      expect(find.byType(ShimmerExerciseLibrarySkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(ShimmerExerciseLibrarySkeleton), findsOneWidget);
    });

    testWidgets('respects MediaQuery disableAnimations accessibility setting cleanly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: PulseShimmer(
                child: ShimmerBox(width: 80, height: 16),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PulseShimmer), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly with zero-bounds children without shader error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseShimmer(
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.byType(PulseShimmer), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'renders ShimmerTrainerDashboardSkeleton on compact/landscape viewport without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Trainer Dashboard')),
            body: const SizedBox(
              height: 250,
              child: ShimmerTrainerDashboardSkeleton(),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerTrainerDashboardSkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ShimmerTrainerDiscoverySkeleton allows scrolling on compact viewports',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: ShimmerTrainerDiscoverySkeleton(),
            ),
          ),
        ),
      );

      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);

      await tester.drag(listViewFinder, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ShimmerExerciseLibrarySkeleton includes SafeArea to protect notch on full-screen layouts',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: 44)),
            child: Scaffold(
              body: ShimmerExerciseLibrarySkeleton(),
            ),
          ),
        ),
      );

      final safeAreaFinder = find.descendant(
        of: find.byType(ShimmerExerciseLibrarySkeleton),
        matching: find.byType(SafeArea),
      );
      expect(safeAreaFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'renders ShimmerExerciseLibrarySkeleton on compact/landscape viewport without overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 120,
              child: ShimmerExerciseLibrarySkeleton(),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerExerciseLibrarySkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ShimmerBox and ShimmerCircle handle negative and NaN sizes safely',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ShimmerBox(width: 50, height: 20, borderRadius: -5.0),
                ShimmerBox(width: 50, height: 20, borderRadius: double.nan),
                ShimmerBox(width: -20.0, height: -10.0),
                ShimmerBox(width: double.nan, height: double.nan),
                ShimmerCircle(size: -10.0),
                ShimmerCircle(size: double.nan),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

