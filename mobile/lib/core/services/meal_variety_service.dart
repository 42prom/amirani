import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:amirani_app/features/diet/domain/entities/monthly_plan_entity.dart';

/// Pure-Dart service that rotates meals across weeks using the
/// bundled `assets/data/meal_alternatives.json` catalogue.
///
/// Strategy: for each meal in weeks 2, 3, and 4 rotate to the next
/// alternative in its type bucket (breakfast, lunch, etc.) so users
/// see a different meal every week while keeping the same macro shape.
///
/// Independent of the workout system and the AI service.
class MealVarietyService {
  MealVarietyService();

  Map<String, List<Map<String, dynamic>>>? _catalogue;

  Future<void> init() async {
    if (_catalogue != null) return;
    final raw =
        await rootBundle.loadString('assets/data/meal_alternatives.json');
    final Map<String, dynamic> json = jsonDecode(raw);
    _catalogue = json.map(
      (key, value) => MapEntry(
        key,
        (value as List).cast<Map<String, dynamic>>(),
      ),
    );
  }

  /// Applies meal rotation to [plan], returning a new plan with varied meals
  /// in weeks 2-4. Week 1 (the AI baseline) is never modified.
  ///
  /// Call [init] before this method.
  MonthlyDietPlanEntity applyVariety(MonthlyDietPlanEntity plan) {
    if (_catalogue == null || plan.weeks.length < 2) return plan;

    final newWeeks = plan.weeks.map((week) {
      if (week.weekNumber == 1) return week;
      final offset = week.weekNumber - 1; // 1 for week2, 2 for week3 …
      final newDays = week.days.map((day) {
        final newMeals = day.meals.map((meal) {
          final alternative = _pickAlternative(meal, offset);
          return alternative ?? meal;
        }).toList();
        return day.copyWith(meals: newMeals);
      }).toList();
      return week.copyWith(days: newDays);
    }).toList();

    return plan.copyWith(weeks: newWeeks, updatedAt: DateTime.now());
  }

  PlannedMealEntity? _pickAlternative(PlannedMealEntity meal, int offset) {
    final bucket = _catalogueBucket(meal.type);
    final alternatives = _catalogue![bucket];
    if (alternatives == null || alternatives.isEmpty) return null;

    final index = offset % alternatives.length;
    final data = alternatives[index];

    // Check if the alternative name is different from current meal
    final altName = data['name']?.toString() ?? '';
    if (altName == meal.name) {
      // Try the next one
      final nextIndex = (offset + 1) % alternatives.length;
      final nextData = alternatives[nextIndex];
      return _buildMeal(meal, nextData);
    }
    return _buildMeal(meal, data);
  }

  PlannedMealEntity _buildMeal(
      PlannedMealEntity original, Map<String, dynamic> data) {
    final ingredients = (data['ingredients'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((i) => IngredientEntity(
              name: i['name'] as String? ?? '',
              amount: (i['amount'] ?? '').toString(),
              unit: i['unit'] as String? ?? '',
            ))
        .toList();

    return original.copyWith(
      name: data['name'] as String? ?? original.name,
      description: data['name'] as String? ?? original.description,
      ingredients: ingredients,
      instructions:
          data['instructions'] as String? ?? original.instructions,
      prepTimeMinutes:
          (data['prepTimeMinutes'] as num? ?? original.prepTimeMinutes).toInt(),
      isCompleted: false,
      isSwapped: false,
      isSkipped: false,
      completedAt: null,
      nutrition: NutritionInfoEntity(
        calories: (data['calories'] as num? ?? original.nutrition.calories).toInt(),
        protein: (data['protein'] as num? ?? original.nutrition.protein).toInt(),
        carbs: (data['carbs'] as num? ?? original.nutrition.carbs).toInt(),
        fats: (data['fats'] as num? ?? original.nutrition.fats).toInt(),
      ),
    );
  }

  String _catalogueBucket(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.morningSnack:
        return 'morningSnack';
      case MealType.lunch:
        return 'lunch';
      case MealType.afternoonSnack:
        return 'afternoonSnack';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }
}
