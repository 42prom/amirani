class FoodSearchResult {
  final String? id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double servingGrams;
  final String? servingUnit;
  final String? barcode;
  final String? source;
  final String? imageUrl;

  const FoodSearchResult({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.servingGrams,
    this.servingUnit,
    this.barcode,
    this.source,
    this.imageUrl,
  });

  factory FoodSearchResult.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return FoodSearchResult(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      calories: toD(json['caloriesPer100g'] ?? json['calories']),
      protein: toD(json['proteinPer100g'] ?? json['protein']),
      carbs: toD(json['carbsPer100g'] ?? json['carbs']),
      fats: toD(json['fatsPer100g'] ?? json['fats']),
      servingGrams: toD(json['servingGrams'] ?? 100),
      servingUnit: json['servingUnit'] as String?,
      barcode: json['barcode'] as String?,
      source: json['source'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  FoodSearchResult copyWith({double? servingGrams}) => FoodSearchResult(
        id: id,
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fats: fats,
        servingGrams: servingGrams ?? this.servingGrams,
        servingUnit: servingUnit,
        barcode: barcode,
        source: source,
        imageUrl: imageUrl,
      );

  double get scaledCalories => calories * servingGrams / 100;
  double get scaledProtein => protein * servingGrams / 100;
  double get scaledCarbs => carbs * servingGrams / 100;
  double get scaledFats => fats * servingGrams / 100;
}

class FoodLogEntry {
  final String id;
  final String foodName;
  final double grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final String mealType;
  final DateTime loggedAt;

  const FoodLogEntry({
    required this.id,
    required this.foodName,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.mealType,
    required this.loggedAt,
  });

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final item = json['foodItem'] as Map<String, dynamic>?;
    final name = json['foodName'] as String? ??
        item?['name'] as String? ??
        'Unknown Food';

    return FoodLogEntry(
      id: json['id'] as String? ?? '',
      foodName: name,
      grams: toD(json['grams']),
      calories: toD(json['calories']),
      protein: toD(json['protein']),
      carbs: toD(json['carbs']),
      fats: toD(json['fats']),
      mealType: json['mealType'] as String? ?? 'SNACK',
      loggedAt: json['loggedAt'] != null
          ? DateTime.tryParse(json['loggedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class FoodDiaryMealGroup {
  final String mealType;
  final List<FoodLogEntry> entries;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;

  const FoodDiaryMealGroup({
    required this.mealType,
    required this.entries,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
  });

  factory FoodDiaryMealGroup.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    return FoodDiaryMealGroup(
      mealType: json['mealType'] as String? ?? 'SNACK',
      entries: rawEntries
          .map((e) => FoodLogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCalories: toD(json['totalCalories']),
      totalProtein: toD(json['totalProtein']),
      totalCarbs: toD(json['totalCarbs']),
      totalFats: toD(json['totalFats']),
    );
  }
}

class FoodDiary {
  final String date;
  final List<FoodDiaryMealGroup> meals;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;

  const FoodDiary({
    required this.date,
    required this.meals,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
  });

  factory FoodDiary.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final rawMeals = json['meals'] as List<dynamic>? ?? [];
    return FoodDiary(
      date: json['date'] as String? ?? '',
      meals: rawMeals
          .map((m) => FoodDiaryMealGroup.fromJson(m as Map<String, dynamic>))
          .toList(),
      totalCalories: toD(json['totalCalories']),
      totalProtein: toD(json['totalProtein']),
      totalCarbs: toD(json['totalCarbs']),
      totalFats: toD(json['totalFats']),
    );
  }

  bool get isEmpty => meals.every((m) => m.entries.isEmpty);
}
