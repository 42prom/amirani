import 'package:freezed_annotation/freezed_annotation.dart';
import 'meal_ingredient_entity.dart';

part 'meal_entity.freezed.dart';

@freezed
class MealEntity with _$MealEntity {
  const factory MealEntity({
    required String id,
    required String name,
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
    DateTime? scheduledDate,
    String? type,
    String? timeOfDay,
    String? instructions,
    List<MealIngredientEntity>? ingredients,
    String? heroIngredient,
    String? ingredientSummary,
    int? orderIndex,
    String? mediaUrl,
    required DateTime timestamp,
    // P1-D: per-rotation-day macro targets (null = use plan-level average)
    int? dayTargetCalories,
    int? dayTargetProtein,
    int? dayTargetCarbs,
    int? dayTargetFats,
  }) = _MealEntity;
}
