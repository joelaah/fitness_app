import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/core/math/fitness_math.dart';
import 'package:fitness_app/core/math/fitness_math_v2.dart';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/nutrition/services/nutrition_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum MacroCalculationMode {
  standardPercent,
  perKgProtein,
}

class MacroCalculatorScreen extends StatefulWidget {
  const MacroCalculatorScreen({
    this.nutritionService,
    super.key,
  });

  final NutritionService? nutritionService;

  @override
  State<MacroCalculatorScreen> createState() => _MacroCalculatorScreenState();
}

class _MacroCalculatorScreenState extends State<MacroCalculatorScreen> {
  late final NutritionService _service;

  final _weightController = TextEditingController(text: '75');
  final _heightController = TextEditingController(text: '178');
  final _ageController = TextEditingController(text: '25');

  final _waistController = TextEditingController();
  final _neckController = TextEditingController();
  final _hipController = TextEditingController();

  BiologicalSex _sex = BiologicalSex.male;
  ActivityLevel _activity = ActivityLevel.moderate;
  FitnessGoal _goal = FitnessGoal.maintain;

  // Phase 2: Per-Kg Protein options
  MacroCalculationMode _calcMode = MacroCalculationMode.perKgProtein;
  double _proteinGPerKg = 1.8;
  CarbFatStrategy _carbFatStrategy = CarbFatStrategy.balanced;

  MacroSplit? _computedSplit;
  ProteinFirstSplit? _computedProteinFirstSplit;
  BodyCompositionResult? _computedBodyComp;
  BmrComparison? _bmrComparison;

  bool _isSaving = false;
  bool _showNavyMethod = false;

  @override
  void initState() {
    super.initState();
    _service = widget.nutritionService ?? NutritionService();
    _proteinGPerKg = ProteinFirstCalculator.recommendedProteinGPerKg(_goal);
    _loadSavedWeight();
    _recalculate();
  }

