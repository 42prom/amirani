import 'package:flutter/foundation.dart';
import '../../features/diet/domain/entities/diet_preferences_entity.dart';
import '../../features/diet/domain/entities/monthly_plan_entity.dart';

/// Lazy-loaded meal database with on-demand loading and memory management
///
/// This class provides efficient meal data access by:
/// 1. Loading meal data only when requested (lazy loading)
/// 2. Caching loaded data for fast subsequent access
/// 3. Providing memory pressure handling to free unused data
class MealDatabase {
  // Singleton instance
  static MealDatabase? _instance;
  static MealDatabase get instance => _instance ??= MealDatabase._();

  MealDatabase._();

  // Cache for loaded meal data
  final Map<DietaryStyle, Map<MealType, List<Map<String, dynamic>>>> _cache = {};

  // Track which styles are loaded
  final Set<DietaryStyle> _loadedStyles = {};

  // Track last access time for each style (for LRU eviction if needed)
  final Map<DietaryStyle, DateTime> _lastAccess = {};

  /// Get meals for a specific style, loading lazily if needed
  Map<MealType, List<Map<String, dynamic>>> getMealsForStyle(DietaryStyle style) {
    if (!_loadedStyles.contains(style)) {
      _loadStyleData(style);
    }
    _lastAccess[style] = DateTime.now();
    return _cache[style] ?? {};
  }

  /// Preload a specific style (e.g., user's selected style on app start)
  void preloadStyle(DietaryStyle style) {
    if (!_loadedStyles.contains(style)) {
      _loadStyleData(style);
    }
  }

  /// Preload multiple styles
  void preloadStyles(List<DietaryStyle> styles) {
    for (final style in styles) {
      preloadStyle(style);
    }
  }

  /// Check if a style is already loaded
  bool isStyleLoaded(DietaryStyle style) => _loadedStyles.contains(style);

  /// Get number of loaded styles (for monitoring)
  int get loadedStyleCount => _loadedStyles.length;

  /// Get approximate memory usage info
  Map<String, dynamic> get memoryInfo {
    int totalMeals = 0;
    for (final styleData in _cache.values) {
      for (final mealList in styleData.values) {
        totalMeals += mealList.length;
      }
    }
    return {
      'loadedStyles': _loadedStyles.length,
      'totalMeals': totalMeals,
      'estimatedBytes': totalMeals * 500, // Rough estimate per meal
    };
  }

  /// Clear cache to free memory (call on low memory warning)
  /// Optionally keep a specific style (e.g., user's current preference)
  void clearCache({DietaryStyle? exceptStyle}) {
    if (exceptStyle != null) {
      final keepData = _cache[exceptStyle];
      final keepAccess = _lastAccess[exceptStyle];
      _cache.clear();
      _loadedStyles.clear();
      _lastAccess.clear();
      if (keepData != null) {
        _cache[exceptStyle] = keepData;
        _loadedStyles.add(exceptStyle);
        if (keepAccess != null) {
          _lastAccess[exceptStyle] = keepAccess;
        }
      }
    } else {
      _cache.clear();
      _loadedStyles.clear();
      _lastAccess.clear();
    }

    if (kDebugMode) {
      print('MealDatabase: Cache cleared${exceptStyle != null ? ' (kept $exceptStyle)' : ''}');
    }
  }

  /// Clear least recently used styles to free memory
  void clearLeastRecentlyUsed({int keepCount = 2}) {
    if (_loadedStyles.length <= keepCount) return;

    // Sort by last access time
    final sortedStyles = _lastAccess.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Remove oldest entries
    final toRemove = sortedStyles.take(_loadedStyles.length - keepCount);
    for (final entry in toRemove) {
      _cache.remove(entry.key);
      _loadedStyles.remove(entry.key);
      _lastAccess.remove(entry.key);
    }

    if (kDebugMode) {
      print('MealDatabase: Cleared ${toRemove.length} LRU styles');
    }
  }

