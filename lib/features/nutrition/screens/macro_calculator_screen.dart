import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/core/math/fitness_math.dart';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/nutrition/services/nutrition_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  MacroSplit? _computedSplit;
  BodyCompositionResult? _computedBodyComp;
  bool _isSaving = false;
  bool _showNavyMethod = false;

  @override
  void initState() {
    super.initState();
    _service = widget.nutritionService ?? NutritionService();
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

  void _recalculate() {
    final weight = double.tryParse(_weightController.text) ?? 75.0;
    final height = double.tryParse(_heightController.text) ?? 178.0;
    final age = int.tryParse(_ageController.text) ?? 25;

    final split = BmrTdeeCalculator.autoMacros(
      weightKg: weight,
      heightCm: height,
      ageYears: age,
      sex: _sex,
      activity: _activity,
      goal: _goal,
    );

    BodyCompositionResult? bodyComp;
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
      }
    }

    setState(() {
      _computedSplit = split;
      _computedBodyComp = bodyComp;
    });
  }

  Future<void> _saveAndApply() async {
    if (_computedSplit == null) return;
    setState(() => _isSaving = true);

    try {
      final calories = _computedSplit!.calories.round();
      final protein = _computedSplit!.proteinG.round();
      final carbs = _computedSplit!.carbsG.round();
      final fat = _computedSplit!.fatG.round();

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
                const SizedBox(width: 8),
                Text(
                  'Targets updated: $calories kcal ($protein P / $carbs C / $fat F)',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
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
    final split = _computedSplit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Calorie & Macro Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personalized Mifflin-St Jeor metabolic calculation for training & athletic goals.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Live Calculated Preview Card
            if (split != null)
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
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DAILY ENERGY TARGET',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'BMR: ${split.bmr.round()} | TDEE: ${split.tdee.round()}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${split.calories.round()} kcal',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MacroPill(
                            label: 'PROTEIN',
                            grams: '${split.proteinG.round()}g',
                            color: const Color(0xFF00E676),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MacroPill(
                            label: 'CARBS',
                            grams: '${split.carbsG.round()}g',
                            color: const Color(0xFF06B6D4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MacroPill(
                            label: 'FAT',
                            grams: '${split.fatG.round()}g',
                            color: const Color(0xFFFFB300),
                          ),
                        ),
                      ],
                    ),

                    // Body Composition Result Pill if available
                    if (_computedBodyComp != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
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
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Input Fields
            Row(
              children: [
                Expanded(
                  child: _buildInput('Weight (kg)', _weightController),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput('Height (cm)', _heightController),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput('Age', _ageController),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Biological Sex
            Text('Biological Sex', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
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
                const SizedBox(width: 12),
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

            const SizedBox(height: 20),

            // Activity Level
            Text('Activity Level', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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

            const SizedBox(height: 20),

            // Goal
            Text('Fitness Goal', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FitnessGoal.values.map((g) {
                final label = _goalLabel(g);
                return _SelectionChip(
                  label: label,
                  isSelected: _goal == g,
                  onTap: () {
                    setState(() => _goal = g);
                    _recalculate();
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Expandable Navy Method Body Fat
            InkWell(
              onTap: () => setState(() => _showNavyMethod = !_showNavyMethod),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _showNavyMethod ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Optional: US Navy Body Fat % Estimator',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showNavyMethod) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildInput('Waist (cm)', _waistController)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput('Neck (cm)', _neckController)),
                  if (_sex == BiologicalSex.female) ...[
                    const SizedBox(width: 10),
                    Expanded(child: _buildInput('Hip (cm)', _hipController)),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Save & Apply Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                    : const Text(
                        'APPLY & SAVE TARGETS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => _recalculate(),
          ),
        ),
      ],
    );
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

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.grams,
    required this.color,
  });

  final String label;
  final String grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            grams,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
