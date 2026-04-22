/// Comprehensive food emoji registry with unique emojis and fallback system
/// Provides distinct visual representation for foods to avoid confusion
class FoodEmojiRegistry {
  FoodEmojiRegistry._();

  // ════════════════════════════════════════════════════════════════════════════
  // UNIQUE EMOJI MAPPINGS (80+ entries with minimal duplication)
  // ════════════════════════════════════════════════════════════════════════════

  static const Map<String, String> _uniqueEmojis = {
    // ─── Proteins - Animal ───────────────────────────────────────────────────
    'chicken': '🍗',
    'chicken breast': '🍗',
    'beef': '🥩',
    'beef steak': '🥩',
    'ribeye': '🥩',
    'steak': '🥩',
    'brisket': '🥓',
    'pastrami': '🥓',
    'turkey': '🦃',
    'turkey sausage': '🦃',
    'lamb': '🍖',
    'ground lamb': '🍖',

    // ─── Proteins - Seafood ──────────────────────────────────────────────────
    'fish': '🐟',
    'white fish': '🐟',
    'sea bass': '🐟',
    'salmon': '🍣',
    'salmon fillet': '🍣',
    'smoked salmon': '🍣',
    'tuna': '🐠',
    'canned tuna': '🐠',
    'shrimp': '🦐',
    'mixed seafood': '🦐',

    // ─── Proteins - Plant ────────────────────────────────────────────────────
    'tofu': '🧊',
    'lentils': '🫘',
    'red lentils': '🫘',
    'chickpeas': '🫛',
    'beans': '🫘',
    'black beans': '🫘',
    'fava beans': '🫘',
    'quinoa': '🌾',
    'falafel': '🧆',

    // ─── Eggs & Dairy ────────────────────────────────────────────────────────
    'eggs': '🥚',
    'yogurt': '🥛',
    'greek yogurt': '🥛',
    'cheese': '🧀',
    'mozzarella': '🧀',
    'parmesan': '🧀',
    'feta': '🧀',
    'feta cheese': '🧀',
    'cheddar': '🧀',
    'cream cheese': '🧈',
    'cottage cheese': '🥛',
    'sour cream': '🥛',
    'labneh': '🥛',
    'milk': '🥛',
    'butter': '🧈',
    'almond milk': '🥜',

    // ─── Grains & Carbs ──────────────────────────────────────────────────────
    'rice': '🍚',
    'brown rice': '🍚',
    'basmati rice': '🍚',
    'arborio rice': '🍚',
    'pasta': '🍝',
    'bread': '🍞',
    'whole grain bread': '🍞',
    'toast': '🍞',
    'rye bread': '🍞',
    'pita bread': '🫓',
    'pita': '🫓',
    'pita chips': '🫓',
    'lavash bread': '🫓',
    'tortilla': '🫔',
    'corn tortillas': '🫔',
    'wrap': '🌯',
    'whole wheat wrap': '🌯',
    'oatmeal': '🥣',
    'granola': '🥣',
    'bagel': '🥯',
    'challah': '🥯',
    'matzo': '🫓',
    'couscous': '🌾',
    'potatoes': '🥔',
    'sweet potato': '🍠',
    'crackers': '🍘',
    'breadcrumbs': '🍞',
    'blintzes': '🥞',
    'pancakes': '🥞',

    // ─── Vegetables ──────────────────────────────────────────────────────────
    'broccoli': '🥦',
    'spinach': '🥬',
    'lettuce': '🥗',
    'romaine lettuce': '🥗',
    'mixed greens': '🥗',
    'tomatoes': '🍅',
    'cherry tomatoes': '🍅',
    'carrots': '🥕',
    'carrot sticks': '🥕',
    'cucumber': '🥒',
    'peppers': '🫑',
    'bell pepper': '🫑',
    'bell peppers': '🫑',
    'onions': '🧅',
    'mushrooms': '🍄',
    'cabbage': '🥬',
    'cabbage slaw': '🥬',
    'asparagus': '🌿',
    'eggplant': '🍆',
    'avocado': '🥑',
    'corn': '🌽',
    'olives': '🫒',
    'mixed vegetables': '🥗',
    'roasted veggies': '🥗',
    'grilled vegetables': '🥗',
    'root vegetables': '🥕',
    'vegetables': '🥗',
    'israeli salad': '🥗',
    'salad': '🥗',

    // ─── Fruits ──────────────────────────────────────────────────────────────
    'banana': '🍌',
    'apple': '🍎',
    'orange': '🍊',
    'berries': '🫐',
    'frozen berries': '🫐',
    'grapes': '🍇',
    'mango': '🥭',
    'watermelon': '🍉',
    'lemon': '🍋',
    'lime': '🍋',
    'apricots': '🍑',
    'dates': '🫘',
    'medjool dates': '🫘',
    'dried fruit': '🍇',

    // ─── Nuts & Seeds ────────────────────────────────────────────────────────
    'almonds': '🌰',
    'peanuts': '🥜',
    'walnuts': '🧠', // Brain shape reference
    'cashews': '🌙', // Crescent shape
    'mixed nuts': '🥜',
    'chia seeds': '🌱',
    'trail mix': '🥜',

    // ─── Condiments & Sauces ─────────────────────────────────────────────────
    'hummus': '🫘',
    'tahini': '🫘',
    'olive oil': '🫒',
    'maple syrup': '🍯',
    'honey': '🍯',
    'salsa': '🫙',
    'tomato sauce': '🫙',
    'dressing': '🫙',
    'lemon dressing': '🍋',
    'yogurt sauce': '🥛',
    'mustard': '🟡',
    'horseradish': '🟢',
    'coconut milk': '🥥',

    // ─── Prepared Foods ──────────────────────────────────────────────────────
    'fish patties': '🐟',
    'rugelach': '🥐',
    'protein powder': '💪',
    'bacon': '🥓',
  };

