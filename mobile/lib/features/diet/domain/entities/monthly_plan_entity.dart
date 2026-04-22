import 'package:freezed_annotation/freezed_annotation.dart';
import 'diet_preferences_entity.dart';

part 'monthly_plan_entity.freezed.dart';

/// Meal type enum
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  morningSnack,
  afternoonSnack,
}

/// Single ingredient in a meal
@freezed
class IngredientEntity with _$IngredientEntity {
  const factory IngredientEntity({
    required String name,
    // Canonical identifier for shopping-list deduplication.
    // e.g. "chicken_breast_raw" so "Diced Chicken" and "Grilled Chicken"
    // collapse into a single shopping list line item.
    String? canonicalName,
    required String amount,
    required String unit,
    // Non-optional with safe defaults so the shopping list never shows blank.
    @Default(0) int calories,
    @Default(0) int protein,
    @Default(0) int carbs,
    @Default(0) int fats,
  }) = _IngredientEntity;
}

/// Nutrition information
@freezed
class NutritionInfoEntity with _$NutritionInfoEntity {
  const factory NutritionInfoEntity({
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
    int? fiber,
    int? sugar,
    int? sodium,
  }) = _NutritionInfoEntity;
}

/// A single planned meal
@freezed
class PlannedMealEntity with _$PlannedMealEntity {
  const factory PlannedMealEntity({
    required String id,
    required MealType type,
    required String name,
    required String description,
    required List<IngredientEntity> ingredients,
    required String instructions,
    required int prepTimeMinutes,
    required NutritionInfoEntity nutrition,
    String? imageUrl,
    String? scheduledTime, // "08:00" for reminders
    String? heroIngredient,
    String? ingredientSummary,
    @Default(false) bool isCompleted,
    @Default(false) bool isSwapped,
    @Default(false) bool isSkipped,
    DateTime? completedAt,
  }) = _PlannedMealEntity;
}

@freezed
class SmartBagEntryEntity with _$SmartBagEntryEntity {
  const factory SmartBagEntryEntity({
    required String name,
    required double qty,
  }) = _SmartBagEntryEntity;
}

/// A single day's plan
@freezed
class DailyPlanEntity with _$DailyPlanEntity {
  const factory DailyPlanEntity({
    required String id,
    required DateTime date,
    required List<PlannedMealEntity> meals,
    required int targetCalories,
    required int targetProtein,
    required int targetCarbs,
    required int targetFats,
    @Default([]) List<SmartBagEntryEntity> smartBagEntries,
  }) = _DailyPlanEntity;

  const DailyPlanEntity._();

  int get totalPlannedCalories =>
      meals.fold(0, (sum, m) => sum + m.nutrition.calories);

  int get completedCalories => meals
      .where((m) => m.isCompleted)
      .fold(0, (sum, m) => sum + m.nutrition.calories);

  int get completedMeals => meals.where((m) => m.isCompleted).length;

  double get completionProgress =>
      meals.isEmpty ? 0 : completedMeals / meals.length;
}

/// A week's plan
@freezed
class WeeklyPlanEntity with _$WeeklyPlanEntity {
  const factory WeeklyPlanEntity({
    required int weekNumber,
    required DateTime startDate,
    required DateTime endDate,
    required List<DailyPlanEntity> days,
  }) = _WeeklyPlanEntity;

  const WeeklyPlanEntity._();

  double get completionProgress {
    if (days.isEmpty) return 0;
    return days.fold(0.0, (sum, d) => sum + d.completionProgress) / days.length;
  }
}

/// Shopping list item
@freezed
class ShoppingItemEntity with _$ShoppingItemEntity {
  const factory ShoppingItemEntity({
    required String name,
    required String amount,
    required String unit,
    required String category, // "Produce", "Dairy", "Meat", etc.
    @Default(false) bool isPurchased,
  }) = _ShoppingItemEntity;
}

/// Weekly shopping list
@freezed
class ShoppingListEntity with _$ShoppingListEntity {
  const factory ShoppingListEntity({
    required int weekNumber,
    required List<ShoppingItemEntity> items,
  }) = _ShoppingListEntity;

  const ShoppingListEntity._();

  int get purchasedCount => items.where((i) => i.isPurchased).length;
  double get progress => items.isEmpty ? 0 : purchasedCount / items.length;
}

/// Daily macro targets
@freezed
class DailyMacroTargetEntity with _$DailyMacroTargetEntity {
  const factory DailyMacroTargetEntity({
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
  }) = _DailyMacroTargetEntity;
}

/// The complete monthly diet plan
@freezed
class MonthlyDietPlanEntity with _$MonthlyDietPlanEntity {
  const factory MonthlyDietPlanEntity({
    required String id,
    required String odUserId,
    required DateTime startDate,
    required DateTime endDate,
    required DietGoal goal,
    required DailyMacroTargetEntity macroTarget,
    required List<WeeklyPlanEntity> weeks,
    required List<ShoppingListEntity> shoppingLists,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _MonthlyDietPlanEntity;

  const MonthlyDietPlanEntity._();

  /// Get the plan for a specific date
  DailyPlanEntity? getDayPlan(DateTime date) {
    for (final week in weeks) {
      for (final day in week.days) {
        if (day.date.year == date.year &&
            day.date.month == date.month &&
            day.date.day == date.day) {
          return day;
        }
      }
    }
    return null;
  }

  /// Get current week number (1-4)
  int getCurrentWeek(DateTime now) {
    final daysSinceStart = now.difference(startDate).inDays;
    return (daysSinceStart ~/ 7) + 1;
  }

  /// Overall completion progress
  double get overallProgress {
    if (weeks.isEmpty) return 0;
    return weeks.fold(0.0, (sum, w) => sum + w.completionProgress) /
        weeks.length;
  }
}
