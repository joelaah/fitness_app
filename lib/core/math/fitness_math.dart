import 'dart:math' as math;

/// ═══════════════════════════════════════════════════════════════════════════
/// PulseFit Fitness Mathematics Engine
/// ═══════════════════════════════════════════════════════════════════════════
/// All deterministic, scientifically-validated formulas for fitness tracking.
/// No ML, no deep learning — pure math that runs instantly on-device.
///
/// References:
///   • Mifflin-St Jeor (1990) — BMR
///   • Epley (1985) / Brzycki (1993) — 1RM
///   • ACSM MET Compendium (2011) — Calorie Burn
///   • Hodgdon & Beckett (1984) — Navy Body Fat %
///   • Shannon Entropy — Volume Balance Scoring

// ─────────────────────────────────────────────────────────────────────────────
// 1. BMR / TDEE / Auto Macro Splits
// ─────────────────────────────────────────────────────────────────────────────

enum BiologicalSex { male, female }

enum ActivityLevel {
  sedentary,     // Desk job, no exercise
  light,         // 1–3 days/week
  moderate,      // 3–5 days/week
  active,        // 6–7 days/week
  athlete,       // 2× daily / physical job + training
}

enum FitnessGoal {
  fatLoss,       // –500 kcal deficit
  mildCut,       // –250 kcal deficit
  maintain,      //  0
  mildBulk,      // +250 kcal surplus
  bulking,       // +500 kcal surplus
}

class MacroSplit {
  const MacroSplit({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.tdee,
    required this.bmr,
    required this.goalAdjustment,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double tdee;
  final double bmr;
  final int goalAdjustment;

  @override
  String toString() =>
      'MacroSplit(cal=${calories.round()}, P=${proteinG.round()}g, '
      'C=${carbsG.round()}g, F=${fatG.round()}g, '
      'TDEE=${tdee.round()}, BMR=${bmr.round()})';
}

class BmrTdeeCalculator {
  const BmrTdeeCalculator._();

  /// Activity multiplier table (ACSM / Harris-Benedict validated).
  static double activityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.athlete:
        return 1.9;
    }
  }

