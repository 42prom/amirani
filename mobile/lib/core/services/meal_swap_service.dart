import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../features/diet/domain/entities/diet_preferences_entity.dart';
import 'diet_plan_storage_service.dart';
import 'ai/meal_data.dart';
import 'ai/meal_selection_service.dart';
import 'ai/meal_nutrition_calculator.dart';

export 'ai/meal_data.dart' show MealAlternative;

/// Service for handling meal swapping functionality (Facade)
/// Orchestrates the swap process by delegating to specialized services:
/// - MealSelectionService: Logic for finding alternatives
/// - MealNutritionCalculator: Logic for macro/calorie calculations
/// - MealData: Repository for static meal maps
class MealSwapService {
  final Ref _ref;
  final MealSelectionService _selection;

  MealSwapService(this._ref) : _selection = MealSelectionService();

  /// Get alternative meals for a specific meal type and dietary style
  List<MealAlternative> getAlternatives({
    required MealType mealType,
    required DietaryStyle dietaryStyle,
    required PlannedMealEntity currentMeal,
    List<String> dislikedFoods = const [],
    List<String> likedFoods = const [],
    int? targetCalories,
    int? targetFats,
    int? targetCarbs,
    int calorieVariance = 150,
    int macroVariancePercent = 40,
    int count = 3,
  }) {
    return _selection.getAlternatives(
      mealType: mealType,
      dietaryStyle: dietaryStyle,
      currentMeal: currentMeal,
      dislikedFoods: dislikedFoods,
      likedFoods: likedFoods,
      targetCalories: targetCalories,
      targetFats: targetFats,
      targetCarbs: targetCarbs,
      calorieVariance: calorieVariance,
      macroVariancePercent: macroVariancePercent,
      count: count,
    );
  }

  /// Swap a meal in the plan and save
  Future<MonthlyDietPlanEntity?> swapMeal({
    required MonthlyDietPlanEntity plan,
    required DateTime date,
    required MealType mealType,
    required MealAlternative newMeal,
  }) async {
    final updatedWeeks = <WeeklyPlanEntity>[];

    for (final week in plan.weeks) {
      final updatedDays = <DailyPlanEntity>[];

      for (final day in week.days) {
        if (_isSameDay(day.date, date)) {
          final updatedMeals = day.meals.map((meal) {
            if (meal.type == mealType) {
              return PlannedMealEntity(
                id: meal.id,
                type: mealType,
                name: newMeal.name,
                description: newMeal.description,
                ingredients: newMeal.ingredients,
                instructions: newMeal.instructions,
                prepTimeMinutes: newMeal.prepTime,
                nutrition: NutritionInfoEntity(
                  calories: newMeal.calories,
                  protein: newMeal.protein > 0 ? newMeal.protein : MealNutritionCalculator.estimateProtein(newMeal.calories, DietaryStyle.noRestrictions),
                  carbs: newMeal.carbs > 0 ? newMeal.carbs : MealNutritionCalculator.estimateCarbs(newMeal.calories, DietaryStyle.noRestrictions),
                  fats: newMeal.fats > 0 ? newMeal.fats : MealNutritionCalculator.estimateFats(newMeal.calories, DietaryStyle.noRestrictions),
                ),
                imageUrl: newMeal.imageUrl,
                scheduledTime: meal.scheduledTime,
                isSwapped: true,
              );
            }
            return meal;
          }).toList();

          updatedDays.add(day.copyWith(meals: updatedMeals));
        } else {
          updatedDays.add(day);
        }
      }

      updatedWeeks.add(week.copyWith(days: updatedDays));
    }

    final updatedPlan = plan.copyWith(
      weeks: updatedWeeks,
      updatedAt: DateTime.now(),
    );

    final storage = _ref.read(dietPlanStorageProvider);
    await storage.savePlan(updatedPlan);

    return updatedPlan;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Provider for meal swap service
final mealSwapServiceProvider = Provider<MealSwapService>((ref) {
  return MealSwapService(ref);
});
