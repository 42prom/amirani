import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../providers/storage_providers.dart';

/// Meal event types for tracking
enum MealEventType {
  completed,
  skipped,
  swapped,
}

/// A single meal history entry
class MealHistoryEntry {
  final String mealId;
  final String mealName;
  final MealType mealType;
  final MealEventType eventType;
  final DateTime date;
  final List<String> ingredients;

  MealHistoryEntry({
    required this.mealId,
    required this.mealName,
    required this.mealType,
    required this.eventType,
    required this.date,
    this.ingredients = const [],
  });

  Map<String, dynamic> toJson() => {
        'mealId': mealId,
        'mealName': mealName,
        'mealType': mealType.name,
        'eventType': eventType.name,
        'date': date.toIso8601String(),
        'ingredients': ingredients,
      };

  factory MealHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MealHistoryEntry(
      mealId: json['mealId']?.toString() ?? '',
      mealName: json['mealName']?.toString() ?? '',
      mealType: MealType.values.firstWhere(
        (e) => e.name == json['mealType'],
        orElse: () => MealType.breakfast,
      ),
      eventType: MealEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => MealEventType.completed,
      ),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Pattern data for a specific meal
class MealPattern {
  final int completionCount;
  final int skipCount;
  final int swapCount;
  final List<String> completedWithIngredients;
  final DateTime? lastCompleted;
  final DateTime? lastSkipped;

  MealPattern({
    this.completionCount = 0,
    this.skipCount = 0,
    this.swapCount = 0,
    this.completedWithIngredients = const [],
    this.lastCompleted,
    this.lastSkipped,
  });

  Map<String, dynamic> toJson() => {
        'completionCount': completionCount,
        'skipCount': skipCount,
        'swapCount': swapCount,
        'completedWithIngredients': completedWithIngredients,
        'lastCompleted': lastCompleted?.toIso8601String(),
        'lastSkipped': lastSkipped?.toIso8601String(),
      };

