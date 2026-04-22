import '../../../../core/utils/app_date.dart';
import '../entities/diet_plan_entity.dart';
import '../entities/meal_entity.dart';
import '../entities/meal_ingredient_entity.dart';
import '../entities/diet_preferences_entity.dart';
import '../entities/monthly_plan_entity.dart' as monthly;

/// Maps a flat [DietPlanEntity] (from backend) into the rich
/// [MonthlyDietPlanEntity] used by the UI.
///
/// Extracted from [DietPlanEntity.toMonthlyEntity] so business logic
/// does not live inside an entity.
class DietPlanMapper {
  const DietPlanMapper();

  monthly.MonthlyDietPlanEntity toMonthlyEntity(
      DietPlanEntity plan, String userId) {
    // AppDate.localMidnight strips the time/timezone portion from the ISO
    // string so "2025-04-14T00:00:00.000Z" and DateTime.now() on the same
    // calendar day both map to DateTime(2025,4,14) — no UTC-offset math.
    final planStartDate = AppDate.localMidnight(plan.startDate ?? plan.createdAt);
    final planEndDate   = planStartDate.add(Duration(days: plan.numWeeks * 7));

    // Key: YYYY-MM-DD string — timezone-agnostic, works UTC-12 to UTC+14.
    final mealsByKey   = <String, List<MealEntity>>{};
    final undatedMeals = <MealEntity>[];

    for (final meal in plan.meals) {
      if (meal.scheduledDate != null) {
        final key = AppDate.toKey(meal.scheduledDate!);
        mealsByKey.putIfAbsent(key, () => []).add(meal);
      } else {
        undatedMeals.add(meal);
      }
    }

    if (undatedMeals.isNotEmpty && mealsByKey.isEmpty) {
      // Safety-net path: sync/down always provides scheduledDate for backend plans,
      // so this branch only fires for locally-cached stale data.
      //
      // FIX: Do NOT treat orderIndex as a day-of-week index — it may be a
      // per-day meal slot (0=breakfast, 1=lunch, 2=dinner repeating per day),
      // which would collapse all meals onto the first 3 days of the week.
      //
      // Instead: group meals by their orderIndex value (unique values = unique
      // day slots) and assign them sequential day positions within the week.
      final byOrderIndex = <int, List<MealEntity>>{};
      for (final meal in undatedMeals) {
        byOrderIndex.putIfAbsent(meal.orderIndex ?? 0, () => []).add(meal);
      }
      final orderKeys = byOrderIndex.keys.toList()..sort();
      for (int ki = 0; ki < orderKeys.length; ki++) {
        final dayIndex = ki % 7; // wrap into 0-6 for the 7-day week
        for (int w = 0; w < plan.numWeeks; w++) {
          final dayDate = planStartDate.add(Duration(days: w * 7 + dayIndex));
          final dateKey = AppDate.toKey(dayDate);
          mealsByKey.putIfAbsent(dateKey, () => []).addAll(byOrderIndex[orderKeys[ki]]!);
        }
      }
    }

    final weeks = <monthly.WeeklyPlanEntity>[];
    for (int w = 0; w < plan.numWeeks; w++) {
      final weekStart = planStartDate.add(Duration(days: w * 7));
      final weekEnd =
          weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
      final days = <monthly.DailyPlanEntity>[];

      for (int d = 0; d < 7; d++) {
        final currentDate = weekStart.add(Duration(days: d));
        final dateKey     = AppDate.toKey(currentDate);
        // Sort by chronological meal-type order (Breakfast → Morning Snack →
        // Lunch → Afternoon Snack → Dinner → Snack) so the card list always
        // renders in the expected sequence regardless of backend insertion order.
        final dailyMeals  = List<MealEntity>.from(mealsByKey[dateKey] ?? [])
          ..sort((a, b) => _mealTypeOrderIndex(a.type ?? '').compareTo(
                           _mealTypeOrderIndex(b.type ?? '')));

        // P1-D: use per-rotation-day macro targets stored on the first meal
        // that carries them, falling back to plan-level averages.
        final dayTargetMeal = dailyMeals.cast<MealEntity?>().firstWhere(
          (m) => m?.dayTargetCalories != null,
          orElse: () => null,
        );
        final targetCal = dayTargetMeal?.dayTargetCalories ?? plan.targetCalories;
        final targetPro = dayTargetMeal?.dayTargetProtein ?? plan.targetProtein;
        final targetCarb = dayTargetMeal?.dayTargetCarbs ?? plan.targetCarbs;
        final targetFat = dayTargetMeal?.dayTargetFats ?? plan.targetFats;

        days.add(monthly.DailyPlanEntity(
          id: 'day_$dateKey',
          date: AppDate.localMidnight(currentDate),
          targetCalories: targetCal,
          targetProtein: targetPro,
          targetCarbs: targetCarb,
          targetFats: targetFat,
          meals: dailyMeals
              .map((m) {
                    final mealType = _mapToPlannedMealType(m.type ?? '');

                    // ── TITLE vs. RECIPE NAME resolution ────────────────────
                    // Two plan creation paths send different values in m.name:
                    //   AI plans:      m.name = "BREAKFAST" (type keyword)
                    //                  recipe name is first line of m.instructions
                    //   Trainer plans: m.name = "Chicken Breast Salad" (recipe)
                    //                  m.type = "LUNCH" (canonical type)
                    //
                    // Desired output in every case:
                    //   PlannedMealEntity.name        = "Breakfast"   (display title)
                    //   PlannedMealEntity.description = "Oatmeal Bowl" (recipe name)
                    final bool nameIsTypeKeyword = _isTypeKeyword(m.name);

                    // Recipe name:
                    //   AI path   → first segment of "RecipeName\n\nSteps"
                    //   Trainer   → m.name itself (it IS the recipe name)
                    final String? recipeName = nameIsTypeKeyword
                        ? _extractRecipeName(m.instructions)
                        : m.name;

                    // Cooking instructions:
                    //   AI path   → everything after the first "\n\n"
                    //   Trainer   → m.instructions as-is
                    final String cookingSteps = nameIsTypeKeyword
                        ? _stripRecipePrefix(m.instructions)
                        : (m.instructions ?? "Follow trainer's instructions");

                    return monthly.PlannedMealEntity(
                      id: m.id,
                      name: _mealTypeDisplayName(mealType),  // "Breakfast"
                      type: mealType,
                      description: recipeName?.isNotEmpty == true
                          ? recipeName!
                          : _mealTypeDisplayName(mealType),
                      instructions: cookingSteps.isNotEmpty
                          ? cookingSteps
                          : "Follow trainer's instructions",
                      prepTimeMinutes: 20,
                      ingredients: _parseIngredients(m.ingredients),
                      scheduledTime: m.timeOfDay,
                      nutrition: monthly.NutritionInfoEntity(
                        calories: m.calories,
                        protein: m.protein,
                        carbs: m.carbs,
                        fats: m.fats,
                      ),
                    );
                  })
              .toList(),
        ));
      }

      weeks.add(monthly.WeeklyPlanEntity(
        weekNumber: w + 1,
        startDate: weekStart,
        endDate: weekEnd,
        days: days,
      ));
    }

    final shoppingLists = <monthly.ShoppingListEntity>[];
    for (int w = 0; w < plan.numWeeks; w++) {
      final weekMeals =
          weeks[w].days.expand((d) => d.meals).toList();
      final consolidated = <String, monthly.ShoppingItemEntity>{};
      for (final meal in weekMeals) {
        for (final ingredient in meal.ingredients) {
          final key =
              '${ingredient.name.toLowerCase()}_${ingredient.unit.toLowerCase()}';
          if (consolidated.containsKey(key)) {
            final current = consolidated[key]!;
            consolidated[key] = current.copyWith(
              amount: _addAmounts(current.amount, ingredient.amount),
            );
          } else {
            consolidated[key] = monthly.ShoppingItemEntity(
              name: ingredient.name,
              amount: ingredient.amount,
              unit: ingredient.unit,
              category: _inferCategory(ingredient.name),
            );
          }
        }
      }
      shoppingLists.add(monthly.ShoppingListEntity(
        weekNumber: w + 1,
        items: consolidated.values.toList(),
      ));
    }

    return monthly.MonthlyDietPlanEntity(
      id: plan.id,
      odUserId: userId,
      startDate: planStartDate,
      endDate: planEndDate,
      goal: plan.goal ?? _mapGoalFromName(plan.name),
      macroTarget: monthly.DailyMacroTargetEntity(
        calories: plan.targetCalories,
        protein: plan.targetProtein,
        carbs: plan.targetCarbs,
        fats: plan.targetFats,
      ),
      weeks: weeks,
      shoppingLists: shoppingLists,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  DietGoal _mapGoalFromName(String planName) {
    final name = planName.toLowerCase();
    if (name.contains('loss') || name.contains('cut')) {
      return DietGoal.weightLoss;
    }
    if (name.contains('gain') || name.contains('bulk')) {
      return DietGoal.muscleGain;
    }
    return DietGoal.generalHealth;
  }

  String _addAmounts(String a1, String a2) {
    if (a1.isEmpty) return a2;
    if (a2.isEmpty) return a1;
    final n1 = double.tryParse(a1);
    final n2 = double.tryParse(a2);
    if (n1 != null && n2 != null) {
      final sum = n1 + n2;
      return sum % 1 == 0
          ? sum.toInt().toString()
          : sum.toStringAsFixed(1);
    }
    if (a1 == a2) return a1;
    return '$a1 + $a2';
  }

  String _inferCategory(String name) {
    final s = name.toLowerCase();
    if (s.contains('chicken') || s.contains('beef') || s.contains('steak') ||
        s.contains('turkey') || s.contains('meat') || s.contains('pork') ||
        s.contains('lamb')) {
      return 'Meat';
    }
    if (s.contains('salmon') || s.contains('tuna') || s.contains('fish') ||
        s.contains('shrimp') || s.contains('prawn') || s.contains('cod')) {
      return 'Seafood';
    }
    if (s.contains('milk') || s.contains('cheese') || s.contains('yogurt') ||
        s.contains('butter') || s.contains('cream') || s.contains('kefir') ||
        s.contains('curd')) {
      return 'Dairy';
    }
    if (s.contains('egg')) { return 'Dairy/Eggs'; }
    if (s.contains('apple') || s.contains('banana') || s.contains('spinach') ||
        s.contains('tomato') || s.contains('vegetable') ||
        s.contains('fruit') || s.contains('berry') || s.contains('peach') ||
        s.contains('broccoli') || s.contains('carrot') ||
        s.contains('onion')) {
      return 'Produce';
    }
    if (s.contains('bread') || s.contains('pasta') || s.contains('rice') ||
        s.contains('cereal') || s.contains('oat') || s.contains('flour') ||
        s.contains('quinoa')) {
      return 'Grains';
    }
    if (s.contains('oil') || s.contains('olive') || s.contains('sauce') ||
        s.contains('salt') || s.contains('pepper') || s.contains('spice')) {
      return 'Condiments/Pantry';
    }
    return 'Other';
  }

  List<monthly.IngredientEntity> _parseIngredients(dynamic items) {
    if (items == null) return [];
    final List<dynamic> ingredientList;
    if (items is List) {
      ingredientList = items;
    } else if (items is Map<String, dynamic>) {
      ingredientList = (items['ingredients'] ?? []) as List<dynamic>;
    } else {
      return [];
    }

    return ingredientList.map((i) {
      final Map<String, dynamic> data;
      if (i is MealIngredientEntity) {
        data = {
          'name': i.name,
          'amount': i.amount.toString(),
          'unit': i.unit,
          'calories': i.calories,
          'protein': i.protein,
          'carbs': i.carbs,
          'fats': i.fats,
        };
      } else if (i is Map<String, dynamic>) {
        data = i;
      } else {
        data = {'name': i.toString(), 'amount': '', 'unit': ''};
      }

      return monthly.IngredientEntity(
        name: (data['name'] ?? 'Unknown Ingredient').toString(),
        amount: (data['amount'] ?? '').toString(),
        unit: data['unit']?.toString() ??
            (data['grams'] != null || data['weight'] != null ? 'g' : ''),
        calories: (data['calories'] as num? ?? 0).toInt(),
        protein: (data['protein'] as num? ?? 0).toInt(),
        carbs: (data['carbs'] as num? ?? 0).toInt(),
        fats: (data['fats'] as num? ?? 0).toInt(),
      );
    }).toList();
  }

  int _mealTypeOrderIndex(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':        return 0;
      case 'morning snack':
      case 'morning_snack':
      case 'morningsnack':
      case 'snack 1':          return 1;
      case 'lunch':            return 2;
      case 'afternoon snack':
      case 'afternoon_snack':
      case 'afternoonsnack':
      case 'snack 2':          return 3;
      case 'dinner':           return 4;
      default:                 return 5;
    }
  }

  monthly.MealType _mapToPlannedMealType(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return monthly.MealType.breakfast;
      case 'morning snack':
      case 'morning_snack':
      case 'morningsnack':
      case 'snack 1': // AI prompt uses "SNACK 1" for 5-meal plans
        return monthly.MealType.morningSnack;
      case 'lunch':
        return monthly.MealType.lunch;
      case 'afternoon snack':
      case 'afternoon_snack':
      case 'afternoonsnack':
      case 'snack 2': // AI prompt uses "SNACK 2" for 5-meal plans
        return monthly.MealType.afternoonSnack;
      case 'dinner':
        return monthly.MealType.dinner;
      default:
        return monthly.MealType.snack;
    }
  }

