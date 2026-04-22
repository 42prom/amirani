import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../features/diet/domain/entities/diet_preferences_entity.dart';
import 'diet_plan_storage_service.dart';

/// Service for handling meal swapping functionality
/// Generates alternatives and updates the plan without breaking other days
class MealSwapService {
  final Ref _ref;

  MealSwapService(this._ref);

  // ─── Dietary-style macro ratios ───────────────────────────────────────────
  // [proteinPct, carbsPct, fatPct] as fractions of total calories
  static const Map<DietaryStyle, List<double>> _macroRatios = {
    DietaryStyle.keto:          [0.25, 0.05, 0.70],
    DietaryStyle.vegan:         [0.15, 0.60, 0.25],
    DietaryStyle.vegetarian:    [0.20, 0.50, 0.30],
    DietaryStyle.pescatarian:   [0.30, 0.40, 0.30],
    DietaryStyle.mediterranean: [0.25, 0.45, 0.30],
    DietaryStyle.halal:         [0.25, 0.45, 0.30],
    DietaryStyle.kosher:        [0.25, 0.45, 0.30],
    DietaryStyle.noRestrictions:[0.25, 0.45, 0.30],
  };

  int _estimateProtein(int calories, DietaryStyle style) {
    final pct = _macroRatios[style]?[0] ?? 0.25;
    return (calories * pct / 4).round();
  }

  int _estimateCarbs(int calories, DietaryStyle style) {
    final pct = _macroRatios[style]?[1] ?? 0.45;
    return (calories * pct / 4).round();
  }

  int _estimateFats(int calories, DietaryStyle style) {
    final pct = _macroRatios[style]?[2] ?? 0.30;
    return (calories * pct / 9).round();
  }

  /// Get alternative meals for a specific meal type and dietary style
  /// Filters disliked foods, prioritizes liked foods, and matches calories + macros
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
    final alternatives = <MealAlternative>[];
    final mealOptions = _getMealOptionsForStyle(mealType, dietaryStyle);

    // Filter out current meal AND meals containing disliked ingredients
    var filtered = mealOptions.where((m) {
      // Exclude current meal
      if (m['name'] == currentMeal.name) return false;

      // Exclude meals with disliked ingredients
      final ingredients = m['ingredients'] as List<IngredientEntity>;
      for (final ingredient in ingredients) {
        for (final disliked in dislikedFoods) {
          final ingName = ingredient.name.toLowerCase();
          final dislikedLower = disliked.toLowerCase();
          if (ingName.contains(dislikedLower) || dislikedLower.contains(ingName)) {
            return false; // Meal contains disliked food
          }
        }
      }

      return true;
    }).toList();

    // Sort by preference score (liked foods first)
    if (likedFoods.isNotEmpty) {
      filtered.sort((a, b) {
        final aScore = _calculatePreferenceScore(a, likedFoods);
        final bScore = _calculatePreferenceScore(b, likedFoods);
        return bScore.compareTo(aScore);
      });
    }

    // Filter by calorie proximity
    if (targetCalories != null && targetCalories > 0) {
      filtered = filtered.where((m) {
        final cal = _calculateCalories(m['ingredients'] as List);
        return (cal - targetCalories).abs() <= calorieVariance;
      }).toList();

      // Sort by calorie proximity
      filtered.sort((a, b) {
        final aCal = _calculateCalories(a['ingredients'] as List);
        final bCal = _calculateCalories(b['ingredients'] as List);
        final aDiff = (aCal - targetCalories).abs();
        final bDiff = (bCal - targetCalories).abs();
        return aDiff.compareTo(bDiff);
      });
    }

    // Filter by fats proximity
    if (targetFats != null && targetFats > 0) {
      final fatsVariance = ((targetFats * macroVariancePercent) / 100).round().clamp(5, 30);
      filtered = filtered.where((m) {
        final cal = _calculateCalories(m['ingredients'] as List);
        final fats = _estimateFats(cal, dietaryStyle);
        return (fats - targetFats).abs() <= fatsVariance;
      }).toList();
    }

    // Filter by carbs proximity
    if (targetCarbs != null && targetCarbs > 0) {
      final carbsVariance = ((targetCarbs * macroVariancePercent) / 100).round().clamp(10, 60);
      filtered = filtered.where((m) {
        final cal = _calculateCalories(m['ingredients'] as List);
        final carbs = _estimateCarbs(cal, dietaryStyle);
        return (carbs - targetCarbs).abs() <= carbsVariance;
      }).toList();
    }

    // If macro filtering was too strict and removed all options, relax and use calorie-only results
    if (filtered.isEmpty && targetCalories != null && targetCalories > 0) {
      filtered = mealOptions.where((m) {
        if (m['name'] == currentMeal.name) return false;
        final cal = _calculateCalories(m['ingredients'] as List);
        return (cal - targetCalories).abs() <= calorieVariance * 2;
      }).toList();
    }

    for (int i = 0; i < count && i < filtered.length; i++) {
      final option = filtered[i];
      final calories = _calculateCalories(option['ingredients'] as List);
      final protein = _estimateProtein(calories, dietaryStyle);
      final fats = _estimateFats(calories, dietaryStyle);
      final carbs = _estimateCarbs(calories, dietaryStyle);
      alternatives.add(MealAlternative(
        name: option['name'] as String,
        description: option['description'] as String,
        calories: calories,
        protein: protein,
        fats: fats,
        carbs: carbs,
        imageUrl: option['imageUrl'] as String,
        ingredients: option['ingredients'] as List<IngredientEntity>,
        instructions: option['instructions'] as String,
        prepTime: option['prepTime'] as int,
        calorieMatch: targetCalories != null && targetCalories > 0
            ? _calculateCalorieMatchScore(calories, targetCalories)
            : 1.0,
      ));
    }