  // ════════════════════════════════════════════════════════════════════════════
  // CATEGORY FALLBACKS
  // ════════════════════════════════════════════════════════════════════════════

  static const Map<String, String> _categoryFallbacks = {
    'protein': '🍖',
    'meat': '🍖',
    'fish': '🐟',
    'seafood': '🦐',
    'vegetable': '🥬',
    'fruit': '🍎',
    'dairy': '🥛',
    'grain': '🌾',
    'nut': '🥜',
    'sauce': '🫙',
    'snack': '🍿',
  };

  // Pre-sorted keys for efficient keyword search (longest first)
  static List<String>? _sortedKeys;

  static List<String> get _getSortedKeys {
    _sortedKeys ??= _uniqueEmojis.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return _sortedKeys!;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════════════════════

  /// Get emoji for a food name with fallback priority:
  /// 1. Exact unique match
  /// 2. Keyword search in unique map (longest match first)
  /// 3. Category fallback
  /// 4. Generic food emoji
  static String getEmoji(String foodName, {String? category}) {
    final lowerName = foodName.toLowerCase().trim();

    // Priority 1: Exact match
    if (_uniqueEmojis.containsKey(lowerName)) {
      return _uniqueEmojis[lowerName]!;
    }

    // Priority 2: Keyword search (longest match first for specificity)
    for (final keyword in _getSortedKeys) {
      if (lowerName.contains(keyword)) {
        return _uniqueEmojis[keyword]!;
      }
    }

    // Priority 3: Category fallback
    if (category != null) {
      final lowerCategory = category.toLowerCase();
      if (_categoryFallbacks.containsKey(lowerCategory)) {
        return _categoryFallbacks[lowerCategory]!;
      }
    }

    // Priority 4: Generic food emoji
    return '🍽️';
  }

  /// Get emoji with indicator whether it's a fallback
  /// Returns (emoji, isFallback) tuple
  static (String, bool) getEmojiWithFallbackIndicator(String foodName) {
    final lowerName = foodName.toLowerCase().trim();

    // Check exact match
    if (_uniqueEmojis.containsKey(lowerName)) {
      return (_uniqueEmojis[lowerName]!, false);
    }

    // Check keyword match
    for (final keyword in _getSortedKeys) {
      if (lowerName.contains(keyword)) {
        return (_uniqueEmojis[keyword]!, false);
      }
    }

    // It's a fallback
    return (getEmoji(foodName), true);
  }

  /// Check if a specific food has a unique emoji defined
  static bool hasUniqueEmoji(String foodName) {
    final lowerName = foodName.toLowerCase().trim();

    if (_uniqueEmojis.containsKey(lowerName)) return true;

    for (final keyword in _getSortedKeys) {
      if (lowerName.contains(keyword)) return true;
    }

    return false;
  }
}
