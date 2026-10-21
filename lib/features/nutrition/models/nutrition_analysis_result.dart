import 'package:fitness_app/features/nutrition/models/food_item.dart';

/// Complete multimodal analysis result received from the PulseFit vision backend.
class NutritionAnalysisResult {
  const NutritionAnalysisResult({
    required this.mealName,
    required this.items,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.atwaterCalories,
    this.healthScore = 85,
    this.nutritionalSummary = '',
    this.scientificNotes = '',
    this.analyzedAt = '',
  });

  final String mealName;
  final List<FoodItem> items;
  final double totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final double atwaterCalories;
  final int healthScore;
  final String nutritionalSummary;
  final String scientificNotes;
  final String analyzedAt;

  /// Recalculates all total macros and Atwater calories from the current item list.
  NutritionAnalysisResult recalculate() {
    double p = 0;
    double c = 0;
    double f = 0;
    for (final item in items) {
      p += item.proteinG;
      c += item.carbsG;
      f += item.fatG;
    }
    p = double.parse(p.toStringAsFixed(1));
    c = double.parse(c.toStringAsFixed(1));
    f = double.parse(f.toStringAsFixed(1));
    final atwater = FoodItem.calculateAtwater(p, c, f);

    return copyWith(
      totalCalories: atwater,
      totalProteinG: p,
      totalCarbsG: c,
      totalFatG: f,
      atwaterCalories: atwater,
    );
  }

  NutritionAnalysisResult copyWith({
    String? mealName,
    List<FoodItem>? items,
    double? totalCalories,
    double? totalProteinG,
    double? totalCarbsG,
    double? totalFatG,
    double? atwaterCalories,
    int? healthScore,
    String? nutritionalSummary,
    String? scientificNotes,
    String? analyzedAt,
  }) {
    return NutritionAnalysisResult(
      mealName: mealName ?? this.mealName,
      items: items ?? this.items,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalFatG: totalFatG ?? this.totalFatG,
      atwaterCalories: atwaterCalories ?? this.atwaterCalories,
      healthScore: healthScore ?? this.healthScore,
      nutritionalSummary: nutritionalSummary ?? this.nutritionalSummary,
      scientificNotes: scientificNotes ?? this.scientificNotes,
      analyzedAt: analyzedAt ?? this.analyzedAt,
    );
  }

  factory NutritionAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] as List<dynamic>? ?? const [];
    final items = rawList
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();

    var p = (json['total_protein_g'] as num?)?.toDouble() ?? 0.0;
    var c = (json['total_carbs_g'] as num?)?.toDouble() ?? 0.0;
    var f = (json['total_fat_g'] as num?)?.toDouble() ?? 0.0;

    // Recalculate if totals are 0 but items exist
    if (p == 0 && c == 0 && f == 0 && items.isNotEmpty) {
      for (final i in items) {
        p += i.proteinG;
        c += i.carbsG;
        f += i.fatG;
      }
    }
    p = double.parse(p.toStringAsFixed(1));
    c = double.parse(c.toStringAsFixed(1));
    f = double.parse(f.toStringAsFixed(1));

    final atwaterCal = FoodItem.calculateAtwater(p, c, f);

    return NutritionAnalysisResult(
      mealName: (json['meal_name'] as String?)?.trim() ?? 'Analyzed Meal',
      items: items,
      totalCalories: atwaterCal,
      totalProteinG: p,
      totalCarbsG: c,
      totalFatG: f,
      atwaterCalories: atwaterCal,
      healthScore: (json['health_score'] as num?)?.toInt() ?? 85,
      nutritionalSummary: (json['nutritional_summary'] as String?)?.trim() ?? '',
      scientificNotes: (json['scientific_notes'] as String?)?.trim() ?? '',
      analyzedAt: (json['analyzed_at'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'meal_name': mealName,
        'items': items.map((i) => i.toJson()).toList(),
        'total_calories': totalCalories,
        'total_protein_g': totalProteinG,
        'total_carbs_g': totalCarbsG,
        'total_fat_g': totalFatG,
        'atwater_calories': atwaterCalories,
        'health_score': healthScore,
        'nutritional_summary': nutritionalSummary,
        'scientific_notes': scientificNotes,
        'analyzed_at': analyzedAt,
      };
}