    return alternatives;
  }

  /// Calculate preference score based on liked ingredients
  int _calculatePreferenceScore(Map<String, dynamic> meal, List<String> likedFoods) {
    if (likedFoods.isEmpty) return 0;

    final ingredients = meal['ingredients'] as List<IngredientEntity>;
    int score = 0;

    for (final ingredient in ingredients) {
      for (final liked in likedFoods) {
        final ingName = ingredient.name.toLowerCase();
        final likedLower = liked.toLowerCase();
        if (ingName.contains(likedLower) || likedLower.contains(ingName)) {
          score += 10; // Boost for liked ingredients
        }
      }
    }

    return score;
  }

  /// Calculate calorie match score (0.0 to 1.0)
  double _calculateCalorieMatchScore(int actual, int target) {
    final diff = (actual - target).abs();
    if (diff == 0) return 1.0;
    if (diff <= 50) return 0.95;
    if (diff <= 100) return 0.85;
    if (diff <= 150) return 0.70;
    if (diff <= 200) return 0.50;
    return 0.30;
  }

  /// Swap a meal in the plan and save
  Future<MonthlyDietPlanEntity?> swapMeal({
    required MonthlyDietPlanEntity plan,
    required DateTime date,
    required MealType mealType,
    required MealAlternative newMeal,
  }) async {
    // Find the day in the plan
    final updatedWeeks = <WeeklyPlanEntity>[];

    for (final week in plan.weeks) {
      final updatedDays = <DailyPlanEntity>[];

      for (final day in week.days) {
        if (_isSameDay(day.date, date)) {
          // This is the day to update
          final updatedMeals = day.meals.map((meal) {
            if (meal.type == mealType) {
              // Swap this meal
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
                  protein: newMeal.protein > 0 ? newMeal.protein : _estimateProtein(newMeal.calories, DietaryStyle.noRestrictions),
                  carbs: newMeal.carbs > 0 ? newMeal.carbs : _estimateCarbs(newMeal.calories, DietaryStyle.noRestrictions),
                  fats: newMeal.fats > 0 ? newMeal.fats : _estimateFats(newMeal.calories, DietaryStyle.noRestrictions),
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

    // Save to local storage
    final storage = _ref.read(dietPlanStorageProvider);
    await storage.savePlan(updatedPlan);

    return updatedPlan;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _calculateCalories(List ingredients) {
    int total = 0;
    for (final ing in ingredients) {
      if (ing is IngredientEntity) {
        total += ing.calories; // W4: calories is now @Default(0) int — always safe
      }
    }
    return total > 0 ? total : 450; // Default if no calories
  }


  /// Get meal options based on dietary style
  List<Map<String, dynamic>> _getMealOptionsForStyle(MealType type, DietaryStyle style) {
    switch (style) {
      case DietaryStyle.vegan:
        return _veganMeals[type] ?? [];
      case DietaryStyle.vegetarian:
        return _vegetarianMeals[type] ?? [];
      case DietaryStyle.pescatarian:
        return _pescatarianMeals[type] ?? [];
      case DietaryStyle.keto:
        return _ketoMeals[type] ?? [];
      case DietaryStyle.mediterranean:
        return _mediterraneanMeals[type] ?? [];
      case DietaryStyle.halal:
        return _halalMeals[type] ?? [];
      case DietaryStyle.kosher:
        return _kosherMeals[type] ?? [];
      case DietaryStyle.noRestrictions:
        return _standardMeals[type] ?? [];
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MEAL OPTIONS BY DIETARY STYLE
  // ════════════════════════════════════════════════════════════════════════════

  static final Map<MealType, List<Map<String, dynamic>>> _veganMeals = {
    MealType.breakfast: [
      {
        'name': 'Oatmeal with Banana',
        'description': 'Warm oatmeal topped with banana',
        'ingredients': [
          const IngredientEntity(name: 'Oatmeal', amount: '80', unit: 'g', calories: 300),
          const IngredientEntity(name: 'Banana', amount: '1', unit: 'medium', calories: 105),
          const IngredientEntity(name: 'Maple Syrup', amount: '1', unit: 'tbsp', calories: 52),
        ],
        'instructions': 'Cook oatmeal, slice banana, drizzle maple syrup',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1495214783159-3503fd1b572d?w=400', // Oatmeal bowl
      },
      {
        'name': 'Smoothie Bowl',
        'description': 'Frozen fruit blend with granola',
        'ingredients': [
          const IngredientEntity(name: 'Frozen Berries', amount: '200', unit: 'g', calories: 100),
          const IngredientEntity(name: 'Banana', amount: '1', unit: 'medium', calories: 105),
          const IngredientEntity(name: 'Granola', amount: '40', unit: 'g', calories: 180),
        ],
        'instructions': 'Blend fruits, top with granola',
        'prepTime': 8,
        'imageUrl': 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=400', // Smoothie bowl
      },
      {
        'name': 'Avocado Toast',
        'description': 'Whole grain toast with avocado',
        'ingredients': [
          const IngredientEntity(name: 'Bread', amount: '2', unit: 'slices', calories: 160),
          const IngredientEntity(name: 'Avocado', amount: '1/2', unit: 'medium', calories: 120),
          const IngredientEntity(name: 'Cherry Tomatoes', amount: '50', unit: 'g', calories: 15),
        ],
        'instructions': 'Toast bread, mash avocado, add tomatoes',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1588137378633-dea1336ce1e2?w=400', // Avocado toast
      },
      {
        'name': 'Chia Pudding',
        'description': 'Overnight chia with fruit',
        'ingredients': [
          const IngredientEntity(name: 'Chia Seeds', amount: '40', unit: 'g', calories: 195),
          const IngredientEntity(name: 'Almond Milk', amount: '200', unit: 'ml', calories: 30),
          const IngredientEntity(name: 'Berries', amount: '100', unit: 'g', calories: 50),
        ],
        'instructions': 'Mix chia with milk overnight, top with berries',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=400', // Chia pudding
      },
    ],
    MealType.lunch: [
      {
        'name': 'Buddha Bowl',
        'description': 'Quinoa with roasted vegetables',
        'ingredients': [
          const IngredientEntity(name: 'Quinoa', amount: '150', unit: 'g', calories: 180),
          const IngredientEntity(name: 'Chickpeas', amount: '100', unit: 'g', calories: 164),
          const IngredientEntity(name: 'Roasted Veggies', amount: '150', unit: 'g', calories: 80),
        ],
        'instructions': 'Cook quinoa, roast vegetables, combine',
        'prepTime': 25,
        'imageUrl': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
      },
      {
        'name': 'Lentil Soup',
        'description': 'Hearty red lentil soup',
        'ingredients': [
          const IngredientEntity(name: 'Red Lentils', amount: '100', unit: 'g', calories: 116),
          const IngredientEntity(name: 'Carrots', amount: '100', unit: 'g', calories: 41),
          const IngredientEntity(name: 'Crusty Bread', amount: '60', unit: 'g', calories: 160),
        ],
        'instructions': 'Simmer lentils with vegetables, serve with bread',
        'prepTime': 30,
        'imageUrl': 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=400',
      },
      {
        'name': 'Falafel Wrap',
        'description': 'Crispy falafel in pita',
        'ingredients': [
          const IngredientEntity(name: 'Falafel', amount: '4', unit: 'pieces', calories: 220),
          const IngredientEntity(name: 'Pita Bread', amount: '1', unit: 'large', calories: 165),
          const IngredientEntity(name: 'Hummus', amount: '50', unit: 'g', calories: 83),
        ],
        'instructions': 'Warm falafel, fill pita with hummus and veggies',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1593001874117-c99c800e3eb6?w=400',
      },
      {
        'name': 'Pasta Primavera',
        'description': 'Pasta with fresh vegetables',
        'ingredients': [
          const IngredientEntity(name: 'Pasta', amount: '100', unit: 'g', calories: 174),
          const IngredientEntity(name: 'Mixed Vegetables', amount: '150', unit: 'g', calories: 50),
          const IngredientEntity(name: 'Tomato Sauce', amount: '100', unit: 'g', calories: 30),
        ],
        'instructions': 'Cook pasta, sauté vegetables, combine with sauce',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=400',
      },
    ],
    MealType.dinner: [
      {
        'name': 'Tofu Stir Fry',
        'description': 'Crispy tofu with rice',
        'ingredients': [
          const IngredientEntity(name: 'Tofu', amount: '150', unit: 'g', calories: 130),
          const IngredientEntity(name: 'Mixed Vegetables', amount: '150', unit: 'g', calories: 50),
          const IngredientEntity(name: 'Brown Rice', amount: '150', unit: 'g', calories: 165),
        ],
        'instructions': 'Press tofu, stir fry with vegetables, serve with rice',
        'prepTime': 30,
        'imageUrl': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
      },
      {
        'name': 'Bean Burrito Bowl',
        'description': 'Mexican style rice bowl',
        'ingredients': [
          const IngredientEntity(name: 'Black Beans', amount: '150', unit: 'g', calories: 132),
          const IngredientEntity(name: 'Brown Rice', amount: '150', unit: 'g', calories: 165),
          const IngredientEntity(name: 'Salsa', amount: '60', unit: 'g', calories: 20),
        ],
        'instructions': 'Warm beans and rice, top with salsa and corn',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?w=400',
      },
      {
        'name': 'Vegetable Curry',
        'description': 'Coconut curry with rice',
        'ingredients': [
          const IngredientEntity(name: 'Chickpeas', amount: '100', unit: 'g', calories: 164),
          const IngredientEntity(name: 'Coconut Milk', amount: '100', unit: 'ml', calories: 50),
          const IngredientEntity(name: 'Basmati Rice', amount: '150', unit: 'g', calories: 195),
        ],
        'instructions': 'Simmer vegetables in curry sauce, serve with rice',
        'prepTime': 35,
        'imageUrl': 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=400',
      },
      {
        'name': 'Stuffed Peppers',
        'description': 'Peppers filled with quinoa',
        'ingredients': [
          const IngredientEntity(name: 'Bell Peppers', amount: '2', unit: 'large', calories: 60),
          const IngredientEntity(name: 'Quinoa', amount: '100', unit: 'g', calories: 120),
          const IngredientEntity(name: 'Black Beans', amount: '100', unit: 'g', calories: 88),
        ],
        'instructions': 'Hollow peppers, fill with quinoa mix, bake',
        'prepTime': 40,
        'imageUrl': 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=400',
      },
    ],
    MealType.snack: [
      {
        'name': 'Fresh Fruit Bowl',
        'description': 'Mixed seasonal fruits',
        'ingredients': [
          const IngredientEntity(name: 'Apple', amount: '1', unit: 'medium', calories: 95),
          const IngredientEntity(name: 'Orange', amount: '1', unit: 'medium', calories: 62),
          const IngredientEntity(name: 'Grapes', amount: '100', unit: 'g', calories: 69),
        ],
        'instructions': 'Wash and slice fruits',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400',
      },
      {
        'name': 'Hummus & Veggies',
        'description': 'Creamy hummus with raw vegetables',
        'ingredients': [
          const IngredientEntity(name: 'Hummus', amount: '80', unit: 'g', calories: 133),
          const IngredientEntity(name: 'Carrot Sticks', amount: '100', unit: 'g', calories: 41),
        ],
        'instructions': 'Serve hummus with vegetable sticks',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1576203939571-4d3f3b6d2c97?w=400',
      },
      {
        'name': 'Trail Mix',
        'description': 'Nuts and dried fruits',
        'ingredients': [
          const IngredientEntity(name: 'Mixed Nuts', amount: '30', unit: 'g', calories: 175),
          const IngredientEntity(name: 'Dried Fruit', amount: '20', unit: 'g', calories: 65),
        ],
        'instructions': 'Mix nuts and dried fruits',
        'prepTime': 2,
        'imageUrl': 'https://images.unsplash.com/photo-1599599810694-b5b37304c041?w=400',
      },
    ],
  };

  static final Map<MealType, List<Map<String, dynamic>>> _vegetarianMeals = {
    MealType.breakfast: [
      {
        'name': 'Greek Yogurt Parfait',
        'description': 'Creamy yogurt with granola',
        'ingredients': [
          const IngredientEntity(name: 'Greek Yogurt', amount: '200', unit: 'g', calories: 146),
          const IngredientEntity(name: 'Granola', amount: '50', unit: 'g', calories: 225),
          const IngredientEntity(name: 'Berries', amount: '100', unit: 'g', calories: 57),
        ],
        'instructions': 'Layer yogurt, granola, and berries',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400',
      },
      {
        'name': 'Vegetable Omelette',
        'description': 'Fluffy eggs with veggies',
        'ingredients': [
          const IngredientEntity(name: 'Eggs', amount: '3', unit: 'large', calories: 234),
          const IngredientEntity(name: 'Cheese', amount: '30', unit: 'g', calories: 120),
          const IngredientEntity(name: 'Mixed Vegetables', amount: '80', unit: 'g', calories: 30),
        ],
        'instructions': 'Whisk eggs, add vegetables, cook until set',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400',
      },
      {
        'name': 'Pancakes with Fruit',
        'description': 'Fluffy pancakes with fresh fruit',
        'ingredients': [
          const IngredientEntity(name: 'Pancakes', amount: '3', unit: 'medium', calories: 280),
          const IngredientEntity(name: 'Maple Syrup', amount: '2', unit: 'tbsp', calories: 104),
          const IngredientEntity(name: 'Berries', amount: '100', unit: 'g', calories: 50),
        ],
        'instructions': 'Make pancakes, top with fruit and syrup',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400',
      },
    ],
    MealType.lunch: [
      {
        'name': 'Caprese Salad',
        'description': 'Fresh mozzarella with tomatoes',
        'ingredients': [
          const IngredientEntity(name: 'Mozzarella', amount: '150', unit: 'g', calories: 336),
          const IngredientEntity(name: 'Tomatoes', amount: '200', unit: 'g', calories: 36),
          const IngredientEntity(name: 'Olive Oil', amount: '1', unit: 'tbsp', calories: 119),
        ],
        'instructions': 'Slice mozzarella and tomatoes, drizzle with oil',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=400',
      },
      {
        'name': 'Veggie Quesadilla',
        'description': 'Cheesy tortilla with vegetables',
        'ingredients': [
          const IngredientEntity(name: 'Tortilla', amount: '2', unit: 'large', calories: 220),
          const IngredientEntity(name: 'Cheese', amount: '80', unit: 'g', calories: 320),
          const IngredientEntity(name: 'Peppers', amount: '100', unit: 'g', calories: 30),
        ],
        'instructions': 'Fill tortilla with cheese and veggies, grill',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1618040996337-56904b7850b9?w=400',
      },
    ],
    MealType.dinner: [
      {
        'name': 'Eggplant Parmesan',
        'description': 'Baked eggplant with cheese',
        'ingredients': [
          const IngredientEntity(name: 'Eggplant', amount: '300', unit: 'g', calories: 75),
          const IngredientEntity(name: 'Mozzarella', amount: '100', unit: 'g', calories: 224),
          const IngredientEntity(name: 'Tomato Sauce', amount: '150', unit: 'g', calories: 45),
        ],
        'instructions': 'Bread and bake eggplant, top with cheese and sauce',
        'prepTime': 45,
        'imageUrl': 'https://images.unsplash.com/photo-1625944525533-473f1a3d54e7?w=400',
      },
      {
        'name': 'Mushroom Risotto',
        'description': 'Creamy Italian rice dish',
        'ingredients': [
          const IngredientEntity(name: 'Arborio Rice', amount: '100', unit: 'g', calories: 130),
          const IngredientEntity(name: 'Mushrooms', amount: '150', unit: 'g', calories: 33),
          const IngredientEntity(name: 'Parmesan', amount: '40', unit: 'g', calories: 166),
        ],
        'instructions': 'Slowly cook rice with broth, add mushrooms and cheese',
        'prepTime': 35,
        'imageUrl': 'https://images.unsplash.com/photo-1476124369491-e7addf5db371?w=400',
      },
    ],
    MealType.snack: [
      {
        'name': 'Cheese & Crackers',
        'description': 'Assorted cheese with crackers',
        'ingredients': [
          const IngredientEntity(name: 'Cheese', amount: '50', unit: 'g', calories: 200),
          const IngredientEntity(name: 'Crackers', amount: '30', unit: 'g', calories: 130),
        ],
        'instructions': 'Arrange cheese and crackers on plate',
        'prepTime': 2,
        'imageUrl': 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400',
      },
    ],
  };

  static final Map<MealType, List<Map<String, dynamic>>> _ketoMeals = {
    MealType.breakfast: [
      {
        'name': 'Bacon & Eggs',
        'description': 'Classic low-carb breakfast',
        'ingredients': [
          const IngredientEntity(name: 'Eggs', amount: '3', unit: 'large', calories: 234),
          const IngredientEntity(name: 'Bacon', amount: '60', unit: 'g', calories: 258),
          const IngredientEntity(name: 'Avocado', amount: '1/2', unit: 'medium', calories: 120),
        ],
        'instructions': 'Fry bacon and eggs, serve with avocado',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400',
      },
      {
        'name': 'Keto Smoothie',
        'description': 'Low-carb creamy smoothie',
        'ingredients': [
          const IngredientEntity(name: 'Almond Milk', amount: '200', unit: 'ml', calories: 30),
          const IngredientEntity(name: 'Avocado', amount: '1/2', unit: 'medium', calories: 120),
          const IngredientEntity(name: 'Protein Powder', amount: '30', unit: 'g', calories: 120),
        ],
        'instructions': 'Blend all ingredients until smooth',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400',
      },
    ],
    MealType.lunch: [
      {
        'name': 'Caesar Salad',
        'description': 'Grilled chicken caesar',
        'ingredients': [
          const IngredientEntity(name: 'Chicken Breast', amount: '150', unit: 'g', calories: 248),
          const IngredientEntity(name: 'Romaine Lettuce', amount: '150', unit: 'g', calories: 25),
          const IngredientEntity(name: 'Parmesan', amount: '30', unit: 'g', calories: 124),
        ],
        'instructions': 'Grill chicken, toss with lettuce and dressing',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=400',
      },
    ],
    MealType.dinner: [
      {
        'name': 'Grilled Steak',
        'description': 'Ribeye with vegetables',
        'ingredients': [
          const IngredientEntity(name: 'Ribeye Steak', amount: '200', unit: 'g', calories: 544),
          const IngredientEntity(name: 'Asparagus', amount: '150', unit: 'g', calories: 30),
          const IngredientEntity(name: 'Butter', amount: '20', unit: 'g', calories: 143),
        ],
        'instructions': 'Season and grill steak, sauté asparagus in butter',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=400',
      },
      {
        'name': 'Salmon with Broccoli',
        'description': 'Baked salmon with roasted broccoli',
        'ingredients': [
          const IngredientEntity(name: 'Salmon', amount: '180', unit: 'g', calories: 367),
          const IngredientEntity(name: 'Broccoli', amount: '150', unit: 'g', calories: 51),
          const IngredientEntity(name: 'Olive Oil', amount: '1', unit: 'tbsp', calories: 119),
        ],
        'instructions': 'Bake salmon, roast broccoli with olive oil',
        'prepTime': 25,
        'imageUrl': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400',
      },
    ],
    MealType.snack: [
      {
        'name': 'Cheese Crisps',
        'description': 'Baked cheese snacks',
        'ingredients': [
          const IngredientEntity(name: 'Cheddar', amount: '60', unit: 'g', calories: 240),
        ],
        'instructions': 'Bake cheese until crispy',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1618164436241-4473940d1f5c?w=400',
      },
    ],
  };

  static final Map<MealType, List<Map<String, dynamic>>> _mediterraneanMeals = {
    MealType.breakfast: [
      {
        'name': 'Mediterranean Eggs',
        'description': 'Shakshuka style eggs',
        'ingredients': [
          const IngredientEntity(name: 'Eggs', amount: '2', unit: 'large', calories: 156),
          const IngredientEntity(name: 'Tomatoes', amount: '200', unit: 'g', calories: 36),
          const IngredientEntity(name: 'Feta Cheese', amount: '40', unit: 'g', calories: 100),
        ],
        'instructions': 'Simmer tomatoes, crack eggs, add feta',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1590412200988-a436970781fa?w=400',
      },
    ],
    MealType.lunch: [
      {
        'name': 'Greek Salad',
        'description': 'Fresh vegetables with feta',
        'ingredients': [
          const IngredientEntity(name: 'Cucumber', amount: '150', unit: 'g', calories: 24),
          const IngredientEntity(name: 'Tomatoes', amount: '150', unit: 'g', calories: 27),
          const IngredientEntity(name: 'Feta', amount: '80', unit: 'g', calories: 200),
        ],
        'instructions': 'Chop vegetables, crumble feta, dress with olive oil',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400',
      },
    ],
    MealType.dinner: [
      {
        'name': 'Grilled Fish',
        'description': 'Mediterranean style fish',
        'ingredients': [
          const IngredientEntity(name: 'Sea Bass', amount: '180', unit: 'g', calories: 200),
          const IngredientEntity(name: 'Lemon', amount: '1', unit: 'medium', calories: 17),
          const IngredientEntity(name: 'Olive Oil', amount: '2', unit: 'tbsp', calories: 238),
        ],
        'instructions': 'Season fish with lemon and herbs, grill',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400',
      },
    ],
    MealType.snack: [
      {
        'name': 'Olives & Nuts',
        'description': 'Mediterranean snack plate',
        'ingredients': [
          const IngredientEntity(name: 'Olives', amount: '50', unit: 'g', calories: 73),
          const IngredientEntity(name: 'Almonds', amount: '30', unit: 'g', calories: 173),
        ],
        'instructions': 'Arrange olives and nuts on plate',
        'prepTime': 2,
        'imageUrl': 'https://images.unsplash.com/photo-1593253787226-567eda4d0509?w=400',
      },
    ],
  };

  static final Map<MealType, List<Map<String, dynamic>>> _standardMeals = {
    MealType.breakfast: [
      {
        'name': 'Scrambled Eggs & Toast',
        'description': 'Classic breakfast combo',
        'ingredients': [
          const IngredientEntity(name: 'Eggs', amount: '3', unit: 'large', calories: 234),
          const IngredientEntity(name: 'Bread', amount: '2', unit: 'slices', calories: 160),
          const IngredientEntity(name: 'Butter', amount: '10', unit: 'g', calories: 72),
        ],
        'instructions': 'Scramble eggs, toast bread, spread butter',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400',
      },
    ],
    MealType.lunch: [
      {
        'name': 'Chicken Salad',
        'description': 'Grilled chicken with greens',
        'ingredients': [
          const IngredientEntity(name: 'Chicken Breast', amount: '150', unit: 'g', calories: 248),
          const IngredientEntity(name: 'Mixed Greens', amount: '100', unit: 'g', calories: 20),
          const IngredientEntity(name: 'Dressing', amount: '30', unit: 'ml', calories: 90),
        ],
        'instructions': 'Grill chicken, toss with greens and dressing',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
      },
    ],
    MealType.dinner: [
      {
        'name': 'Grilled Chicken & Rice',
        'description': 'Protein with steamed rice',
        'ingredients': [
          const IngredientEntity(name: 'Chicken Breast', amount: '180', unit: 'g', calories: 297),
          const IngredientEntity(name: 'Rice', amount: '150', unit: 'g', calories: 195),
          const IngredientEntity(name: 'Vegetables', amount: '100', unit: 'g', calories: 35),
        ],
        'instructions': 'Grill chicken, cook rice, steam vegetables',
        'prepTime': 30,
        'imageUrl': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400',
      },
    ],
    MealType.snack: [
      {
        'name': 'Apple & Almonds',
        'description': 'Fresh fruit with nuts',
        'ingredients': [
          const IngredientEntity(name: 'Apple', amount: '1', unit: 'medium', calories: 95),
          const IngredientEntity(name: 'Almonds', amount: '30', unit: 'g', calories: 173),
        ],
        'instructions': 'Slice apple, enjoy with almonds',
        'prepTime': 2,
        'imageUrl': 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400',
      },
    ],
  };

  // ════════════════════════════════════════════════════════════════════════════
  // PESCATARIAN MEALS (Fish and seafood, no meat)
  // ════════════════════════════════════════════════════════════════════════════
  static final Map<MealType, List<Map<String, dynamic>>> _pescatarianMeals = {
    MealType.breakfast: [
      {
        'name': 'Smoked Salmon Toast',
        'description': 'Cream cheese and salmon on whole grain',
        'ingredients': [
          const IngredientEntity(name: 'Whole Grain Bread', amount: '2', unit: 'slices', calories: 160),
          const IngredientEntity(name: 'Smoked Salmon', amount: '60', unit: 'g', calories: 99),
          const IngredientEntity(name: 'Cream Cheese', amount: '30', unit: 'g', calories: 99),
        ],
        'instructions': 'Toast bread, spread cream cheese, top with salmon',
        'prepTime': 8,
        'imageUrl': 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=400',
      },
      {
        'name': 'Tuna Omelette',
        'description': 'Fluffy eggs with tuna and herbs',
        'ingredients': [
          const IngredientEntity(name: 'Eggs', amount: '3', unit: 'large', calories: 234),
          const IngredientEntity(name: 'Canned Tuna', amount: '80', unit: 'g', calories: 90),
          const IngredientEntity(name: 'Cheese', amount: '30', unit: 'g', calories: 120),
        ],
        'instructions': 'Whisk eggs, fold in tuna and cheese, cook until set',
        'prepTime': 12,
        'imageUrl': 'https://images.unsplash.com/photo-1510693206972-df098062cb71?w=400',
      },
      {
        'name': 'Shrimp Avocado Bowl',
        'description': 'Fresh shrimp with creamy avocado',
        'ingredients': [
          const IngredientEntity(name: 'Shrimp', amount: '100', unit: 'g', calories: 99),
          const IngredientEntity(name: 'Avocado', amount: '1/2', unit: 'medium', calories: 120),
          const IngredientEntity(name: 'Lime', amount: '1', unit: 'wedge', calories: 2),
        ],
        'instructions': 'Sauté shrimp, slice avocado, squeeze lime',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1551248429-40975aa4de74?w=400',
      },
    ],
    MealType.lunch: [
      {
        'name': 'Grilled Fish Tacos',
        'description': 'Fresh fish in corn tortillas',
        'ingredients': [
          const IngredientEntity(name: 'White Fish', amount: '150', unit: 'g', calories: 150),
          const IngredientEntity(name: 'Corn Tortillas', amount: '3', unit: 'small', calories: 150),
          const IngredientEntity(name: 'Cabbage Slaw', amount: '80', unit: 'g', calories: 20),
        ],
        'instructions': 'Grill fish, warm tortillas, assemble with slaw',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=400',
      },
      {
        'name': 'Seafood Salad',
        'description': 'Mixed seafood on greens',
        'ingredients': [
          const IngredientEntity(name: 'Mixed Seafood', amount: '150', unit: 'g', calories: 150),
          const IngredientEntity(name: 'Mixed Greens', amount: '100', unit: 'g', calories: 20),
          const IngredientEntity(name: 'Lemon Dressing', amount: '30', unit: 'ml', calories: 60),
        ],
        'instructions': 'Cook seafood, toss with greens and dressing',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1580959375944-abd7e991f971?w=400',
      },
      {
        'name': 'Tuna Wrap',
        'description': 'Tuna salad in whole wheat wrap',
        'ingredients': [
          const IngredientEntity(name: 'Canned Tuna', amount: '120', unit: 'g', calories: 135),
          const IngredientEntity(name: 'Whole Wheat Wrap', amount: '1', unit: 'large', calories: 130),
          const IngredientEntity(name: 'Greek Yogurt', amount: '40', unit: 'g', calories: 30),
        ],
        'instructions': 'Mix tuna with yogurt, wrap with veggies',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=400',
      },
    ],
    MealType.dinner: [
      {
        'name': 'Baked Salmon',
        'description': 'Herb-crusted salmon with vegetables',
        'ingredients': [
          const IngredientEntity(name: 'Salmon Fillet', amount: '180', unit: 'g', calories: 367),
          const IngredientEntity(name: 'Asparagus', amount: '150', unit: 'g', calories: 30),
          const IngredientEntity(name: 'Lemon', amount: '1', unit: 'medium', calories: 17),
        ],
        'instructions': 'Season salmon with herbs, bake with asparagus',
        'prepTime': 25,
        'imageUrl': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400',
      },
      {
        'name': 'Shrimp Stir-Fry',
        'description': 'Garlic shrimp with vegetables',
        'ingredients': [
          const IngredientEntity(name: 'Shrimp', amount: '200', unit: 'g', calories: 198),
          const IngredientEntity(name: 'Mixed Vegetables', amount: '200', unit: 'g', calories: 70),
          const IngredientEntity(name: 'Rice', amount: '150', unit: 'g', calories: 195),
        ],
        'instructions': 'Stir-fry shrimp and vegetables, serve over rice',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400',
      },
      {
        'name': 'Fish Curry',
        'description': 'Coconut fish curry with rice',
        'ingredients': [
          const IngredientEntity(name: 'White Fish', amount: '180', unit: 'g', calories: 180),
          const IngredientEntity(name: 'Coconut Milk', amount: '100', unit: 'ml', calories: 50),
          const IngredientEntity(name: 'Basmati Rice', amount: '150', unit: 'g', calories: 195),
        ],
        'instructions': 'Simmer fish in curry sauce, serve with rice',
        'prepTime': 30,
        'imageUrl': 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=400',
      },
    ],
    MealType.snack: [
      {
        'name': 'Tuna Cucumber Bites',
        'description': 'Light tuna on cucumber rounds',
        'ingredients': [
          const IngredientEntity(name: 'Cucumber', amount: '1', unit: 'medium', calories: 16),
          const IngredientEntity(name: 'Canned Tuna', amount: '60', unit: 'g', calories: 68),
          const IngredientEntity(name: 'Olive Oil', amount: '1', unit: 'tsp', calories: 40),
        ],
        'instructions': 'Slice cucumber, top with seasoned tuna',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1608039755401-742074f0548d?w=400',
      },
      {
        'name': 'Smoked Salmon Roll',
        'description': 'Salmon wrapped around cream cheese',
        'ingredients': [
          const IngredientEntity(name: 'Smoked Salmon', amount: '50', unit: 'g', calories: 83),
          const IngredientEntity(name: 'Cream Cheese', amount: '30', unit: 'g', calories: 99),
        ],
        'instructions': 'Spread cream cheese on salmon, roll up',
        'prepTime': 3,
        'imageUrl': 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=400',
      },
    ],
  };

  // ════════════════════════════════════════════════════════════════════════════
  // HALAL MEALS (No pork, no alcohol, properly slaughtered meat)
  // ════════════════════════════════════════════════════════════════════════════
  static final Map<MealType, List<Map<String, dynamic>>> _halalMeals = {
    MealType.breakfast: [
      {
        'name': 'Shakshuka',
        'description': 'Eggs poached in spiced tomato sauce',
        'ingredients': [
          const IngredientEntity(name: 'Eggs', amount: '2', unit: 'large', calories: 156),
          const IngredientEntity(name: 'Tomatoes', amount: '200', unit: 'g', calories: 36),
          const IngredientEntity(name: 'Pita Bread', amount: '1', unit: 'medium', calories: 165),
        ],
        'instructions': 'Sauté tomatoes with spices, crack eggs, cover and cook',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1590412200988-a436970781fa?w=400',
      },
      {
        'name': 'Ful Medames',
        'description': 'Traditional fava bean breakfast',
        'ingredients': [
          const IngredientEntity(name: 'Fava Beans', amount: '200', unit: 'g', calories: 187),
          const IngredientEntity(name: 'Olive Oil', amount: '1', unit: 'tbsp', calories: 119),
          const IngredientEntity(name: 'Pita Bread', amount: '1', unit: 'medium', calories: 165),
        ],
        'instructions': 'Warm beans, mash slightly, drizzle oil, serve with pita',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=400',
      },
      {
        'name': 'Halal Turkey Sausage',
        'description': 'Turkey sausage with eggs',
        'ingredients': [
          const IngredientEntity(name: 'Turkey Sausage', amount: '100', unit: 'g', calories: 196),
          const IngredientEntity(name: 'Eggs', amount: '2', unit: 'large', calories: 156),
          const IngredientEntity(name: 'Toast', amount: '1', unit: 'slice', calories: 80),
        ],
        'instructions': 'Cook sausage, fry eggs, serve with toast',
        'prepTime': 12,
        'imageUrl': 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400',
      },
    ],
    MealType.lunch: [
      {
        'name': 'Chicken Shawarma',
        'description': 'Spiced chicken in pita with tahini',
        'ingredients': [
          const IngredientEntity(name: 'Chicken Breast', amount: '150', unit: 'g', calories: 248),
          const IngredientEntity(name: 'Pita Bread', amount: '1', unit: 'large', calories: 165),
          const IngredientEntity(name: 'Tahini', amount: '30', unit: 'g', calories: 89),
        ],
        'instructions': 'Marinate and grill chicken, slice thin, serve in pita',
        'prepTime': 25,
        'imageUrl': 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=400',
      },
      {
        'name': 'Lamb Kebab Wrap',
        'description': 'Grilled lamb in lavash',
        'ingredients': [
          const IngredientEntity(name: 'Ground Lamb', amount: '150', unit: 'g', calories: 330),
          const IngredientEntity(name: 'Lavash Bread', amount: '1', unit: 'large', calories: 120),
          const IngredientEntity(name: 'Yogurt Sauce', amount: '40', unit: 'g', calories: 30),
        ],
        'instructions': 'Form lamb into kebabs, grill, wrap with sauce',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=400',
      },
      {
        'name': 'Falafel Bowl',
        'description': 'Crispy falafel with hummus',
        'ingredients': [
          const IngredientEntity(name: 'Falafel', amount: '5', unit: 'pieces', calories: 275),
          const IngredientEntity(name: 'Hummus', amount: '80', unit: 'g', calories: 133),
          const IngredientEntity(name: 'Quinoa', amount: '100', unit: 'g', calories: 120),
        ],
        'instructions': 'Prepare falafel, serve over quinoa with hummus',
        'prepTime': 30,
        'imageUrl': 'https://images.unsplash.com/photo-1593001874117-c99c800e3eb6?w=400',
      },
    ],
    MealType.dinner: [
      {
        'name': 'Lamb Tagine',
        'description': 'Slow-cooked Moroccan lamb stew',
        'ingredients': [
          const IngredientEntity(name: 'Lamb', amount: '200', unit: 'g', calories: 440),
          const IngredientEntity(name: 'Apricots', amount: '50', unit: 'g', calories: 24),
          const IngredientEntity(name: 'Couscous', amount: '150', unit: 'g', calories: 176),
        ],
        'instructions': 'Slow cook lamb with spices and apricots, serve over couscous',
        'prepTime': 45,
        'imageUrl': 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=400',
      },
      {
        'name': 'Chicken Biryani',
        'description': 'Fragrant spiced rice with chicken',
        'ingredients': [
          const IngredientEntity(name: 'Chicken', amount: '180', unit: 'g', calories: 297),
          const IngredientEntity(name: 'Basmati Rice', amount: '150', unit: 'g', calories: 195),
          const IngredientEntity(name: 'Yogurt', amount: '50', unit: 'g', calories: 30),
        ],
        'instructions': 'Layer marinated chicken with rice, cook until fragrant',
        'prepTime': 50,
        'imageUrl': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400',
      },
      {
        'name': 'Grilled Halal Steak',
        'description': 'Seasoned beef with vegetables',
        'ingredients': [
          const IngredientEntity(name: 'Beef Steak', amount: '200', unit: 'g', calories: 400),
          const IngredientEntity(name: 'Grilled Vegetables', amount: '150', unit: 'g', calories: 50),
          const IngredientEntity(name: 'Rice', amount: '100', unit: 'g', calories: 130),
        ],
        'instructions': 'Season and grill steak, serve with vegetables and rice',
        'prepTime': 25,
        'imageUrl': 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=400',
      },
    ],
    MealType.snack: [
      {
        'name': 'Hummus Plate',
        'description': 'Creamy hummus with pita',
        'ingredients': [
          const IngredientEntity(name: 'Hummus', amount: '100', unit: 'g', calories: 166),
          const IngredientEntity(name: 'Pita Chips', amount: '30', unit: 'g', calories: 130),
        ],
        'instructions': 'Serve hummus with warm pita chips',
        'prepTime': 2,
        'imageUrl': 'https://images.unsplash.com/photo-1576203939571-4d3f3b6d2c97?w=400',
      },
      {
        'name': 'Dates with Almonds',
        'description': 'Sweet dates stuffed with almonds',
        'ingredients': [
          const IngredientEntity(name: 'Medjool Dates', amount: '4', unit: 'pieces', calories: 133),
          const IngredientEntity(name: 'Almonds', amount: '20', unit: 'g', calories: 115),
        ],
        'instructions': 'Pit dates, stuff with almonds',
        'prepTime': 3,
        'imageUrl': 'https://images.unsplash.com/photo-1593253787226-567eda4d0509?w=400',
      },
      {
        'name': 'Labneh Dip',
        'description': 'Strained yogurt with olive oil',
        'ingredients': [
          const IngredientEntity(name: 'Labneh', amount: '80', unit: 'g', calories: 120),
          const IngredientEntity(name: 'Olive Oil', amount: '1', unit: 'tbsp', calories: 119),
          const IngredientEntity(name: 'Pita', amount: '1/2', unit: 'medium', calories: 82),
        ],
        'instructions': 'Spread labneh, drizzle oil, serve with pita',
        'prepTime': 2,
        'imageUrl': 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400',
      },
    ],
  };

  // ════════════════════════════════════════════════════════════════════════════
  // KOSHER MEALS (No shellfish, no mixing meat/dairy, no pork)
  // ════════════════════════════════════════════════════════════════════════════
  static final Map<MealType, List<Map<String, dynamic>>> _kosherMeals = {
    MealType.breakfast: [
      {
        'name': 'Bagel with Lox',
        'description': 'Classic kosher breakfast',
        'ingredients': [
          const IngredientEntity(name: 'Bagel', amount: '1', unit: 'whole', calories: 245),
          const IngredientEntity(name: 'Cream Cheese', amount: '40', unit: 'g', calories: 140),
          const IngredientEntity(name: 'Smoked Salmon', amount: '50', unit: 'g', calories: 82),
        ],
        'instructions': 'Slice bagel, spread cream cheese, layer salmon',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=400',
      },
      {
        'name': 'Matzo Brei',
        'description': 'Scrambled eggs with matzo',
        'ingredients': [
          const IngredientEntity(name: 'Matzo', amount: '2', unit: 'sheets', calories: 220),
          const IngredientEntity(name: 'Eggs', amount: '3', unit: 'large', calories: 234),
          const IngredientEntity(name: 'Butter', amount: '15', unit: 'g', calories: 107),
        ],
        'instructions': 'Soak matzo, mix with eggs, scramble',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1510693206972-df098062cb71?w=400',
      },
      {
        'name': 'Cheese Blintzes',
        'description': 'Sweet cheese-filled crepes',
        'ingredients': [
          const IngredientEntity(name: 'Blintzes', amount: '2', unit: 'pieces', calories: 280),
          const IngredientEntity(name: 'Cottage Cheese', amount: '100', unit: 'g', calories: 98),
          const IngredientEntity(name: 'Sour Cream', amount: '40', unit: 'g', calories: 80),
        ],
        'instructions': 'Fill blintzes with cheese mixture, pan fry',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400',
      },
    ],
    MealType.lunch: [
      {
        'name': 'Chicken Schnitzel',
        'description': 'Breaded chicken cutlet',
        'ingredients': [
          const IngredientEntity(name: 'Chicken Breast', amount: '180', unit: 'g', calories: 297),
          const IngredientEntity(name: 'Breadcrumbs', amount: '40', unit: 'g', calories: 160),
          const IngredientEntity(name: 'Salad', amount: '100', unit: 'g', calories: 20),
        ],
        'instructions': 'Bread and fry chicken, serve with salad',
        'prepTime': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400',
      },
      {
        'name': 'Falafel Pita',
        'description': 'Falafel in pita with tahini',
        'ingredients': [
          const IngredientEntity(name: 'Falafel', amount: '4', unit: 'pieces', calories: 220),
          const IngredientEntity(name: 'Pita Bread', amount: '1', unit: 'large', calories: 165),
          const IngredientEntity(name: 'Israeli Salad', amount: '80', unit: 'g', calories: 25),
        ],
        'instructions': 'Stuff pita with falafel, salad, and tahini',
        'prepTime': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1593001874117-c99c800e3eb6?w=400',
      },
      {
        'name': 'Kosher Deli Sandwich',
        'description': 'Pastrami on rye bread',
        'ingredients': [
          const IngredientEntity(name: 'Pastrami', amount: '100', unit: 'g', calories: 147),
          const IngredientEntity(name: 'Rye Bread', amount: '2', unit: 'slices', calories: 166),
          const IngredientEntity(name: 'Mustard', amount: '10', unit: 'g', calories: 10),
        ],
        'instructions': 'Layer pastrami on rye with mustard',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=400',
      },
    ],
    MealType.dinner: [
      {
        'name': 'Brisket',
        'description': 'Slow-cooked beef brisket',
        'ingredients': [
          const IngredientEntity(name: 'Beef Brisket', amount: '200', unit: 'g', calories: 468),
          const IngredientEntity(name: 'Carrots', amount: '100', unit: 'g', calories: 41),
          const IngredientEntity(name: 'Potatoes', amount: '150', unit: 'g', calories: 116),
        ],
        'instructions': 'Braise brisket slowly with vegetables',
        'prepTime': 180,
        'imageUrl': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=400',
      },
      {
        'name': 'Roast Chicken',
        'description': 'Herb-roasted whole chicken',
        'ingredients': [
          const IngredientEntity(name: 'Chicken', amount: '200', unit: 'g', calories: 330),
          const IngredientEntity(name: 'Root Vegetables', amount: '200', unit: 'g', calories: 100),
          const IngredientEntity(name: 'Olive Oil', amount: '1', unit: 'tbsp', calories: 119),
        ],
        'instructions': 'Season chicken, roast with vegetables',
        'prepTime': 60,
        'imageUrl': 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=400',
      },
      {
        'name': 'Gefilte Fish',
        'description': 'Traditional poached fish patties',
        'ingredients': [
          const IngredientEntity(name: 'Fish Patties', amount: '3', unit: 'pieces', calories: 180),
          const IngredientEntity(name: 'Horseradish', amount: '20', unit: 'g', calories: 10),
          const IngredientEntity(name: 'Carrots', amount: '50', unit: 'g', calories: 21),
        ],
        'instructions': 'Serve chilled fish with horseradish',
        'prepTime': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400',
      },
    ],
    MealType.snack: [
      {
        'name': 'Rugelach',
        'description': 'Traditional pastry crescents',
        'ingredients': [
          const IngredientEntity(name: 'Rugelach', amount: '3', unit: 'pieces', calories: 240),
        ],
        'instructions': 'Serve at room temperature',
        'prepTime': 1,
        'imageUrl': 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400',
      },
      {
        'name': 'Challah Toast',
        'description': 'Toasted egg bread with honey',
        'ingredients': [
          const IngredientEntity(name: 'Challah', amount: '2', unit: 'slices', calories: 200),
          const IngredientEntity(name: 'Honey', amount: '1', unit: 'tbsp', calories: 64),
        ],
        'instructions': 'Toast challah, drizzle with honey',
        'prepTime': 3,
        'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
      },
      {
        'name': 'Fresh Fruit Plate',
        'description': 'Seasonal kosher fruits',
        'ingredients': [
          const IngredientEntity(name: 'Apple', amount: '1', unit: 'medium', calories: 95),
          const IngredientEntity(name: 'Grapes', amount: '100', unit: 'g', calories: 69),
          const IngredientEntity(name: 'Orange', amount: '1', unit: 'medium', calories: 62),
        ],
        'instructions': 'Wash and slice fruits',
        'prepTime': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400',
      },
    ],
  };
}

/// Alternative meal data class
class MealAlternative {
  final String name;
  final String description;
  final int calories;
  final int protein;
  final int fats;
  final int carbs;
  final String imageUrl;
  final List<IngredientEntity> ingredients;
  final String instructions;
  final int prepTime;
  final double calorieMatch; // 0.0 to 1.0 indicating how close to target calories

  MealAlternative({
    required this.name,
    required this.description,
    required this.calories,
    this.protein = 0,
    this.fats = 0,
    this.carbs = 0,
    required this.imageUrl,
    required this.ingredients,
    required this.instructions,
    required this.prepTime,
    this.calorieMatch = 1.0,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

/// Provider for meal swap service
final mealSwapServiceProvider = Provider<MealSwapService>((ref) {
  return MealSwapService(ref);
});
