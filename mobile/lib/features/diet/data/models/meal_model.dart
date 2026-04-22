import '../../domain/entities/meal_entity.dart';
import '../../domain/entities/meal_ingredient_entity.dart';

/// Manual DTO for Diet Meals to avoid generation collisions.
class MealModel {
  final String id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final DateTime? scheduledDate;
  final String? type;
  final String? timeOfDay;
  final DateTime timestamp;
  final String? instructions;
  final List<MealIngredientEntity>? ingredients;
  final String? heroIngredient;
  final String? ingredientSummary;
  final int? orderIndex;
  final int? dayTargetCalories;
  final int? dayTargetProtein;
  final int? dayTargetCarbs;
  final int? dayTargetFats;

  const MealModel({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.scheduledDate,
    this.type,
    this.timeOfDay,
    required this.timestamp,
    this.instructions,
    this.ingredients,
    this.heroIngredient,
    this.ingredientSummary,
    this.orderIndex,
    this.dayTargetCalories,
    this.dayTargetProtein,
    this.dayTargetCarbs,
    this.dayTargetFats,
  });

  factory MealModel.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    var rawItems = json['ingredients'];

    List<MealIngredientEntity>? parsedItems;
    if (rawItems is List) {
      parsedItems = rawItems.map((e) {
        final map = e as Map<String, dynamic>;
        return MealIngredientEntity(
          name: map['name'] as String? ?? 'Food Item',
          amount: toDouble(map['amount']),
          unit: map['unit'] as String? ?? 'g',
          calories: toInt(map['calories']),
          protein: toInt(map['protein']),
          carbs: toInt(map['carbs']),
          fats: toInt(map['fats']),
        );
      }).toList();
    }

    return MealModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      calories: toInt(json['calories'] ?? json['totalCalories']),
      protein: toInt(json['protein']),
      carbs: toInt(json['carbs']),
      fats: toInt(json['fats']),
      type: json['type'] as String?,
      timeOfDay: json['timeOfDay']?.toString(),
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'].toString())
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      instructions: json['instructions'] as String?,
      ingredients: parsedItems,
      heroIngredient: json['heroIngredient'] as String?,
      ingredientSummary: json['ingredientSummary'] as String?,
      orderIndex: toInt(json['orderIndex']),
      dayTargetCalories: json['dayTargetCalories'] != null ? toInt(json['dayTargetCalories']) : null,
      dayTargetProtein: json['dayTargetProtein'] != null ? toInt(json['dayTargetProtein']) : null,
      dayTargetCarbs: json['dayTargetCarbs'] != null ? toInt(json['dayTargetCarbs']) : null,
      dayTargetFats: json['dayTargetFats'] != null ? toInt(json['dayTargetFats']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        if (scheduledDate != null)
          'scheduledDate': scheduledDate!.toIso8601String(),
        'timestamp': timestamp.toIso8601String(),
        if (instructions != null) 'instructions': instructions,
        'ingredients': ingredients?.map((e) => e.toJson()).toList(),
        'heroIngredient': heroIngredient,
        'ingredientSummary': ingredientSummary,
      };

  MealEntity toEntity() {
    return MealEntity(
      id: id,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      scheduledDate: scheduledDate,
      type: type,
      timeOfDay: timeOfDay,
      timestamp: timestamp,
      instructions: instructions,
      ingredients: ingredients,
      heroIngredient: heroIngredient,
      ingredientSummary: ingredientSummary,
      orderIndex: orderIndex,
      dayTargetCalories: dayTargetCalories,
      dayTargetProtein: dayTargetProtein,
      dayTargetCarbs: dayTargetCarbs,
      dayTargetFats: dayTargetFats,
    );
  }
}
