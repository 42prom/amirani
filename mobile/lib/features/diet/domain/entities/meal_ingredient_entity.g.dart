// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_ingredient_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MealIngredientEntityImpl _$$MealIngredientEntityImplFromJson(
        Map<String, dynamic> json) =>
    _$MealIngredientEntityImpl(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
      calories: (json['calories'] as num).toInt(),
      protein: (json['protein'] as num).toInt(),
      carbs: (json['carbs'] as num).toInt(),
      fats: (json['fats'] as num).toInt(),
    );

Map<String, dynamic> _$$MealIngredientEntityImplToJson(
        _$MealIngredientEntityImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'amount': instance.amount,
      'unit': instance.unit,
      'calories': instance.calories,
      'protein': instance.protein,
      'carbs': instance.carbs,
      'fats': instance.fats,
    };
