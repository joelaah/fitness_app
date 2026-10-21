import 'package:fitness_app/features/nutrition/models/daily_macro_summary.dart';
import 'package:fitness_app/features/nutrition/models/food_item.dart';
import 'package:fitness_app/features/nutrition/models/nutrition_analysis_result.dart';
import 'package:fitness_app/features/nutrition/models/nutrition_log.dart';
import 'package:fitness_app/features/nutrition/widgets/food_scanner_overlay.dart';
import 'package:fitness_app/features/nutrition/widgets/macro_target_card.dart';
import 'package:fitness_app/features/nutrition/widgets/meal_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nutrition Models & Atwater Energy Calculations', () {
    test('FoodItem calculates exact Atwater 4P + 4C + 9F energy', () {
      // 50g protein * 4 = 200 kcal
      expect(FoodItem.calculateAtwater(50.0, 0.0, 0.0), equals(200.0));

      // 40g Protein (160) + 50g Carbs (200) + 15g Fat (135) = 495.0 kcal
      expect(FoodItem.calculateAtwater(40.0, 50.0, 15.0), equals(495.0));

      // 0 macros
      expect(FoodItem.calculateAtwater(0.0, 0.0, 0.0), equals(0.0));
    });

    test('FoodItem portion scaling recalculates macros and Atwater calories', () {
      const item = FoodItem(
        name: 'Grilled Salmon',
        portionG: 100.0,
        calories: 206.0,
        proteinG: 22.0,
        carbsG: 0.0,
        fatG: 13.0,
      );

      // Scale to 200g
      final scaled = item.scaleToPortion(200.0);
      expect(scaled.portionG, equals(200.0));
      expect(scaled.proteinG, equals(44.0));
      expect(scaled.carbsG, equals(0.0));
      expect(scaled.fatG, equals(26.0));
      // Atwater = 44*4 + 0 + 26*9 = 176 + 234 = 410.0 kcal
      expect(scaled.calories, equals(410.0));
    });

    test('NutritionAnalysisResult recalculates totals dynamically', () {
      const item1 = FoodItem(
        name: 'Chicken Breast',
        portionG: 150.0,
        calories: 247.5,
        proteinG: 46.5,
        carbsG: 0.0,
        fatG: 5.5,
      );
      const item2 = FoodItem(
        name: 'Brown Rice',
        portionG: 200.0,
        calories: 220.0,
        proteinG: 5.0,
        carbsG: 45.0,
        fatG: 2.0,
      );

      final result = const NutritionAnalysisResult(
        mealName: 'Lunch Fuel',
        items: [item1, item2],
        totalCalories: 0,
        totalProteinG: 0,
        totalCarbsG: 0,
        totalFatG: 0,
        atwaterCalories: 0,
      ).recalculate();

      expect(result.totalProteinG, equals(51.5));
      expect(result.totalCarbsG, equals(45.0));
      expect(result.totalFatG, equals(7.5));
      // Atwater = 51.5*4 + 45.0*4 + 7.5*9 = 206 + 180 + 67.5 = 453.5
      expect(result.atwaterCalories, equals(453.5));
      expect(result.totalCalories, equals(453.5));
    });

    test('DailyMacroSummary progress ratios clamp cleanly', () {
      const summary = DailyMacroSummary(
        date: '2026-10-21',
        loggedMeals: 2,
        totalCalories: 1500,
        totalProteinG: 120,
        totalCarbsG: 150,
        totalFatG: 50,
        targetCalories: 2000,
        targetProteinG: 150,
        targetCarbsG: 200,
        targetFatG: 65,
      );

      expect(summary.caloriesProgress, equals(0.75));
      expect(summary.proteinProgress, equals(0.8));
      expect(summary.carbsProgress, equals(0.75));
    });

    test('FoodItem preserves baseline density and prevents cumulative scaling drift', () {
      const original = FoodItem(
        name: 'Whey Protein Isolate',
        portionG: 30.0,
        calories: 120.0,
        proteinG: 27.0,
        carbsG: 1.0,
        fatG: 0.5,
      );

      // Simulate user dragging slider from 30g -> 15g -> 60g -> 5g -> 30g
      final s1 = original.scaleToPortion(15.0);
      final s2 = s1.scaleToPortion(60.0);
      final s3 = s2.scaleToPortion(5.0);
      final backToOriginal = s3.scaleToPortion(30.0);

      expect(backToOriginal.portionG, equals(30.0));
      expect(backToOriginal.proteinG, equals(27.0));
      expect(backToOriginal.carbsG, equals(1.0));
      expect(backToOriginal.fatG, equals(0.5));
      expect(backToOriginal.calories, equals(116.5));
    });

    test('FoodItem zero portion handling recovers gracefully without data loss', () {
      const original = FoodItem(
        name: 'Greek Yogurt',
        portionG: 100.0,
        calories: 90.0,
        proteinG: 15.0,
        carbsG: 5.0,
        fatG: 1.0,
      );

      final zeroPortion = original.scaleToPortion(0.0);
      expect(zeroPortion.portionG, equals(0.0));
      expect(zeroPortion.proteinG, equals(0.0));
      expect(zeroPortion.calories, equals(0.0));

      final restored = zeroPortion.scaleToPortion(100.0);
      expect(restored.portionG, equals(100.0));
      expect(restored.proteinG, equals(15.0));
      expect(restored.carbsG, equals(5.0));
      expect(restored.fatG, equals(1.0));
    });

    test('FoodItem.fromJson enforces strict Atwater calories even if raw json differs', () {
      final json = {
        'name': 'Peanut Butter',
        'portion_g': 32.0,
        'protein_g': 8.0,
        'carbs_g': 6.0,
        'fat_g': 16.0,
        'calories': 999.0, // Hallucinated LLM calories
      };

      final item = FoodItem.fromJson(json);
      // Expected Atwater: 8*4 + 6*4 + 16*9 = 32 + 24 + 144 = 200.0 kcal
      expect(item.calories, equals(200.0));
    });
  });

  group('Food Scanner UI Widgets', () {
    testWidgets('FoodScannerOverlay renders radar, laser, and HUD telemetry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: FoodScannerOverlay(
                statusText: 'SCANNING ATWATER 4P+4C+9F...',
                isAnalyzing: true,
              ),
            ),
          ),
        ),
      );

      // Verify HUD badges
      expect(find.text('PULSEFIT NEURAL VISION'), findsOneWidget);
      expect(find.text('SCANNING ATWATER 4P+4C+9F...'), findsOneWidget);

      // Advance animation ticks
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('MacroTargetCard displays calories, macro bars, and scan action', (tester) async {
      bool scannerTapped = false;
      const summary = DailyMacroSummary(
        date: '2026-10-21',
        loggedMeals: 3,
        totalCalories: 1850,
        totalProteinG: 160,
        totalCarbsG: 180,
        totalFatG: 55,
        targetCalories: 2200,
        targetProteinG: 180,
        targetCarbsG: 220,
        targetFatG: 70,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroTargetCard(
              summary: summary,
              onTapScanner: () => scannerTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Daily Nutrition'), findsOneWidget);
      expect(find.text('3 meals logged today'), findsOneWidget);
      expect(find.text('Energy: 1850 / 2200 kcal'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);

      // Tap scan icon
      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pump();
      expect(scannerTapped, isTrue);
    });

    testWidgets('MealReviewSheet allows portion slider adjustments and saves', (tester) async {
      NutritionLog? savedLog;
      const initialItem = FoodItem(
        name: 'Grilled Steak',
        portionG: 200.0,
        calories: 494.0,
        proteinG: 52.0,
        carbsG: 0.0,
        fatG: 32.0,
      );

      const analysis = NutritionAnalysisResult(
        mealName: 'Post-Workout Steak',
        items: [initialItem],
        totalCalories: 494.0,
        totalProteinG: 52.0,
        totalCarbsG: 0.0,
        totalFatG: 32.0,
        atwaterCalories: 494.0,
        healthScore: 88,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealReviewSheet(
              analysisResult: analysis,
              onSaveMeal: (log) => savedLog = log,
            ),
          ),
        ),
      );

      expect(find.text('Grilled Steak'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Tap Save button
      final saveBtn = find.textContaining('Save');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pump();

      expect(savedLog, isNotNull);
      expect(savedLog!.mealName, equals('Post-Workout Steak'));
      expect(savedLog!.totalProteinG, equals(52.0));
    });

    testWidgets('MealReviewSheet opens portion edit dialog on tapping badge and updates weight', (tester) async {
      const initialItem = FoodItem(
        name: 'Brown Rice',
        portionG: 100.0,
        calories: 111.0,
        proteinG: 2.6,
        carbsG: 23.0,
        fatG: 0.9,
      );

      const analysis = NutritionAnalysisResult(
        mealName: 'Carb Plate',
        items: [initialItem],
        totalCalories: 111.0,
        totalProteinG: 2.6,
        totalCarbsG: 23.0,
        totalFatG: 0.9,
        atwaterCalories: 111.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealReviewSheet(
              analysisResult: analysis,
              onSaveMeal: (_) {},
            ),
          ),
        ),
      );

      // Tap portion badge '100g'
      await tester.tap(find.text('100g'));
      await tester.pumpAndSettle();

      // Check dialog opened
      expect(find.text('Set Portion: Brown Rice'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      // Enter 200
      await tester.enterText(find.widgetWithText(TextField, 'Weight in Grams (g)'), '200');
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      // Verify updated portion is displayed
      expect(find.text('200g'), findsOneWidget);
      // Macros doubled: 2.6 * 2 = 5.2g protein
      expect(find.textContaining('P: 5.2g'), findsOneWidget);
    });
  });
}
