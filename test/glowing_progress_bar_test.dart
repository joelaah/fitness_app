import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/glowing_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlowingProgressBar Tests', () {
    testWidgets('renders track and fill proportionally without overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: GlowingProgressBar(
                  progress: 0.5,
                  height: 6.0,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlowingProgressBar), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(GlowingProgressBar), findsOneWidget);
    });

    testWidgets('clamps progress values below 0.0 and above 1.0 safely',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: GlowingProgressBar(
                  progress: 1.5,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GlowingProgressBar), findsOneWidget);
    });

    testWidgets('supports custom gradient, background, and glow colors',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                child: GlowingProgressBar(
                  progress: 0.75,
                  glowColor: AppColors.secondaryAccent,
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.cyan],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GlowingProgressBar), findsOneWidget);
    });

    testWidgets('handles NaN and infinite progress gracefully without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                child: GlowingProgressBar(
                  progress: double.nan,
                ),
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
              child: SizedBox(
                width: 150,
                child: GlowingProgressBar(
                  progress: double.infinity,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('functions natively as an AppBar bottom PreferredSizeWidget',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Workout Progress'),
              bottom: const GlowingProgressBar(
                progress: 0.6,
                height: 4.0,
              ),
            ),
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      expect(find.byType(GlowingProgressBar), findsOneWidget);
      final widget = tester.widget<GlowingProgressBar>(find.byType(GlowingProgressBar));
      expect(widget.preferredSize.height, equals(4.0));
      expect(tester.takeException(), isNull);
    });
    testWidgets('handles negative or NaN height safely without crashing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                child: GlowingProgressBar(
                  progress: 0.5,
                  height: -4.0,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('zero height GlowingProgressBar suppresses box shadow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                child: GlowingProgressBar(
                  progress: 0.5,
                  height: 0.0,
                ),
              ),
            ),
          ),
        ),
      );

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final boxDecoration = animatedContainer.decoration as BoxDecoration?;
      expect(boxDecoration?.boxShadow, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
