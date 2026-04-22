import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_db_service.dart';
import '../../features/workout/domain/entities/monthly_workout_plan_entity.dart';
import '../../features/workout/domain/entities/workout_preferences_entity.dart';

/// Local storage service for workout plans
/// Provides persistent storage for monthly workout plans
/// Uses Hive for high-performance binary storage
class WorkoutPlanStorageService {
  static const String _planId = 'active_monthly_plan';
  static const String _prefsId = 'user_workout_preferences';
  // Job IDs and schema version strings go in kvBox (the generic KV store)
  // because workoutBox is typed as Box<MonthlyWorkoutPlanEntity> and cannot hold strings.
  static const String _jobIdKey = 'workout_pending_job_id';
  // W13: Schema version stamp — auto-clear on mismatch after app updates
  static const String _schemaVersionKey = 'workout_schema_version';
  static const String _currentSchemaVersion = '1';

  // W14: In-memory write-through cache — eliminates race conditions on rapid
  // set taps. Reads hit memory (microseconds). Writes persist async to Hive.
  MonthlyWorkoutPlanEntity? _cached;

  /// Save monthly workout plan to local storage
  Future<bool> savePlan(MonthlyWorkoutPlanEntity plan) async {
    try {
      _cached = plan; // W14: Update cache immediately (synchronous — no race)
      await LocalDBService.workoutBox.put(_planId, plan);
      // W13: Stamp schema version in kvBox (string KV) since workoutBox is typed
      await LocalDBService.kvBox.put(_schemaVersionKey, _currentSchemaVersion);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load monthly workout plan from local storage
  Future<MonthlyWorkoutPlanEntity?> loadPlan() async {
    // W14: Return cached plan if available (avoids disk reads on rapid calls)
    if (_cached != null) return _cached;
    try {
      // W13: Schema version guard — auto-clear if adapter mismatch after update.
      // Version key is stored in kvBox (string KV) since workoutBox is typed.
      final savedVersion = LocalDBService.kvBox.get(_schemaVersionKey);
      if (savedVersion != null && savedVersion != _currentSchemaVersion) {
        debugPrint('[WorkoutStorage] Schema mismatch (saved=$savedVersion, current=$_currentSchemaVersion) — clearing stale plan');
        await deletePlan();
        return null;
      }
      final plan = LocalDBService.workoutBox.get(_planId);
      // W13: Validate minimum structural integrity after deserialization
      if (plan != null && (plan.id.isEmpty || plan.weeks.isEmpty)) {
        debugPrint('[WorkoutStorage] Corrupt plan detected (empty id or weeks) — clearing');
        await deletePlan();
        return null;
      }
      _cached = plan;
      return plan;
    } catch (e) {
      // W13: Hive type adapter mismatch after app update — clear and return null
      // rather than crashing. UI will show empty state and trigger re-generation.
      debugPrint('[WorkoutStorage] Deserialization error — clearing stale plan: $e');
      await deletePlan();
      return null;
    }
  }

  /// Check if a plan exists — cache-first for consistency with loadPlan().
  Future<bool> hasSavedPlan() async {
    // Issue 5: if cache is warm, we already know a plan exists.
    // Avoids a disk read and keeps hasSavedPlan() consistent with loadPlan().
    if (_cached != null) return true;
    return LocalDBService.workoutBox.containsKey(_planId);
  }

  /// Get last updated timestamp
  Future<DateTime?> getLastUpdated() async {
    final plan = await loadPlan();
    return plan?.updatedAt;
  }

  /// Delete saved plan
  Future<bool> deletePlan() async {
    try {
      _cached = null; // W14: Clear cache on delete
      await LocalDBService.workoutBox.delete(_planId);
      await LocalDBService.kvBox.delete(_schemaVersionKey); // stored in kvBox
      return true;
    } catch (e) {
      return false;
    }
  }

  // W7: Job IDs are strings — they must go in kvBox (dynamic KV box), NOT in
  // workoutBox which is typed as Box<MonthlyWorkoutPlanEntity>. Collision risk is
  // eliminated by the namespaced key prefix 'workout_pending_job_id'.
  Future<void> saveJobId(String jobId) async {
    await LocalDBService.kvBox.put(_jobIdKey, jobId);
  }

  Future<String?> loadJobId() async {
    return LocalDBService.kvBox.get(_jobIdKey);
  }

  Future<void> clearJobId() async {
    await LocalDBService.kvBox.delete(_jobIdKey);
  }

  /// Save workout preferences
  Future<bool> savePreferences(WorkoutPreferencesEntity preferences) async {
    try {
      await LocalDBService.preferencesBox.put(_prefsId, preferences);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load workout preferences
  Future<WorkoutPreferencesEntity?> loadPreferences() async {
    try {
      return LocalDBService.preferencesBox.get(_prefsId);
    } catch (e) {
      return null;
    }
  }

  /// Update a single exercise completion status
  Future<bool> updateExerciseCompletion({
    required DateTime date,
    required String exerciseId,
    required bool isCompleted,
  }) async {
    final plan = await loadPlan();
    if (plan == null) return false;

    // Find the day and exercise
    for (int wi = 0; wi < plan.weeks.length; wi++) {
      for (int di = 0; di < plan.weeks[wi].days.length; di++) {
        final day = plan.weeks[wi].days[di];
        if (day.date.year == date.year &&
            day.date.month == date.month &&
            day.date.day == date.day) {
          // Found the day, now find the exercise
          for (int ei = 0; ei < day.exercises.length; ei++) {
            if (day.exercises[ei].id == exerciseId) {
              // Update the exercise
              final updatedExercise = day.exercises[ei].copyWith(
                isCompleted: isCompleted,
                completedAt: isCompleted ? DateTime.now() : null,
              );

              // Rebuild the structure
              final updatedExercises = List<PlannedExerciseEntity>.from(day.exercises);
              updatedExercises[ei] = updatedExercise;

              final updatedDay = day.copyWith(
                exercises: updatedExercises,
                isCompleted: updatedExercises.every((e) => e.isCompleted),
                completedAt: updatedExercises.every((e) => e.isCompleted) ? DateTime.now() : null,
              );

              final updatedDays = List<DailyWorkoutPlanEntity>.from(plan.weeks[wi].days);
              updatedDays[di] = updatedDay;

              final updatedWeek = plan.weeks[wi].copyWith(days: updatedDays);

              final updatedWeeks = List<WeeklyWorkoutPlanEntity>.from(plan.weeks);
              updatedWeeks[wi] = updatedWeek;

              final updatedPlan = plan.copyWith(weeks: updatedWeeks);
              return await savePlan(updatedPlan);
            }
          }
        }
      }
    }
    return false;
  }

  /// Mark all sets of an exercise as complete in one operation
  Future<bool> markAllSetsComplete({
    required DateTime date,
    required String exerciseId,
  }) async {
    final plan = await loadPlan();
    if (plan == null) return false;

    for (int wi = 0; wi < plan.weeks.length; wi++) {
      for (int di = 0; di < plan.weeks[wi].days.length; di++) {
        final day = plan.weeks[wi].days[di];
        if (day.date.year == date.year &&
            day.date.month == date.month &&
            day.date.day == date.day) {
          for (int ei = 0; ei < day.exercises.length; ei++) {
            if (day.exercises[ei].id == exerciseId) {
              final exercise = day.exercises[ei];
              final allDone = exercise.sets.map((s) => s.copyWith(isCompleted: true)).toList();
              final updatedExercise = exercise.copyWith(
                sets: allDone,
                isCompleted: true,
                completedAt: DateTime.now(),
              );
              final updatedExercises = List<PlannedExerciseEntity>.from(day.exercises);
              updatedExercises[ei] = updatedExercise;
              final updatedDay = day.copyWith(
                exercises: updatedExercises,
                isCompleted: updatedExercises.every((e) => e.isCompleted),
                completedAt: updatedExercises.every((e) => e.isCompleted) ? DateTime.now() : null,
              );
              final updatedDays = List<DailyWorkoutPlanEntity>.from(plan.weeks[wi].days);
              updatedDays[di] = updatedDay;
              final updatedWeek = plan.weeks[wi].copyWith(days: updatedDays);
              final updatedWeeks = List<WeeklyWorkoutPlanEntity>.from(plan.weeks);
              updatedWeeks[wi] = updatedWeek;
              return await savePlan(plan.copyWith(weeks: updatedWeeks));
            }
          }
        }
      }
    }
    return false;
  }

  /// Swap an exercise with a new one
  Future<bool> swapExercise({
    required DateTime date,
    required String oldExerciseId,
    required PlannedExerciseEntity newExercise,
  }) async {
    final plan = await loadPlan();
    if (plan == null) return false;

    for (int wi = 0; wi < plan.weeks.length; wi++) {
      for (int di = 0; di < plan.weeks[wi].days.length; di++) {
        final day = plan.weeks[wi].days[di];
        if (day.date.year == date.year &&
            day.date.month == date.month &&
            day.date.day == date.day) {
          
          for (int ei = 0; ei < day.exercises.length; ei++) {
            if (day.exercises[ei].id == oldExerciseId) {
              final updatedExercises = List<PlannedExerciseEntity>.from(day.exercises);
              updatedExercises[ei] = newExercise.copyWith(
                id: oldExerciseId, // Keep same ID to avoid breaking references elsewhere if any
                isSwapped: true,
              );

              final updatedDay = day.copyWith(exercises: updatedExercises);
              final updatedDays = List<DailyWorkoutPlanEntity>.from(plan.weeks[wi].days);
              updatedDays[di] = updatedDay;

              final updatedWeek = plan.weeks[wi].copyWith(days: updatedDays);
              final updatedWeeks = List<WeeklyWorkoutPlanEntity>.from(plan.weeks);
              updatedWeeks[wi] = updatedWeek;

              final updatedPlan = plan.copyWith(weeks: updatedWeeks);
              return await savePlan(updatedPlan);
            }
          }
        }
      }
    }
    return false;
  }

  /// Increment set completion for a planned exercise
  Future<bool> incrementPlannedSetCompletion({
    required DateTime date,
    required String exerciseId,
  }) async {
    final plan = await loadPlan();
    if (plan == null) return false;

    for (int wi = 0; wi < plan.weeks.length; wi++) {
      for (int di = 0; di < plan.weeks[wi].days.length; di++) {
        final day = plan.weeks[wi].days[di];
        if (day.date.year == date.year &&
            day.date.month == date.month &&
            day.date.day == date.day) {
          
          for (int ei = 0; ei < day.exercises.length; ei++) {
            if (day.exercises[ei].id == exerciseId) {
              final exercise = day.exercises[ei];
              final completedCount = exercise.sets.where((s) => s.isCompleted).length;
              
              List<ExerciseSetEntity> updatedSets;
              bool isAllCompleted = false;

              if (completedCount >= exercise.sets.length) {
                // Reset all sets if already completed
                updatedSets = exercise.sets.map((s) => s.copyWith(isCompleted: false)).toList();
              } else {
                // Complete the next set
                updatedSets = List<ExerciseSetEntity>.from(exercise.sets);
                for (int si = 0; si < updatedSets.length; si++) {
                  if (!updatedSets[si].isCompleted) {
                    updatedSets[si] = updatedSets[si].copyWith(isCompleted: true);
                    break;
                  }
                }
                isAllCompleted = updatedSets.every((s) => s.isCompleted);
              }

              final updatedExercise = exercise.copyWith(
                sets: updatedSets,
                isCompleted: isAllCompleted,
                completedAt: isAllCompleted ? DateTime.now() : null,
              );

              final updatedExercises = List<PlannedExerciseEntity>.from(day.exercises);
              updatedExercises[ei] = updatedExercise;

              final updatedDay = day.copyWith(
                exercises: updatedExercises,
                isCompleted: updatedExercises.every((e) => e.isCompleted),
                completedAt: updatedExercises.every((e) => e.isCompleted) ? DateTime.now() : null,
              );

              final updatedDays = List<DailyWorkoutPlanEntity>.from(plan.weeks[wi].days);
              updatedDays[di] = updatedDay;

              final updatedWeek = plan.weeks[wi].copyWith(days: updatedDays);
              final updatedWeeks = List<WeeklyWorkoutPlanEntity>.from(plan.weeks);
              updatedWeeks[wi] = updatedWeek;

              final updatedPlan = plan.copyWith(weeks: updatedWeeks);
              return await savePlan(updatedPlan);
            }
          }
        }
      }
    }
    return false;
  }

}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

/// Provider for workout plan storage service
final workoutPlanStorageProvider = Provider<WorkoutPlanStorageService>((ref) {
  return WorkoutPlanStorageService();
});

/// Provider for the saved workout plan (auto-loads from storage)
final savedWorkoutPlanProvider = FutureProvider<MonthlyWorkoutPlanEntity?>((ref) async {
  final storage = ref.watch(workoutPlanStorageProvider);
  return await storage.loadPlan();
});

/// Provider for checking if plan exists
final hasWorkoutPlanProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(workoutPlanStorageProvider);
  return await storage.hasSavedPlan();
});

