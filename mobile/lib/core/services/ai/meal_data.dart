import '../../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../../features/diet/domain/entities/diet_preferences_entity.dart';

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
  final double calorieMatch;

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

class MealData {
  // Dietary-style macro ratios
  static const Map<DietaryStyle, List<double>> macroRatios = {
    DietaryStyle.keto:          [0.25, 0.05, 0.70],
    DietaryStyle.vegan:         [0.15, 0.60, 0.25],
    DietaryStyle.vegetarian:    [0.20, 0.50, 0.30],
    DietaryStyle.pescatarian:   [0.30, 0.40, 0.30],
    DietaryStyle.mediterranean: [0.25, 0.45, 0.30],
    DietaryStyle.halal:         [0.25, 0.45, 0.30],
    DietaryStyle.kosher:        [0.25, 0.45, 0.30],
    DietaryStyle.noRestrictions:[0.25, 0.45, 0.30],
  };

  static final Map<MealType, List<Map<String, dynamic>>> veganMeals = {
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
        'imageUrl': 'https://images.unsplash.com/photo-1495214783159-3503fd1b572d?w=400',
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
        'imageUrl': 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=400',
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
        'imageUrl': 'https://images.unsplash.com/photo-1588137378633-dea1336ce1e2?w=400',
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
        'imageUrl': 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=400',
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

  static final Map<MealType, List<Map<String, dynamic>>> vegetarianMeals = {
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
    ],
    // ... Simplified for brevity in this step, full data applied in final
  };

  static final Map<MealType, List<Map<String, dynamic>>> ketoMeals = { /* ... */ };
  static final Map<MealType, List<Map<String, dynamic>>> mediterraneanMeals = { /* ... */ };
  static final Map<MealType, List<Map<String, dynamic>>> pescatarianMeals = { /* ... */ };
  static final Map<MealType, List<Map<String, dynamic>>> standardMeals = { /* ... */ };
  static final Map<MealType, List<Map<String, dynamic>>> halalMeals = { /* ... */ };
  static final Map<MealType, List<Map<String, dynamic>>> kosherMeals = { /* ... */ };

  static List<Map<String, dynamic>> getMealOptionsForStyle(MealType type, DietaryStyle style) {
    switch (style) {
      case DietaryStyle.vegan: return veganMeals[type] ?? [];
      case DietaryStyle.vegetarian: return vegetarianMeals[type] ?? [];
      case DietaryStyle.pescatarian: return pescatarianMeals[type] ?? [];
      case DietaryStyle.keto: return ketoMeals[type] ?? [];
      case DietaryStyle.mediterranean: return mediterraneanMeals[type] ?? [];
      case DietaryStyle.halal: return halalMeals[type] ?? [];
      case DietaryStyle.kosher: return kosherMeals[type] ?? [];
      case DietaryStyle.noRestrictions: return standardMeals[type] ?? [];
    }
  }
}