  /// Goal calorie adjustment (kcal/day).
  static int goalAdjustment(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.fatLoss:
        return -500;
      case FitnessGoal.mildCut:
        return -250;
      case FitnessGoal.maintain:
        return 0;
      case FitnessGoal.mildBulk:
        return 250;
      case FitnessGoal.bulking:
        return 500;
    }
  }

  /// Mifflin-St Jeor BMR (kcal/day) — gold standard, ±10% accuracy.
  ///
  /// Male:   BMR = 10w + 6.25h − 5a + 5
  /// Female: BMR = 10w + 6.25h − 5a − 161
  ///
  /// [weightKg]  Body weight in kilograms.
  /// [heightCm]  Height in centimeters.
  /// [ageYears]  Age in years.
  /// [sex]       Biological sex for the sex-specific constant.
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required BiologicalSex sex,
  }) {
    final base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * ageYears);
    return sex == BiologicalSex.male ? base + 5.0 : base - 161.0;
  }

  /// TDEE = BMR × Activity Factor.
  static double tdee({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required BiologicalSex sex,
    required ActivityLevel activity,
  }) {
    return bmr(
          weightKg: weightKg,
          heightCm: heightCm,
          ageYears: ageYears,
          sex: sex,
        ) *
        activityMultiplier(activity);
  }

  /// Full auto-macro calculation: TDEE → goal adjustment → macro split.
  ///
  /// Default macro ratio: 30% protein / 40% carbs / 30% fat.
  /// Can be overridden for keto (P:35 C:5 F:60), high-carb (P:25 C:55 F:20), etc.
  static MacroSplit autoMacros({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required BiologicalSex sex,
    required ActivityLevel activity,
    FitnessGoal goal = FitnessGoal.maintain,
    double proteinPct = 0.30,
    double carbsPct = 0.40,
    double fatPct = 0.30,
  }) {
    final bmrVal = bmr(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      sex: sex,
    );
    final tdeeVal = bmrVal * activityMultiplier(activity);
    final adj = goalAdjustment(goal);
    final targetCal = (tdeeVal + adj).clamp(1200.0, 10000.0);

    // 1g protein = 4 kcal, 1g carbs = 4 kcal, 1g fat = 9 kcal
    final proteinG = (targetCal * proteinPct) / 4.0;
    final carbsG = (targetCal * carbsPct) / 4.0;
    final fatG = (targetCal * fatPct) / 9.0;

    return MacroSplit(
      calories: _round1(targetCal),
      proteinG: _round1(proteinG),
      carbsG: _round1(carbsG),
      fatG: _round1(fatG),
      tdee: _round1(tdeeVal),
      bmr: _round1(bmrVal),
      goalAdjustment: adj,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. One-Rep Max (1RM) Estimation
// ─────────────────────────────────────────────────────────────────────────────

class OneRepMax {
  const OneRepMax._();

  /// Epley Formula (most widely validated, best for reps > 1):
  /// 1RM = w × (1 + r/30)
  static double epley(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0.0;
    if (reps == 1) return weight;
    return _round1(weight * (1.0 + reps / 30.0));
  }

  /// Brzycki Formula (better for low-rep sets ≤ 10):
  /// 1RM = w / (1.0278 − 0.0278 × r)
  static double brzycki(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0.0;
    if (reps == 1) return weight;
    final denom = 1.0278 - (0.0278 * reps);
    if (denom <= 0) return epley(weight, reps); // Fallback for reps > 36
    return _round1(weight / denom);
  }

  /// Best-fit 1RM — uses Brzycki for reps ≤ 10, Epley for reps > 10.
  static double estimate(double weight, int reps) {
    if (reps <= 10) return brzycki(weight, reps);
    return epley(weight, reps);
  }

  /// Estimate working weight for a target rep count from a known 1RM.
  /// w = 1RM × (1 − 0.025 × targetReps)   (Lombardi approximation)
  static double workingWeight(double oneRm, int targetReps) {
    if (oneRm <= 0 || targetReps <= 0) return 0.0;
    return _round1(oneRm * (1.0 - 0.025 * targetReps).clamp(0.2, 1.0));
  }

  /// Percentage of 1RM for a given weight.
  static double percentOf1RM(double weight, double oneRm) {
    if (oneRm <= 0) return 0.0;
    return _round1((weight / oneRm) * 100.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Progressive Overload Tracking
// ─────────────────────────────────────────────────────────────────────────────

class OverloadResult {
  const OverloadResult({
    required this.currentVolume,
    required this.previousVolume,
    required this.overloadPercent,
    required this.label,
    this.isFirstSession = false,
  });

  final double currentVolume;
  final double previousVolume;
  final double overloadPercent;
  final String label; // e.g. "+5.2%" or "−3.1%" or "New PR"
  final bool isFirstSession;

  bool get isPositive => !isFirstSession && overloadPercent > 0;
  bool get isPR => !isFirstSession && overloadPercent >= 5.0;
}

class ProgressiveOverload {
  const ProgressiveOverload._();

  /// Volume for a single exercise across all its completed sets.
  /// V = Σ(weight_i × reps_i)
  static double exerciseVolume(List<({double weight, int reps})> sets) {
    double v = 0.0;
    for (final s in sets) {
      v += s.weight * s.reps;
    }
    return _round1(v);
  }

  /// Session-over-session overload percentage.
  /// Δ% = ((V_current − V_previous) / V_previous) × 100
  static OverloadResult compare(double currentVolume, double previousVolume) {
    if (previousVolume <= 0) {
      return OverloadResult(
        currentVolume: currentVolume,
        previousVolume: 0,
        overloadPercent: 0.0,
        label: 'First Session',
        isFirstSession: true,
      );
    }

    final delta = ((currentVolume - previousVolume) / previousVolume) * 100.0;
    final rounded = _round1(delta);

    String label;
    if (rounded >= 5.0) {
      label = '+${rounded.abs()}% 🔥 PR';
    } else if (rounded > 0) {
      label = '+${rounded.abs()}%';
    } else if (rounded == 0) {
      label = '0% (Maintained)';
    } else {
      label = '−${rounded.abs()}%';
    }

    return OverloadResult(
      currentVolume: currentVolume,
      previousVolume: previousVolume,
      overloadPercent: rounded,
      label: label,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Adaptive Rest Timer
// ─────────────────────────────────────────────────────────────────────────────

class AdaptiveRest {
  const AdaptiveRest._();

  /// Rep-range based rest (NSCA guidelines):
  ///   reps ≥ 15 → 60s  (endurance)
  ///   8–14      → 90s  (hypertrophy)
  ///   4–7       → 150s (strength)
  ///   1–3       → 240s (power)
  static int fromReps(int reps) {
    if (reps >= 15) return 60;
    if (reps >= 8) return 90;
    if (reps >= 4) return 150;
    return 240;
  }

  /// Intensity-scaled rest using estimated %1RM:
  ///   Rest(s) = 30 + 150 × (weight / est1RM)²
  /// Falls back to rep-based if 1RM is unknown.
  static int fromIntensity({
    required double weight,
    required int reps,
    double? estimated1RM,
  }) {
    if (estimated1RM == null || estimated1RM <= 0) {
      return fromReps(reps);
    }

    final pct = (weight / estimated1RM).clamp(0.0, 1.0);
    final rest = 30.0 + 150.0 * pct * pct;
    return rest.round().clamp(45, 300);
  }

  /// Human-readable label for the training zone.
  static String zoneLabel(int reps) {
    if (reps >= 15) return 'Endurance';
    if (reps >= 8) return 'Hypertrophy';
    if (reps >= 4) return 'Strength';
    return 'Power';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Streak & Consistency Score
// ─────────────────────────────────────────────────────────────────────────────

class ConsistencyResult {
  const ConsistencyResult({
    required this.currentStreak,
    required this.workoutsThisWeek,
    required this.consistencyPct,
    required this.last28DaysSessions,
    required this.targetPerWeek,
  });

  final int currentStreak;
  final int workoutsThisWeek;
  final double consistencyPct; // 0–100
  final int last28DaysSessions;
  final int targetPerWeek;

  String get consistencyLabel {
    if (consistencyPct >= 90) return 'Elite';
    if (consistencyPct >= 75) return 'Strong';
    if (consistencyPct >= 50) return 'Decent';
    if (consistencyPct >= 25) return 'Building';
    return 'Getting Started';
  }
}

class StreakCalculator {
  const StreakCalculator._();

  /// Calculate streak, weekly count, and consistency from a list of session dates.
  ///
  /// [sessionDates] — All session start/end DateTimes (need not be sorted).
  /// [targetPerWeek] — User's workout frequency goal (default 4).
  static ConsistencyResult calculate(
    List<DateTime> sessionDates, {
    int targetPerWeek = 4,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (sessionDates.isEmpty) {
      return ConsistencyResult(
        currentStreak: 0,
        workoutsThisWeek: 0,
        consistencyPct: 0,
        last28DaysSessions: 0,
        targetPerWeek: targetPerWeek,
      );
    }

    // Unique workout days (set of dates without time)
    final uniqueDays = <DateTime>{};
    for (final dt in sessionDates) {
      uniqueDays.add(DateTime(dt.year, dt.month, dt.day));
    }

    final sortedDays = uniqueDays.toList()..sort((a, b) => b.compareTo(a));

    // ── Current Streak ──
    int streak = 0;
    var checkDate = todayDate;
    // Allow starting from today or yesterday (in case no workout today yet)
    if (sortedDays.isNotEmpty && sortedDays.first != todayDate) {
      final yesterday = DateTime(todayDate.year, todayDate.month, todayDate.day - 1);
      if (sortedDays.first == yesterday) {
        checkDate = yesterday;
      } else {
        // No workout today or yesterday → streak is 0
        checkDate = todayDate; // will fail the loop
      }
    }

    for (final day in sortedDays) {
      if (day == checkDate) {
        streak++;
        checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
      } else if (day.isBefore(checkDate)) {
        break; // Gap found
      }
    }

    // ── Workouts This Week (Monday-based) ──
    final weekday = today.weekday; // 1=Mon, 7=Sun
    final mondayOfWeek = DateTime(todayDate.year, todayDate.month, todayDate.day - (weekday - 1));
    int thisWeek = 0;
    for (final day in uniqueDays) {
      if (!day.isBefore(mondayOfWeek) && !day.isAfter(todayDate)) {
        thisWeek++;
      }
    }

    // ── Consistency (last 28 days) ──
    final cutoff28 = DateTime(todayDate.year, todayDate.month, todayDate.day - 28);
    int last28 = 0;
    for (final day in uniqueDays) {
      if (!day.isBefore(cutoff28) && !day.isAfter(todayDate)) {
        last28++;
      }
    }

    final targetIn28 = targetPerWeek * 4; // 4 weeks
    final consistency =
        targetIn28 > 0 ? (last28 / targetIn28 * 100.0).clamp(0.0, 100.0) : 0.0;

    return ConsistencyResult(
      currentStreak: streak,
      workoutsThisWeek: thisWeek,
      consistencyPct: _round1(consistency),
      last28DaysSessions: last28,
      targetPerWeek: targetPerWeek,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Per-Muscle Training Frequency Analysis
// ─────────────────────────────────────────────────────────────────────────────

class MuscleFrequencyResult {
  const MuscleFrequencyResult({
    required this.muscle,
    required this.sessionsHit,
    required this.frequencyPerWeek,
    required this.status,
  });

  final String muscle;
  final int sessionsHit;
  final double frequencyPerWeek;
  final MuscleFrequencyStatus status;
}

enum MuscleFrequencyStatus {
  neglected,   // < 1.0×/week
  undertrained, // 1.0–1.49×/week
  optimal,      // 1.5–3.0×/week
  overreaching, // > 3.0×/week
}

class MuscleFrequencyAnalyzer {
  const MuscleFrequencyAnalyzer._();

  static const standardGroups = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core',
  ];

  /// Analyze training frequency per muscle group over a date range.
  ///
  /// [sessionsWithMuscles] — List of (sessionDate, List<muscleGroup>) pairs.
  /// [windowDays] — Analysis window (default 28 days = 4 weeks).
  static List<MuscleFrequencyResult> analyze(
    List<({DateTime date, List<String> muscles})> sessionsWithMuscles, {
    int windowDays = 28,
  }) {
    final weeks = (windowDays / 7.0).clamp(1.0, 52.0);
    final muscleCount = <String, int>{};

    for (final group in standardGroups) {
      muscleCount[group] = 0;
    }

    for (final session in sessionsWithMuscles) {
      final uniqueMuscles = session.muscles.toSet();
      for (final m in uniqueMuscles) {
        // Normalize to standard group
        final matched = standardGroups.firstWhere(
          (g) => g.toLowerCase() == m.toLowerCase(),
          orElse: () => m,
        );
        muscleCount[matched] = (muscleCount[matched] ?? 0) + 1;
      }
    }

    return muscleCount.entries.map((e) {
      final freq = _round1(e.value / weeks);
      MuscleFrequencyStatus status;
      if (freq < 1.0) {
        status = MuscleFrequencyStatus.neglected;
      } else if (freq < 1.5) {
        status = MuscleFrequencyStatus.undertrained;
      } else if (freq <= 3.0) {
        status = MuscleFrequencyStatus.optimal;
      } else {
        status = MuscleFrequencyStatus.overreaching;
      }
      return MuscleFrequencyResult(
        muscle: e.key,
        sessionsHit: e.value,
        frequencyPerWeek: freq,
        status: status,
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Workout Intensity Score (Volume Load Index)
// ─────────────────────────────────────────────────────────────────────────────

enum IntensityLevel { light, moderate, hard, brutal }

class IntensityResult {
  const IntensityResult({
    required this.vli,
    required this.level,
    required this.label,
  });

  final double vli; // Volume / Duration(min)
  final IntensityLevel level;
  final String label;
}

class WorkoutIntensity {
  const WorkoutIntensity._();

  /// Volume Load Index = Total Volume(kg) / Duration(min).
  ///
  /// | VLI Range | Label    |
  /// |-----------|----------|
  /// | < 50      | Light    |
  /// | 50–150    | Moderate |
  /// | 150–300   | Hard     |
  /// | > 300     | Brutal   |
  static IntensityResult calculate({
    required double totalVolumeKg,
    required int durationSeconds,
  }) {
    if (durationSeconds <= 0) {
      return const IntensityResult(
        vli: 0,
        level: IntensityLevel.light,
        label: 'Light',
      );
    }

    final durationMin = durationSeconds / 60.0;
    final vli = _round1(totalVolumeKg / durationMin);

    IntensityLevel level;
    String label;
    if (vli < 50) {
      level = IntensityLevel.light;
      label = 'Light';
    } else if (vli < 150) {
      level = IntensityLevel.moderate;
      label = 'Moderate';
    } else if (vli < 300) {
      level = IntensityLevel.hard;
      label = 'Hard';
    } else {
      level = IntensityLevel.brutal;
      label = 'Brutal 🔥';
    }

    return IntensityResult(vli: vli, level: level, label: label);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. Body Composition (BMI + Navy Body Fat %)
// ─────────────────────────────────────────────────────────────────────────────

class BodyCompositionResult {
  const BodyCompositionResult({
    required this.bmi,
    required this.bmiCategory,
    required this.bodyFatPct,
    required this.fatMassKg,
    required this.leanMassKg,
    required this.bodyFatCategory,
  });

  final double bmi;
  final String bmiCategory;
  final double bodyFatPct;
  final double fatMassKg;
  final double leanMassKg;
  final String bodyFatCategory;
}

class BodyComposition {
  const BodyComposition._();

  /// BMI = weight(kg) / height(m)²
  static double bmi(double weightKg, double heightCm) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    final hm = heightCm / 100.0;
    return _round1(weightKg / (hm * hm));
  }

  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  /// US Navy Body Fat % — Hodgdon & Beckett (1984).
  ///
  /// Male:
  ///   BF% = 86.010 × log₁₀(waist − neck) − 70.041 × log₁₀(height) + 36.76
  ///
  /// Female:
  ///   BF% = 163.205 × log₁₀(waist + hip − neck) − 97.684 × log₁₀(height) − 78.387
  ///
  /// All measurements in **centimeters**.
  static double navyBodyFat({
    required BiologicalSex sex,
    required double waistCm,
    required double neckCm,
    required double heightCm,
    double? hipCm, // Required for female
  }) {
    if (heightCm <= 0 || neckCm <= 0 || waistCm <= 0) return 0;

    double bf;
    if (sex == BiologicalSex.male) {
      final diff = waistCm - neckCm;
      if (diff <= 0) return 0;
      bf = 86.010 * _log10(diff) -
          70.041 * _log10(heightCm) +
          36.76;
    } else {
      final hip = hipCm ?? 0;
      if (hip <= 0) return 0;
      final circumference = waistCm + hip - neckCm;
      if (circumference <= 0) return 0;
      bf = 163.205 * _log10(circumference) -
          97.684 * _log10(heightCm) -
          78.387;
    }

    return _round1(bf.clamp(2.0, 60.0));
  }

  /// Full body composition analysis.
  static BodyCompositionResult analyze({
    required double weightKg,
    required double heightCm,
    required BiologicalSex sex,
    required double waistCm,
    required double neckCm,
    double? hipCm,
  }) {
    final bmiVal = bmi(weightKg, heightCm);

    final isInvalid = weightKg <= 0 ||
        waistCm <= 0 ||
        neckCm <= 0 ||
        heightCm <= 0 ||
        (sex == BiologicalSex.male && waistCm <= neckCm) ||
        (sex == BiologicalSex.female && ((hipCm ?? 0) <= 0 || (waistCm + (hipCm ?? 0) <= neckCm)));

    if (isInvalid) {
      return BodyCompositionResult(
        bmi: bmiVal,
        bmiCategory: bmiCategory(bmiVal),
        bodyFatPct: 0.0,
        fatMassKg: 0.0,
        leanMassKg: weightKg,
        bodyFatCategory: 'Invalid Measurements',
      );
    }

    final bfPct = navyBodyFat(
      sex: sex,
      waistCm: waistCm,
      neckCm: neckCm,
      heightCm: heightCm,
      hipCm: hipCm,
    );

    final fatMass = _round1(weightKg * bfPct / 100.0);
    final leanMass = _round1(weightKg - fatMass);

    String bfCategory;
    if (sex == BiologicalSex.male) {
      if (bfPct < 6) {
        bfCategory = 'Essential';
      } else if (bfPct < 14) {
        bfCategory = 'Athletic';
      } else if (bfPct < 18) {
        bfCategory = 'Fitness';
      } else if (bfPct < 25) {
        bfCategory = 'Average';
      } else {
        bfCategory = 'Above Average';
      }
    } else {
      if (bfPct < 14) {
        bfCategory = 'Essential';
      } else if (bfPct < 21) {
        bfCategory = 'Athletic';
      } else if (bfPct < 25) {
        bfCategory = 'Fitness';
      } else if (bfPct < 32) {
        bfCategory = 'Average';
      } else {
        bfCategory = 'Above Average';
      }
    }

    return BodyCompositionResult(
      bmi: bmiVal,
      bmiCategory: bmiCategory(bmiVal),
      bodyFatPct: bfPct,
      fatMassKg: fatMass,
      leanMassKg: leanMass,
      bodyFatCategory: bfCategory,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. Calorie Burn Estimation (MET-based)
// ─────────────────────────────────────────────────────────────────────────────

class CalorieBurnResult {
  const CalorieBurnResult({
    required this.totalKcal,
    required this.activeKcal,
    required this.restKcal,
    required this.averageMet,
  });

  final double totalKcal;
  final double activeKcal;
  final double restKcal;
  final double averageMet;
}

class CalorieBurn {
  const CalorieBurn._();

  /// MET values from ACSM Compendium of Physical Activities.
  static const double metWeightlifting = 6.0;
  static const double metHighIntensity = 8.0;
  static const double metBodyweight = 5.0;
  static const double metRest = 2.0;
  static const double metCardio = 7.0;

  /// kcal = MET × bodyWeight(kg) × time(hours)
  static double metCalories(double met, double weightKg, double minutes) {
    return _round1(met * weightKg * (minutes / 60.0));
  }

  /// Estimate total workout calorie burn.
  ///
  /// [weightKg]         — User's body weight.
  /// [durationSeconds]  — Total session duration.
  /// [activeSeconds]    — Estimated active lifting time (typically 40-50% of total).
  /// [isHighIntensity]  — Whether the session was high-intensity (heavy compounds).
  /// [isBodyweight]     — Whether the session was primarily calisthenics.
  static CalorieBurnResult estimateWorkoutBurn({
    required double weightKg,
    required int durationSeconds,
    int? activeSeconds,
    bool isHighIntensity = false,
    bool isBodyweight = false,
  }) {
    if (durationSeconds <= 0 || weightKg <= 0) {
      return const CalorieBurnResult(
        totalKcal: 0,
        activeKcal: 0,
        restKcal: 0,
        averageMet: 0,
      );
    }

    final totalMin = durationSeconds / 60.0;
    // Default: active time is 45% of total session (rest between sets accounts for ~55%)
    final activeMin = activeSeconds != null
        ? math.min(totalMin, math.max(0.0, activeSeconds / 60.0))
        : totalMin * 0.45;
    final restMin = math.max(0.0, totalMin - activeMin);

    double activeMet;
    if (isBodyweight) {
      activeMet = metBodyweight;
    } else if (isHighIntensity) {
      activeMet = metHighIntensity;
    } else {
      activeMet = metWeightlifting;
    }

    final activeKcal = metCalories(activeMet, weightKg, activeMin);
    final restKcal = metCalories(metRest, weightKg, restMin);
    final totalKcal = _round1(activeKcal + restKcal);

    final avgMet = totalMin > 0
        ? _round1((activeMet * activeMin + metRest * restMin) / totalMin)
        : 0.0;

    return CalorieBurnResult(
      totalKcal: totalKcal,
      activeKcal: activeKcal,
      restKcal: restKcal,
      averageMet: avgMet,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. Entropy-Based Volume Balance Scoring
// ─────────────────────────────────────────────────────────────────────────────

class BalanceScoreResult {
  const BalanceScoreResult({
    required this.score,
    required this.label,
    required this.entropy,
    required this.maxEntropy,
    required this.dominantMuscle,
    required this.dominantPct,
  });

  final double score; // 0–100
  final String label;
  final double entropy;
  final double maxEntropy;
  final String dominantMuscle;
  final double dominantPct;
}

class VolumeBalance {
  const VolumeBalance._();

  static const int totalStandardGroups = 6;

  /// Shannon entropy-based balance score.
  ///
  /// H = −Σ pᵢ × ln(pᵢ)
  /// Score = (H / ln(totalStandardGroups)) × 100
  ///
  /// 100 = perfectly balanced across all 6 standard muscle groups.
  /// 0   = all volume in a single muscle group.
  static BalanceScoreResult score(Map<String, double> volumeByMuscle) {
    final nonZero = <String, double>{};
    for (final e in volumeByMuscle.entries) {
      if (e.value > 0) nonZero[e.key] = e.value;
    }

    if (nonZero.isEmpty) {
      return const BalanceScoreResult(
        score: 0,
        label: 'No Data',
        entropy: 0,
        maxEntropy: 0,
        dominantMuscle: '-',
        dominantPct: 0,
      );
    }

    if (nonZero.length == 1) {
      return BalanceScoreResult(
        score: 0,
        label: 'Single Focus',
        entropy: 0,
        maxEntropy: 0,
        dominantMuscle: nonZero.keys.first,
        dominantPct: 100,
      );
    }

    final total = nonZero.values.fold<double>(0, (a, b) => a + b);
    final maxEntropy = math.log(totalStandardGroups);

    double entropy = 0.0;
    String dominant = '';
    double dominantVal = 0;

    for (final e in nonZero.entries) {
      final p = e.value / total;
      if (p > 0) {
        entropy -= p * math.log(p);
      }
      if (e.value > dominantVal) {
        dominantVal = e.value;
        dominant = e.key;
      }
    }

    final normalizedScore = _round1((entropy / maxEntropy * 100.0).clamp(0.0, 100.0));
    final dominantPct = _round1((dominantVal / total) * 100.0);

    String label;
    if (normalizedScore >= 85) {
      label = 'Excellent Balance';
    } else if (normalizedScore >= 65) {
      label = 'Good Balance';
    } else if (normalizedScore >= 40) {
      label = 'Moderate Imbalance';
    } else {
      label = 'Heavily Skewed';
    }

    return BalanceScoreResult(
      score: normalizedScore,
      label: label,
      entropy: _round1(entropy),
      maxEntropy: _round1(maxEntropy),
      dominantMuscle: dominant,
      dominantPct: dominantPct,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

double _round1(double v) => !v.isFinite ? 0.0 : double.parse(v.toStringAsFixed(1));
double _log10(double x) => x > 0 ? math.log(x) / math.ln10 : 0.0;