  factory MealPattern.fromJson(Map<String, dynamic> json) {
    return MealPattern(
      completionCount: json['completionCount'] as int? ?? 0,
      skipCount: json['skipCount'] as int? ?? 0,
      swapCount: json['swapCount'] as int? ?? 0,
      completedWithIngredients:
          (json['completedWithIngredients'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              [],
      lastCompleted: json['lastCompleted'] != null
          ? DateTime.tryParse(json['lastCompleted'].toString())
          : null,
      lastSkipped: json['lastSkipped'] != null
          ? DateTime.tryParse(json['lastSkipped'].toString())
          : null,
    );
  }

  MealPattern copyWith({
    int? completionCount,
    int? skipCount,
    int? swapCount,
    List<String>? completedWithIngredients,
    DateTime? lastCompleted,
    DateTime? lastSkipped,
  }) {
    return MealPattern(
      completionCount: completionCount ?? this.completionCount,
      skipCount: skipCount ?? this.skipCount,
      swapCount: swapCount ?? this.swapCount,
      completedWithIngredients:
          completedWithIngredients ?? this.completedWithIngredients,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      lastSkipped: lastSkipped ?? this.lastSkipped,
    );
  }

  /// Calculate preference score (positive = liked, negative = avoided)
  double get preferenceScore {
    final total = completionCount + skipCount;
    if (total == 0) return 0;
    return (completionCount - skipCount) / total;
  }
}

/// Analytics summary for the diet dashboard
class MealAnalytics {
  final int totalMeals;
  final int completedMeals;
  final int skippedMeals;
  final int swappedMeals;
  final double completionRate;
  final Map<MealType, int> mealTypeCompletion;
  final List<String> topCompletedMeals;
  final List<String> frequentlySkippedMeals;

  MealAnalytics({
    required this.totalMeals,
    required this.completedMeals,
    required this.skippedMeals,
    required this.swappedMeals,
    required this.completionRate,
    required this.mealTypeCompletion,
    required this.topCompletedMeals,
    required this.frequentlySkippedMeals,
  });
}

/// Service for tracking meal completion/skip history and learning from patterns
class MealHistoryService {
  static const String _historyKey = 'meal_history_v1';
  static const String _patternsKey = 'meal_patterns_v1';
  static const int _maxHistoryMonths = 6;

  final SharedPreferences _prefs;

  MealHistoryService(this._prefs);

  // ════════════════════════════════════════════════════════════════════════════
  // RECORDING EVENTS
  // ════════════════════════════════════════════════════════════════════════════

  /// Record a meal event (completion, skip, or swap)
  Future<void> recordMealEvent({
    required String mealId,
    required String mealName,
    required MealType mealType,
    required MealEventType eventType,
    required DateTime date,
    List<String>? ingredients,
  }) async {

    // Load current history
    final history = await _loadHistory();
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

    // Add new entry
    history[monthKey] ??= [];
    history[monthKey]!.add(MealHistoryEntry(
      mealId: mealId,
      mealName: mealName,
      mealType: mealType,
      eventType: eventType,
      date: date,
      ingredients: ingredients ?? [],
    ));

    // Prune old history to save memory
    _pruneOldHistory(history);

    // Save updated history
    await _saveHistory(history);

    // Update learned patterns
    await _updatePatterns(mealName, ingredients ?? [], eventType, date);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // QUERYING PATTERNS
  // ════════════════════════════════════════════════════════════════════════════

  /// Get meals that are frequently skipped (avoid suggesting these)
  Future<List<String>> getFrequentlySkippedMeals({int threshold = 3}) async {
    final patterns = await _loadPatterns();

    return patterns.entries
        .where((e) => e.value.skipCount >= threshold)
        .where((e) => e.value.preferenceScore < -0.3) // More skips than completions
        .map((e) => e.key)
        .toList();
  }

  /// Get meals that user tends to complete (prefer these)
  Future<List<String>> getPreferredMeals({int minCompletions = 3}) async {
    final patterns = await _loadPatterns();

    final preferred = patterns.entries
        .where((e) => e.value.completionCount >= minCompletions)
        .where((e) => e.value.preferenceScore > 0.3) // More completions than skips
        .toList()
      ..sort((a, b) =>
          b.value.preferenceScore.compareTo(a.value.preferenceScore));

    return preferred.map((e) => e.key).toList();
  }

  /// Get ingredients user tends to complete (prioritize meals with these)
  Future<List<String>> getPreferredIngredients({int minOccurrences = 5}) async {
    final patterns = await _loadPatterns();

    final ingredientScores = <String, int>{};

    for (final pattern in patterns.values) {
      for (final ingredient in pattern.completedWithIngredients) {
        ingredientScores[ingredient] =
            (ingredientScores[ingredient] ?? 0) + 1;
      }
    }

    return ingredientScores.entries
        .where((e) => e.value >= minOccurrences)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) =>
          ingredientScores[b]!.compareTo(ingredientScores[a]!));
  }

  /// Check if a specific meal is frequently skipped
  Future<bool> isMealFrequentlySkipped(String mealName,
      {int threshold = 3}) async {
    final patterns = await _loadPatterns();

    final pattern = patterns[mealName.toLowerCase()];
    if (pattern == null) return false;

    return pattern.skipCount >= threshold && pattern.preferenceScore < -0.3;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ANALYTICS
  // ════════════════════════════════════════════════════════════════════════════

  /// Get analytics summary for the dashboard
  Future<MealAnalytics> getAnalytics({int months = 1}) async {
    final history = await _loadHistory();
    final patterns = await _loadPatterns();

    int totalMeals = 0;
    int completedMeals = 0;
    int skippedMeals = 0;
    int swappedMeals = 0;
    final mealTypeCompletion = <MealType, int>{};

    final cutoff = DateTime.now().subtract(Duration(days: months * 30));

    for (final monthData in history.values) {
      for (final entry in monthData) {
        if (entry.date.isAfter(cutoff)) {
          totalMeals++;
          switch (entry.eventType) {
            case MealEventType.completed:
              completedMeals++;
              mealTypeCompletion[entry.mealType] =
                  (mealTypeCompletion[entry.mealType] ?? 0) + 1;
              break;
            case MealEventType.skipped:
              skippedMeals++;
              break;
            case MealEventType.swapped:
              swappedMeals++;
              break;
          }
        }
      }
    }

    // Get top completed meals
    final topCompleted = patterns.entries
        .where((e) => e.value.completionCount > 0)
        .toList()
      ..sort((a, b) =>
          b.value.completionCount.compareTo(a.value.completionCount));

    // Get frequently skipped meals
    final frequentlySkipped = patterns.entries
        .where((e) => e.value.skipCount >= 3 && e.value.preferenceScore < -0.3)
        .map((e) => e.key)
        .toList();

    return MealAnalytics(
      totalMeals: totalMeals,
      completedMeals: completedMeals,
      skippedMeals: skippedMeals,
      swappedMeals: swappedMeals,
      completionRate: totalMeals > 0 ? completedMeals / totalMeals : 0,
      mealTypeCompletion: mealTypeCompletion,
      topCompletedMeals: topCompleted.take(5).map((e) => e.key).toList(),
      frequentlySkippedMeals: frequentlySkipped,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, List<MealHistoryEntry>>> _loadHistory() async {
    final jsonStr = _prefs.getString(_historyKey);
    if (jsonStr == null) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((key, value) {
        final entries = (value as List<dynamic>)
            .map((e) => MealHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        return MapEntry(key, entries);
      });
    } catch (e) {
      return {};
    }
  }

  Future<void> _saveHistory(
      Map<String, List<MealHistoryEntry>> history) async {
    final encoded = history.map((key, value) {
      return MapEntry(key, value.map((e) => e.toJson()).toList());
    });
    await _prefs.setString(_historyKey, jsonEncode(encoded));
  }

  Future<Map<String, MealPattern>> _loadPatterns() async {
    final jsonStr = _prefs.getString(_patternsKey);
    if (jsonStr == null) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((key, value) {
        return MapEntry(key, MealPattern.fromJson(value as Map<String, dynamic>));
      });
    } catch (e) {
      return {};
    }
  }

  Future<void> _savePatterns(Map<String, MealPattern> patterns) async {
    final encoded = patterns.map((key, value) => MapEntry(key, value.toJson()));
    await _prefs.setString(_patternsKey, jsonEncode(encoded));
  }

  Future<void> _updatePatterns(
    String mealName,
    List<String> ingredients,
    MealEventType eventType,
    DateTime date,
  ) async {
    final patterns = await _loadPatterns();
    final key = mealName.toLowerCase();

    final existing = patterns[key] ?? MealPattern();

    MealPattern updated;
    switch (eventType) {
      case MealEventType.completed:
        // Add new ingredients to the list (avoiding duplicates)
        final allIngredients = <String>{
          ...existing.completedWithIngredients,
          ...ingredients.map((e) => e.toLowerCase()),
        }.toList();

        updated = existing.copyWith(
          completionCount: existing.completionCount + 1,
          completedWithIngredients: allIngredients,
          lastCompleted: date,
        );
        break;
      case MealEventType.skipped:
        updated = existing.copyWith(
          skipCount: existing.skipCount + 1,
          lastSkipped: date,
        );
        break;
      case MealEventType.swapped:
        updated = existing.copyWith(
          swapCount: existing.swapCount + 1,
        );
        break;
    }

    patterns[key] = updated;
    await _savePatterns(patterns);
  }

  void _pruneOldHistory(Map<String, List<MealHistoryEntry>> history) {
    final now = DateTime.now();
    final cutoffDate = DateTime(
      now.year,
      now.month - _maxHistoryMonths,
      1,
    );
    final cutoffKey =
        '${cutoffDate.year}-${cutoffDate.month.toString().padLeft(2, '0')}';

    // Remove months older than cutoff
    history.removeWhere((key, _) => key.compareTo(cutoffKey) < 0);
  }

  /// Clear all history (for testing or user request)
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
    await _prefs.remove(_patternsKey);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDER
// ════════════════════════════════════════════════════════════════════════════

/// Provider for meal history service
final mealHistoryServiceProvider = Provider<MealHistoryService>((ref) {
  return MealHistoryService(ref.watch(sharedPreferencesProvider));
});
