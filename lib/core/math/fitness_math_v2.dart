import 'dart:math' as math;
import 'package:fitness_app/core/math/fitness_math.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PulseFit Fitness Mathematics Engine — Phase 2
/// ═══════════════════════════════════════════════════════════════════════════
/// Advanced deterministic formulas for nutrition & metabolic tracking.
/// No ML, no deep learning — pure math that runs instantly on-device.
///
/// References:
///   • Morton et al. (2018) — Per-kg protein targets
///   • ISSN Position Stand (Jäger et al. 2017) — Protein recommendations
///   • McArdle, Katch & Katch (2010) — Katch-McArdle BMR
///   • FAO/WHO (2003), Livesey (1995) — Fiber energy factor
///   • Hall (2008) — Adaptive TDEE / energy balance

double _round1(double v) =>
    !v.isFinite ? 0.0 : double.parse(v.toStringAsFixed(1));

// ─────────────────────────────────────────────────────────────────────────────
// 11. Per-Kg Protein Targets & Protein-First Macro Allocation
// ─────────────────────────────────────────────────────────────────────────────

/// Protein allocation strategy: how to fill the remaining calories after
/// protein is set in grams.
enum CarbFatStrategy {
  /// Balanced: 50/50 split of remaining calories between carbs and fat.
  balanced,

  /// High-Carb: 65% carbs / 35% fat of remaining calories (endurance athletes).
  highCarb,

  /// Low-Carb: 35% carbs / 65% fat of remaining calories (keto-leaning).
  lowCarb,

  /// Even: equal gram weights of carbs and fat (visual simplicity).
  evenGrams,
}

