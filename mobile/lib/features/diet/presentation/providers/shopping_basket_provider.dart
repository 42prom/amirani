import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/monthly_plan_entity.dart' as plan_entity;
import 'diet_provider.dart';
import '../../../../core/services/diet_plan_storage_service.dart';

/// Shopping list range in days with persistence
class ShoppingRangeNotifier extends StateNotifier<int> {
  final Ref _ref;
  ShoppingRangeNotifier(this._ref) : super(3) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _ref.read(dietPlanStorageProvider).loadShoppingRange();
    if (saved != null) state = saved;
  }

  Future<void> update(int days) async {
    state = days;
    await _ref.read(dietPlanStorageProvider).saveShoppingRange(days);
  }
}

final shoppingDaysRangeProvider = StateNotifierProvider<ShoppingRangeNotifier, int>((ref) {
  return ShoppingRangeNotifier(ref);
});

/// State for checked items with persistence (Premium Flagship Quality)
class ShoppingChecksNotifier extends StateNotifier<Map<String, bool>> {
  final Ref _ref;
  ShoppingChecksNotifier(this._ref) : super({}) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _ref.read(dietPlanStorageProvider).loadShoppingChecks();
    if (saved != null) state = saved;
  }

  Future<void> toggle(String itemKey, bool value) async {
    final newState = Map<String, bool>.from(state);
    newState[itemKey] = value;
    state = newState;
    await _ref.read(dietPlanStorageProvider).saveShoppingChecks(newState);
  }

  Future<void> clear() async {
    state = {};
    await _ref.read(dietPlanStorageProvider).saveShoppingChecks({});
  }
}

final checkedShoppingItemsProvider = StateNotifierProvider<ShoppingChecksNotifier, Map<String, bool>>((ref) {
  return ShoppingChecksNotifier(ref);
});

/// Virtual Pantry with persistence
class VirtualPantryNotifier extends StateNotifier<Map<String, double>> {
  final Ref _ref;
  VirtualPantryNotifier(this._ref) : super({}) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _ref.read(dietPlanStorageProvider).loadPantry();
    if (saved != null) state = saved;
  }

  Future<void> updatePantry(Map<String, double> newPantry) async {
    state = newPantry;
    await _ref.read(dietPlanStorageProvider).savePantry(newPantry);
  }
}

final virtualPantryProvider = StateNotifierProvider<VirtualPantryNotifier, Map<String, double>>((ref) {
  return VirtualPantryNotifier(ref);
});

/// Provider to calculate days remaining in the diet plan
final dietDaysLeftProvider = Provider<Map<String, dynamic>>((ref) {
  final plan = ref.watch(generatedDietPlanProvider);
  if (plan == null) return {'left': 0, 'total': 0, 'progress': 0.0};

  final today = DateTime.now();
  final todayNormalized = DateTime(today.year, today.month, today.day);
  
  // Find start and end dates
  DateTime? startDate;
  DateTime? endDate;

  for (final week in plan.weeks) {
    for (final day in week.days) {
      if (startDate == null || day.date.isBefore(startDate)) startDate = day.date;
      if (endDate == null || day.date.isAfter(endDate)) endDate = day.date;
    }
  }

  if (startDate == null || endDate == null) return {'left': 0, 'total': 0, 'progress': 0.0};

  final totalDays = endDate.difference(startDate).inDays + 1;
  final daysPassed = todayNormalized.difference(startDate).inDays;
  final daysLeft = totalDays - daysPassed;

  return {
    'left': daysLeft < 0 ? 0 : daysLeft,
    'total': totalDays,
    'progress': (daysPassed / totalDays).clamp(0.0, 1.0),
  };
});

/// Provider to aggregate ingredients based on the selected day range,
/// subtracting what's already in the Virtual Pantry.
final aggregatedShoppingIngredientsProvider = Provider<List<plan_entity.IngredientEntity>>((ref) {
  final plan = ref.watch(generatedDietPlanProvider);
  final daysRange = ref.watch(shoppingDaysRangeProvider);
  final pantry = ref.watch(virtualPantryProvider);
  
  if (plan == null) return [];

  final List<plan_entity.IngredientEntity> allIngredients = [];
  final today = DateTime.now();
  final startDay = DateTime(today.year, today.month, today.day);
  final endDay = startDay.add(Duration(days: daysRange));

  // 1. Collect all ingredients needed for the range
  for (final week in plan.weeks) {
    for (final day in week.days) {
      final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
      if (dayDate.isAtSameMomentAs(startDay) || 
          (dayDate.isAfter(startDay) && dayDate.isBefore(endDay))) {
        for (final meal in day.meals) {
          allIngredients.addAll(meal.ingredients);
        }
      }
    }
  }

  // 2. Aggregate by name and unit (Ensure unique, case-insensitive keys)
  final Map<String, plan_entity.IngredientEntity> aggregated = {};

  for (final ing in allIngredients) {
    // Normalize key to prevent 'mark one marks all' bug due to casing mismatches
    final key = "${ing.name.trim().toLowerCase()}_${ing.unit.trim().toLowerCase()}";
    if (aggregated.containsKey(key)) {
      final existing = aggregated[key]!;
      final currentAmount = double.tryParse(existing.amount.replaceAll(',', '.')) ?? 0;
      final newAmount = double.tryParse(ing.amount.replaceAll(',', '.')) ?? 0;
      
      if (currentAmount > 0 && newAmount > 0) {
        aggregated[key] = existing.copyWith(
          amount: (currentAmount + newAmount).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
        );
      } else if (existing.amount != ing.amount) {
         // Different non-numeric units? Rare but handled
        aggregated[key] = existing.copyWith(
          amount: "${existing.amount} + ${ing.amount}",
        );
      }
    } else {
      aggregated[key] = ing.copyWith(
        name: ing.name.trim(),
        unit: ing.unit.trim(),
      );
    }
  }

  // 3. Subtract Virtual Pantry inventory
  final List<plan_entity.IngredientEntity> result = [];
  
  for (final ing in aggregated.values) {
    final pantryQty = pantry[ing.name.toLowerCase()] ?? 0.0;
    final neededQty = double.tryParse(ing.amount) ?? 0.0;

    if (pantryQty >= neededQty && neededQty > 0) {
      // Fully covered by pantry - we can still show it as "In Stock" or skip it
      // Let's keep it but mark it with 0 amount needed to buy
      result.add(ing.copyWith(amount: "0")); 
    } else if (pantryQty > 0) {
      // Partially covered
      final remaining = neededQty - pantryQty;
      result.add(ing.copyWith(
        amount: remaining.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
      ));
    } else {
      // Nothing in pantry
      result.add(ing);
    }
  }

  return result;
});
