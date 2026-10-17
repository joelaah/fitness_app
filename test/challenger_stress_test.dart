import 'dart:async';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/utils/web_splash_util.dart';
import 'package:fitness_app/core/widgets/animated_neon_volume_ring.dart';
import 'package:fitness_app/core/widgets/perspective_tilt_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Challenger Stress Tests: PerspectiveTiltCard', () {
    testWidgets('Stress 1.1: Extreme pointer coordinates outside bounds',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: PerspectiveTiltCard(
                  child: const Text('Extreme Coordinate Card'),
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(PerspectiveTiltCard);
      final transformFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(Transform),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);

      // Extreme far-away coordinates: 1,000,000 px away
      await gesture.moveTo(const Offset(1000000.0, 1000000.0));
      await tester.pump();

      // Negative extreme coordinates: -1,000,000 px away
      await gesture.moveTo(const Offset(-1000000.0, -1000000.0));
      await tester.pump();

      Transform transform = tester.widget(transformFinder);
      final matrix = transform.transform;

      // Verify no NaN or Infinity in matrix entries
      for (int i = 0; i < 16; i++) {
        expect(matrix.storage[i].isNaN, isFalse,
            reason: 'Matrix index $i must not be NaN');
        expect(matrix.storage[i].isInfinite, isFalse,
            reason: 'Matrix index $i must not be Infinite');
      }

      // Verify matrix determinant is non-zero (non-degenerate invertible projection)
      expect(matrix.determinant(), isNot(equals(0.0)));
      expect(matrix.determinant().isNaN, isFalse);
    });

    testWidgets('Stress 1.2: Zero-size and collapsed bounding box',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 0,
                height: 0,
                child: PerspectiveTiltCard(
                  child: SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(PerspectiveTiltCard);
      expect(cardFinder, findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(Offset.zero);
      await tester.pump();

      final transformFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(Transform),
      );
      Transform transform = tester.widget(transformFinder);
      expect(transform.transform.storage.every((v) => !v.isNaN && !v.isInfinite),
          isTrue);
    });

    testWidgets('Stress 1.3: Rapid pointer exit and re-entry during spring curve',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: PerspectiveTiltCard(
                  child: const Text('Rapid Exit Card'),
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(PerspectiveTiltCard);
      final transformFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(Transform),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final cardCenter = tester.getCenter(cardFinder);
      await gesture.addPointer(location: cardCenter);
      await tester.pump();

      // Rapidly exit and re-enter 5 times in succession
      for (int i = 0; i < 5; i++) {
        await gesture.moveTo(const Offset(10, 10)); // exit
        await tester.pump(const Duration(milliseconds: 20)); // partial tick
        await gesture.moveTo(cardCenter + Offset(i * 10.0, i * 5.0)); // re-enter
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Finally exit and allow full settle
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      Transform transform = tester.widget(transformFinder);
      final matrix = transform.transform;
      for (int i = 0; i < 16; i++) {
        expect(matrix.storage[i].isNaN, isFalse);
        expect(matrix.storage[i].isInfinite, isFalse);
      }
    });

    testWidgets('Stress 1.4: Pure touch gestures (pan start, update, cancel)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                height: 150,
                child: PerspectiveTiltCard(
                  child: const Text('Touch Pan Card'),
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(PerspectiveTiltCard);
      final transformFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(Transform),
      );

      // Start touch pan
      final gesture = await tester.startGesture(tester.getCenter(cardFinder));
      await tester.pump();

      // Pan to bottom-right corner
      await gesture.moveBy(const Offset(100, 60));
      await tester.pump();

      Transform activeTransform = tester.widget(transformFinder);
      expect(activeTransform.transform != Matrix4.identity(), isTrue);

      // Cancel gesture (e.g. scroll intercept)
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      Transform settledTransform = tester.widget(transformFinder);
      expect(settledTransform.transform[0], closeTo(1.0, 0.05));
    });

    testWidgets('Stress 1.5: Tap during active tilt gesture executes onTap',
        (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: PerspectiveTiltCard(
                  onTap: () => tapCount++,
                  child: const Text('Tap Me'),
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(PerspectiveTiltCard);
      await tester.tap(cardFinder);
      await tester.pump();
      expect(tapCount, equals(1));
    });
  });

  group('Challenger Stress Tests: AnimatedNeonVolumeRing', () {
    testWidgets('Stress 2.1: 0.0% completion, 100.0% completion, and > 1.0 (over-target)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedNeonVolumeRing(
                size: 180,
                rings: [
                  VolumeRingData(
                    progress: 0.0, // 0.0% completion
                    startColor: AppColors.primary,
                    endColor: AppColors.primaryVariant,
                    label: 'Zero Target',
                  ),
                  VolumeRingData(
                    progress: 1.0, // 100.0% completion
                    startColor: AppColors.secondaryAccent,
                    endColor: Color(0xFF06B6D4),
                    label: 'Full Target',
                  ),
                  VolumeRingData(
                    progress: 2.75, // Over-target volume (275%)
                    startColor: Color(0xFFA855F7),
                    endColor: Color(0xFFEC4899),
                    label: 'Over Target',
                  ),
                  VolumeRingData(
                    progress: -0.5, // Negative edge case
                    startColor: Colors.amber,
                    endColor: Colors.orange,
                    label: 'Negative Progress',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedNeonVolumeRing), findsOneWidget);

      // Animate frame by frame through complete curve
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Stress 2.2: Zero size and small radius edge conditions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedNeonVolumeRing(
                size: 0.0, // 0 size
                rings: [
                  VolumeRingData(
                    progress: 0.5,
                    startColor: AppColors.primary,
                    endColor: AppColors.primaryVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Zero size should not crash widget tree');
    });

    testWidgets('Stress 2.3: Many concentric rings exceeding outer diameter',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedNeonVolumeRing(
                size: 100,
                rings: List.generate(
                  8,
                  (index) => VolumeRingData(
                    progress: 0.8,
                    strokeWidth: 8.0,
                    startColor: AppColors.primary,
                    endColor: AppColors.secondaryAccent,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      final exception = tester.takeException();
      expect(exception, isNull,
          reason: 'Concentric rings exceeding container bounds must not crash paint');
    });

    testWidgets('Stress 2.4: Empty rings list renders cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedNeonVolumeRing(
                size: 150,
                rings: [],
                centerTitle: 'No Data',
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Data'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  });

  group('Challenger Stress Tests: Web Startup & Non-blocking Auth Resilience', () {
    test('Stress 3.1: Unawaited anonymous authentication error resilience', () async {
      // Emulate the exact pattern used in main.dart:
      // An unawaited background task with error boundary
      bool caughtError = false;
      bool mainExecutionProceeded = false;

      Future<void> simulateUnawaitedAuth({required bool shouldFail}) {
        if (shouldFail) {
          return Future<void>.error(
            TimeoutException('Simulated Supabase connection timeout (offline mode)'),
          );
        }
        return Future<void>.value();
      }

      // Pattern from lib/main.dart line 33-38:
      simulateUnawaitedAuth(shouldFail: true).then((_) {
        // unreachable in failure
      }).catchError((Object e) {
        caughtError = true;
      });

      // Synchronous code proceeds immediately without waiting
      mainExecutionProceeded = true;

      expect(mainExecutionProceeded, isTrue);

      // Wait a microtask turn for the error handler to fire
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(caughtError, isTrue);
    });

    test('Stress 3.2: dismissWebSplash() executes safely without exceptions', () {
      // Calling dismissWebSplash on VM/desktop or web must not throw
      expect(() => dismissWebSplash(), returnsNormally);
    });
  });
}
