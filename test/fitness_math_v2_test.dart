import 'package:fitness_app/core/math/fitness_math.dart';
import 'package:fitness_app/core/math/fitness_math_v2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 11. Per-Kg Protein Targets & Protein-First Macro Allocation
  // ═══════════════════════════════════════════════════════════════════════════

  group('ProteinFirstCalculator', () {
    test('80kg male maintenance — protein = 80 × 1.8 = 144g', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        goal: FitnessGoal.maintain,
      );

      // 1.8 g/kg for maintenance
      expect(result.proteinGPerKg, 1.8);
      expect(result.proteinG, closeTo(144.0, 2.0));
      expect(result.calories, greaterThan(1200));
      expect(result.bmrMethod, 'mifflin_st_jeor');
    });

    test('fat loss goal uses 2.2 g/kg to preserve muscle', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 75, heightCm: 175, ageYears: 30,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        goal: FitnessGoal.fatLoss,
      );

      expect(result.proteinGPerKg, 2.2);
      // 75 × 2.2 = 165g, but may be capped at 45% of calories
      expect(result.proteinG, greaterThan(0));
      expect(result.goalAdjustment, -500);
    });

    test('bulking goal uses 1.6 g/kg (surplus supports anabolism)', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 70, heightCm: 170, ageYears: 22,
        sex: BiologicalSex.male, activity: ActivityLevel.active,
        goal: FitnessGoal.bulking,
      );

      expect(result.proteinGPerKg, 1.6);
      expect(result.goalAdjustment, 500);
    });

    test('Atwater invariant: P×4 + C×4 + F×9 ≈ target calories', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
      );

      final atwater =
          result.proteinG * 4 + result.carbsG * 4 + result.fatG * 9;
      expect(atwater, closeTo(result.calories, 5.0));
    });

    test('percentage sum ≈ 100% (within rounding)', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 65, heightCm: 165, ageYears: 28,
        sex: BiologicalSex.female, activity: ActivityLevel.light,
      );

      final pctSum =
          result.proteinPctActual + result.carbsPctActual + result.fatPctActual;
      expect(pctSum, closeTo(100.0, 2.0));
    });

    test('protein cap at 45% prevents starvation of carbs/fat', () {
      // Very light person with high protein target
      final result = ProteinFirstCalculator.calculate(
        weightKg: 50, heightCm: 155, ageYears: 40,
        sex: BiologicalSex.female, activity: ActivityLevel.sedentary,
        goal: FitnessGoal.fatLoss, // 2.2 g/kg = 110g = 440 kcal
      );

      // Protein should not exceed 45% of total calories
      expect(result.proteinPctActual, lessThanOrEqualTo(46.0));
    });

    test('minimum fat floor of 0.8 g/kg maintained', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
      );

      // Fat should be at least 0.8 × 80 = 64g
      expect(result.fatG, greaterThanOrEqualTo(63.0));
    });

    test('custom protein override: 2.5 g/kg', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        proteinGPerKg: 2.5,
      );

      expect(result.proteinGPerKg, 2.5);
      // 80 × 2.5 = 200g, may be capped at 45%
      expect(result.proteinG, greaterThan(0));
    });

    test('high-carb strategy allocates 65% remaining to carbs', () {
      final balanced = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        strategy: CarbFatStrategy.balanced,
      );
      final highCarb = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        strategy: CarbFatStrategy.highCarb,
      );

      // High-carb should have more carbs, less fat
      expect(highCarb.carbsG, greaterThan(balanced.carbsG));
      expect(highCarb.fatG, lessThan(balanced.fatG));
      // Same protein
      expect(highCarb.proteinG, closeTo(balanced.proteinG, 1.0));
    });

    test('low-carb strategy allocates 65% remaining to fat', () {
      final balanced = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        strategy: CarbFatStrategy.balanced,
      );
      final lowCarb = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        strategy: CarbFatStrategy.lowCarb,
      );

      expect(lowCarb.fatG, greaterThan(balanced.fatG));
      expect(lowCarb.carbsG, lessThan(balanced.carbsG));
    });

    test('evenGrams strategy produces equal carb and fat grams (approx)', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        strategy: CarbFatStrategy.evenGrams,
      );

      expect(result.carbsG, greaterThan(0));
      expect(result.fatG, greaterThan(0));
      expect(result.carbsG, closeTo(result.fatG, 1.0));
    });

    test('evenGrams falls back to minFatG when targetG < minFatG', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 100, heightCm: 160, ageYears: 50,
        sex: BiologicalSex.female, activity: ActivityLevel.sedentary,
        goal: FitnessGoal.fatLoss,
        strategy: CarbFatStrategy.evenGrams,
      );

      // minFatG = 100 * 0.8 = 80g
      expect(result.fatG, greaterThanOrEqualTo(79.0));
    });

    test('Katch-McArdle used when bodyFatPct is provided', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
        bodyFatPct: 14.0,
      );

      expect(result.bmrMethod, 'katch_mcardle');
      expect(result.katchMcArdleBmr, isNotNull);
      expect(result.katchMcArdleBmr, greaterThan(0));
    });

    test('zero/negative inputs return zeroed result', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 0, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, activity: ActivityLevel.moderate,
      );

      expect(result.calories, 0);
      expect(result.proteinG, 0);
    });

    test('female 60kg mild cut', () {
      final result = ProteinFirstCalculator.calculate(
        weightKg: 60, heightCm: 165, ageYears: 30,
        sex: BiologicalSex.female, activity: ActivityLevel.light,
        goal: FitnessGoal.mildCut,
      );

      expect(result.proteinGPerKg, 2.0);
      expect(result.proteinG, closeTo(120.0, 10.0));
      expect(result.goalAdjustment, -250);
      expect(result.calories, greaterThan(1200));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. Katch-McArdle BMR
  // ═══════════════════════════════════════════════════════════════════════════

  group('KatchMcArdle', () {
    test('BMR: 80kg at 14% body fat', () {
      final bmr = KatchMcArdle.bmr(weightKg: 80, bodyFatPct: 14);
      // LBM = 80 × 0.86 = 68.8 kg
      // BMR = 370 + 21.6 × 68.8 = 370 + 1486.08 = 1856.08
      expect(bmr, closeTo(1856.1, 0.2));
    });

    test('BMR: 60kg at 25% body fat (female typical)', () {
      final bmr = KatchMcArdle.bmr(weightKg: 60, bodyFatPct: 25);
      // LBM = 60 × 0.75 = 45 kg
      // BMR = 370 + 21.6 × 45 = 370 + 972 = 1342
      expect(bmr, closeTo(1342.0, 0.2));
    });

    test('BMR: 0% body fat (essential minimum edge case)', () {
      final bmr = KatchMcArdle.bmr(weightKg: 80, bodyFatPct: 0);
      // LBM = 80 kg
      // BMR = 370 + 21.6 × 80 = 370 + 1728 = 2098
      expect(bmr, closeTo(2098.0, 0.2));
    });

    test('BMR: invalid inputs return 0', () {
      expect(KatchMcArdle.bmr(weightKg: 0, bodyFatPct: 14), 0.0);
      expect(KatchMcArdle.bmr(weightKg: -10, bodyFatPct: 14), 0.0);
      expect(KatchMcArdle.bmr(weightKg: 80, bodyFatPct: 100), 0.0);
      expect(KatchMcArdle.bmr(weightKg: 80, bodyFatPct: -5), 0.0);
    });

    test('TDEE multiplies BMR by activity factor', () {
      final bmr = KatchMcArdle.bmr(weightKg: 80, bodyFatPct: 14);
      final tdee = KatchMcArdle.tdee(
        weightKg: 80, bodyFatPct: 14,
        activity: ActivityLevel.moderate,
      );
      expect(tdee, closeTo(bmr * 1.55, 0.5));
    });

    test('compare() shows side-by-side Mifflin vs Katch', () {
      final comp = KatchMcArdle.compare(
        weightKg: 80, heightCm: 180, ageYears: 25,
        sex: BiologicalSex.male, bodyFatPct: 14,
      );

      // Mifflin: 10(80) + 6.25(180) − 5(25) + 5 = 1805
      expect(comp.mifflinStJeor, closeTo(1805.0, 0.5));
      // Katch: 370 + 21.6 × 68.8 ≈ 1856.1
      expect(comp.katchMcArdle, closeTo(1856.1, 0.5));
      // Delta should be positive (Katch higher for muscular individual)
      expect(comp.deltaKcal, greaterThan(0));
      expect(comp.leanMassKg, closeTo(68.8, 0.1));
      expect(comp.bodyFatPct, 14.0);
    });

    test('compare() high body fat — Katch lower than Mifflin', () {
      final comp = KatchMcArdle.compare(
        weightKg: 100, heightCm: 175, ageYears: 35,
        sex: BiologicalSex.male, bodyFatPct: 35,
      );

      // High BF means less lean mass → Katch gives lower BMR
      // Mifflin uses total weight and gives a higher estimate
      expect(comp.deltaKcal, lessThan(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. Fiber-Aware Modified Atwater
  // ═══════════════════════════════════════════════════════════════════════════

  group('FiberAwareAtwater', () {
    test('netCarbs: 50g total − 10g fiber = 40g', () {
      expect(FiberAwareAtwater.netCarbs(50, fiberG: 10), 40.0);
    });

    test('netCarbs: fiber exceeds total carbs → clamps to 0', () {
      expect(FiberAwareAtwater.netCarbs(5, fiberG: 10), 0.0);
    });

    test('netCarbs with sugar alcohols', () {
      expect(
        FiberAwareAtwater.netCarbs(50, fiberG: 10, sugarAlcoholsG: 5),
        35.0,
      );
    });

    test('standardCalories matches classic 4-4-9', () {
      final cal = FiberAwareAtwater.standardCalories(
        proteinG: 30, totalCarbsG: 50, fatG: 20,
      );
      // 30×4 + 50×4 + 20×9 = 120 + 200 + 180 = 500
      expect(cal, 500.0);
    });

    test('fiberAwareCalories: 30g fiber saves 60 kcal', () {
      final standard = FiberAwareAtwater.standardCalories(
        proteinG: 40, totalCarbsG: 200, fatG: 60,
      );
      final fiberAware = FiberAwareAtwater.fiberAwareCalories(
        proteinG: 40, totalCarbsG: 200, fatG: 60, fiberG: 30,
      );

      // Difference should be 30 × (4 − 2) = 60 kcal
      expect(standard - fiberAware, closeTo(60.0, 0.2));
    });

    test('fiberAwareCalories: zero fiber matches standard', () {
      final standard = FiberAwareAtwater.standardCalories(
        proteinG: 30, totalCarbsG: 50, fatG: 20,
      );
      final fiberAware = FiberAwareAtwater.fiberAwareCalories(
        proteinG: 30, totalCarbsG: 50, fatG: 20, fiberG: 0,
      );
      expect(fiberAware, standard);
    });

    test('fiberAwareCalories: sugar alcohols reduce calories', () {
      final withoutSA = FiberAwareAtwater.fiberAwareCalories(
        proteinG: 30, totalCarbsG: 50, fatG: 20,
      );
      final withSA = FiberAwareAtwater.fiberAwareCalories(
        proteinG: 30, totalCarbsG: 50, fatG: 20, sugarAlcoholsG: 10,
      );

      // 10g SA saves 10 × (4 − 2.4) = 16 kcal
      expect(withoutSA - withSA, closeTo(16.0, 0.2));
    });

    test('fiberAwareCalories: fiber clamped to total carbs', () {
      // 10g carbs, 20g fiber → effective fiber = 10g
      final cal = FiberAwareAtwater.fiberAwareCalories(
        proteinG: 30, totalCarbsG: 10, fatG: 20, fiberG: 20,
      );
      // P: 30×4=120, C: 0×4=0, Fiber: 10×2=20, F: 20×9=180
      // Total = 120 + 0 + 20 + 180 = 320
      expect(cal, closeTo(320.0, 0.2));
    });

    test('savings: 30g fiber = 60 kcal saved', () {
      expect(
        FiberAwareAtwater.savings(totalCarbsG: 200, fiberG: 30),
        closeTo(60.0, 0.2),
      );
    });

    test('savings: 10g SA = 16 kcal saved', () {
      expect(
        FiberAwareAtwater.savings(totalCarbsG: 200, sugarAlcoholsG: 10),
        closeTo(16.0, 0.2),
      );
    });

    test('savings: fiber + SA combined', () {
      expect(
        FiberAwareAtwater.savings(
          totalCarbsG: 200, fiberG: 25, sugarAlcoholsG: 10,
        ),
        closeTo(25 * 2.0 + 10 * 1.6, 0.2), // 50 + 16 = 66
      );
    });

    test('savings: zero when no fiber or SA', () {
      expect(FiberAwareAtwater.savings(totalCarbsG: 200), 0.0);
    });

    test('real-world: oatmeal bowl (high fiber)', () {
      // 100g oats: ~13g protein, ~66g carbs (10g fiber), ~7g fat
      final standard = FiberAwareAtwater.standardCalories(
        proteinG: 13, totalCarbsG: 66, fatG: 7,
      );
      final fiberAware = FiberAwareAtwater.fiberAwareCalories(
        proteinG: 13, totalCarbsG: 66, fatG: 7, fiberG: 10,
      );

      // Standard: 52 + 264 + 63 = 379
      expect(standard, closeTo(379.0, 0.2));
      // Fiber-aware: 52 + 224 + 20 + 63 = 359 (saves 20 kcal)
      expect(fiberAware, closeTo(359.0, 0.2));
      expect(standard - fiberAware, closeTo(20.0, 0.2));
    });

    test('negative fiber and sugar alcohols are guarded to 0', () {
      expect(FiberAwareAtwater.netCarbs(50, fiberG: -10, sugarAlcoholsG: -5), 50.0);
      final standard = FiberAwareAtwater.standardCalories(
        proteinG: 30, totalCarbsG: 50, fatG: 20,
      );
      final fiberAware = FiberAwareAtwater.fiberAwareCalories(
        proteinG: 30, totalCarbsG: 50, fatG: 20, fiberG: -10, sugarAlcoholsG: -5,
      );
      expect(fiberAware, standard);
      expect(FiberAwareAtwater.savings(totalCarbsG: 50, fiberG: -10, sugarAlcoholsG: -5), 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 14. Adaptive TDEE
  // ═══════════════════════════════════════════════════════════════════════════

  group('AdaptiveTdee', () {
    List<DailyMetabolicEntry> generateEntries({
      required int days,
      required double startWeight,
      required double endWeight,
      required int dailyCalories,
      double weightNoise = 0.0,
    }) {
      final entries = <DailyMetabolicEntry>[];
      final baseDate = DateTime(2026, 1, 1);
      for (int i = 0; i < days; i++) {
        final t = days > 1 ? i / (days - 1) : 0.0;
        final trendWeight = startWeight + (endWeight - startWeight) * t;
        // Add deterministic "noise" based on day index
        final noise = weightNoise * ((i % 3 == 0) ? 0.5 : (i % 3 == 1) ? -0.3 : 0.1);
        entries.add(DailyMetabolicEntry(
          date: baseDate.add(Duration(days: i)),
          morningWeightKg: trendWeight + noise,
          caloriesConsumed: dailyCalories,
        ));
      }
      return entries;
    }

    test('empty entries returns zeroed result', () {
      final result = AdaptiveTdee.calculate([]);
      expect(result.estimatedTdee, 0);
      expect(result.minimumDaysMet, false);
      expect(result.confidenceLevel, 'low');
    });

    test('single entry returns low confidence', () {
      final result = AdaptiveTdee.calculate([
        DailyMetabolicEntry(
          date: DateTime(2026, 1, 1),
          morningWeightKg: 80,
          caloriesConsumed: 2500,
        ),
      ]);
      expect(result.minimumDaysMet, false);
      expect(result.confidenceLevel, 'low');
    });

    test('weight maintenance over 21 days → TDEE ≈ intake', () {
      // If weight stays flat at 80kg and intake is 2500 kcal/day,
      // then TDEE should be ≈ 2500 kcal.
      final entries = generateEntries(
        days: 21, startWeight: 80.0, endWeight: 80.0,
        dailyCalories: 2500,
      );
      final result = AdaptiveTdee.calculate(entries);

      expect(result.estimatedTdee, closeTo(2500, 100));
      expect(result.weightTrendKgPerWeek, closeTo(0.0, 0.1));
      expect(result.minimumDaysMet, true);
    });

    test('losing 1kg over 21 days → TDEE ≈ intake + 367/day', () {
      // Losing 1kg in 21 days: 1 × 7700 / 21 ≈ 367 kcal/day deficit
      // If eating 2000 kcal → TDEE ≈ 2000 + 367 ≈ 2367
      final entries = generateEntries(
        days: 21, startWeight: 80.0, endWeight: 79.0,
        dailyCalories: 2000,
      );
      final result = AdaptiveTdee.calculate(entries);

      // Note: EMA smoothing slightly shifts the effective delta
      expect(result.estimatedTdee, closeTo(2367, 120));
      expect(result.weightTrendKgPerWeek, lessThan(0));
    });

    test('gaining 2kg over 28 days → TDEE ≈ intake − 550/day', () {
      // Gaining 2kg in 28 days: 2 × 7700 / 28 ≈ 550 kcal/day surplus
      // If eating 3000 kcal → TDEE ≈ 3000 − 550 ≈ 2450
      final entries = generateEntries(
        days: 28, startWeight: 80.0, endWeight: 82.0,
        dailyCalories: 3000,
      );
      final result = AdaptiveTdee.calculate(entries);

      expect(result.estimatedTdee, closeTo(2450, 150));
      expect(result.weightTrendKgPerWeek, greaterThan(0));
    });

    test('confidence: high at 21+ days with 80%+ completeness', () {
      final entries = generateEntries(
        days: 25, startWeight: 80, endWeight: 80,
        dailyCalories: 2500,
      );
      final result = AdaptiveTdee.calculate(entries);

      expect(result.confidenceLevel, 'high');
      expect(result.minimumDaysMet, true);
    });

    test('confidence: moderate at 14-20 days with 60%+ completeness', () {
      final entries = generateEntries(
        days: 16, startWeight: 80, endWeight: 80,
        dailyCalories: 2500,
      );
      final result = AdaptiveTdee.calculate(entries);

      expect(result.confidenceLevel, 'moderate');
      expect(result.minimumDaysMet, true);
    });

    test('confidence: low with <14 days', () {
      final entries = generateEntries(
        days: 10, startWeight: 80, endWeight: 80,
        dailyCalories: 2500,
      );
      final result = AdaptiveTdee.calculate(entries);

      expect(result.confidenceLevel, 'low');
      expect(result.minimumDaysMet, false);
    });

    test('EMA smooths water weight noise', () {
      final entries = generateEntries(
        days: 21, startWeight: 80.0, endWeight: 80.0,
        dailyCalories: 2500, weightNoise: 1.5,
      );
      final result = AdaptiveTdee.calculate(entries);

      // Despite ±1.5kg noise, TDEE should still be close to intake.
      // EMA dampens noise but deterministic patterns can shift the trend
      // slightly, so we use a wider tolerance.
      expect(result.estimatedTdee, closeTo(2500, 300));
      // Smoothed weight should be near 80kg
      expect(result.smoothedWeightKg, closeTo(80.0, 1.5));
    });

    test('TDEE clamped between 800 and 8000', () {
      // Extreme case: massive deficit
      final entries = generateEntries(
        days: 21, startWeight: 100.0, endWeight: 80.0,
        dailyCalories: 500,
      );
      final result = AdaptiveTdee.calculate(entries);

      expect(result.estimatedTdee, greaterThanOrEqualTo(800));
      expect(result.estimatedTdee, lessThanOrEqualTo(8000));
    });

    test('missing calorie entries handled gracefully', () {
      final baseDate = DateTime(2026, 1, 1);
      final entries = <DailyMetabolicEntry>[];
      for (int i = 0; i < 21; i++) {
        entries.add(DailyMetabolicEntry(
          date: baseDate.add(Duration(days: i)),
          morningWeightKg: 80.0,
          // Only log calories every other day
          caloriesConsumed: i % 2 == 0 ? 2500 : null,
        ));
      }
      final result = AdaptiveTdee.calculate(entries);

      // Should still compute, using available calorie data
      expect(result.avgDailyCalories, closeTo(2500, 1));
      expect(result.estimatedTdee, greaterThan(0));
    });

    test('missing weight entries handled gracefully', () {
      final baseDate = DateTime(2026, 1, 1);
      final entries = <DailyMetabolicEntry>[];
      for (int i = 0; i < 21; i++) {
        entries.add(DailyMetabolicEntry(
          date: baseDate.add(Duration(days: i)),
          // Only log weight every 3rd day
          morningWeightKg: i % 3 == 0 ? 80.0 : null,
          caloriesConsumed: 2500,
        ));
      }
      final result = AdaptiveTdee.calculate(entries);

      expect(result.estimatedTdee, greaterThan(0));
      expect(result.smoothedWeightKg, closeTo(80.0, 0.5));
    });

    test('avgDailyCalories is accurate', () {
      final entries = generateEntries(
        days: 14, startWeight: 80, endWeight: 80,
        dailyCalories: 2200,
      );
      final result = AdaptiveTdee.calculate(entries);
      expect(result.avgDailyCalories, closeTo(2200, 1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Cross-Engine Integration Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('Cross-Engine Integration', () {
    test('ProteinFirst with Katch-McArdle vs without — different BMR', () {
      final withoutBF = ProteinFirstCalculator.calculate(
        weightKg: 90, heightCm: 185, ageYears: 28,
        sex: BiologicalSex.male, activity: ActivityLevel.active,
        bodyFatPct: null,
      );
      final withBF = ProteinFirstCalculator.calculate(
        weightKg: 90, heightCm: 185, ageYears: 28,
        sex: BiologicalSex.male, activity: ActivityLevel.active,
        bodyFatPct: 12.0,
      );

      expect(withoutBF.bmrMethod, 'mifflin_st_jeor');
      expect(withBF.bmrMethod, 'katch_mcardle');
      // Muscular person: Katch should give higher BMR
      expect(withBF.bmr, greaterThan(withoutBF.bmr));
      // Calories should differ accordingly
      expect(withBF.calories, isNot(equals(withoutBF.calories)));
    });

    test('FiberAware savings matches manual calculation', () {
      // Meal: 40g protein, 80g carbs (12g fiber, 5g SA), 25g fat
      final standard = FiberAwareAtwater.standardCalories(
        proteinG: 40, totalCarbsG: 80, fatG: 25,
      );
      final aware = FiberAwareAtwater.fiberAwareCalories(
        proteinG: 40, totalCarbsG: 80, fatG: 25,
        fiberG: 12, sugarAlcoholsG: 5,
      );
      final saved = FiberAwareAtwater.savings(
        totalCarbsG: 80, fiberG: 12, sugarAlcoholsG: 5,
      );

      expect(standard - aware, closeTo(saved, 0.5));
      // Manual: 12×2 + 5×1.6 = 24 + 8 = 32
      expect(saved, closeTo(32.0, 0.5));
    });
  });
}
