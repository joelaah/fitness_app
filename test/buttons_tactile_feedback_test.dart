import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/core/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrimaryButton & SecondaryButton Tactile Feedback Tests', () {
    testWidgets('PrimaryButton scales to 0.97 on press down and restores on release',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: PrimaryButton(
                  label: 'Submit',
                  onPressed: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      final scaleFinder = find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(AnimatedScale),
      );
      expect(scaleFinder, findsOneWidget);

      AnimatedScale initialScale = tester.widget(scaleFinder);
      expect(initialScale.scale, equals(1.0));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      AnimatedScale pressedScale = tester.widget(scaleFinder);
      expect(pressedScale.scale, equals(0.97));

      await gesture.up();
      await tester.pumpAndSettle();

      AnimatedScale releasedScale = tester.widget(scaleFinder);
      expect(releasedScale.scale, equals(1.0));
      expect(tapped, isTrue);
    });

    testWidgets('PrimaryButton handles unmounting on tap without setState-after-dispose error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return PrimaryButton(
                  label: 'Dismiss Dialog',
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        content: PrimaryButton(
                          label: 'Close Now',
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Dismiss Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Close Now'), findsOneWidget);

      // Tap to close dialog - this disposes the dialog's button
      await tester.tap(find.text('Close Now'));
      await tester.pumpAndSettle();

      expect(find.text('Close Now'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SecondaryButton scales on press down and restores on release',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                label: 'Cancel Action',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final scaleFinder = find.descendant(
        of: find.byType(SecondaryButton),
        matching: find.byType(AnimatedScale),
      );
      expect(scaleFinder, findsOneWidget);

      AnimatedScale initialScale = tester.widget(scaleFinder);
      expect(initialScale.scale, equals(1.0));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Cancel Action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      AnimatedScale pressedScale = tester.widget(scaleFinder);
      expect(pressedScale.scale, equals(0.97));

      await gesture.up();
      await tester.pumpAndSettle();

      AnimatedScale releasedScale = tester.widget(scaleFinder);
      expect(releasedScale.scale, equals(1.0));
      expect(tapped, isTrue);
    });

    testWidgets('SecondaryButton handles unmounting on tap without setState-after-dispose error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return SecondaryButton(
                  label: 'Open Sheet',
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => SecondaryButton(
                        label: 'Dismiss Sheet',
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Dismiss Sheet'), findsOneWidget);

      await tester.tap(find.text('Dismiss Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Dismiss Sheet'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('SecondaryButton hit tests cleanly on find.byType(SecondaryButton)',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SecondaryButton(
                label: 'Test Button',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SecondaryButton));
      expect(tapped, isTrue);
    });
  });
}
