import 'package:fitness_app/features/nutrition/models/nutrition_log.dart';

/// Aggregated macro breakdown for a specific calendar day.
class DailyMacroSummary {
  const DailyMacroSummary({
    required this.date,
    required this.loggedMeals,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    this.targetCalories = 2000,
    this.targetProteinG = 150,
    this.targetCarbsG = 200,
    this.targetFatG = 65,
    this.meals = const [],
  });

  final String date;
  final int loggedMeals;
  final double totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final int targetCalories;
  final int targetProteinG;
  final int targetCarbsG;
  final int targetFatG;
  final List<NutritionLog> meals;

  double get caloriesProgress =>
      targetCalories > 0 ? (totalCalories / targetCalories).clamp(0.0, 1.0) : 0.0;
  double get proteinProgress =>
      targetProteinG > 0 ? (totalProteinG / targetProteinG).clamp(0.0, 1.0) : 0.0;
  double get carbsProgress =>
      targetCarbsG > 0 ? (totalCarbsG / targetCarbsG).clamp(0.0, 1.0) : 0.0;
  double get fatProgress =>
      targetFatG > 0 ? (totalFatG / targetFatG).clamp(0.0, 1.0) : 0.0;

  factory DailyMacroSummary.empty({String? date}) {
    return DailyMacroSummary(
      date: date ?? DateTime.now().toIso8601String().substring(0, 10),
      loggedMeals: 0,
      totalCalories: 0,
      totalProteinG: 0,
      totalCarbsG: 0,
      totalFatG: 0,
    );
  }

  factory DailyMacroSummary.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as List<dynamic>? ?? const [];
    final meals = rawMeals
        .map((e) => NutritionLog.fromJson(e as Map<String, dynamic>))
        .toList();

    return DailyMacroSummary(
      date: json['date'] as String? ?? '',
      loggedMeals: (json['logged_meals'] as num?)?.toInt() ?? meals.length,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0.0,
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0.0,
      totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0.0,
      targetCalories: (json['target_calories'] as num?)?.toInt() ?? 2000,
      targetProteinG: (json['target_protein_g'] as num?)?.toInt() ?? 150,
      targetCarbsG: (json['target_carbs_g'] as num?)?.toInt() ?? 200,
      targetFatG: (json['target_fat_g'] as num?)?.toInt() ?? 65,
      meals: meals,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'logged_meals': loggedMeals,
        'total_calories': totalCalories,
        'total_protein_g': totalProteinG,
        'total_carbs_g': totalCarbsG,
        'total_fat_g': totalFatG,
        'target_calories': targetCalories,
        'target_protein_g': targetProteinG,
        'target_carbs_g': targetCarbsG,
        'target_fat_g': targetFatG,
        'meals': meals.map((m) => m.toJson()).toList(),
      };
}
