import '../../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../../features/diet/domain/entities/diet_preferences_entity.dart';
import 'meal_data.dart';

class MealNutritionCalculator {
  static int estimateProtein(int calories, DietaryStyle style) {
    final pct = MealData.macroRatios[style]?[0] ?? 0.25;
    return (calories * pct / 4).round();
  }

  static int estimateCarbs(int calories, DietaryStyle style) {
    final pct = MealData.macroRatios[style]?[1] ?? 0.45;
    return (calories * pct / 4).round();
  }

  static int estimateFats(int calories, DietaryStyle style) {
    final pct = MealData.macroRatios[style]?[2] ?? 0.30;
    return (calories * pct / 9).round();
  }

  static int calculateCalories(List ingredients) {
    int total = 0;
    for (final ing in ingredients) {
      if (ing is IngredientEntity) {
        total += ing.calories;
      }
    }
    return total > 0 ? total : 450;
  }

  static double calculateCalorieMatchScore(int actual, int target) {
    final diff = (actual - target).abs();
    if (diff == 0) return 1.0;
    if (diff <= 50) return 0.95;
    if (diff <= 100) return 0.85;
    if (diff <= 150) return 0.70;
    if (diff <= 200) return 0.50;
    return 0.30;
  }
}