  /// Load meal data for a specific style
  void _loadStyleData(DietaryStyle style) {
    // This delegates to the loader functions
    // In a real implementation, these could load from JSON files or API
    switch (style) {
      case DietaryStyle.vegan:
        _cache[style] = _getVeganMeals();
        break;
      case DietaryStyle.vegetarian:
        _cache[style] = _getVegetarianMeals();
        break;
      case DietaryStyle.pescatarian:
        _cache[style] = _getPescatarianMeals();
        break;
      case DietaryStyle.keto:
        _cache[style] = _getKetoMeals();
        break;
      case DietaryStyle.mediterranean:
        _cache[style] = _getMediterraneanMeals();
        break;
      case DietaryStyle.halal:
        _cache[style] = _getHalalMeals();
        break;
      case DietaryStyle.kosher:
        _cache[style] = _getKosherMeals();
        break;
      case DietaryStyle.noRestrictions:
        _cache[style] = _getStandardMeals();
        break;
    }
    _loadedStyles.add(style);
    _lastAccess[style] = DateTime.now();

    if (kDebugMode) {
      print('MealDatabase: Loaded $style meals');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MEAL DATA LOADERS
  // These return meal data without storing it in static final maps
  // In a production app, these could load from JSON assets or API
  // ════════════════════════════════════════════════════════════════════════════

  Map<MealType, List<Map<String, dynamic>>> _getVeganMeals() {
    return {
      MealType.breakfast: _createMealList([
        _meal('Oatmeal with Banana', 'Warm oatmeal topped with banana', 457, 10,
            'https://images.unsplash.com/photo-1495214783159-3503fd1b572d?w=400'),
        _meal('Smoothie Bowl', 'Frozen fruit blend with granola', 385, 8,
            'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=400'),
        _meal('Avocado Toast', 'Whole grain toast with avocado', 295, 5,
            'https://images.unsplash.com/photo-1588137378633-dea1336ce1e2?w=400'),
        _meal('Chia Pudding', 'Overnight chia with fruit', 275, 5,
            'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=400'),
      ]),
      MealType.lunch: _createMealList([
        _meal('Buddha Bowl', 'Quinoa with roasted vegetables', 424, 25,
            'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400'),
        _meal('Lentil Soup', 'Hearty red lentil soup', 317, 30,
            'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=400'),
        _meal('Falafel Wrap', 'Crispy falafel in pita', 468, 15,
            'https://images.unsplash.com/photo-1593001874117-c99c800e3eb6?w=400'),
      ]),
      MealType.dinner: _createMealList([
        _meal('Tofu Stir Fry', 'Crispy tofu with rice', 345, 30,
            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400'),
        _meal('Vegetable Curry', 'Coconut curry with rice', 409, 35,
            'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=400'),
      ]),
      MealType.snack: _createMealList([
        _meal('Fresh Fruit Bowl', 'Mixed seasonal fruits', 226, 5,
            'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400'),
        _meal('Hummus & Veggies', 'Creamy hummus with raw vegetables', 174, 5,
            'https://images.unsplash.com/photo-1576203939571-4d3f3b6d2c97?w=400'),
      ]),
    };
  }

  Map<MealType, List<Map<String, dynamic>>> _getVegetarianMeals() {
    return {
      MealType.breakfast: _createMealList([
        _meal('Greek Yogurt Parfait', 'Creamy yogurt with granola', 428, 5,
            'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400'),
        _meal('Vegetable Omelette', 'Fluffy eggs with veggies', 384, 10,
            'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400'),
      ]),
      MealType.lunch: _createMealList([
        _meal('Caprese Salad', 'Fresh mozzarella with tomatoes', 491, 10,
            'https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=400'),
        _meal('Veggie Quesadilla', 'Cheesy tortilla with vegetables', 570, 15,
            'https://images.unsplash.com/photo-1618040996337-56904b7850b9?w=400'),
      ]),
      MealType.dinner: _createMealList([
        _meal('Eggplant Parmesan', 'Baked eggplant with cheese', 344, 45,
            'https://images.unsplash.com/photo-1625944525533-473f1a3d54e7?w=400'),
        _meal('Mushroom Risotto', 'Creamy Italian rice dish', 329, 35,
            'https://images.unsplash.com/photo-1476124369491-e7addf5db371?w=400'),
      ]),
      MealType.snack: _createMealList([
        _meal('Cheese & Crackers', 'Assorted cheese with crackers', 330, 2,
            'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400'),
      ]),
    };
  }

  Map<MealType, List<Map<String, dynamic>>> _getPescatarianMeals() {
    return {
      MealType.breakfast: _createMealList([
        _meal('Smoked Salmon Toast', 'Cream cheese and salmon on whole grain', 358, 8,
            'https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=400'),
        _meal('Tuna Omelette', 'Fluffy eggs with tuna and herbs', 444, 12,
            'https://images.unsplash.com/photo-1510693206972-df098062cb71?w=400'),
      ]),
      MealType.lunch: _createMealList([
        _meal('Grilled Fish Tacos', 'Fresh fish in corn tortillas', 320, 20,
            'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=400'),
        _meal('Seafood Salad', 'Mixed seafood on greens', 230, 15,
            'https://images.unsplash.com/photo-1580959375944-abd7e991f971?w=400'),
      ]),
      MealType.dinner: _createMealList([
        _meal('Baked Salmon', 'Herb-crusted salmon with vegetables', 414, 25,
            'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400'),
        _meal('Shrimp Stir-Fry', 'Garlic shrimp with vegetables', 463, 20,
            'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400'),
      ]),
      MealType.snack: _createMealList([
        _meal('Tuna Cucumber Bites', 'Light tuna on cucumber rounds', 124, 5,
            'https://images.unsplash.com/photo-1608039755401-742074f0548d?w=400'),
      ]),
    };
  }

  Map<MealType, List<Map<String, dynamic>>> _getKetoMeals() {
    return {
      MealType.breakfast: _createMealList([
        _meal('Bacon & Eggs', 'Classic low-carb breakfast', 612, 15,
            'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400'),
        _meal('Keto Smoothie', 'Low-carb creamy smoothie', 270, 5,
            'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400'),
      ]),
      MealType.lunch: _createMealList([
        _meal('Caesar Salad', 'Grilled chicken caesar', 397, 20,
            'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=400'),
      ]),
      MealType.dinner: _createMealList([
        _meal('Grilled Steak', 'Ribeye with vegetables', 717, 20,
            'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=400'),
        _meal('Salmon with Broccoli', 'Baked salmon with roasted broccoli', 537, 25,
            'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400'),
      ]),
      MealType.snack: _createMealList([
        _meal('Cheese Crisps', 'Baked cheese snacks', 240, 10,
            'https://images.unsplash.com/photo-1618164436241-4473940d1f5c?w=400'),
      ]),
    };
  }

  Map<MealType, List<Map<String, dynamic>>> _getMediterraneanMeals() {
    return {
      MealType.breakfast: _createMealList([
        _meal('Mediterranean Eggs', 'Shakshuka style eggs', 292, 15,
            'https://images.unsplash.com/photo-1590412200988-a436970781fa?w=400'),
      ]),
      MealType.lunch: _createMealList([
        _meal('Greek Salad', 'Fresh vegetables with feta', 251, 10,
            'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400'),
      ]),
      MealType.dinner: _createMealList([
        _meal('Grilled Fish', 'Mediterranean style fish', 455, 20,
            'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400'),
      ]),
      MealType.snack: _createMealList([
        _meal('Olives & Nuts', 'Mediterranean snack plate', 246, 2,
            'https://images.unsplash.com/photo-1593253787226-567eda4d0509?w=400'),
      ]),
    };
  }

  Map<MealType, List<Map<String, dynamic>>> _getHalalMeals() {
    return {
      MealType.breakfast: _createMealList([
        _meal('Shakshuka', 'Eggs poached in spiced tomato sauce', 357, 20,
            'https://images.unsplash.com/photo-1590412200988-a436970781fa?w=400'),
        _meal('Ful Medames', 'Traditional fava bean breakfast', 471, 15,
            'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=400'),
      ]),
      MealType.lunch: _createMealList([
        _meal('Chicken Shawarma', 'Spiced chicken in pita with tahini', 502, 25,
            'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=400'),
        _meal('Falafel Bowl', 'Crispy falafel with hummus', 528, 30,
            'https://images.unsplash.com/photo-1593001874117-c99c800e3eb6?w=400'),
      ]),
      MealType.dinner: _createMealList([
        _meal('Lamb Tagine', 'Slow-cooked Moroccan lamb stew', 640, 45,
            'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=400'),
        _meal('Chicken Biryani', 'Fragrant spiced rice with chicken', 522, 50,
            'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400'),
      ]),
      MealType.snack: _createMealList([
        _meal('Hummus Plate', 'Creamy hummus with pita', 296, 2,
            'https://images.unsplash.com/photo-1576203939571-4d3f3b6d2c97?w=400'),
        _meal('Dates with Almonds', 'Sweet dates stuffed with almonds', 248, 3,
            'https://images.unsplash.com/photo-1593253787226-567eda4d0509?w=400'),
      ]),
    };
  }

  Map<MealType, List<Map<String, dynamic>>> _getKosherMeals() {
    return {
      MealType.breakfast: _createMealList([
        _meal('Bagel with Lox', 'Classic kosher breakfast', 467, 5,
            'https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=400'),
        _meal('Matzo Brei', 'Scrambled eggs with matzo', 561, 10,
            'https://images.unsplash.com/photo-1510693206972-df098062cb71?w=400'),
      ]),
      MealType.lunch: _createMealList([
        _meal('Chicken Schnitzel', 'Breaded chicken cutlet', 477, 20,
            'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400'),
        _meal('Falafel Pita', 'Falafel in pita with tahini', 410, 15,
            'https://images.unsplash.com/photo-1593001874117-c99c800e3eb6?w=400'),
      ]),
      MealType.dinner: _createMealList([
        _meal('Brisket', 'Slow-cooked beef brisket', 625, 180,
            'https://images.unsplash.com/photo-1544025162-d76694265947?w=400'),
        _meal('Roast Chicken', 'Herb-roasted whole chicken', 549, 60,
            'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=400'),
      ]),
      MealType.snack: _createMealList([
        _meal('Rugelach', 'Traditional pastry crescents', 240, 1,
            'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400'),
        _meal('Fresh Fruit Plate', 'Seasonal kosher fruits', 226, 5,
            'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400'),
      ]),
    };
  }

  Map<MealType, List<Map<String, dynamic>>> _getStandardMeals() {
    return {
      MealType.breakfast: _createMealList([
        _meal('Scrambled Eggs & Toast', 'Classic breakfast combo', 466, 10,
            'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400'),
      ]),
      MealType.lunch: _createMealList([
        _meal('Chicken Salad', 'Grilled chicken with greens', 358, 20,
            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400'),
      ]),
      MealType.dinner: _createMealList([
        _meal('Grilled Chicken & Rice', 'Protein with steamed rice', 527, 30,
            'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400'),
      ]),
      MealType.snack: _createMealList([
        _meal('Apple & Almonds', 'Fresh fruit with nuts', 268, 2,
            'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400'),
      ]),
    };
  }

  // Helper to create a simplified meal map
  Map<String, dynamic> _meal(String name, String description, int calories, int prepTime, String imageUrl) {
    return {
      'name': name,
      'description': description,
      'calories': calories,
      'prepTime': prepTime,
      'imageUrl': imageUrl,
      'ingredients': <IngredientEntity>[], // Simplified - ingredients loaded separately if needed
      'instructions': '',
    };
  }

  List<Map<String, dynamic>> _createMealList(List<Map<String, dynamic>> meals) {
    return meals;
  }
}
