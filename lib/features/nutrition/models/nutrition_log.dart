import 'package:fitness_app/features/nutrition/models/food_item.dart';

/// Database entity for a logged meal in Supabase / local storage.
class NutritionLog {
  const NutritionLog({
    required this.id,
    required this.userId,
    required this.mealName,
    this.mealType = 'other',
    this.imageUrl,
    required this.loggedAt,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    this.atwaterCalories,
    this.items = const [],
    this.healthScore,
    this.notes,
  });

  final String id;
  final String userId;
  final String mealName;
  final String mealType;
  final String? imageUrl;
  final DateTime loggedAt;
  final double totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final double? atwaterCalories;
  final List<FoodItem> items;
  final int? healthScore;
  final String? notes;

  factory NutritionLog.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items_json'] ?? json['items'];
    List<FoodItem> parsedItems = const [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final rawLoggedAt = json['logged_at'] as String?;
    final loggedAt = rawLoggedAt != null
        ? DateTime.tryParse(rawLoggedAt)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    final p = (json['total_protein_g'] as num?)?.toDouble() ?? 0.0;
    final c = (json['total_carbs_g'] as num?)?.toDouble() ?? 0.0;
    final f = (json['total_fat_g'] as num?)?.toDouble() ?? 0.0;
    final atwater = FoodItem.calculateAtwater(p, c, f);

    return NutritionLog(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      mealName: (json['meal_name'] as String?)?.trim() ?? 'Logged Meal',
      mealType: (json['meal_type'] as String?)?.trim() ?? 'other',
      imageUrl: json['image_url'] as String?,
      loggedAt: loggedAt,
      totalCalories: atwater > 0 ? atwater : ((json['total_calories'] as num?)?.toDouble() ?? 0.0),
      totalProteinG: p,
      totalCarbsG: c,
      totalFatG: f,
      atwaterCalories: atwater,
      items: parsedItems,
      healthScore: (json['health_score'] as num?)?.toInt(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'meal_name': mealName,
        'meal_type': mealType,
        'image_url': imageUrl,
        'logged_at': loggedAt.toUtc().toIso8601String(),
        'total_calories': totalCalories,
        'total_protein_g': totalProteinG,
        'total_carbs_g': totalCarbsG,
        'total_fat_g': totalFatG,
        'atwater_calories': atwaterCalories ?? totalCalories,
        'items_json': items.map((i) => i.toJson()).toList(),
        'health_score': healthScore,
        'notes': notes,
      };
}
