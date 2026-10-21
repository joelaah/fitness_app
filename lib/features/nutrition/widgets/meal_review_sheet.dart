import 'dart:math' as math;
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/features/nutrition/models/food_item.dart';
import 'package:fitness_app/features/nutrition/models/nutrition_analysis_result.dart';
import 'package:fitness_app/features/nutrition/models/nutrition_log.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Interactive modal sheet allowing users to review AI-detected foods,
/// tweak portion gram weights, add/remove items, and confirm daily intake.
class MealReviewSheet extends StatefulWidget {
  const MealReviewSheet({
    required this.analysisResult,
    required this.onSaveMeal,
    super.key,
  });

  final NutritionAnalysisResult analysisResult;
  final ValueChanged<NutritionLog> onSaveMeal;

  @override
  State<MealReviewSheet> createState() => _MealReviewSheetState();
}

class _MealReviewSheetState extends State<MealReviewSheet> {
  late String _mealName;
  late String _mealType;
  late List<FoodItem> _items;

  @override
  void initState() {
    super.initState();
    _mealName = widget.analysisResult.mealName;
    _mealType = _inferDefaultMealType();
    _items = List<FoodItem>.from(widget.analysisResult.items);
  }

  String _inferDefaultMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 16) return 'lunch';
    if (hour >= 16 && hour < 21) return 'dinner';
    return 'snack';
  }

  double get _totalProtein {
    var p = 0.0;
    for (final i in _items) {
      p += i.proteinG;
    }
    return double.parse(p.toStringAsFixed(1));
  }

  double get _totalCarbs {
    var c = 0.0;
    for (final i in _items) {
      c += i.carbsG;
    }
    return double.parse(c.toStringAsFixed(1));
  }

  double get _totalFat {
    var f = 0.0;
    for (final i in _items) {
      f += i.fatG;
    }
    return double.parse(f.toStringAsFixed(1));
  }

  double get _atwaterCalories {
    return FoodItem.calculateAtwater(_totalProtein, _totalCarbs, _totalFat);
  }

  void _updatePortion(int index, double newPortionG) {
    if (index < 0 || index >= _items.length) return;
    setState(() {
      _items[index] = _items[index].scaleToPortion(newPortionG);
    });
  }

  void _editPortionDialog(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    final ctrl = TextEditingController(text: item.portionG.toStringAsFixed(0));

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Set Portion: ${item.name}',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Weight in Grams (g)',
            labelStyle: TextStyle(color: AppColors.primary),
            suffixText: 'g',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text);
              if (parsed != null && parsed >= 0) {
                _updatePortion(index, parsed);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Update', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    setState(() {
      _items.removeAt(index);
    });
  }

  void _addNewItemDialog() {
    final nameCtrl = TextEditingController();
    final portionCtrl = TextEditingController(text: '100');
    final proteinCtrl = TextEditingController(text: '10');
    final carbsCtrl = TextEditingController(text: '15');
    final fatCtrl = TextEditingController(text: '3');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Add Food Item',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portionCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Portion (g)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        labelStyle: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g)',
                        labelStyle: TextStyle(color: Color(0xFF06B6D4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Fat (g)',
                        labelStyle: TextStyle(color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final portion = double.tryParse(portionCtrl.text) ?? 100.0;
                final p = double.tryParse(proteinCtrl.text) ?? 0.0;
                final c = double.tryParse(carbsCtrl.text) ?? 0.0;
                final f = double.tryParse(fatCtrl.text) ?? 0.0;
                final cal = FoodItem.calculateAtwater(p, c, f);

                setState(() {
                  _items.add(FoodItem(
                    name: name,
                    portionG: portion,
                    calories: cal,
                    proteinG: p,
                    carbsG: c,
                    fatG: f,
                    confidence: 1.0,
                    category: 'manual',
                  ));
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    final log = NutritionLog(
      id: const Uuid().v4(),
      userId: '',
      mealName: _mealName.trim().isNotEmpty ? _mealName.trim() : 'Logged Meal',
      mealType: _mealType,
      loggedAt: DateTime.now(),
      totalCalories: _atwaterCalories,
      totalProteinG: _totalProtein,
      totalCarbsG: _totalCarbs,
      totalFatG: _totalFat,
      atwaterCalories: _atwaterCalories,
      items: _items,
      healthScore: widget.analysisResult.healthScore,
      notes: widget.analysisResult.nutritionalSummary,
    );

    widget.onSaveMeal(log);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.sizeOf(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: mediaQuery.height * 0.90,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Meal Name & Type Picker
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _mealName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Meal Name',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      onChanged: (v) => _mealName = v,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _mealType,
                    dropdownColor: AppColors.surface,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                      DropdownMenuItem(value: 'snack', child: Text('Snack')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _mealType = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Macro Ticker Overview Card
              ElevatedCard(
                hasGlow: true,
                glowColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMacroPill(
                        label: 'Calories',
                        value: '${_atwaterCalories.toStringAsFixed(0)} kcal',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _buildMacroPill(
                        label: 'Protein',
                        value: '${_totalProtein}g',
                        color: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: _buildMacroPill(
                        label: 'Carbs',
                        value: '${_totalCarbs}g',
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                    Expanded(
                      child: _buildMacroPill(
                        label: 'Fat',
                        value: '${_totalFat}g',
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Items Section Title & Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Detected Components (${_items.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addNewItemDialog,
                    icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Add Item',
                      style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              // Items List with Live Sliders
              Flexible(
                child: _items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No items detected. Tap Add Item to log manually.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${item.calories.toStringAsFixed(0)} kcal',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                                      onPressed: () => _removeItem(i),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Macro chips
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'P: ${item.proteinG}g  ',
                                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                            TextSpan(
                                              text: 'C: ${item.carbsG}g  ',
                                              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                            TextSpan(
                                              text: 'F: ${item.fatG}g',
                                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _editPortionDialog(i),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${item.portionG.toStringAsFixed(0)}g',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Portion weight slider
                                Builder(
                                  builder: (context) {
                                    final sliderMax = math.max(500.0, ((item.portionG * 1.4) / 50).ceil() * 50.0);
                                    return SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: AppColors.primary,
                                        inactiveTrackColor: AppColors.surfaceElevated,
                                        thumbColor: AppColors.primary,
                                        overlayColor: AppColors.primary.withValues(alpha: 0.2),
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      ),
                                      child: Slider(
                                        value: item.portionG.clamp(5.0, sliderMax),
                                        min: 5.0,
                                        max: sliderMax,
                                        divisions: (sliderMax - 5.0) ~/ 5,
                                        onChanged: (val) => _updatePortion(i, val),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Save Action
              PrimaryButton(
                label: 'Save ${_atwaterCalories.toStringAsFixed(0)} kcal to Daily Intake',
                icon: Icons.check_circle_outline,
                onPressed: _items.isNotEmpty ? _onSave : null,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildMacroPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
