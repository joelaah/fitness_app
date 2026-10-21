/// Represents a single identified food component on a plate.
/// Calculates calories deterministically via the Atwater 4-4-9 factor system.
class FoodItem {
  const FoodItem({
    required this.name,
    required this.portionG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.confidence = 0.85,
    this.category = 'general',
    this.basePortionG,
    this.baseProteinG,
    this.baseCarbsG,
    this.baseFatG,
  });

  final String name;
  final double portionG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double confidence;
  final String category;

  // Baseline nutritional metrics to prevent cumulative rounding drift
  final double? basePortionG;
  final double? baseProteinG;
  final double? baseCarbsG;
  final double? baseFatG;

  double get effectiveBasePortionG =>
      (basePortionG != null && basePortionG! > 0) ? basePortionG! : (portionG > 0 ? portionG : 100.0);
  double get effectiveBaseProteinG => baseProteinG ?? proteinG;
  double get effectiveBaseCarbsG => baseCarbsG ?? carbsG;
  double get effectiveBaseFatG => baseFatG ?? fatG;

  /// Standard Atwater factor energy calculation:
  /// Calories = 4 * Protein(g) + 4 * Carbs(g) + 9 * Fat(g)
  static double calculateAtwater(double p, double c, double f) {
    return double.parse(((p * 4.0) + (c * 4.0) + (f * 9.0)).toStringAsFixed(1));
  }

  /// Returns a copy of this item scaled to a new portion weight in grams.
  /// Preserves the reference density so repeated slider adjustments never drift or zero out.
  FoodItem scaleToPortion(double newPortionG) {
    final basePortion = effectiveBasePortionG;
    final baseP = effectiveBaseProteinG;
    final baseC = effectiveBaseCarbsG;
    final baseF = effectiveBaseFatG;

    if (newPortionG <= 0) {
      return copyWith(
        portionG: 0,
        calories: 0,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
        basePortionG: basePortion,
        baseProteinG: baseP,
        baseCarbsG: baseC,
        baseFatG: baseF,
      );
    }

    final factor = newPortionG / basePortion;
    final newP = double.parse((baseP * factor).toStringAsFixed(1));
    final newC = double.parse((baseC * factor).toStringAsFixed(1));
    final newF = double.parse((baseF * factor).toStringAsFixed(1));
    final newCal = calculateAtwater(newP, newC, newF);

    return copyWith(
      portionG: double.parse(newPortionG.toStringAsFixed(1)),
      calories: newCal,
      proteinG: newP,
      carbsG: newC,
      fatG: newF,
      basePortionG: basePortion,
      baseProteinG: baseP,
      baseCarbsG: baseC,
      baseFatG: baseF,
    );
  }

  FoodItem copyWith({
    String? name,
    double? portionG,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? confidence,
    String? category,
    double? basePortionG,
    double? baseProteinG,
    double? baseCarbsG,
    double? baseFatG,
  }) {
    return FoodItem(
      name: name ?? this.name,
      portionG: portionG ?? this.portionG,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      confidence: confidence ?? this.confidence,
      category: category ?? this.category,
      basePortionG: basePortionG ?? this.basePortionG,
      baseProteinG: baseProteinG ?? this.baseProteinG,
      baseCarbsG: baseCarbsG ?? this.baseCarbsG,
      baseFatG: baseFatG ?? this.baseFatG,
    );
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final p = (json['protein_g'] as num?)?.toDouble() ?? 0.0;
    final c = (json['carbs_g'] as num?)?.toDouble() ?? 0.0;
    final f = (json['fat_g'] as num?)?.toDouble() ?? 0.0;
    final portion = (json['portion_g'] as num?)?.toDouble() ?? 100.0;
    final atwaterCal = calculateAtwater(p, c, f);

    return FoodItem(
      name: (json['name'] as String?)?.trim() ?? 'Food Item',
      portionG: portion,
      calories: atwaterCal,
      proteinG: p,
      carbsG: c,
      fatG: f,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      category: (json['category'] as String?)?.trim() ?? 'general',
      basePortionG: (json['base_portion_g'] as num?)?.toDouble() ?? portion,
      baseProteinG: (json['base_protein_g'] as num?)?.toDouble() ?? p,
      baseCarbsG: (json['base_carbs_g'] as num?)?.toDouble() ?? c,
      baseFatG: (json['base_fat_g'] as num?)?.toDouble() ?? f,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'portion_g': portionG,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'confidence': confidence,
        'category': category,
        if (basePortionG != null) 'base_portion_g': basePortionG,
        if (baseProteinG != null) 'base_protein_g': baseProteinG,
        if (baseCarbsG != null) 'base_carbs_g': baseCarbsG,
        if (baseFatG != null) 'base_fat_g': baseFatG,
      };
}
