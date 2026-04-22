import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/storage_providers.dart';

/// Workout event types for tracking
enum WorkoutEventType {
  completed,
  skipped,
  partiallyCompleted,
}

/// A single workout history entry
class WorkoutHistoryEntry {
  final String routineId;
  final String routineName;
  final WorkoutEventType eventType;
  final DateTime date;
  final int completedExerciseCount;
  final int totalExerciseCount;
  final int durationMinutes;

  WorkoutHistoryEntry({
    required this.routineId,
    required this.routineName,
    required this.eventType,
    required this.date,
    required this.completedExerciseCount,
    required this.totalExerciseCount,
    this.durationMinutes = 0,
  });

  Map<String, dynamic> toJson() => {
        'routineId': routineId,
        'routineName': routineName,
        'eventType': eventType.name,
        'date': date.toIso8601String(),
        'completedExerciseCount': completedExerciseCount,
        'totalExerciseCount': totalExerciseCount,
        'durationMinutes': durationMinutes,
      };

  factory WorkoutHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WorkoutHistoryEntry(
      routineId: json['routineId']?.toString() ?? '',
      routineName: json['routineName']?.toString() ?? '',
      eventType: WorkoutEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => WorkoutEventType.completed,
      ),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      completedExerciseCount: (json['completedExerciseCount'] as num?)?.toInt() ?? 0,
      totalExerciseCount: (json['totalExerciseCount'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service for tracking workout completion history locally
class WorkoutHistoryService {
  static const String _historyKey = 'workout_history_v1';

  final SharedPreferences _prefs;

  WorkoutHistoryService(this._prefs);

  /// Record a workout event
  Future<void> recordWorkoutEvent({
    required String routineId,
    required String routineName,
    required WorkoutEventType eventType,
    required DateTime date,
    required int completedExerciseCount,
    required int totalExerciseCount,
    int durationMinutes = 0,
  }) async {
    final history = await _loadHistory();
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

    history[monthKey] ??= [];
    history[monthKey]!.add(WorkoutHistoryEntry(
      routineId: routineId,
      routineName: routineName,
      eventType: eventType,
      date: date,
      completedExerciseCount: completedExerciseCount,
      totalExerciseCount: totalExerciseCount,
      durationMinutes: durationMinutes,
    ));

    await _saveHistory(history);
  }

  /// Get history for a specific month
  Future<List<WorkoutHistoryEntry>> getHistoryForMonth(int year, int month) async {
    final history = await _loadHistory();
    final monthKey = '$year-${month.toString().padLeft(2, '0')}';
    return history[monthKey] ?? [];
  }

  Future<Map<String, List<WorkoutHistoryEntry>>> _loadHistory() async {
    final jsonStr = _prefs.getString(_historyKey);
    if (jsonStr == null) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((key, value) {
        final entries = (value as List<dynamic>)
            .map((e) => WorkoutHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        return MapEntry(key, entries);
      });
    } catch (e) {
      return {};
    }
  }

  Future<void> _saveHistory(Map<String, List<WorkoutHistoryEntry>> history) async {
    final encoded = history.map((key, value) {
      return MapEntry(key, value.map((e) => e.toJson()).toList());
    });
    await _prefs.setString(_historyKey, jsonEncode(encoded));
  }

  /// Clear all history
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }
}

final workoutHistoryServiceProvider = Provider<WorkoutHistoryService>((ref) {
  return WorkoutHistoryService(ref.watch(sharedPreferencesProvider));
});