  Future<void> _loadSavedWeight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.get('profile_weight_kg');
      if (saved is num && saved > 0 && mounted) {
        setState(() {
          _weightController.text =
              saved % 1 == 0 ? saved.toInt().toString() : saved.toString();
          _recalculate();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _waistController.dispose();
    _neckController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  String _goalToSnake(FitnessGoal g) {
    switch (g) {
      case FitnessGoal.fatLoss:
        return 'fat_loss';
      case FitnessGoal.mildCut:
        return 'mild_cut';
      case FitnessGoal.maintain:
        return 'maintain';
      case FitnessGoal.mildBulk:
        return 'mild_bulk';
      case FitnessGoal.bulking:
        return 'bulking';
    }
  }

  void _onGoalChanged(FitnessGoal g) {
    setState(() {
      _goal = g;
      _proteinGPerKg = ProteinFirstCalculator.recommendedProteinGPerKg(g);
    });
    _recalculate();
  }

  void _recalculate() {
    final weight = double.tryParse(_weightController.text) ?? 75.0;
    final height = double.tryParse(_heightController.text) ?? 178.0;
    final age = int.tryParse(_ageController.text) ?? 25;

    // Body composition (US Navy method) if inputs available
    BodyCompositionResult? bodyComp;
    BmrComparison? bmrComp;
    final waist = double.tryParse(_waistController.text);
    final neck = double.tryParse(_neckController.text);
    final hip = double.tryParse(_hipController.text);

    if (waist != null && neck != null && waist > 0 && neck > 0) {
      if (_sex == BiologicalSex.male || (hip != null && hip > 0)) {
        bodyComp = BodyComposition.analyze(
          weightKg: weight,
          heightCm: height,
          sex: _sex,
          waistCm: waist,
          neckCm: neck,
          hipCm: hip,
        );

        if (bodyComp.bodyFatPct > 0) {
          bmrComp = KatchMcArdle.compare(
            weightKg: weight,
            heightCm: height,
            ageYears: age,
            sex: _sex,
            bodyFatPct: bodyComp.bodyFatPct,
          );
        }
      }
    }

    // Standard % split (30% P / 40% C / 30% F)
    final standardSplit = BmrTdeeCalculator.autoMacros(
      weightKg: weight,
      heightCm: height,
      ageYears: age,
      sex: _sex,
      activity: _activity,
      goal: _goal,
    );

    // Protein-First split (per-kg target)
    final proteinFirstSplit = ProteinFirstCalculator.calculate(
      weightKg: weight,
      heightCm: height,
      ageYears: age,
      sex: _sex,
      activity: _activity,
      goal: _goal,
      proteinGPerKg: _proteinGPerKg,
      strategy: _carbFatStrategy,
      bodyFatPct: bodyComp?.bodyFatPct,
    );

    setState(() {
      _computedSplit = standardSplit;
      _computedProteinFirstSplit = proteinFirstSplit;
      _computedBodyComp = bodyComp;
      _bmrComparison = bmrComp;
    });
  }

  int get _activeCalories => _calcMode == MacroCalculationMode.perKgProtein
      ? (_computedProteinFirstSplit?.calories.round() ?? 2000)
      : (_computedSplit?.calories.round() ?? 2000);

  int get _activeProteinG => _calcMode == MacroCalculationMode.perKgProtein
      ? (_computedProteinFirstSplit?.proteinG.round() ?? 150)
      : (_computedSplit?.proteinG.round() ?? 150);

  int get _activeCarbsG => _calcMode == MacroCalculationMode.perKgProtein
      ? (_computedProteinFirstSplit?.carbsG.round() ?? 200)
      : (_computedSplit?.carbsG.round() ?? 200);

  int get _activeFatG => _calcMode == MacroCalculationMode.perKgProtein
      ? (_computedProteinFirstSplit?.fatG.round() ?? 65)
      : (_computedSplit?.fatG.round() ?? 65);

  double get _activeBmr => _calcMode == MacroCalculationMode.perKgProtein
      ? (_computedProteinFirstSplit?.bmr ?? 1800.0)
      : (_computedSplit?.bmr ?? 1800.0);

  double get _activeTdee => _calcMode == MacroCalculationMode.perKgProtein
      ? (_computedProteinFirstSplit?.tdee ?? 2500.0)
      : (_computedSplit?.tdee ?? 2500.0);

  Future<void> _saveAndApply() async {
    setState(() => _isSaving = true);

    try {
      final calories = _activeCalories;
      final protein = _activeProteinG;
      final carbs = _activeCarbsG;
      final fat = _activeFatG;

      await _service.saveMacroTargets(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );

      final weight = double.tryParse(_weightController.text);
      if (weight != null && weight > 0) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('profile_weight_kg', weight);
        } catch (_) {}
      }

      // Save additional profile metrics if Supabase authenticated
      if (SupabaseConfig.isInitialized) {
        try {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final height = double.tryParse(_heightController.text);
            final age = int.tryParse(_ageController.text);

            await Supabase.instance.client.from('profiles').update({
              'weight_kg': weight,
              'height_cm': height,
              'age_years': age,
              'biological_sex': _sex.name,
              'activity_level': _activity.name,
              'fitness_goal': _goalToSnake(_goal),
              if (_waistController.text.isNotEmpty)
                'waist_cm': double.tryParse(_waistController.text),
              if (_neckController.text.isNotEmpty)
                'neck_cm': double.tryParse(_neckController.text),
              if (_hipController.text.isNotEmpty)
                'hip_cm': double.tryParse(_hipController.text),
            }).eq('id', user.id);
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Targets saved: $calories kcal ($protein P / $carbs C / $fat F)',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPerKg = _calcMode == MacroCalculationMode.perKgProtein;
    final pFirst = _computedProteinFirstSplit;

    // Calorie breakdown for proportional indicator
    final pKcal = _activeProteinG * 4;
    final cKcal = _activeCarbsG * 4;
    final fKcal = _activeFatG * 9;
    final totalMacroKcal = pKcal + cKcal + fKcal;
    final safeTotal = totalMacroKcal > 0 ? totalMacroKcal : 2000;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Target Calorie & Macro Setup',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Personalized metabolic calculations for athletic goals and training performance.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Hero Live Telemetry Preview Card
                  ElevatedCard(
                    hasGlow: true,
                    glowColor: AppColors.primary,
                    borderGradient: const LinearGradient(
                      colors: [
                        Color(0x9900E676),
                        Color(0x4406B6D4),
                        Color(0x22334155),
                      ],
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary,
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'DAILY ENERGY TARGET',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  isPerKg && pFirst?.bmrMethod == 'katch_mcardle'
                                      ? 'BMR: ${_activeBmr.round()} (Katch) • TDEE: ${_activeTdee.round()}'
                                      : 'BMR: ${_activeBmr.round()} • TDEE: ${_activeTdee.round()}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$_activeCalories kcal',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                isPerKg
                                    ? '(${_proteinGPerKg.toStringAsFixed(1)} g/kg protein)'
                                    : '(Standard 30% protein)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Visual Proportional Macro Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Row(
                            children: [
                              Expanded(
                                flex: ((pKcal / safeTotal) * 100).round().clamp(1, 100),
                                child: Container(
                                  height: 5,
                                  color: const Color(0xFF00E676),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: ((cKcal / safeTotal) * 100).round().clamp(1, 100),
                                child: Container(
                                  height: 5,
                                  color: const Color(0xFF06B6D4),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: ((fKcal / safeTotal) * 100).round().clamp(1, 100),
                                child: Container(
                                  height: 5,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm + 4),

                        // Macro Target Mini-Cards
                        Row(
                          children: [
                            Expanded(
                              child: _MacroPill(
                                label: isPerKg
                                    ? 'PROTEIN (${_proteinGPerKg.toStringAsFixed(1)}g/kg)'
                                    : 'PROTEIN (30%)',
                                grams: '${_activeProteinG}g',
                                color: const Color(0xFF00E676),
                                subtitle: '$pKcal kcal • ${((pKcal / safeTotal) * 100).round()}%',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _MacroPill(
                                label: isPerKg
                                    ? 'CARBS (${pFirst?.carbsPctActual.round() ?? 40}%)'
                                    : 'CARBS (40%)',
                                grams: '${_activeCarbsG}g',
                                color: const Color(0xFF06B6D4),
                                subtitle: '$cKcal kcal • ${((cKcal / safeTotal) * 100).round()}%',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _MacroPill(
                                label: isPerKg
                                    ? 'FAT (${pFirst?.fatPctActual.round() ?? 30}%)'
                                    : 'FAT (30%)',
                                grams: '${_activeFatG}g',
                                color: const Color(0xFFF59E0B),
                                subtitle: '$fKcal kcal • ${((fKcal / safeTotal) * 100).round()}%',
                              ),
                            ),
                          ],
                        ),

                        // Body Composition & Katch-McArdle comparison banner
                        if (_computedBodyComp != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                              horizontal: AppSpacing.sm + 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Navy Body Fat: ${_computedBodyComp!.bodyFatPct.toStringAsFixed(1)}% (${_computedBodyComp!.bodyFatCategory})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'BMI: ${_computedBodyComp!.bmi.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_bmrComparison != null) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Lean Mass: ${_bmrComparison!.leanMassKg} kg • Katch BMR: ${_bmrComparison!.katchMcArdle.round()} vs Mifflin: ${_bmrComparison!.mifflinStJeor.round()} kcal (${_bmrComparison!.deltaKcal >= 0 ? "+" : ""}${_bmrComparison!.deltaKcal.round()} kcal)',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Section: Calculation Protocol
                  _SectionCard(
                    title: 'Calculation Protocol',
                    icon: Icons.tune_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculation Method',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SelectionChip(
                                  label: '⚡ Athletic (Per-kg Protein)',
                                  isSelected: _calcMode == MacroCalculationMode.perKgProtein,
                                  onTap: () {
                                    setState(() => _calcMode = MacroCalculationMode.perKgProtein);
                                    _recalculate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _SelectionChip(
                                  label: 'Standard % Split',
                                  isSelected: _calcMode == MacroCalculationMode.standardPercent,
                                  onTap: () {
                                    setState(() => _calcMode = MacroCalculationMode.standardPercent);
                                    _recalculate();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Per-Kg Protein options (when in per-kg mode)
                        if (_calcMode == MacroCalculationMode.perKgProtein) ...[
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Protein Target (g/kg)',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_proteinGPerKg.toStringAsFixed(1)} g/kg',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [1.6, 1.8, 2.0, 2.2, 2.4].map((ratio) {
                              final label = _proteinRatioLabel(ratio);
                              return _SelectionChip(
                                label: '$ratio g/kg\n$label',
                                isSelected: (_proteinGPerKg - ratio).abs() < 0.05,
                                onTap: () {
                                  setState(() => _proteinGPerKg = ratio);
                                  _recalculate();
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Remaining Calories Distribution (Carb/Fat)',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _StrategyChip(
                                      label: 'Balanced\n(50% C / 50% F)',
                                      isSelected: _carbFatStrategy == CarbFatStrategy.balanced,
                                      onTap: () {
                                        setState(() => _carbFatStrategy = CarbFatStrategy.balanced);
                                        _recalculate();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _StrategyChip(
                                      label: 'High-Carb\n(65% C / 35% F)',
                                      isSelected: _carbFatStrategy == CarbFatStrategy.highCarb,
                                      onTap: () {
                                        setState(() => _carbFatStrategy = CarbFatStrategy.highCarb);
                                        _recalculate();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StrategyChip(
                                      label: 'Low-Carb\n(35% C / 65% F)',
                                      isSelected: _carbFatStrategy == CarbFatStrategy.lowCarb,
                                      onTap: () {
                                        setState(() => _carbFatStrategy = CarbFatStrategy.lowCarb);
                                        _recalculate();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _StrategyChip(
                                      label: 'Even Grams\n(Equal C & F)',
                                      isSelected: _carbFatStrategy == CarbFatStrategy.evenGrams,
                                      onTap: () {
                                        setState(() => _carbFatStrategy = CarbFatStrategy.evenGrams);
                                        _recalculate();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Section: Biometric Profile
                  _SectionCard(
                    title: 'Biometric Profile',
                    icon: Icons.person_outline,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInput('Weight (kg)', _weightController, unit: 'kg'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _buildInput('Height (cm)', _heightController, unit: 'cm'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _buildInput('Age', _ageController, unit: 'yr'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Text(
                          'Biological Sex',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SelectionChip(
                                  label: 'Male',
                                  isSelected: _sex == BiologicalSex.male,
                                  onTap: () {
                                    setState(() => _sex = BiologicalSex.male);
                                    _recalculate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _SelectionChip(
                                  label: 'Female',
                                  isSelected: _sex == BiologicalSex.female,
                                  onTap: () {
                                    setState(() => _sex = BiologicalSex.female);
                                    _recalculate();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Activity Level',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: ActivityLevel.values.map((lvl) {
                            final label = _activityLabel(lvl);
                            return _SelectionChip(
                              label: label,
                              isSelected: _activity == lvl,
                              onTap: () {
                                setState(() => _activity = lvl);
                                _recalculate();
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Fitness Goal',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: FitnessGoal.values.map((g) {
                            final label = _goalLabel(g);
                            return _SelectionChip(
                              label: label,
                              isSelected: _goal == g,
                              onTap: () => _onGoalChanged(g),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Section: US Navy Body Composition (Optional Accordion)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _showNavyMethod = !_showNavyMethod),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.architecture_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Optional: US Navy Body Fat & Katch-McArdle BMR',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _showNavyMethod ? Icons.expand_less : Icons.expand_more,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showNavyMethod) ...[
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput('Waist (cm)', _waistController, unit: 'cm'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _buildInput('Neck (cm)', _neckController, unit: 'cm'),
                              ),
                              if (_sex == BiologicalSex.female) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _buildInput('Hip (cm)', _hipController, unit: 'cm'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Apply & Save Targets Button
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSaving ? null : _saveAndApply,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 20, color: Colors.black),
                                  SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'APPLY & SAVE TARGETS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {String? unit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
              if (unit != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _proteinRatioLabel(double r) {
    if (r <= 1.6) return 'Bulking / Rec';
    if (r <= 1.8) return 'Maintenance';
    if (r <= 2.0) return 'Athletic';
    if (r <= 2.2) return 'Deficit / Cut';
    return 'Hypertrophy';
  }

  String _activityLabel(ActivityLevel l) {
    switch (l) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.light:
        return 'Light (1-2x/wk)';
      case ActivityLevel.moderate:
        return 'Moderate (3-5x/wk)';
      case ActivityLevel.active:
        return 'Active (6-7x/wk)';
      case ActivityLevel.athlete:
        return 'Athlete (2x daily)';
    }
  }

  String _goalLabel(FitnessGoal g) {
    switch (g) {
      case FitnessGoal.fatLoss:
        return 'Fat Loss (-500 kcal)';
      case FitnessGoal.mildCut:
        return 'Mild Cut (-250 kcal)';
      case FitnessGoal.maintain:
        return 'Maintenance';
      case FitnessGoal.mildBulk:
        return 'Mild Bulk (+250 kcal)';
      case FitnessGoal.bulking:
        return 'Bulking (+500 kcal)';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.icon,
    required this.child,
  });

  final String title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.grams,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String grams;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              grams,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.surfaceElevated.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.8),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _StrategyChip extends StatelessWidget {
  const _StrategyChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.surfaceElevated.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.8),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 11,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
