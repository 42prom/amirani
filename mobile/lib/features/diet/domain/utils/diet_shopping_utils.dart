import '../entities/monthly_plan_entity.dart';

/// Builds one [ShoppingListEntity] per week by aggregating all ingredients
/// from every meal in that week, deduplicating by (name, unit).
List<ShoppingListEntity> buildShoppingLists(List<WeeklyPlanEntity> weeks) {
  return weeks.map((week) {
    // Aggregate: key = "name|unit"
    final Map<String, _AggItem> agg = {};

    for (final day in week.days) {
      for (final meal in day.meals) {
        for (final ing in meal.ingredients) {
          // W3b: Use canonicalName for deduplication when available.
          // e.g. "Diced Chicken Breast" and "Grilled Chicken Breast" both have
          // canonicalName = "chicken_breast_raw" → merge into one line item.
          // Fall back to lowercased display name when canonicalName is absent.
          final dedupKey = ing.canonicalName != null
              ? '${ing.canonicalName}|${ing.unit.toLowerCase()}'
              : '${ing.name.toLowerCase()}|${ing.unit.toLowerCase()}';
          final qty = _parseAmount(ing.amount);
          if (agg.containsKey(dedupKey)) {
            agg[dedupKey]!.qty += qty;
          } else {
            agg[dedupKey] = _AggItem(
              name: _toTitleCase(ing.name),
              qty: qty,
              unit: ing.unit,
              category: _categorise(ing.canonicalName ?? ing.name),
            );
          }
        }
      }
    }

    final items = agg.values.map((a) {
      final amountStr = a.qty == a.qty.roundToDouble()
          ? a.qty.round().toString()
          : a.qty.toStringAsFixed(1);
      return ShoppingItemEntity(
        name: a.name,
        amount: amountStr,
        unit: a.unit,
        category: a.category,
      );
    }).toList()
      ..sort((x, y) => x.category.compareTo(y.category));

    return ShoppingListEntity(weekNumber: week.weekNumber, items: items);
  }).toList();
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _AggItem {
  final String name;
  double qty;
  final String unit;
  final String category;
  _AggItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.category,
  });
}

double _parseAmount(String raw) {
  final trimmed = raw.trim();
  // Handle fractions like "1/2", "1/4"
  if (trimmed.contains('/')) {
    final parts = trimmed.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0].trim()) ?? 1;
      final den = double.tryParse(parts[1].trim()) ?? 1;
      return den == 0 ? 1 : num / den;
    }
  }
  return double.tryParse(trimmed) ?? 1;
}

String _toTitleCase(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1).toLowerCase();
}

String _categorise(String name) {
  final n = name.toLowerCase();

  const produce = [
    'tomato', 'onion', 'garlic', 'spinach', 'lettuce', 'carrot', 'broccoli',
    'pepper', 'cucumber', 'zucchini', 'mushroom', 'avocado', 'lemon', 'lime',
    'apple', 'banana', 'berry', 'berries', 'mango', 'orange', 'potato',
    'sweet potato', 'kale', 'celery', 'ginger', 'herb', 'basil', 'parsley',
    'cilantro', 'mint', 'arugula', 'asparagus', 'eggplant', 'corn',
  ];
  const dairy = [
    'milk', 'cheese', 'yogurt', 'butter', 'cream', 'egg', 'eggs',
    'whey', 'cottage cheese', 'mozzarella', 'parmesan', 'feta',
  ];
  const protein = [
    'chicken', 'beef', 'salmon', 'tuna', 'turkey', 'shrimp', 'pork',
    'lamb', 'fish', 'tofu', 'tempeh', 'lentil', 'bean', 'chickpea',
    'edamame', 'steak', 'ground', 'cod', 'tilapia',
  ];
  const grains = [
    'rice', 'oat', 'bread', 'pasta', 'quinoa', 'barley', 'flour',
    'tortilla', 'wrap', 'noodle', 'cereal', 'cracker', 'granola',
  ];
  const pantry = [
    'oil', 'vinegar', 'sauce', 'salt', 'pepper', 'spice', 'seasoning',
    'honey', 'syrup', 'sugar', 'soy', 'mustard', 'ketchup', 'mayo',
    'almond', 'walnut', 'cashew', 'peanut', 'seed', 'nut', 'cocoa',
    'protein powder', 'supplement',
  ];

  for (final kw in produce) {
    if (n.contains(kw)) return 'Produce';
  }
  for (final kw in dairy) {
    if (n.contains(kw)) return 'Dairy & Eggs';
  }
  for (final kw in protein) {
    if (n.contains(kw)) return 'Meat & Protein';
  }
  for (final kw in grains) {
    if (n.contains(kw)) return 'Grains & Bakery';
  }
  for (final kw in pantry) {
    if (n.contains(kw)) return 'Pantry';
  }
  return 'Other';
}