class ProteinFirstSplit {
  const ProteinFirstSplit({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.proteinGPerKg,
    required this.proteinPctActual,
    required this.carbsPctActual,
    required this.fatPctActual,
    required this.tdee,
    required this.bmr,
    required this.goalAdjustment,
    required this.strategy,
    this.bmrMethod = 'mifflin_st_jeor',
    this.katchMcArdleBmr,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double proteinGPerKg;
  final double proteinPctActual; // Actual % of total calories from protein
  final double carbsPctActual;
  final double fatPctActual;
  final double tdee;
  final double bmr;
  final int goalAdjustment;
  final CarbFatStrategy strategy;
  final String bmrMethod;
  final double? katchMcArdleBmr; // For side-by-side comparison

  @override
  String toString() =>
      'ProteinFirstSplit(cal=${calories.round()}, '
      'P=${proteinG.round()}g (${proteinGPerKg}g/kg), '
      'C=${carbsG.round()}g, F=${fatG.round()}g, '
      'method=$bmrMethod)';
}

class ProteinFirstCalculator {
  const ProteinFirstCalculator._();

  /// Evidence-based protein targets (g/kg of body weight) by goal.
  ///
  /// References:
  ///   - Morton et al. (2018) meta-analysis: 1.6-2.2 g/kg for hypertrophy
  ///   - Helms et al. (2014): 2.3-3.1 g/kg of lean mass during deficit
  ///   - ISSN Position Stand (Jager et al. 2017): 1.4-2.0 g/kg general
  static double recommendedProteinGPerKg(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.fatLoss:
        return 2.2; // Higher during deficit to preserve muscle
      case FitnessGoal.mildCut:
        return 2.0;
      case FitnessGoal.maintain:
        return 1.8;
      case FitnessGoal.mildBulk:
        return 1.8;
      case FitnessGoal.bulking:
        return 1.6; // Surplus already supports anabolism
    }
  }

  /// Protein-first macro allocation.
  ///
  /// 1. Set protein in grams from body weight: P(g) = weightKg x proteinGPerKg
  /// 2. Compute protein calories: P(kcal) = P(g) x 4
  /// 3. Remaining calories = targetCal - P(kcal)
  /// 4. Distribute remaining between carbs and fat by strategy
  ///
  /// Guards:
  ///   - Protein calories capped at 45% of total to prevent starvation of
  ///     essential fatty acids and carbohydrate fuel.
  ///   - Minimum fat floor: 0.8 g/kg (hormonal health, fat-soluble vitamins).
  ///   - Total calories floored at 1200 kcal (safety).
  static ProteinFirstSplit calculate({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required BiologicalSex sex,
    required ActivityLevel activity,
    FitnessGoal goal = FitnessGoal.maintain,
    double? proteinGPerKg, // Override; null = use recommended
    CarbFatStrategy strategy = CarbFatStrategy.balanced,
    double? bodyFatPct, // If known, enables Katch-McArdle comparison
  }) {
    if (weightKg <= 0 || heightCm <= 0 || ageYears <= 0) {
      return ProteinFirstSplit(
        calories: 0, proteinG: 0, carbsG: 0, fatG: 0,
        proteinGPerKg: 0, proteinPctActual: 0, carbsPctActual: 0,
        fatPctActual: 0, tdee: 0, bmr: 0, goalAdjustment: 0,
        strategy: strategy,
      );
    }

    // -- Step 1: BMR --
    final mifflinBmr = BmrTdeeCalculator.bmr(
      weightKg: weightKg, heightCm: heightCm,
      ageYears: ageYears, sex: sex,
    );

    // Katch-McArdle if body fat % is available
    double? katchBmr;
    String bmrMethod = 'mifflin_st_jeor';
    double selectedBmr = mifflinBmr;

    if (bodyFatPct != null && bodyFatPct > 0 && bodyFatPct < 60) {
      katchBmr = KatchMcArdle.bmr(
        weightKg: weightKg, bodyFatPct: bodyFatPct,
      );
      // Use Katch-McArdle as primary when body fat is known
      selectedBmr = katchBmr;
      bmrMethod = 'katch_mcardle';
    }

    // -- Step 2: TDEE & target calories --
    final tdeeVal = selectedBmr * BmrTdeeCalculator.activityMultiplier(activity);
    final adj = BmrTdeeCalculator.goalAdjustment(goal);
    final targetCal = (tdeeVal + adj).clamp(1200.0, 10000.0);

    // -- Step 3: Protein grams from body weight --
    final pPerKg = proteinGPerKg ?? recommendedProteinGPerKg(goal);
    var proteinG = weightKg * pPerKg;

    // Cap protein at 45% of total calories
    final maxProteinKcal = targetCal * 0.45;
    if (proteinG * 4.0 > maxProteinKcal) {
      proteinG = maxProteinKcal / 4.0;
    }

    final proteinKcal = proteinG * 4.0;
    final remainingKcal = math.max(0.0, targetCal - proteinKcal);

    // -- Step 4: Fat floor — minimum 0.8 g/kg for hormonal health --
    final minFatG = weightKg * 0.8;
    final minFatKcal = minFatG * 9.0;

    double carbsG;
    double fatG;

    if (minFatKcal >= remainingKcal) {
      // Edge case: very low calorie — give fat its minimum, carbs get remainder
      fatG = _round1(remainingKcal / 9.0);
      carbsG = 0.0;
    } else {
      // Remaining after fat floor
      final afterFatFloor = remainingKcal - minFatKcal;

      switch (strategy) {
        case CarbFatStrategy.balanced:
          carbsG = _round1(afterFatFloor * 0.50 / 4.0);
          fatG = _round1(minFatG + afterFatFloor * 0.50 / 9.0);
          break;
        case CarbFatStrategy.highCarb:
          carbsG = _round1(afterFatFloor * 0.65 / 4.0);
          fatG = _round1(minFatG + afterFatFloor * 0.35 / 9.0);
          break;
        case CarbFatStrategy.lowCarb:
          carbsG = _round1(afterFatFloor * 0.35 / 4.0);
          fatG = _round1(minFatG + afterFatFloor * 0.65 / 9.0);
          break;
        case CarbFatStrategy.evenGrams:
          final targetG = remainingKcal / 13.0;
          if (targetG >= minFatG) {
            carbsG = _round1(targetG);
            fatG = _round1(targetG);
          } else {
            fatG = _round1(minFatG);
            carbsG = _round1(math.max(0.0, (remainingKcal - minFatG * 9.0) / 4.0));
          }
          break;
      }
    }

    // -- Step 5: Reconcile rounding to hit exact calorie target --
    proteinG = _round1(proteinG);
    final checkKcal = proteinG * 4.0 + carbsG * 4.0 + fatG * 9.0;
    final diff = targetCal - checkKcal;
    if (diff.abs() > 1.0) {
      // Adjust carbs (4 kcal/g) — smallest caloric impact per gram
      carbsG = _round1(carbsG + diff / 4.0);
    }

    return _buildResult(
      targetCal: targetCal, proteinG: proteinG, carbsG: carbsG,
      fatG: fatG, pPerKg: pPerKg, tdeeVal: tdeeVal,
      selectedBmr: selectedBmr, adj: adj, strategy: strategy,
      bmrMethod: bmrMethod, katchBmr: katchBmr,
    );
  }

  static ProteinFirstSplit _buildResult({
    required double targetCal,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double pPerKg,
    required double tdeeVal,
    required double selectedBmr,
    required int adj,
    required CarbFatStrategy strategy,
    required String bmrMethod,
    required double? katchBmr,
  }) {
    final totalKcal = proteinG * 4.0 + carbsG * 4.0 + fatG * 9.0;
    final safeTotalKcal = totalKcal > 0 ? totalKcal : 1.0;

    return ProteinFirstSplit(
      calories: _round1(targetCal),
      proteinG: _round1(proteinG),
      carbsG: _round1(math.max(0.0, carbsG)),
      fatG: _round1(math.max(0.0, fatG)),
      proteinGPerKg: _round1(pPerKg),
      proteinPctActual: _round1(proteinG * 4.0 / safeTotalKcal * 100.0),
      carbsPctActual: _round1(math.max(0.0, carbsG) * 4.0 / safeTotalKcal * 100.0),
      fatPctActual: _round1(math.max(0.0, fatG) * 9.0 / safeTotalKcal * 100.0),
      tdee: _round1(tdeeVal),
      bmr: _round1(selectedBmr),
      goalAdjustment: adj,
      strategy: strategy,
      bmrMethod: bmrMethod,
      katchMcArdleBmr: katchBmr,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 12. Katch-McArdle BMR (Lean-Mass Based)
// ─────────────────────────────────────────────────────────────────────────────

class KatchMcArdle {
  const KatchMcArdle._();

  /// Katch-McArdle BMR from lean body mass.
  ///
  /// BMR = 370 + 21.6 × LBM(kg)
  /// where LBM = weightKg × (1 − bodyFatPct/100)
  ///
  /// Reference: McArdle, Katch & Katch (2010),
  ///            Exercise Physiology, 7th Edition.
  ///
  /// Accuracy: ±3–5% when body fat % is accurately measured.
  /// Compared to Mifflin-St Jeor's ±5–10% from total body weight.
  static double bmr({
    required double weightKg,
    required double bodyFatPct,
  }) {
    if (weightKg <= 0 || bodyFatPct < 0 || bodyFatPct >= 100) return 0.0;
    final leanMassKg = weightKg * (1.0 - bodyFatPct / 100.0);
    return _round1(370.0 + 21.6 * leanMassKg);
  }

  /// TDEE via Katch-McArdle.
  static double tdee({
    required double weightKg,
    required double bodyFatPct,
    required ActivityLevel activity,
  }) {
    return bmr(weightKg: weightKg, bodyFatPct: bodyFatPct) *
        BmrTdeeCalculator.activityMultiplier(activity);
  }

  /// Side-by-side BMR comparison between Mifflin-St Jeor and Katch-McArdle.
  ///
  /// Returns a [BmrComparison] with both values and the absolute/percentage
  /// delta so the UI can display them comparatively rather than dogmatically.
  static BmrComparison compare({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required BiologicalSex sex,
    required double bodyFatPct,
  }) {
    final mifflin = BmrTdeeCalculator.bmr(
      weightKg: weightKg, heightCm: heightCm,
      ageYears: ageYears, sex: sex,
    );
    final katch = bmr(weightKg: weightKg, bodyFatPct: bodyFatPct);
    final delta = katch - mifflin;
    final deltaPct = mifflin > 0 ? (delta / mifflin * 100.0) : 0.0;

    return BmrComparison(
      mifflinStJeor: _round1(mifflin),
      katchMcArdle: _round1(katch),
      deltaKcal: _round1(delta),
      deltaPct: _round1(deltaPct),
      leanMassKg: _round1(weightKg * (1.0 - bodyFatPct / 100.0)),
      bodyFatPct: _round1(bodyFatPct),
    );
  }
}

class BmrComparison {
  const BmrComparison({
    required this.mifflinStJeor,
    required this.katchMcArdle,
    required this.deltaKcal,
    required this.deltaPct,
    required this.leanMassKg,
    required this.bodyFatPct,
  });

  final double mifflinStJeor;
  final double katchMcArdle;
  final double deltaKcal; // Positive = Katch is higher
  final double deltaPct;
  final double leanMassKg;
  final double bodyFatPct;

  @override
  String toString() =>
      'BmrComparison(Mifflin: ${mifflinStJeor.round()} kcal, '
      'Katch: ${katchMcArdle.round()} kcal, '
      'delta: ${deltaKcal.round()} kcal / ${deltaPct.toStringAsFixed(1)}%)';
}

// ─────────────────────────────────────────────────────────────────────────────
// 13. Fiber-Aware Modified Atwater Energy Calculation
// ─────────────────────────────────────────────────────────────────────────────

class FiberAwareAtwater {
  const FiberAwareAtwater._();

  /// Standard Atwater energy factors (kcal/g).
  static const double proteinFactor = 4.0;
  static const double carbFactor = 4.0;
  static const double fatFactor = 9.0;

  /// Dietary fiber yields ~2 kcal/g on average (fermentation in the colon
  /// produces short-chain fatty acids, but no blood glucose spike).
  ///
  /// Reference: FAO/WHO (2003), Livesey (1995) — fiber energy factor 2.0 kcal/g.
  /// The EU legally uses 2 kcal/g; the US FDA still uses 4 kcal/g for total carbs.
  static const double fiberFactor = 2.0;

  /// Sugar alcohol average factor: ~2.4 kcal/g (varies by type).
  /// Erythritol ≈ 0.2, Xylitol ≈ 2.4, Maltitol ≈ 3.0.
  /// We use the FDA's general approximation of 2.4 kcal/g.
  static const double sugarAlcoholFactor = 2.4;

  /// Net Carbs = Total Carbs − Fiber − Sugar Alcohols.
  /// Clamped to zero (fiber can't exceed total carbs).
  static double netCarbs(double totalCarbsG, {
    double fiberG = 0.0,
    double sugarAlcoholsG = 0.0,
  }) {
    final cleanFiber = math.max(0.0, fiberG);
    final cleanSA = math.max(0.0, sugarAlcoholsG);
    return math.max(0.0, totalCarbsG - cleanFiber - cleanSA);
  }

  /// Standard Atwater: 4P + 4C + 9F (ignores fiber distinction).
  static double standardCalories({
    required double proteinG,
    required double totalCarbsG,
    required double fatG,
  }) {
    return _round1(proteinG * proteinFactor +
        totalCarbsG * carbFactor +
        fatG * fatFactor);
  }

  /// Fiber-aware Atwater:
  ///   Calories = 4×P + 4×(C − fiber − sugarAlcohols)
  ///            + 2×fiber + 2.4×sugarAlcohols + 9×F
  ///
  /// Reduces overcounting by (4 − 2) = 2 kcal per gram of fiber,
  /// and (4 − 2.4) = 1.6 kcal per gram of sugar alcohols.
  ///
  /// For a high-fiber day (30g fiber), this saves 60 kcal from overcounting.
  static double fiberAwareCalories({
    required double proteinG,
    required double totalCarbsG,
    required double fatG,
    double fiberG = 0.0,
    double sugarAlcoholsG = 0.0,
  }) {
    final cleanFiber = math.max(0.0, fiberG);
    final cleanSA = math.max(0.0, sugarAlcoholsG);
    // Clamp fiber + sugar alcohols to not exceed total carbs
    final maxDeductible = math.max(0.0, totalCarbsG);
    final effectiveFiber = math.min(cleanFiber, maxDeductible);
    final effectiveSA = math.min(cleanSA, maxDeductible - effectiveFiber);

    final digestibleCarbs = math.max(
        0.0, totalCarbsG - effectiveFiber - effectiveSA);

    final cal = proteinG * proteinFactor +
        digestibleCarbs * carbFactor +
        effectiveFiber * fiberFactor +
        effectiveSA * sugarAlcoholFactor +
        fatG * fatFactor;

    return _round1(cal);
  }

  /// Calorie savings from using fiber-aware vs standard Atwater.
  static double savings({
    required double totalCarbsG,
    double fiberG = 0.0,
    double sugarAlcoholsG = 0.0,
  }) {
    final cleanFiber = math.max(0.0, fiberG);
    final cleanSA = math.max(0.0, sugarAlcoholsG);
    final maxDeductible = math.max(0.0, totalCarbsG);
    final effectiveFiber = math.min(cleanFiber, maxDeductible);
    final effectiveSA = math.min(
        cleanSA, maxDeductible - effectiveFiber);

    // Standard charges fiber at 4 kcal/g; fiber-aware at 2 kcal/g → saves 2/g
    // Standard charges SA at 4 kcal/g; fiber-aware at 2.4 kcal/g → saves 1.6/g
    return _round1(
        effectiveFiber * (carbFactor - fiberFactor) +
        effectiveSA * (carbFactor - sugarAlcoholFactor));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 14. Adaptive TDEE (Weight-Trend + Calorie History)
// ─────────────────────────────────────────────────────────────────────────────

/// A single day's metabolic log entry for the Adaptive TDEE engine.
class DailyMetabolicEntry {
  const DailyMetabolicEntry({
    required this.date,
    this.morningWeightKg,
    this.caloriesConsumed,
  });

  final DateTime date;
  final double? morningWeightKg;
  final int? caloriesConsumed;
}

class AdaptiveTdeeResult {
  const AdaptiveTdeeResult({
    required this.estimatedTdee,
    required this.smoothedWeightKg,
    required this.weightTrendKgPerWeek,
    required this.avgDailyCalories,
    required this.confidenceLevel,
    required this.dataPointsUsed,
    required this.minimumDaysMet,
  });

  final double estimatedTdee;
  final double smoothedWeightKg; // EMA-smoothed current weight
  final double weightTrendKgPerWeek; // Negative = losing, Positive = gaining
  final double avgDailyCalories;
  final String confidenceLevel; // 'low', 'moderate', 'high'
  final int dataPointsUsed;
  final bool minimumDaysMet; // Need >=14 days for meaningful estimate

  @override
  String toString() =>
      'AdaptiveTdee(TDEE=${estimatedTdee.round()} kcal, '
      'trend=${weightTrendKgPerWeek > 0 ? "+" : ""}'
      '${weightTrendKgPerWeek.toStringAsFixed(2)} kg/wk, '
      'confidence=$confidenceLevel, n=$dataPointsUsed)';
}

class AdaptiveTdee {
  const AdaptiveTdee._();

  /// Energy density of body mass change: ~7700 kcal per kg of body weight.
  ///
  /// This is the standard estimate (mix of ~87% fat at 9400 kcal/kg and
  /// ~13% lean tissue at 1800 kcal/kg, with water).
  /// Reference: Hall (2008), "What is the required energy deficit per unit
  /// weight loss?" — Int J Obesity.
  static const double kcalPerKgBodyWeight = 7700.0;

  /// Minimum days of data required for a meaningful TDEE estimate.
  static const int minimumDays = 14;

  /// EMA smoothing factor α for daily weight (dampens water fluctuations).
  ///
  /// α = 2 / (N + 1) where N = 10 (10-day smoothing window).
  /// Higher α = more responsive to recent weight, more noise.
  /// Lower α = smoother trend, slower to react.
  static const double emaSmoothingFactor = 2.0 / 11.0; // ≈ 0.1818

  /// Compute Adaptive TDEE from a history of daily weigh-ins and calorie logs.
  ///
  /// Algorithm:
  /// 1. Apply Exponential Moving Average (EMA) to raw daily weights to produce
  ///    a smooth weight trend, eliminating water/sodium noise (±0.5–2 kg/day).
  /// 2. Compute the weight delta between the EMA at the start and end of the
  ///    analysis window.
  /// 3. Convert delta to caloric equivalent: deltaW × 7700 kcal/kg.
  /// 4. True TDEE = Avg Daily Intake − (deltaW × 7700 / days).
  ///
  /// Confidence levels:
  ///   - 'high'     — >=21 days, >=80% days have both weight+calories
  ///   - 'moderate' — >=14 days, >=60% completeness
  ///   - 'low'      — <14 days or <60% completeness
  static AdaptiveTdeeResult calculate(List<DailyMetabolicEntry> entries) {
    if (entries.isEmpty) {
      return const AdaptiveTdeeResult(
        estimatedTdee: 0, smoothedWeightKg: 0, weightTrendKgPerWeek: 0,
        avgDailyCalories: 0, confidenceLevel: 'low',
        dataPointsUsed: 0, minimumDaysMet: false,
      );
    }

    // Sort by date ascending
    final sorted = List<DailyMetabolicEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    // -- EMA smoothing for weight --
    final weightEntries = sorted
        .where((e) =>
            e.morningWeightKg != null && e.morningWeightKg! > 0)
        .toList();
    final calorieEntries = sorted
        .where((e) =>
            e.caloriesConsumed != null && e.caloriesConsumed! > 0)
        .toList();

    if (weightEntries.length < 2 || calorieEntries.isEmpty) {
      return AdaptiveTdeeResult(
        estimatedTdee: 0,
        smoothedWeightKg: weightEntries.isNotEmpty
            ? weightEntries.last.morningWeightKg!
            : 0,
        weightTrendKgPerWeek: 0,
        avgDailyCalories: calorieEntries.isNotEmpty
            ? _round1(calorieEntries
                .map((e) => e.caloriesConsumed!.toDouble())
                .reduce((a, b) => a + b) / calorieEntries.length)
            : 0,
        confidenceLevel: 'low',
        dataPointsUsed: weightEntries.length + calorieEntries.length,
        minimumDaysMet: false,
      );
    }

    // Compute EMA of weights
    final emaWeights = <double>[];
    double ema = weightEntries.first.morningWeightKg!;
    emaWeights.add(ema);

    for (int i = 1; i < weightEntries.length; i++) {
      final raw = weightEntries[i].morningWeightKg!;
      ema = emaSmoothingFactor * raw +
          (1.0 - emaSmoothingFactor) * ema;
      emaWeights.add(ema);
    }

    final smoothedStart = emaWeights.first;
    final smoothedEnd = emaWeights.last;
    final smoothedCurrent = smoothedEnd;

    // -- Weight delta over the analysis window --
    final firstDate = weightEntries.first.date;
    final lastDate = weightEntries.last.date;
    final daySpan = lastDate.difference(firstDate).inDays;

    if (daySpan <= 0) {
      return AdaptiveTdeeResult(
        estimatedTdee: 0,
        smoothedWeightKg: _round1(smoothedCurrent),
        weightTrendKgPerWeek: 0,
        avgDailyCalories: 0,
        confidenceLevel: 'low',
        dataPointsUsed: weightEntries.length,
        minimumDaysMet: false,
      );
    }

    final deltaWeightKg = smoothedEnd - smoothedStart;
    final weightTrendPerWeek = deltaWeightKg / daySpan * 7.0;

    // -- Average daily calorie intake --
    final totalCalories = calorieEntries
        .map((e) => e.caloriesConsumed!.toDouble())
        .reduce((a, b) => a + b);
    final avgDailyCal = totalCalories / calorieEntries.length;

    // -- Adaptive TDEE calculation --
    // TDEE = avgDailyCal − (deltaWeight × 7700 / daySpan)
    final weightCalEquivalent =
        deltaWeightKg * kcalPerKgBodyWeight / daySpan;
    final adaptiveTdee =
        (avgDailyCal - weightCalEquivalent).clamp(800.0, 8000.0);

    // -- Confidence assessment --
    final totalDaysWithBoth = sorted
        .where((e) =>
            e.morningWeightKg != null && e.morningWeightKg! > 0 &&
            e.caloriesConsumed != null && e.caloriesConsumed! > 0)
        .length;
    final completeness =
        daySpan > 0 ? totalDaysWithBoth / daySpan : 0.0;

    String confidence;
    if (daySpan >= 21 && completeness >= 0.80) {
      confidence = 'high';
    } else if (daySpan >= minimumDays && completeness >= 0.60) {
      confidence = 'moderate';
    } else {
      confidence = 'low';
    }

    return AdaptiveTdeeResult(
      estimatedTdee: _round1(adaptiveTdee),
      smoothedWeightKg: _round1(smoothedCurrent),
      weightTrendKgPerWeek: _round1(weightTrendPerWeek),
      avgDailyCalories: _round1(avgDailyCal),
      confidenceLevel: confidence,
      dataPointsUsed: totalDaysWithBoth,
      minimumDaysMet: daySpan >= minimumDays,
    );
  }
}
