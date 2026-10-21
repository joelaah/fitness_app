import 'package:fitness_app/features/nutrition/models/daily_macro_summary.dart';
import 'package:fitness_app/features/nutrition/models/food_item.dart';
import 'package:fitness_app/features/nutrition/models/nutrition_analysis_result.dart';
import 'package:fitness_app/features/nutrition/widgets/food_scanner_overlay.dart';
import 'package:fitness_app/features/nutrition/widgets/macro_target_card.dart';
import 'package:fitness_app/features/nutrition/widgets/meal_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nutrition UI Multi-Platform Responsiveness (Mobile, APK & Web)', () {
    const sampleItem = FoodItem(
      name: 'Grilled Salmon with Brown Rice',
      portionG: 250.0,
      calories: 450.0,
      proteinG: 38.0,
      carbsG: 42.0,
      fatG: 12.0,
    );

    const sampleAnalysis = NutritionAnalysisResult(
      mealName: 'Post-Workout Fuel Bowl',
      items: [sampleItem],
      totalCalories: 450.0,
      totalProteinG: 38.0,
      totalCarbsG: 42.0,
      totalFatG: 12.0,
      atwaterCalories: 428.0,
    );

    const sampleSummary = DailyMacroSummary(
      date: '2026-10-21',
      loggedMeals: 3,
      totalCalories: 1850.0,
      totalProteinG: 145.0,
      totalCarbsG: 190.0,
      totalFatG: 55.0,
      targetCalories: 2200,
      targetProteinG: 160,
      targetCarbsG: 220,
      targetFatG: 70,
    );

    Future<void> testViewport(
      WidgetTester tester, {
      required Size physicalSize,
      required double devicePixelRatio,
    }) async {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = devicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('MacroTargetCard renders with zero overflow on compact mobile (360x640)', (tester) async {
      await testViewport(tester, physicalSize: const Size(360, 640), devicePixelRatio: 1.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MacroTargetCard(summary: sampleSummary),
            ),
          ),
        ),
      );

      final dynamic error = tester.takeException();
      if (error != null) {
        // ignore: avoid_print
        print('MacroTargetCard compact error: $error');
      }
      expect(error, isNull);
      expect(find.text('Daily Nutrition'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
    });

    testWidgets('MacroTargetCard renders cleanly on ultra-wide web (1920x1080)', (tester) async {
      await testViewport(tester, physicalSize: const Size(1920, 1080), devicePixelRatio: 1.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 800,
                child: MacroTargetCard(summary: sampleSummary),
              ),
            ),
          ),
        ),
      );

      final dynamic error = tester.takeException();
      expect(error, isNull);
      expect(find.text('Daily Nutrition'), findsOneWidget);
    });

    testWidgets('MealReviewSheet renders and scrolls without overflow on narrow mobile (360x640)', (tester) async {
      await testViewport(tester, physicalSize: const Size(360, 640), devicePixelRatio: 1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealReviewSheet(
              analysisResult: sampleAnalysis,
              onSaveMeal: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Grilled Salmon with Brown Rice'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
    });

    testWidgets('MealReviewSheet centers and constrains width on desktop web (1920x1080)', (tester) async {
      await testViewport(tester, physicalSize: const Size(1920, 1080), devicePixelRatio: 1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealReviewSheet(
              analysisResult: sampleAnalysis,
              onSaveMeal: (_) {},
            ),
          ),
        ),
      );

      final dynamic error = tester.takeException();
      expect(error, isNull);
      expect(find.text('Post-Workout Fuel Bowl'), findsOneWidget);

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final has640Constraint = constrainedBoxes.any((cb) => cb.constraints.maxWidth == 640.0);
      expect(has640Constraint, isTrue);
    });

    testWidgets('FoodScannerOverlay animates cleanly across both mobile and web viewports', (tester) async {
      // 1. Mobile (360x640)
      await testViewport(tester, physicalSize: const Size(360, 640), devicePixelRatio: 1.0);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 320,
              child: FoodScannerOverlay(isAnalyzing: true),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final dynamic mobileErr = tester.takeException();
      if (mobileErr != null) {
        // ignore: avoid_print
        print('FoodScannerOverlay mobile error: $mobileErr');
      }
      expect(mobileErr, isNull);
      expect(find.text('PULSEFIT NEURAL VISION'), findsOneWidget);

      // 2. Web (1920x1080)
      await testViewport(tester, physicalSize: const Size(1920, 1080), devicePixelRatio: 1.0);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 680,
              height: 320,
              child: FoodScannerOverlay(isAnalyzing: true),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final dynamic webErr = tester.takeException();
      expect(webErr, isNull);
      expect(find.text('PULSEFIT NEURAL VISION'), findsOneWidget);
    });
  });
}