  /// Returns true when [name] is a canonical meal-type keyword (AI path).
  /// Returns false when [name] is a recipe title (trainer path).
  static const _typeKeywords = {
    'breakfast', 'lunch', 'dinner', 'snack',
    'snack 1', 'snack 2', 'morning snack', 'afternoon snack',
    'morning_snack', 'afternoon_snack', 'morningsnack', 'afternoonsnack',
  };

  bool _isTypeKeyword(String name) =>
      _typeKeywords.contains(name.toLowerCase().trim());

  /// Friendly display title for a meal type, used as the meal card header.
  String _mealTypeDisplayName(monthly.MealType type) {
    switch (type) {
      case monthly.MealType.breakfast:
        return 'Breakfast';
      case monthly.MealType.morningSnack:
        return 'Morning Snack';
      case monthly.MealType.lunch:
        return 'Lunch';
      case monthly.MealType.afternoonSnack:
        return 'Afternoon Snack';
      case monthly.MealType.dinner:
        return 'Dinner';
      case monthly.MealType.snack:
        return 'Snack';
    }
  }

  /// AI plan instructions are stored as "Recipe Name\n\nCooking steps…".
  /// This extracts the recipe name (first segment before the blank line).
  /// Returns null if the format is not present.
  String? _extractRecipeName(String? instructions) {
    if (instructions == null || instructions.isEmpty) return null;
    final idx = instructions.indexOf('\n\n');
    if (idx <= 0) return null;
    final name = instructions.substring(0, idx).trim();
    // Guard: only return if it looks like a recipe name (not a full sentence)
    return name.length <= 80 ? name : null;
  }

  /// Returns the cooking steps portion of AI-formatted instructions
  /// (everything after the first blank line), or the full string if
  /// no blank line separator is found.
  String _stripRecipePrefix(String? instructions) {
    if (instructions == null || instructions.isEmpty) return '';
    final idx = instructions.indexOf('\n\n');
    if (idx < 0) return instructions;
    return instructions.substring(idx + 2).trim();
  }
}
