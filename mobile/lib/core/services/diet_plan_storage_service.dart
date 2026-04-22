import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../features/diet/domain/entities/diet_preferences_entity.dart';
import '../data/local_db_service.dart';

/// Local storage service for diet plans.
/// Uses a Hive `Box<String>` (JSON strings) for binary-safe, high-performance
/// persistence — same public API as before, no SharedPreferences.
class DietPlanStorageService {
  static const String _planKey = 'saved_diet_plan';
  static const String _preferencesKey = 'saved_diet_preferences';
  static const String _lastUpdatedKey = 'diet_plan_last_updated';
  static const String _pantryKey = 'virtual_pantry_data';
  static const String _shoppingRangeKey = 'shopping_days_range';
  static const String _isAIGeneratedKey = 'diet_plan_is_ai_generated';
  static const String _shoppingChecksKey = 'shopping_list_checks';

  /// Save monthly diet plan to local storage
  Future<bool> savePlan(MonthlyDietPlanEntity plan) async {
    try {
      final box = LocalDBService.dietBox;
      await box.put(_planKey, jsonEncode(_planToJson(plan)));
      await box.put(_lastUpdatedKey, DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load monthly diet plan from local storage
  Future<MonthlyDietPlanEntity?> loadPlan() async {
    try {
      final jsonString = LocalDBService.dietBox.get(_planKey);
      if (jsonString == null) return null;
      return _planFromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Check if a plan exists
  Future<bool> hasSavedPlan() async {
    return LocalDBService.dietBox.containsKey(_planKey);
  }

  /// Save whether the active diet plan was AI-generated (true) or trainer-assigned (false).
  Future<void> saveIsAIGenerated(bool value) async {
    await LocalDBService.dietBox.put(_isAIGeneratedKey, value.toString());
  }

  /// Load attribution flag saved alongside the diet plan.
  Future<bool> loadIsAIGenerated() async {
    return LocalDBService.dietBox.get(_isAIGeneratedKey) == 'true';
  }

  /// Get last updated timestamp
  Future<DateTime?> getLastUpdated() async {
    final timestamp = LocalDBService.dietBox.get(_lastUpdatedKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// Delete saved plan
  Future<bool> deletePlan() async {
    try {
      final box = LocalDBService.dietBox;
      await box.delete(_planKey);
      await box.delete(_lastUpdatedKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save diet preferences
  Future<bool> savePreferences(DietPreferencesEntity preferences) async {
    try {
      await LocalDBService.dietBox
          .put(_preferencesKey, jsonEncode(_preferencesToJson(preferences)));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load diet preferences
  Future<DietPreferencesEntity?> loadPreferences() async {
    try {
      final jsonString = LocalDBService.dietBox.get(_preferencesKey);
      if (jsonString == null) return null;
      return _preferencesFromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Save virtual pantry data
  Future<bool> savePantry(Map<String, double> pantry) async {
    try {
      await LocalDBService.dietBox.put(_pantryKey, jsonEncode(pantry));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load virtual pantry data
  Future<Map<String, double>?> loadPantry() async {
    try {
      final jsonString = LocalDBService.dietBox.get(_pantryKey);
      if (jsonString == null) return null;
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((key, value) => MapEntry(key, (value as num).toDouble()));
    } catch (e) {
      return null;
    }
  }

  /// Save shopping range
  Future<bool> saveShoppingRange(int days) async {
    try {
      await LocalDBService.dietBox.put(_shoppingRangeKey, days.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load shopping range
  Future<int?> loadShoppingRange() async {
    try {
      final value = LocalDBService.dietBox.get(_shoppingRangeKey);
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      return null;
    }
  }

  /// Save shopping list checkboxes
  Future<bool> saveShoppingChecks(Map<String, bool> checks) async {
    try {
      await LocalDBService.dietBox.put(_shoppingChecksKey, jsonEncode(checks));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load shopping list checkboxes
  Future<Map<String, bool>?> loadShoppingChecks() async {
    try {
      final jsonString = LocalDBService.dietBox.get(_shoppingChecksKey);
      if (jsonString == null) return null;
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((key, value) => MapEntry(key, value as bool));
    } catch (e) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // JOB ID — survives app restarts so polling can resume after a relaunch
  // ════════════════════════════════════════════════════════════════════════════

  static const String _jobIdKey = 'diet_pending_job_id';

  Future<void> saveJobId(String jobId) async {
    await LocalDBService.dietBox.put(_jobIdKey, jobId);
  }

  Future<String?> loadJobId() async {
    return LocalDBService.dietBox.get(_jobIdKey);
  }

  Future<void> clearJobId() async {
    await LocalDBService.dietBox.delete(_jobIdKey);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // JSON SERIALIZATION - PLAN
  // ════════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _planToJson(MonthlyDietPlanEntity plan) {
    return {
      // W6: Version stamp — enables stale plan detection on schema changes
      'schemaVersion': 'v1',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'id': plan.id,
      'odUserId': plan.odUserId,
      'startDate': plan.startDate.toIso8601String(),
      'endDate': plan.endDate.toIso8601String(),
      'goal': plan.goal.name,
      'macroTarget': {
        'calories': plan.macroTarget.calories,
        'protein': plan.macroTarget.protein,
        'carbs': plan.macroTarget.carbs,
        'fats': plan.macroTarget.fats,
      },
      'weeks': plan.weeks.map((w) => _weekToJson(w)).toList(),
      'shoppingLists':
          plan.shoppingLists.map((s) => _shoppingListToJson(s)).toList(),
      'createdAt': plan.createdAt?.toIso8601String(),
      'updatedAt': plan.updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _weekToJson(WeeklyPlanEntity week) {
    return {
      'weekNumber': week.weekNumber,
      'startDate': week.startDate.toIso8601String(),
      'endDate': week.endDate.toIso8601String(),
      'days': week.days.map((d) => _dayToJson(d)).toList(),
    };
  }

  Map<String, dynamic> _dayToJson(DailyPlanEntity day) {
    return {
      'id': day.id,
      'date': day.date.toIso8601String(),
      'meals': day.meals.map((m) => _mealToJson(m)).toList(),
      'targetCalories': day.targetCalories,
      'targetProtein': day.targetProtein,
      'targetCarbs': day.targetCarbs,
      'targetFats': day.targetFats,
    };
  }

  Map<String, dynamic> _mealToJson(PlannedMealEntity meal) {
    return {
      'id': meal.id,
      'type': meal.type.name,
      'name': meal.name,
      'description': meal.description,
      'ingredients': meal.ingredients.map((i) => _ingredientToJson(i)).toList(),
      'instructions': meal.instructions,
      'prepTimeMinutes': meal.prepTimeMinutes,
      'nutrition': {
        'calories': meal.nutrition.calories,
        'protein': meal.nutrition.protein,
        'carbs': meal.nutrition.carbs,
        'fats': meal.nutrition.fats,
        'fiber': meal.nutrition.fiber,
        'sugar': meal.nutrition.sugar,
        'sodium': meal.nutrition.sodium,
      },
      'imageUrl': meal.imageUrl,
      'scheduledTime': meal.scheduledTime,
      'isCompleted': meal.isCompleted,
      'isSwapped': meal.isSwapped,
      'isSkipped': meal.isSkipped,
      'completedAt': meal.completedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _ingredientToJson(IngredientEntity ingredient) {
    return {
      'name': ingredient.name,
      // W3b: Persist canonicalName for shopping dedup after reload
      if (ingredient.canonicalName != null) 'canonicalName': ingredient.canonicalName,
      'amount': ingredient.amount,
      'unit': ingredient.unit,
      'calories': ingredient.calories,
      'protein': ingredient.protein,
      'carbs': ingredient.carbs,
      'fats': ingredient.fats,
    };
  }

  Map<String, dynamic> _shoppingListToJson(ShoppingListEntity list) {
    return {
      'weekNumber': list.weekNumber,
      'items': list.items
          .map((i) => <String, dynamic>{
                'name': i.name,
                'amount': i.amount,
                'unit': i.unit,
                'category': i.category,
                'isPurchased': i.isPurchased,
              })
          .toList(),
    };
  }

  // ════════════════════════════════════════════════════════════════════════════
  // JSON DESERIALIZATION - PLAN
  // ════════════════════════════════════════════════════════════════════════════

  MonthlyDietPlanEntity _planFromJson(Map<String, dynamic> json) {
    final macroTarget = json['macroTarget'] as Map<String, dynamic>? ?? {};
    return MonthlyDietPlanEntity(
      id: json['id']?.toString() ?? '',
      odUserId: json['odUserId']?.toString() ?? '',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      goal: DietGoal.values.firstWhere((g) => g.name == json['goal'],
          orElse: () => DietGoal.generalHealth),
      macroTarget: DailyMacroTargetEntity(
        calories: (macroTarget['calories'] as num?)?.toInt() ?? 0,
        protein: (macroTarget['protein'] as num?)?.toInt() ?? 0,
        carbs: (macroTarget['carbs'] as num?)?.toInt() ?? 0,
        fats: (macroTarget['fats'] as num?)?.toInt() ?? 0,
      ),
      weeks: ((json['weeks'] as List?) ?? [])
          .map((w) => _weekFromJson(w as Map<String, dynamic>))
          .toList(),
      shoppingLists: ((json['shoppingLists'] as List?) ?? [])
          .map((s) => _shoppingListFromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  WeeklyPlanEntity _weekFromJson(Map<String, dynamic> json) {
    return WeeklyPlanEntity(
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      days: ((json['days'] as List?) ?? [])
          .map((d) => _dayFromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  DailyPlanEntity _dayFromJson(Map<String, dynamic> json) {
    return DailyPlanEntity(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      meals: ((json['meals'] as List?) ?? [])
          .map((m) => _mealFromJson(m as Map<String, dynamic>))
          .toList(),
      targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 0,
      targetProtein: (json['targetProtein'] as num?)?.toInt() ?? 0,
      targetCarbs: (json['targetCarbs'] as num?)?.toInt() ?? 0,
      targetFats: (json['targetFats'] as num?)?.toInt() ?? 0,
    );
  }

  PlannedMealEntity _mealFromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition'] as Map<String, dynamic>? ?? {};
    return PlannedMealEntity(
      id: json['id']?.toString() ?? '',
      type: MealType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MealType.breakfast,
      ),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      ingredients: ((json['ingredients'] as List?) ?? [])
          .map((i) => _ingredientFromJson(i as Map<String, dynamic>))
          .toList(),
      instructions: json['instructions']?.toString() ?? '',
      prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt() ?? 15,
      nutrition: NutritionInfoEntity(
        calories: (nutrition['calories'] as num?)?.toInt() ?? 0,
        protein: (nutrition['protein'] as num?)?.toInt() ?? 0,
        carbs: (nutrition['carbs'] as num?)?.toInt() ?? 0,
        fats: (nutrition['fats'] as num?)?.toInt() ?? 0,
        fiber: nutrition['fiber'] != null ? (nutrition['fiber'] as num?)?.toInt() : null,
        sugar: nutrition['sugar'] != null ? (nutrition['sugar'] as num?)?.toInt() : null,
        sodium: nutrition['sodium'] != null ? (nutrition['sodium'] as num?)?.toInt() : null,
      ),
      imageUrl: json['imageUrl'] as String?,
      scheduledTime: json['scheduledTime'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isSwapped: json['isSwapped'] as bool? ?? false,
      isSkipped: json['isSkipped'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  IngredientEntity _ingredientFromJson(Map<String, dynamic> json) {
    return IngredientEntity(
      name: json['name'] as String? ?? 'Unknown',
      // W3b: Restore canonicalName from persisted JSON
      canonicalName: json['canonicalName'] as String?,
      amount: json['amount']?.toString() ?? '100',
      unit: json['unit']?.toString() ?? 'g',
      // W4: Default to 0 — macros are now non-optional in IngredientEntity
      calories: json['calories'] != null ? (json['calories'] as num).toInt() : 0,
      protein: json['protein'] != null ? (json['protein'] as num).toInt() : 0,
      carbs: json['carbs'] != null ? (json['carbs'] as num).toInt() : 0,
      fats: json['fats'] != null ? (json['fats'] as num).toInt() : 0,
    );
  }

  ShoppingListEntity _shoppingListFromJson(Map<String, dynamic> json) {
    return ShoppingListEntity(
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
      items: ((json['items'] as List?) ?? []).map((i) {
        final item = i as Map<String, dynamic>;
        return ShoppingItemEntity(
          name: item['name']?.toString() ?? '',
          amount: item['amount']?.toString() ?? '',
          unit: item['unit']?.toString() ?? '',
          category: item['category']?.toString() ?? '',
          isPurchased: item['isPurchased'] as bool? ?? false,
        );
      }).toList(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // JSON SERIALIZATION - PREFERENCES
  // ════════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _preferencesToJson(DietPreferencesEntity prefs) {
    return {
      'odUserId': prefs.odUserId,
      'goal': prefs.goal.name,
      'targetWeightChangePerWeek': prefs.targetWeightChangePerWeek,
      'dietaryStyle': prefs.dietaryStyle.name,
      'allergies': prefs.allergies
          .map((a) => <String, dynamic>{
                'type': a.type.name,
                'severity': a.severity.name,
                'customName': a.customName,
                'notes': a.notes,
              })
          .toList(),
      'likedFoods': prefs.likedFoods,
      'dislikedFoods': prefs.dislikedFoods,
      'mealsPerDay': prefs.mealsPerDay,
      'cookingSkill': prefs.cookingSkill.name,
      'maxPrepTimeMinutes': prefs.maxPrepTimeMinutes,
      'budget': prefs.budget.name,
      'mealRemindersEnabled': prefs.mealRemindersEnabled,
      'breakfastTime': prefs.breakfastTime,
      'lunchTime': prefs.lunchTime,
      'dinnerTime': prefs.dinnerTime,
      'morningSnackTime': prefs.morningSnackTime,
      'afternoonSnackTime': prefs.afternoonSnackTime,
      'createdAt': prefs.createdAt?.toIso8601String(),
      'updatedAt': prefs.updatedAt?.toIso8601String(),
    };
  }

  DietPreferencesEntity _preferencesFromJson(Map<String, dynamic> json) {
    return DietPreferencesEntity(
      odUserId: json['odUserId']?.toString() ?? '',
      goal: DietGoal.values.firstWhere((g) => g.name == json['goal'],
          orElse: () => DietGoal.generalHealth),
      targetWeightChangePerWeek: json['targetWeightChangePerWeek'] as double?,
      dietaryStyle: DietaryStyle.values.firstWhere(
        (s) => s.name == json['dietaryStyle'],
        orElse: () => DietaryStyle.values.first,
      ),
      allergies: (json['allergies'] as List?)?.map((a) {
            final allergy = a as Map<String, dynamic>;
            return UserAllergyEntity(
              type: AllergyType.values.firstWhere(
                (t) => t.name == allergy['type'],
                orElse: () => AllergyType.values.first,
              ),
              severity: AllergySeverity.values.firstWhere(
                (s) => s.name == allergy['severity'],
                orElse: () => AllergySeverity.values.first,
              ),
              customName: allergy['customName'] as String?,
              notes: allergy['notes'] as String?,
            );
          }).toList() ??
          [],
      likedFoods: List<String>.from(json['likedFoods'] ?? []),
      dislikedFoods: List<String>.from(json['dislikedFoods'] ?? []),
      mealsPerDay: json['mealsPerDay'] != null
          ? (json['mealsPerDay'] as num).toInt()
          : 3,
      cookingSkill:
          CookingSkill.values.firstWhere((s) => s.name == json['cookingSkill']),
      maxPrepTimeMinutes: json['maxPrepTimeMinutes'] != null
          ? (json['maxPrepTimeMinutes'] as num).toInt()
          : 30,
      budget:
          BudgetPreference.values.firstWhere((b) => b.name == json['budget']),
      mealRemindersEnabled: json['mealRemindersEnabled'] as bool? ?? true,
      breakfastTime: json['breakfastTime'] as String?,
      lunchTime: json['lunchTime'] as String?,
      dinnerTime: json['dinnerTime'] as String?,
      morningSnackTime: json['morningSnackTime'] as String?,
      afternoonSnackTime:
          json['afternoonSnackTime'] as String? ?? json['snackTime'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

/// Provider for diet plan storage service
final dietPlanStorageProvider = Provider<DietPlanStorageService>((ref) {
  return DietPlanStorageService();
});

/// Provider for the saved diet plan (auto-loads from storage)
final savedDietPlanProvider =
    FutureProvider<MonthlyDietPlanEntity?>((ref) async {
  final storage = ref.watch(dietPlanStorageProvider);
  return await storage.loadPlan();
});

/// Provider for checking if plan exists
final hasSavedPlanProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(dietPlanStorageProvider);
  return await storage.hasSavedPlan();
});
