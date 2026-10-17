import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/animated_neon_volume_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimatedNeonVolumeRing Tests', () {
    testWidgets('renders telemetry text and concentric rings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedNeonVolumeRing(
                size: 200,
                centerTitle: '5 DAYS',
                centerSubtitle: 'STREAK',
                centerIcon: Icons.local_fire_department_rounded,
                rings: [
                  VolumeRingData(
                    progress: 0.8,
                    startColor: AppColors.primary,
                    endColor: AppColors.primaryVariant,
                    label: 'Consistency',
                  ),
                  VolumeRingData(
                    progress: 0.6,
                    startColor: AppColors.secondaryAccent,
                    endColor: Color(0xFF06B6D4),
                    label: 'Volume',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify center telemetry elements
      expect(find.text('5 DAYS'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Advance animation through completion
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('5 DAYS'), findsOneWidget);
    });

    testWidgets('updates cleanly when ring data changes', (tester) async {
      List<VolumeRingData> currentRings = const [
        VolumeRingData(
          progress: 0.5,
          startColor: AppColors.primary,
          endColor: AppColors.primaryVariant,
        ),
      ];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: AnimatedNeonVolumeRing(
                  size: 150,
                  centerTitle: '50%',
                  rings: currentRings,
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      currentRings = const [
                        VolumeRingData(
                          progress: 1.0,
                          startColor: AppColors.primary,
                          endColor: AppColors.primaryVariant,
                        ),
                      ];
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('50%'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.byType(AnimatedNeonVolumeRing), findsOneWidget);
    });
  });
}
