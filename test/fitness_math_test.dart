import 'package:fitness_app/core/math/fitness_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // 1. BMR / TDEE / Auto Macros
  // ═══════════════════════════════════════════════════════════════════════

  group('BMR / TDEE', () {
    test('Mifflin-St Jeor BMR — 80kg, 180cm, 25y, male', () {
      final bmr = BmrTdeeCalculator.bmr(
        weightKg: 80,
        heightCm: 180,
        ageYears: 25,
        sex: BiologicalSex.male,
      );
      // 10(80) + 6.25(180) − 5(25) + 5 = 800 + 1125 − 125 + 5 = 1805
      expect(bmr, 1805.0);
    });

    test('Mifflin-St Jeor BMR — 60kg, 165cm, 30y, female', () {
      final bmr = BmrTdeeCalculator.bmr(
        weightKg: 60,
        heightCm: 165,
        ageYears: 30,
        sex: BiologicalSex.female,
      );
      // 10(60) + 6.25(165) − 5(30) − 161 = 600 + 1031.25 − 150 − 161 = 1320.25
      expect(bmr, closeTo(1320.3, 0.1));
    });

    test('TDEE with moderate activity', () {
      final tdee = BmrTdeeCalculator.tdee(
        weightKg: 80,
        heightCm: 180,
        ageYears: 25,
        sex: BiologicalSex.male,
        activity: ActivityLevel.moderate,
      );
      // 1805 × 1.55 = 2797.75
      expect(tdee, closeTo(2797.8, 0.1));
    });

    test('Auto macros — fat loss goal', () {
      final result = BmrTdeeCalculator.autoMacros(
        weightKg: 80,
        heightCm: 180,
        ageYears: 25,
        sex: BiologicalSex.male,
        activity: ActivityLevel.moderate,
        goal: FitnessGoal.fatLoss,
      );

      // TDEE ≈ 2797.8, −500 = 2297.8
      expect(result.calories, closeTo(2297.8, 1));
      expect(result.goalAdjustment, -500);

      // Verify Atwater invariance: P×4 + C×4 + F×9 ≈ total calories
      final atwater = result.proteinG * 4 + result.carbsG * 4 + result.fatG * 9;
      expect(atwater, closeTo(result.calories, 2));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. One-Rep Max
  // ═══════════════════════════════════════════════════════════════════════

  group('1RM Estimation', () {
    test('Epley — 100kg × 10 reps', () {
      final orm = OneRepMax.epley(100, 10);
      // 100 × (1 + 10/30) = 100 × 1.333 = 133.3
      expect(orm, closeTo(133.3, 0.1));
    });

    test('Brzycki — 100kg × 5 reps', () {
      final orm = OneRepMax.brzycki(100, 5);
      // 100 / (1.0278 − 0.0278×5) = 100 / 0.8888 = 112.5
      expect(orm, closeTo(112.5, 0.2));
    });

    test('Best-fit uses Brzycki for ≤10 reps', () {
      final result = OneRepMax.estimate(100, 8);
      final brzycki = OneRepMax.brzycki(100, 8);
      expect(result, brzycki);
    });

    test('Best-fit uses Epley for >10 reps', () {
      final result = OneRepMax.estimate(100, 15);
      final epley = OneRepMax.epley(100, 15);
      expect(result, epley);
    });

    test('1 rep returns the weight itself', () {
      expect(OneRepMax.estimate(140, 1), 140.0);
    });

    test('Zero weight/reps returns 0', () {
      expect(OneRepMax.estimate(0, 5), 0.0);
      expect(OneRepMax.estimate(100, 0), 0.0);
    });

    test('%1RM calculation', () {
      final pct = OneRepMax.percentOf1RM(80, 100);
      expect(pct, 80.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. Progressive Overload
  // ═══════════════════════════════════════════════════════════════════════

  group('Progressive Overload', () {
    test('Positive overload — volume increased', () {
      final result = ProgressiveOverload.compare(5000, 4750);
      // (5000−4750)/4750 × 100 = 5.26%
      expect(result.overloadPercent, closeTo(5.3, 0.1));
      expect(result.isPositive, true);
      expect(result.isPR, true);
    });

    test('Negative overload — volume decreased', () {
      final result = ProgressiveOverload.compare(4500, 5000);
      expect(result.overloadPercent, closeTo(-10.0, 0.1));
      expect(result.isPositive, false);
    });

    test('First session', () {
      final result = ProgressiveOverload.compare(3000, 0);
      expect(result.isFirstSession, true);
      expect(result.overloadPercent, 0.0);
      expect(result.isPR, false);
      expect(result.isPositive, false);
      expect(result.label, 'First Session');
    });

    test('Exercise volume computation', () {
      final vol = ProgressiveOverload.exerciseVolume([
        (weight: 100.0, reps: 10),
        (weight: 100.0, reps: 8),
        (weight: 90.0, reps: 12),
      ]);
      // 1000 + 800 + 1080 = 2880
      expect(vol, 2880.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. Adaptive Rest Timer
  // ═══════════════════════════════════════════════════════════════════════

  group('Adaptive Rest', () {
    test('Endurance zone — 15+ reps → 60s', () {
      expect(AdaptiveRest.fromReps(20), 60);
      expect(AdaptiveRest.fromReps(15), 60);
    });

    test('Hypertrophy zone — 8–14 reps → 90s', () {
      expect(AdaptiveRest.fromReps(10), 90);
      expect(AdaptiveRest.fromReps(8), 90);
    });

    test('Strength zone — 4–7 reps → 150s', () {
      expect(AdaptiveRest.fromReps(5), 150);
    });

    test('Power zone — 1–3 reps → 240s', () {
      expect(AdaptiveRest.fromReps(2), 240);
    });

    test('Intensity-based rest scales with %1RM', () {
      // Heavy single at 95% of 1RM → should be close to max rest
      final heavy = AdaptiveRest.fromIntensity(
        weight: 95,
        reps: 1,
        estimated1RM: 100,
      );
      // 30 + 150 × 0.95² = 30 + 135.375 ≈ 165
      expect(heavy, closeTo(165, 2));

      // Light set at 50% of 1RM → shorter rest
      final light = AdaptiveRest.fromIntensity(
        weight: 50,
        reps: 12,
        estimated1RM: 100,
      );
      // 30 + 150 × 0.25 = 67.5
      expect(light, closeTo(68, 2));
    });

    test('Zone labels', () {
      expect(AdaptiveRest.zoneLabel(20), 'Endurance');
      expect(AdaptiveRest.zoneLabel(10), 'Hypertrophy');
      expect(AdaptiveRest.zoneLabel(5), 'Strength');
      expect(AdaptiveRest.zoneLabel(2), 'Power');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. Streak & Consistency
  // ═══════════════════════════════════════════════════════════════════════

  group('Streak & Consistency', () {
    test('3-day streak ending today', () {
      final now = DateTime(2026, 10, 24);
      final dates = [
        DateTime(2026, 10, 24), // today
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 22),
        DateTime(2026, 10, 19), // gap
      ];

      final result = StreakCalculator.calculate(dates, now: now);
      expect(result.currentStreak, 3);
    });

    test('Streak from yesterday (no workout today yet)', () {
      final now = DateTime(2026, 10, 24);
      final dates = [
        DateTime(2026, 10, 23), // yesterday
        DateTime(2026, 10, 22),
        DateTime(2026, 10, 21),
      ];

      final result = StreakCalculator.calculate(dates, now: now);
      expect(result.currentStreak, 3);
    });

    test('Zero streak — last workout was 3 days ago', () {
      final now = DateTime(2026, 10, 24);
      final dates = [
        DateTime(2026, 10, 21),
      ];

      final result = StreakCalculator.calculate(dates, now: now);
      expect(result.currentStreak, 0);
    });

    test('Workouts this week (Thursday = 4 weekday)', () {
      final now = DateTime(2026, 10, 22); // Thursday
      final dates = [
        DateTime(2026, 10, 19), // Monday
        DateTime(2026, 10, 20), // Tuesday
        DateTime(2026, 10, 22), // Thursday
        DateTime(2026, 10, 15), // Last Wednesday (outside this week)
      ];

      final result = StreakCalculator.calculate(dates, now: now);
      expect(result.workoutsThisWeek, 3);
    });

    test('Consistency score — 12 sessions in 28 days with 4/week target', () {
      final now = DateTime(2026, 10, 24);
      final dates = List.generate(
        12,
        (i) => now.subtract(Duration(days: i * 2)),
      );

      final result = StreakCalculator.calculate(dates, targetPerWeek: 4, now: now);
      // 12 / 16 × 100 = 75%
      expect(result.consistencyPct, 75.0);
      expect(result.consistencyLabel, 'Strong');
    });

    test('Empty sessions', () {
      final result = StreakCalculator.calculate([]);
      expect(result.currentStreak, 0);
      expect(result.workoutsThisWeek, 0);
      expect(result.consistencyPct, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. Muscle Frequency Analysis
  // ═══════════════════════════════════════════════════════════════════════

  group('Muscle Frequency', () {
    test('Optimal chest frequency — 2× in 7 days', () {
      final sessions = [
        (date: DateTime(2026, 10, 20), muscles: ['Chest', 'Arms']),
        (date: DateTime(2026, 10, 23), muscles: ['Chest', 'Shoulders']),
      ];

      final results = MuscleFrequencyAnalyzer.analyze(sessions, windowDays: 7);
      final chest = results.firstWhere((r) => r.muscle == 'Chest');
      expect(chest.frequencyPerWeek, 2.0);
      expect(chest.status, MuscleFrequencyStatus.optimal);
    });

    test('Neglected legs — 0× in 28 days', () {
      final sessions = [
        (date: DateTime(2026, 10, 20), muscles: ['Chest']),
        (date: DateTime(2026, 10, 23), muscles: ['Back']),
      ];

      final results = MuscleFrequencyAnalyzer.analyze(sessions, windowDays: 28);
      final legs = results.firstWhere((r) => r.muscle == 'Legs');
      expect(legs.frequencyPerWeek, 0.0);
      expect(legs.status, MuscleFrequencyStatus.neglected);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. Workout Intensity (VLI)
  // ═══════════════════════════════════════════════════════════════════════

  group('Workout Intensity', () {
    test('Moderate session — 5000kg in 45min', () {
      final result = WorkoutIntensity.calculate(
        totalVolumeKg: 5000,
        durationSeconds: 45 * 60,
      );
      // 5000 / 45 = 111.1
      expect(result.vli, closeTo(111.1, 0.1));
      expect(result.level, IntensityLevel.moderate);
    });

    test('Brutal session — 20000kg in 50min', () {
      final result = WorkoutIntensity.calculate(
        totalVolumeKg: 20000,
        durationSeconds: 50 * 60,
      );
      // 20000 / 50 = 400
      expect(result.vli, closeTo(400.0, 0.1));
      expect(result.level, IntensityLevel.brutal);
    });

    test('Zero duration → Light', () {
      final result = WorkoutIntensity.calculate(
        totalVolumeKg: 1000,
        durationSeconds: 0,
      );
      expect(result.level, IntensityLevel.light);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. Body Composition
  // ═══════════════════════════════════════════════════════════════════════

  group('Body Composition', () {
    test('BMI — 80kg, 180cm', () {
      final bmiVal = BodyComposition.bmi(80, 180);
      // 80 / (1.8)² = 80 / 3.24 = 24.69
      expect(bmiVal, closeTo(24.7, 0.1));
      expect(BodyComposition.bmiCategory(bmiVal), 'Normal');
    });

    test('Navy body fat — male (waist=85, neck=38, height=180)', () {
      final bf = BodyComposition.navyBodyFat(
        sex: BiologicalSex.male,
        waistCm: 85,
        neckCm: 38,
        heightCm: 180,
      );
      // 86.010 × log₁₀(47) − 70.041 × log₁₀(180) + 36.76
      // 86.010 × 1.6721 − 70.041 × 2.2553 + 36.76
      // 143.81 − 157.92 + 36.76 = 22.65
      expect(bf, closeTo(22.6, 0.2));
      expect(bf, greaterThan(2));
      expect(bf, lessThan(60));
    });

    test('Full body composition analysis', () {
      final result = BodyComposition.analyze(
        weightKg: 80,
        heightCm: 180,
        sex: BiologicalSex.male,
        waistCm: 82,
        neckCm: 38,
      );

      expect(result.bmi, greaterThan(20));
      expect(result.bodyFatPct, greaterThan(5));
      expect(result.fatMassKg, greaterThan(0));
      expect(result.leanMassKg, greaterThan(0));
      expect(result.fatMassKg + result.leanMassKg, closeTo(80, 0.5));
    });

    test('Invalid measurements — waist <= neck returns Invalid Measurements', () {
      final result = BodyComposition.analyze(
        weightKg: 80,
        heightCm: 180,
        sex: BiologicalSex.male,
        waistCm: 35,
        neckCm: 38,
      );

      expect(result.bodyFatPct, 0.0);
      expect(result.bodyFatCategory, 'Invalid Measurements');
      expect(result.fatMassKg, 0.0);
      expect(result.leanMassKg, 80.0);
    });

    test('Invalid measurements — female waist + hip <= neck returns Invalid Measurements', () {
      final result = BodyComposition.analyze(
        weightKg: 60,
        heightCm: 165,
        sex: BiologicalSex.female,
        waistCm: 40,
        neckCm: 80,
        hipCm: 40,
      );

      expect(result.bodyFatPct, 0.0);
      expect(result.bodyFatCategory, 'Invalid Measurements');
      expect(result.fatMassKg, 0.0);
      expect(result.leanMassKg, 60.0);
    });

    test('Invalid measurements — non-positive weight returns Invalid Measurements', () {
      final result = BodyComposition.analyze(
        weightKg: 0,
        heightCm: 180,
        sex: BiologicalSex.male,
        waistCm: 80,
        neckCm: 38,
      );

      expect(result.bodyFatPct, 0.0);
      expect(result.bodyFatCategory, 'Invalid Measurements');
      expect(result.bmi, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. Calorie Burn (MET)
  // ═══════════════════════════════════════════════════════════════════════

  group('Calorie Burn', () {
    test('Standard weightlifting — 80kg, 60min', () {
      final result = CalorieBurn.estimateWorkoutBurn(
        weightKg: 80,
        durationSeconds: 60 * 60,
      );

      // Active: 45% of 60min = 27min, MET=6.0 → 6×80×(27/60) = 216
      // Rest: 33min, MET=2.0 → 2×80×(33/60) = 88
      // Total ≈ 304
      expect(result.totalKcal, greaterThan(200));
      expect(result.totalKcal, lessThan(500));
      expect(result.activeKcal, greaterThan(result.restKcal));
    });

    test('Clamps activeSeconds so rest is never negative', () {
      final result = CalorieBurn.estimateWorkoutBurn(
        weightKg: 80,
        durationSeconds: 30 * 60,
        activeSeconds: 40 * 60, // active exceeds total
      );

      expect(result.restKcal, 0.0);
      expect(result.totalKcal, greaterThan(0));
    });

    test('Clamps negative activeSeconds to zero', () {
      final result = CalorieBurn.estimateWorkoutBurn(
        weightKg: 80,
        durationSeconds: 30 * 60,
        activeSeconds: -120,
      );

      expect(result.activeKcal, 0.0);
      expect(result.restKcal, greaterThan(0));
      expect(result.totalKcal, result.restKcal);
    });

    test('High intensity session', () {
      final hi = CalorieBurn.estimateWorkoutBurn(
        weightKg: 80,
        durationSeconds: 45 * 60,
        isHighIntensity: true,
      );
      final normal = CalorieBurn.estimateWorkoutBurn(
        weightKg: 80,
        durationSeconds: 45 * 60,
      );

      expect(hi.totalKcal, greaterThan(normal.totalKcal));
    });

    test('Zero duration → zero calories', () {
      final result = CalorieBurn.estimateWorkoutBurn(
        weightKg: 80,
        durationSeconds: 0,
      );
      expect(result.totalKcal, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 10. Entropy-Based Volume Balance
  // ═══════════════════════════════════════════════════════════════════════

  group('Volume Balance Score', () {
    test('Perfectly balanced — equal volume in all groups', () {
      final result = VolumeBalance.score({
        'Chest': 1000,
        'Back': 1000,
        'Legs': 1000,
        'Shoulders': 1000,
        'Arms': 1000,
        'Core': 1000,
      });

      expect(result.score, closeTo(100.0, 0.1));
      expect(result.label, 'Excellent Balance');
    });

    test('More than 6 muscle groups clamps cleanly to 100', () {
      final result = VolumeBalance.score({
        'Chest': 1000,
        'Back': 1000,
        'Legs': 1000,
        'Shoulders': 1000,
        'Biceps': 1000,
        'Triceps': 1000,
        'Core': 1000,
        'Calves': 1000,
      });

      expect(result.score, 100.0);
      expect(result.label, 'Excellent Balance');
    });

    test('Heavily skewed — all chest', () {
      final result = VolumeBalance.score({
        'Chest': 5000,
        'Back': 100,
        'Legs': 0,
        'Shoulders': 0,
        'Arms': 0,
        'Core': 0,
      });

      expect(result.score, lessThan(30));
      expect(result.dominantMuscle, 'Chest');
      expect(result.dominantPct, greaterThan(90));
    });

    test('Moderate imbalance — upper body dominant', () {
      final result = VolumeBalance.score({
        'Chest': 3000,
        'Back': 2500,
        'Shoulders': 2000,
        'Arms': 1500,
        'Legs': 500,
        'Core': 200,
      });

      expect(result.score, greaterThan(40));
      expect(result.score, lessThan(90));
      expect(result.dominantMuscle, 'Chest');
    });

    test('Single group → score 0', () {
      final result = VolumeBalance.score({'Chest': 5000});
      expect(result.score, 0);
      expect(result.label, 'Single Focus');
    });

    test('Empty map → score 0', () {
      final result = VolumeBalance.score({});
      expect(result.score, 0);
      expect(result.label, 'No Data');
    });
  });
}
