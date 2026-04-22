import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal_ingredient_entity.freezed.dart';
part 'meal_ingredient_entity.g.dart';

@freezed
class MealIngredientEntity with _$MealIngredientEntity {
  const factory MealIngredientEntity({
    required String name,
    required double amount,
    required String unit,
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
  }) = _MealIngredientEntity;

  factory MealIngredientEntity.fromJson(Map<String, dynamic> json) =>
      _$MealIngredientEntityFromJson(json);
}
