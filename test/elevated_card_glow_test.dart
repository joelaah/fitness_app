import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ElevatedCard Aesthetic & Tactile Interaction Tests', () {
    testWidgets('renders child content and executes onTap callback',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedCard(
                onTap: () => tapped = true,
                child: const Text('Test Card Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Card Content'), findsOneWidget);
      await tester.tap(find.text('Test Card Content'));
      expect(tapped, isTrue);
    });

    testWidgets('renders with custom neon gradient border and glow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedCard(
                hasGlow: true,
                glowColor: AppColors.primary,
                borderGradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondaryAccent],
                ),
                child: const Text('Glow Card'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Glow Card'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('applies tactile scale transformation on press down and resets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: ElevatedCard(
                  onTap: () {},
                  enableTactileFeedback: true,
                  child: const Text('Tactile Target'),
                ),
              ),
            ),
          ),
        ),
      );

      final animatedScaleFinder = find.byType(AnimatedScale);
      expect(animatedScaleFinder, findsOneWidget);

      AnimatedScale initialScale = tester.widget(animatedScaleFinder);
      expect(initialScale.scale, equals(1.0));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Tactile Target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      AnimatedScale pressedScale = tester.widget(animatedScaleFinder);
      expect(pressedScale.scale, equals(0.985));

      await gesture.up();
      await tester.pumpAndSettle();

      AnimatedScale releasedScale = tester.widget(animatedScaleFinder);
      expect(releasedScale.scale, equals(1.0));
    });

    testWidgets('direct tap on find.byType(ElevatedCard) hit tests cleanly without warnings',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedCard(
                onTap: () => tapped = true,
                hasGlow: true,
                child: const Text('Direct Card Hit Target'),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(ElevatedCard);
      expect(cardFinder, findsOneWidget);
      await tester.tap(cardFinder);
      expect(tapped, isTrue);
    });

    testWidgets('resilient when rendered with sub-pixel or zero dimensions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 0.5,
                height: 0.5,
                child: ElevatedCard(
                  child: SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('safely handles negative or NaN borderRadius without assertion error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedCard(
                borderRadius: -12.0,
                child: Text('Negative Radius'),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedCard(
                borderRadius: double.nan,
                child: Text('NaN Radius'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedCard(
                borderRadius: double.infinity,
                child: Text('Infinity Radius'),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
