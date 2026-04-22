import 'package:amirani_app/features/diet/domain/entities/diet_preferences_entity.dart';
import 'package:amirani_app/features/diet/domain/entities/monthly_plan_entity.dart';

/// Pure-Dart, zero-network engine that takes a single AI-generated week (week 1)
/// and expands it into a 4-week macro-cycling plan.
///
/// Macro cycling per goal:
///   weightLoss  → caloric deficit cycles: W1 moderate, W2 deeper, W3 moderate, W4 maintenance refeed
///   muscleGain  → caloric surplus cycles: W1 moderate, W2 higher, W3 moderate, W4 slight cut
///   generalHealth → mild variation (±5%) to prevent metabolic adaptation
///
/// Protein is kept constant (never reduced) to protect lean mass.
/// The engine is completely independent of the workout system and the AI service.
class DietMacroCyclingEngine {
  const DietMacroCyclingEngine();

  /// Expands [week1] into a 4-week macro-cycled plan.
  /// [baseMacro] should be the AI-generated week 1 targets.
  /// Returns a new [MonthlyDietPlanEntity] with all 4 weeks filled.
  MonthlyDietPlanEntity expandToFourWeeks(
    MonthlyDietPlanEntity basePlan,
  ) {
    if (basePlan.weeks.isEmpty) return basePlan;

    final week1 = basePlan.weeks.first;
    final base = basePlan.macroTarget;

    final multipliers = _weekMultipliers(basePlan.goal);

    final progressedWeeks = List.generate(4, (i) {
      final weekNumber = i + 1;
      final m = multipliers[i];
      final weekStart = basePlan.startDate.add(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

      // Compute this week's macro targets
      final weekCalories = (base.calories * m.caloriesFactor).round();
      final weekCarbs = (base.carbs * m.carbsFactor).round();
      final weekFats = (base.fats * m.fatsFactor).round();
      // Protein never reduced — only allow upward rounding
      final weekProtein = base.protein;

      final scaledDays = week1.days.map((day) {
        final newDate = day.date.add(Duration(days: i * 7));
        final scaledMeals = day.meals.map((meal) {
          final scaledCalories = (meal.nutrition.calories * m.caloriesFactor).round();
          final scaledCarbs = (meal.nutrition.carbs * m.carbsFactor).round();
          final scaledFats = (meal.nutrition.fats * m.fatsFactor).round();
          return meal.copyWith(
            isCompleted: false,
            isSwapped: false,
            isSkipped: false,
            completedAt: null,
            nutrition: meal.nutrition.copyWith(
              calories: scaledCalories,
              carbs: scaledCarbs,
              fats: scaledFats,
              // protein unchanged
            ),
          );
        }).toList();

        return day.copyWith(
          id: 'day_${newDate.millisecondsSinceEpoch}',
          date: newDate,
          targetCalories: weekCalories,
          targetProtein: weekProtein,
          targetCarbs: weekCarbs,
          targetFats: weekFats,
          meals: scaledMeals,
          smartBagEntries: const [],
        );
      }).toList();

      return WeeklyPlanEntity(
        weekNumber: weekNumber,
        startDate: weekStart,
        endDate: weekEnd,
        days: scaledDays,
      );
    });

    // Rebuild shopping lists to match new weeks
    final newShoppingLists = List.generate(4, (i) {
      final weekMeals = progressedWeeks[i].days.expand((d) => d.meals).toList();
      final consolidated = <String, ShoppingItemEntity>{};
      for (final meal in weekMeals) {
        for (final ingredient in meal.ingredients) {
          final key = '${ingredient.name.toLowerCase()}_${ingredient.unit.toLowerCase()}';
          if (consolidated.containsKey(key)) {
            final current = consolidated[key]!;
            consolidated[key] = current.copyWith(
              amount: _addAmounts(current.amount, ingredient.amount),
            );
          } else {
            consolidated[key] = ShoppingItemEntity(
              name: ingredient.name,
              amount: ingredient.amount,
              unit: ingredient.unit,
              category: _inferCategory(ingredient.name),
            );
          }
        }
      }
      return ShoppingListEntity(
        weekNumber: i + 1,
        items: consolidated.values.toList(),
      );
    });

    return basePlan.copyWith(
      weeks: progressedWeeks,
      shoppingLists: newShoppingLists,
      updatedAt: DateTime.now(),
    );
  }

  List<_WeekMacroMultiplier> _weekMultipliers(DietGoal goal) {
    switch (goal) {
      case DietGoal.weightLoss:
        // W1: moderate deficit (−10%), W2: deeper (−20%), W3: moderate (−10%), W4: refeed (−5%)
        return [
          _WeekMacroMultiplier(caloriesFactor: 0.90, carbsFactor: 0.85, fatsFactor: 0.92),
          _WeekMacroMultiplier(caloriesFactor: 0.80, carbsFactor: 0.75, fatsFactor: 0.83),
          _WeekMacroMultiplier(caloriesFactor: 0.90, carbsFactor: 0.85, fatsFactor: 0.92),
          _WeekMacroMultiplier(caloriesFactor: 0.95, carbsFactor: 0.95, fatsFactor: 0.95),
        ];
      case DietGoal.muscleGain:
        // W1: moderate surplus (+5%), W2: higher (+10%), W3: moderate (+5%), W4: slight cut (−5%)
        return [
          _WeekMacroMultiplier(caloriesFactor: 1.05, carbsFactor: 1.08, fatsFactor: 1.03),
          _WeekMacroMultiplier(caloriesFactor: 1.10, carbsFactor: 1.15, fatsFactor: 1.05),
          _WeekMacroMultiplier(caloriesFactor: 1.05, carbsFactor: 1.08, fatsFactor: 1.03),
          _WeekMacroMultiplier(caloriesFactor: 0.95, carbsFactor: 0.93, fatsFactor: 0.97),
        ];
      case DietGoal.generalHealth:
      case DietGoal.maintenance:
      case DietGoal.medicalDiet:
      case DietGoal.cleanEating:
      case DietGoal.performance:
        // Mild variation ±5% to prevent metabolic adaptation
        return [
          _WeekMacroMultiplier(caloriesFactor: 1.00, carbsFactor: 1.00, fatsFactor: 1.00),
          _WeekMacroMultiplier(caloriesFactor: 1.05, carbsFactor: 1.05, fatsFactor: 1.05),
          _WeekMacroMultiplier(caloriesFactor: 0.95, carbsFactor: 0.95, fatsFactor: 0.95),
          _WeekMacroMultiplier(caloriesFactor: 1.00, carbsFactor: 1.00, fatsFactor: 1.00),
        ];
    }
  }

  String _addAmounts(String a1, String a2) {
    if (a1.isEmpty) return a2;
    if (a2.isEmpty) return a1;
    final n1 = double.tryParse(a1);
    final n2 = double.tryParse(a2);
    if (n1 != null && n2 != null) {
      final sum = n1 + n2;
      return sum % 1 == 0 ? sum.toInt().toString() : sum.toStringAsFixed(1);
    }
    if (a1 == a2) return a1;
    return '$a1 + $a2';
  }

  String _inferCategory(String name) {
    final s = name.toLowerCase();
    if (s.contains('chicken') || s.contains('beef') || s.contains('steak') ||
        s.contains('turkey') || s.contains('meat') || s.contains('pork') || s.contains('lamb')) {
      return 'Meat';
    }
    if (s.contains('salmon') || s.contains('tuna') || s.contains('fish') ||
        s.contains('shrimp') || s.contains('prawn') || s.contains('cod')) {
      return 'Seafood';
    }
    if (s.contains('milk') || s.contains('cheese') || s.contains('yogurt') ||
        s.contains('butter') || s.contains('cream') || s.contains('kefir')) {
      return 'Dairy';
    }
    if (s.contains('egg')) return 'Dairy/Eggs';
    if (s.contains('apple') || s.contains('banana') || s.contains('spinach') ||
        s.contains('tomato') || s.contains('vegetable') || s.contains('fruit') ||
        s.contains('berry') || s.contains('broccoli') || s.contains('carrot') ||
        s.contains('onion')) {
      return 'Produce';
    }
    if (s.contains('bread') || s.contains('pasta') || s.contains('rice') ||
        s.contains('oat') || s.contains('flour') || s.contains('quinoa')) {
      return 'Grains';
    }
    if (s.contains('oil') || s.contains('olive') || s.contains('sauce') ||
        s.contains('salt') || s.contains('pepper') || s.contains('spice')) {
      return 'Condiments/Pantry';
    }
    return 'Other';
  }
}

class _WeekMacroMultiplier {
  final double caloriesFactor;
  final double carbsFactor;
  final double fatsFactor;
  const _WeekMacroMultiplier({
    required this.caloriesFactor,
    required this.carbsFactor,
    required this.fatsFactor,
  });
}
