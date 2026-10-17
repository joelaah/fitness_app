import 'package:fitness_app/core/widgets/perspective_tilt_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerspectiveTiltCard Tests', () {
    testWidgets('renders child content and responds to tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: PerspectiveTiltCard(
                  onTap: () => tapped = true,
                  child: const Text('Workout Card'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Workout Card'), findsOneWidget);
      await tester.tap(find.text('Workout Card'));
      expect(tapped, isTrue);
    });

    testWidgets('tilts and updates transform on mouse hover and resets on exit',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: PerspectiveTiltCard(
                  onTap: () {},
                  child: const Text('Hover Target'),
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(PerspectiveTiltCard);
      expect(cardFinder, findsOneWidget);

      // Initial transform is identity / scale 1.0
      final transformFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(Transform),
      );
      expect(transformFinder, findsOneWidget);
      Transform initialTransform = tester.widget(transformFinder);
      expect(
        initialTransform.transform,
        equals(Matrix4.identity()..setEntry(3, 2, 0.001)),
      );

      // Hover over the top-right quadrant
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final cardCenter = tester.getCenter(cardFinder);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(cardCenter + const Offset(50, -30));
      await tester.pump();

      Transform hoveredTransform = tester.widget(transformFinder);
      // Transform should not equal identity after mouse hover
      expect(hoveredTransform.transform != Matrix4.identity(), isTrue);

      // Move mouse away (exit)
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      Transform exitedTransform = tester.widget(transformFinder);
      // After animation completes, rotation returns to 0
      expect(exitedTransform.transform[0], closeTo(1.0, 0.05));
    });

    testWidgets('responds to touch pan gestures on mobile/tablet',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: PerspectiveTiltCard(
                  child: const Text('Touch Target'),
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

      final gesture = await tester.startGesture(tester.getCenter(cardFinder));
      await tester.pump();

      await gesture.moveBy(const Offset(30, 20));
      await tester.pump();

      Transform touchTransform = tester.widget(transformFinder);
      expect(touchTransform.transform != Matrix4.identity(), isTrue);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
