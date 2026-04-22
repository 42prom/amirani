import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_provider.dart';
import '../../features/workout/domain/entities/monthly_workout_plan_entity.dart';
import '../../features/workout/domain/entities/workout_preferences_entity.dart';
import '../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../features/diet/domain/entities/diet_preferences_entity.dart';
import 'ai/api_strategy.dart';
import 'ai/deepseek_strategy.dart';
import '../models/user_body_metrics.dart';
import '../../features/diet/domain/utils/diet_shopping_utils.dart';
import 'diet_plan_storage_service.dart';
import 'workout_plan_storage_service.dart';

/// AI Orchestration Service
///
/// Provides a unified interface for AI-powered plan generation.
/// Supports multiple strategies:
/// - Offline: Enhanced mock data generation (fallback)
/// - API: Backend server with AI integration
/// - DeepSeek: Direct DeepSeek API calls
///
/// Architecture follows the 3-Layer pattern:
/// ┌─────────────────────────────────────────────────────┐
/// │              AI Orchestration Service               │
/// ├─────────────────────────────────────────────────────┤
/// │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
/// │  │   Offline   │  │  Backend    │  │  DeepSeek   │ │
/// │  │  (Fallback) │  │    API      │  │    API      │ │
/// │  └─────────────┘  └─────────────┘  └─────────────┘ │
/// └─────────────────────────────────────────────────────┘

enum AIStrategy {
  offline, // Use enhanced mock data (fallback)
  api, // Use backend API
  directAI, // Direct DeepSeek API calls
}

class AIConfig {
  final AIStrategy strategy;
  final String? apiBaseUrl;
  final String? apiKey;
  final String model;
  final Duration timeout;

  const AIConfig({
    this.strategy = AIStrategy.api,
    this.apiBaseUrl,
    this.apiKey,
    this.model = 'deepseek-chat',
    this.timeout = const Duration(seconds: 180),
  });

  static const AIConfig defaultConfig = AIConfig();
}

class AIOrchestrationService {
  final AIConfig config;
  final Dio dio;

  AIOrchestrationService({
    required this.dio,
    this.config = AIConfig.defaultConfig,
  });

  // ════════════════════════════════════════════════════════════════════════════
  // WORKOUT PLAN GENERATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Generate a workout plan based on user preferences
  Future<MonthlyWorkoutPlanEntity> generateWorkoutPlan({
    required WorkoutPreferencesEntity preferences,
    required String odUserId,
    UserBodyMetrics? userMetrics,
    List<String> targetMuscleNames = const [],
    String languageCode = 'en',
  }) async {
    switch (config.strategy) {
      case AIStrategy.offline:
        return _generateWorkoutPlanOffline(preferences, odUserId,
            userMetrics: userMetrics, targetMuscleNames: targetMuscleNames);
      case AIStrategy.api:
        return _generateWorkoutPlanViaAPI(preferences, odUserId,
            userMetrics: userMetrics,
            targetMuscleNames: targetMuscleNames,
            languageCode: languageCode);
      case AIStrategy.directAI:
        return _generateWorkoutPlanViaDirectAI(preferences, odUserId,
            userMetrics: userMetrics,
            targetMuscleNames: targetMuscleNames);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIET PLAN GENERATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Generate a diet plan based on user preferences
  Future<MonthlyDietPlanEntity> generateDietPlan({
    required DietPreferencesEntity preferences,
    required String odUserId,
    UserBodyMetrics? userMetrics,
    String languageCode = 'en',
  }) async {
    switch (config.strategy) {
      case AIStrategy.offline:
        return _generateDietPlanOffline(preferences, odUserId,
            userMetrics: userMetrics);
      case AIStrategy.api:
        return _generateDietPlanViaAPI(preferences, odUserId,
            userMetrics: userMetrics,
            languageCode: languageCode);
      case AIStrategy.directAI:
        return _generateDietPlanViaDirectAI(preferences, odUserId,
            userMetrics: userMetrics);
    }
  }

  /// Regenerate workout plan with same preferences
  Future<MonthlyWorkoutPlanEntity> regenerateWorkoutPlan({
    required WorkoutPreferencesEntity preferences,
    required String odUserId,
    int? seed, // Different seed = different variation
  }) async {
    // Add variation by using different seed
    return generateWorkoutPlan(
      preferences: preferences,
      odUserId: odUserId,
    );
  }

  /// Swap exercises for a specific day
  Future<List<PlannedExerciseEntity>> swapDayExercises({
    required DailyWorkoutPlanEntity currentDay,
    required WorkoutPreferencesEntity preferences,
    int count = 3,
    String languageCode = 'en',
  }) async {
    switch (config.strategy) {
      case AIStrategy.offline:
        return _swapExercisesOffline(currentDay, preferences, count);
      case AIStrategy.api:
        return _swapExercisesViaAPI(currentDay, preferences, count, languageCode: languageCode);
      case AIStrategy.directAI:
        return _swapExercisesViaDirectAI(currentDay, preferences, count);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // OFFLINE GENERATION (Enhanced Mock)
  // ════════════════════════════════════════════════════════════════════════════

  Future<MonthlyWorkoutPlanEntity> _generateWorkoutPlanOffline(
    WorkoutPreferencesEntity prefs,
    String odUserId, {
    UserBodyMetrics? userMetrics,
    List<String> targetMuscleNames = const [],
  }) async {
    // Simulate processing time for UX
    await Future.delayed(const Duration(milliseconds: 1500));

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(const Duration(days: 27));

    final weeks = <WeeklyWorkoutPlanEntity>[];
    // Compute muscle→day assignments once for the whole plan
    // Prioritize passed targetMuscleNames (from UI selection)
    final musclesToAssign = targetMuscleNames.isNotEmpty 
        ? targetMuscleNames 
        : prefs.targetMuscles;
    
    final dayMuscleAssignments = _assignMusclesPerDay(
        musclesToAssign, prefs.preferredDays);

    for (int weekNum = 1; weekNum <= 4; weekNum++) {
      final weekStart = startDate.add(Duration(days: (weekNum - 1) * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final days = <DailyWorkoutPlanEntity>[];

      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final dayDate = weekStart.add(Duration(days: dayOffset));
        final dayOfWeek = dayDate.weekday - 1;

        final isWorkoutDay = prefs.preferredDays.contains(dayOfWeek);

        if (isWorkoutDay) {
          days.add(_generateEnhancedDayPlan(
            date: dayDate,
            prefs: prefs,
            weekNumber: weekNum,
            dayOfWeek: dayOfWeek,
            dayMuscles: dayMuscleAssignments[dayOfWeek],
            userMetrics: userMetrics,
          ));
        } else {
          days.add(DailyWorkoutPlanEntity(
            id: 'day_${dayDate.toIso8601String()}',
            date: dayDate,
            workoutName: 'Rest Day',
            exercises: [],
            estimatedDurationMinutes: 0,
            estimatedCaloriesBurned: 0,
            targetMuscleGroups: [],
            isRestDay: true,
          ));
        }
      }

      weeks.add(WeeklyWorkoutPlanEntity(
        weekNumber: weekNum,
        startDate: weekStart,
        endDate: weekEnd,
        days: days,
      ));
    }

    return MonthlyWorkoutPlanEntity(
      id: 'plan_${now.millisecondsSinceEpoch}',
      odUserId: odUserId,
      startDate: startDate,
      endDate: endDate,
      goal: prefs.goal,
      location: prefs.location,
      split: prefs.trainingSplit,
      dailyTarget: DailyWorkoutTargetEntity(
        exercisesPerSession: _getExerciseCountForGoal(prefs.goal),
        durationMinutes: prefs.sessionDurationMinutes,
        caloriesBurned: _estimateCaloriesBurned(prefs),
        setsPerMuscleGroup: _getSetsForGoal(prefs.goal),
      ),
      weeks: weeks,
      createdAt: now,
      updatedAt: now,
    );
  }

  DailyWorkoutPlanEntity _generateEnhancedDayPlan({
    required DateTime date,
    required WorkoutPreferencesEntity prefs,
    required int weekNumber,
    required int dayOfWeek,
    List<String>? dayMuscles,
    UserBodyMetrics? userMetrics,
  }) {
    final String workoutName;
    final List<MuscleGroup> muscleGroups;
    List<PlannedExerciseEntity> exercises;

    if (dayMuscles != null && dayMuscles.isNotEmpty) {
      // MUSCLE-AWARE PATH: exercises chosen by assigned muscle groups
      workoutName = _getWorkoutLabelForMuscles(dayMuscles);
      muscleGroups = _expandMusclesForQuery(dayMuscles)
          .map((n) => _parseMuscleGroups([n]).first)
          .toSet()
          .toList();
      final raw = _selectExercisesForDayMuscles(
        dayMuscles: dayMuscles,
        prefs: prefs,
        count: _getExerciseCountForGoal(prefs.goal),
      );
      exercises = raw
          .map((ex) => _applyBodyAwareLogic(ex, weekNumber, prefs.goal, userMetrics))
          .toList();
    } else {
      // FALLBACK: split-based selection (no muscle preference set)
      workoutName = _getWorkoutNameForSplit(prefs.trainingSplit, dayOfWeek);
      muscleGroups = _getMuscleGroupsForWorkout(workoutName);
      exercises = _getProgressiveExercises(
        workoutName: workoutName,
        prefs: prefs,
        weekNumber: weekNumber,
        dayVariation: date.day % 3,
      );
      // Apply body-aware logic even to fallback exercises
      exercises = exercises.map((ex) => _applyBodyAwareLogic(ex, weekNumber, prefs.goal, userMetrics)).toList();
    }

    return DailyWorkoutPlanEntity(
      id: 'day_${date.toIso8601String()}',
      date: date,
      workoutName: workoutName,
      exercises: exercises,
      estimatedDurationMinutes: prefs.sessionDurationMinutes,
      estimatedCaloriesBurned: _estimateCaloriesBurned(prefs),
      targetMuscleGroups: muscleGroups,
      scheduledTime: prefs.reminderTime,
    );
  }

  List<PlannedExerciseEntity> _getProgressiveExercises({
    required String workoutName,
    required WorkoutPreferencesEntity prefs,
    required int weekNumber,
    required int dayVariation,
  }) {
    final database = _getExerciseDatabase(prefs.location);
    final workoutExercises =
        database[workoutName] ?? database['Full Body'] ?? [];

    // Filter by equipment and preferences
    var filtered = workoutExercises.where((e) {
      if (e.requiredEquipment.isNotEmpty) {
        final hasEquipment = e.requiredEquipment
            .any((eq) => prefs.availableEquipment.contains(eq));
        if (!hasEquipment) return false;
      }
      if (prefs.dislikedExercises.contains(e.name)) return false;
      return true;
    }).toList();

    // Prioritize user-selected target muscles first, then liked exercises
    if (prefs.targetMuscles.isNotEmpty) {
      final targetSet = prefs.targetMuscles.toSet();
      filtered.sort((a, b) {
        final aTargets = a.targetMuscles.any((m) => targetSet.contains(m.name));
        final bTargets = b.targetMuscles.any((m) => targetSet.contains(m.name));
        if (aTargets && !bTargets) return -1;
        if (!aTargets && bTargets) return 1;
        // Secondary sort: liked exercises
        final aLiked = prefs.likedExercises.contains(a.name) ? 0 : 1;
        final bLiked = prefs.likedExercises.contains(b.name) ? 0 : 1;
        return aLiked.compareTo(bLiked);
      });
    } else {
      // No muscle target — prioritize liked exercises
      filtered.sort((a, b) {
        final aLiked = prefs.likedExercises.contains(a.name) ? 0 : 1;
        final bLiked = prefs.likedExercises.contains(b.name) ? 0 : 1;
        return aLiked.compareTo(bLiked);
      });
    }

    // Shuffle based on day variation for variety
    if (dayVariation > 0 && filtered.length > 3) {
      final shuffled = List<PlannedExerciseEntity>.from(filtered);
      // Rotate exercises based on day variation
      for (int i = 0; i < dayVariation && shuffled.length > 1; i++) {
        final first = shuffled.removeAt(0);
        shuffled.insert(shuffled.length ~/ 2, first);
      }
      filtered = shuffled;
    }

    // Take appropriate number and apply progressive overload
    final count = _getExerciseCountForGoal(prefs.goal);
    return filtered.take(count).map((exercise) {
      return _applyProgressiveOverload(exercise, weekNumber, prefs.goal);
    }).toList();
  }

  PlannedExerciseEntity _applyProgressiveOverload(
    PlannedExerciseEntity exercise,
    int weekNumber,
    WorkoutGoal goal,
  ) {
    // Wave periodization: build → peak → deload pattern
    final baseReps =
        exercise.sets.isNotEmpty ? exercise.sets.first.targetReps : 10;
    final baseSets = exercise.sets.length;

    int newReps;
    int newSets;

    switch (goal) {
      case WorkoutGoal.strength:
        // Strength: low reps, high intensity — reduce reps as weight conceptually increases
        // 6 → 5 → 4 → 6 (deload)
        final repWave = [baseReps, (baseReps * 0.85).round(), (baseReps * 0.70).round(), baseReps];
        newReps = repWave[(weekNumber - 1).clamp(0, 3)];
        newSets = weekNumber == 3 ? baseSets + 1 : baseSets;
        break;
      case WorkoutGoal.muscleGain:
        // Hypertrophy: moderate reps, progressive volume
        // 10 → 12 → 14 → 10 (deload)
        final repWave = [baseReps, baseReps + 2, baseReps + 4, baseReps];
        newReps = repWave[(weekNumber - 1).clamp(0, 3)];
        newSets = weekNumber >= 3 ? baseSets + 1 : baseSets;
        break;
      case WorkoutGoal.endurance:
        // Endurance: high reps
        // 15 → 18 → 21 → 15 (deload)
        final repWave = [baseReps, baseReps + 3, baseReps + 6, baseReps];
        newReps = repWave[(weekNumber - 1).clamp(0, 3)];
        newSets = baseSets;
        break;
      case WorkoutGoal.weightLoss:
        // Fat loss: HIIT-style, steady increase
        // 12 → 14 → 16 → 12 (deload)
        final repWave = [baseReps, baseReps + 2, baseReps + 4, baseReps];
        newReps = repWave[(weekNumber - 1).clamp(0, 3)];
        newSets = baseSets;
        break;
      default:
        // General fitness: moderate progression
        final repWave = [baseReps, baseReps + 2, baseReps + 3, baseReps];
        newReps = repWave[(weekNumber - 1).clamp(0, 3)];
        newSets = baseSets;
    }

    // Rebuild sets with progressive overload
    final newSetsList = List.generate(newSets, (index) {
      final originalSet = index < exercise.sets.length
          ? exercise.sets[index]
          : exercise.sets.last;
      return ExerciseSetEntity(
        setNumber: index + 1,
        targetReps: newReps,
        targetSeconds: originalSet.targetSeconds,
        targetWeight: originalSet.targetWeight,
        restSeconds: originalSet.restSeconds,
      );
    });

    return exercise.copyWith(sets: newSetsList);
  }

  Future<List<PlannedExerciseEntity>> _swapExercisesOffline(
    DailyWorkoutPlanEntity currentDay,
    WorkoutPreferencesEntity preferences,
    int count,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final database = _getExerciseDatabase(preferences.location);
    final currentExerciseNames =
        currentDay.exercises.map((e) => e.name).toSet();

    // Get all exercises for the workout type
    final allExercises =
        database[currentDay.workoutName] ?? database['Full Body'] ?? [];

    // Filter to find alternatives
    final alternatives = allExercises
        .where((e) {
          // Not already in today's workout
          if (currentExerciseNames.contains(e.name)) return false;
          // Has required equipment
          if (e.requiredEquipment.isNotEmpty) {
            final hasEquipment = e.requiredEquipment
                .any((eq) => preferences.availableEquipment.contains(eq));
            if (!hasEquipment) return false;
          }
          // Not disliked
          if (preferences.dislikedExercises.contains(e.name)) return false;
          return true;
        })
        .take(count)
        .toList();

    return alternatives;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // API GENERATION (Future Backend)
  // ════════════════════════════════════════════════════════════════════════════

  Future<MonthlyWorkoutPlanEntity> _generateWorkoutPlanViaAPI(
    WorkoutPreferencesEntity prefs,
    String odUserId, {
    UserBodyMetrics? userMetrics,
    List<String> targetMuscleNames = const [],
    String languageCode = 'en',
  }) async {
    final strategy = ApiGenerationStrategy(
      dio: dio,
      timeout: config.timeout,
    );

    try {
      final data = await strategy.fetchPlanFromApi(prefs, odUserId,
          userMetrics: userMetrics,
          targetMuscleNames: targetMuscleNames,
          languageCode: languageCode);
      if (data != null) {
        if (data['data'] != null && data['data']['status'] == 'QUEUED') {
          final jobId = data['data']['jobId'] as String;
          // dietJobId is present when the backend enqueued both workout AND diet
          // (type=BOTH). Poll both concurrently — workout result is returned to
          // the caller; diet result is saved in the background when it completes.
          final dietJobId = data['data']['dietJobId'] as String?;
          if (dietJobId != null) {
            // Detached diet poll — user sees workout progress in the UI.
            // Diet saves itself when complete; push notification signals readiness.
            _pollJobStatus(
              strategy, dietJobId, 'DIET',
              onJobStarted: (id) => _dietJobStorage?.saveJobId(id),
              onJobFinished: () => _dietJobStorage?.clearJobId(),
            ).then((dietResult) {
              if (dietResult != null) {
                debugPrint('[AI] Background diet poll complete for job $dietJobId');
              } else {
                debugPrint('[AI] Background diet poll failed/timed out for job $dietJobId — push notification will signal when ready');
              }
            }).catchError((e) {
              debugPrint('[AI] Background diet poll error: $e');
            });
          }
          // W8: pass jobId storage callbacks so the poll loop saves/clears automatically
          final resultValue = await _pollJobStatus(
            strategy, jobId, 'WORKOUT',
            onJobStarted: (id) => _workoutJobStorage?.saveJobId(id),
            onJobFinished: () => _workoutJobStorage?.clearJobId(),
          );
          if (resultValue != null) {
            final rawPlan = resultValue['plan'] as Map<String, dynamic>? ?? resultValue;
            return _parsePlanFromApiResponse(rawPlan, prefs, odUserId);
          }
        } else {
          return _parsePlanFromApiResponse(data, prefs, odUserId);
        }
      }
    } catch (e) {
      // 409 DIET_PLAN_REQUIRED: propagate to the caller — offline fallback is wrong here.
      if (e is DioException && e.response?.statusCode == 409) rethrow;
      debugPrint('[AI] Workout API error — falling back to offline: $e');
    }
    // W12: Any error or null result → offline fallback (user always gets a plan)
    return _generateWorkoutPlanOffline(prefs, odUserId,
        userMetrics: userMetrics, targetMuscleNames: targetMuscleNames);
  }

  Future<MonthlyDietPlanEntity> _generateDietPlanViaAPI(
    DietPreferencesEntity prefs,
    String odUserId, {
    UserBodyMetrics? userMetrics,
    String languageCode = 'en',
  }) async {
    final strategy = ApiGenerationStrategy(
      dio: dio,
      timeout: config.timeout,
    );

    try {
      final data = await strategy.fetchDietPlanFromApi(prefs, odUserId,
          userMetrics: userMetrics,
          languageCode: languageCode);

      if (data != null) {
        if (data['data'] != null && data['data']['status'] == 'QUEUED') {
          final jobId = data['data']['jobId'] as String;
          // W8: pass jobId storage callbacks so the poll loop saves/clears automatically
          final result = await _pollJobStatus(
            strategy, jobId, 'DIET',
            onJobStarted: (id) => _dietJobStorage?.saveJobId(id),
            onJobFinished: () => _dietJobStorage?.clearJobId(),
          );
          if (result != null) {
            final rawPlan = result['plan'] as Map<String, dynamic>? ?? result;
            return _parseDietPlanFromApiResponse(rawPlan, prefs, odUserId);
          }
        } else {
          return _parseDietPlanFromApiResponse(data, prefs, odUserId);
        }
      }
    } catch (e) {
      debugPrint('[AI] Diet API error — falling back to offline: $e');
    }
    // W12: Any error or null result → offline fallback (user always gets a plan)
    return _generateDietPlanOffline(prefs, odUserId, userMetrics: userMetrics);
  }

  // Optional storage references — set by providers so the poll loop can persist
  // job IDs internally without callers needing to remember to do so (W8).
  // These are late-injected via setJobStorageRefs().
  dynamic _dietJobStorage;   // DietPlanStorageService (typed loosely to avoid circular import)
  dynamic _workoutJobStorage; // WorkoutPlanStorageService

  void setJobStorageRefs({dynamic diet, dynamic workout}) {
    _dietJobStorage = diet;
    _workoutJobStorage = workout;
  }

  /// Polls for AI job completion with exponential backoff.
  ///
  /// W1: Separates transient network errors from genuine pending state.
  ///     Up to 5 consecutive network errors are tolerated; more → returns null
  ///     (caller triggers offline fallback).
  /// W2: Smoother backoff: 0s → 2s → 3s → 5s → 7s → 9s → 10s (capped).
  ///     Old formula (1 << n) plateaued at attempt 4; this spreads more evenly.
  /// W8: Accepts optional callbacks to persist job ID in Hive automatically.
  /// W12: FAILED status returns null (caller falls back to offline) + structured log.
  Future<Map<String, dynamic>?> _pollJobStatus(
    ApiGenerationStrategy strategy,
    String jobId,
    String type, {
    Future<void> Function(String)? onJobStarted,
    Future<void> Function()? onJobFinished,
  }) async {
    const maxAttempts = 60;
    const maxNetworkErrors = 5; // W1: strike limit for unreachable status endpoint
    int attempts = 0;
    int networkErrors = 0;

    // W8: Persist job ID so polling can resume after app kill
    await onJobStarted?.call(jobId);

    try {
      while (attempts < maxAttempts) {
        final statusData = await strategy.getJobStatus(jobId, type);

        // W1: null = network error or non-200 — don't burn a real attempt
        if (statusData == null) {
          networkErrors++;
          debugPrint('[AI_POLL] Job $jobId | Network error $networkErrors/$maxNetworkErrors');
          if (networkErrors >= maxNetworkErrors) {
            debugPrint('[AI_POLL] Too many consecutive network errors — triggering offline fallback');
            return null;
          }
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        // Issue 8: reset on ANY non-null response — a {success:false} is a valid
        // server response, not a network failure, and should not accumulate strikes.
        networkErrors = 0;

        if (statusData['success'] == true) {
          final job = statusData['data'] as Map<String, dynamic>?;
          if (job == null) {
            attempts++;
            continue;
          }
          final status = job['status'] as String? ?? '';
          final progress = job['progress'] ?? 0;
          debugPrint('[AI_POLL] Job $jobId | Attempt ${attempts + 1} | Status: $status | Progress: $progress%');

          if (status == 'COMPLETED') {
            final result = job['result'] as Map<String, dynamic>?;
            // schemaVersion was intentionally removed from the backend response
            // (it was wasted tokens). The check has been removed to prevent a
            // false-alarm SCHEMA_VERSION_MISSING metric event on every completion.
            return result;
          } else if (status == 'FAILED') {
            // W12: FAILED → structured metric + return null to trigger offline fallback
            debugPrint('[AI_METRICS] {"event":"JOB_FAILED","jobId":"$jobId","type":"$type","error":"${job['error']}"}');
            return null;
          }
        }

        attempts++;
        // W2: Smoother backoff (2s→3s→5s→7s→9s→10s cap).
        // Issue 1: 'attempts==0 ? 0' removed — attempts is always ≥1 here
        // because it increments before the delay. First delay = 2s.
        final delaySeconds = ((attempts * 1.5) + 0.5).round().clamp(2, 10);
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      debugPrint('[AI_POLL] Job $jobId timed out after $maxAttempts attempts — triggering offline fallback');
      return null;
    } finally {
      // W8: Always clear persisted job ID when poll loop exits (success or failure)
      await onJobFinished?.call();
    }
  }

  MonthlyDietPlanEntity _parseDietPlanFromApiResponse(
    Map<String, dynamic> planData,
    DietPreferencesEntity prefs,
    String odUserId,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    debugPrint('[AI_PARSE] Parsing incoming Diet Plan JSON. Keys: ${planData.keys.toList()}');
    if (planData.containsKey('days')) {
      debugPrint('[AI_PARSE] Found ${planData['days'].length} days in plan.');
    }
        
    // Anchor to Monday of the current week so templateDays[0] (MONDAY food)
    // always lands on an actual Monday, regardless of what day generation runs.
    // Dart weekday: 1=Mon ... 7=Sun. Subtract (weekday-1) days to reach Monday.
    final startDate = today.subtract(Duration(days: today.weekday - 1));
    final endDate = startDate.add(const Duration(days: 27));

    // Helper: safely parse any numeric value to int (nullable)
    int? toNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    // Helper: safely parse any numeric value to int, defaulting to 0
    int toInt0(dynamic v) => toNullableInt(v) ?? 0;

    // Helper to parse a single day's JSON into a list of PlannedMealEntity
    List<PlannedMealEntity> parseMealsFromDayJson(Map<String, dynamic> dayJson, DateTime dayDate) {
      final List<PlannedMealEntity> meals = [];
      final mealsJson = dayJson['meals'] as List? ?? [];

      for (var mealEntry in mealsJson.asMap().entries) {
        final mealIndex = mealEntry.key;
        final mealJson = mealEntry.value as Map<String, dynamic>;
        final List<IngredientEntity> ingredients = [];
        final ingredientsJson = mealJson['ingredients'] as List? ?? [];

        for (var ingJson in ingredientsJson) {
          ingredients.add(IngredientEntity(
            // AI returns 'name'; legacy fallback to 'item'
            name: (ingJson['name'] ?? ingJson['item'] ?? 'Ingredient') as String,
            // W3: Read canonicalName for shopping list deduplication
            canonicalName: ingJson['canonicalName'] as String?,
            // AI returns 'amount'; legacy fallback to 'grams'
            amount: ((ingJson['amount'] ?? ingJson['grams'])?.toString() ?? '100'),
            unit: (ingJson['unit'] ?? 'g') as String,
            // W4: Non-optional with default 0 — toInt0 returns 0 for null (safe)
            calories: toInt0(ingJson['calories']),
            protein: toInt0(ingJson['protein']),
            carbs: toInt0(ingJson['carbs']),
            fats: toInt0(ingJson['fat'] ?? ingJson['fats']),
          ));
        }

        // Determine meal type: read explicit 'type' field first (AI schema includes it),
        // then fall back to name-keyword + time + position inference.
        final mealName = mealJson['name'] as String? ?? 'Meal';
        final mealTime = mealJson['time']?.toString() ?? '';
        final mealTypeRaw = mealJson['type'] as String? ?? '';
        final mealType = mealTypeRaw.isNotEmpty
            ? _parseMealTypeByIndexAndTime(mealTypeRaw, mealTime, mealIndex, mealsJson.length)
            : _parseMealTypeByIndexAndTime(mealName, mealTime, mealIndex, mealsJson.length);

        // Description: use ingredient names when description/instructions repeats the meal name or is empty
        final rawDesc = mealJson['description'] as String? ?? mealJson['instructions'] as String? ?? '';
        final ingredientSummary = ingredients.isNotEmpty
            ? ingredients.take(3).map((i) => i.name).join(', ')
            : '';
        final description = (rawDesc.isEmpty || rawDesc.toLowerCase() == mealName.toLowerCase())
            ? ingredientSummary
            : rawDesc;

        meals.add(PlannedMealEntity(
          id: 'meal_${dayDate.millisecondsSinceEpoch}_${mealIndex}_$mealName',
          type: mealType,
          name: mealName,
          description: description,
          ingredients: ingredients,
          instructions: mealJson['instructions'] as String? ?? '',
          prepTimeMinutes: mealJson['prepTimeMinutes'] as int? ?? 20,
          scheduledTime: mealTime.isNotEmpty ? mealTime : null,
          nutrition: NutritionInfoEntity(
            calories: toInt0(mealJson['calories'] ?? mealJson['totalCalories']),
            protein: toInt0(mealJson['protein']),
            carbs: toInt0(mealJson['carbs']),
            fats: toInt0(mealJson['fat'] ?? mealJson['fats']),
          ),
        ));
      }
      return meals;
    }

    final List<WeeklyPlanEntity> weeks = [];

    // Backend AI prompt generates a flat 7-day 'days' array (not nested 'weeks').
    // If 'weeks' is present (future format), use it; otherwise repeat the 7-day
    // pattern across 4 weeks to build a monthly plan.
    // Read plan-level macros BEFORE the loop so DailyPlanEntity targets are correct.
    // AI day JSON has no per-day macro targets — use the global planMeta values.
    final meta = planData['planMeta'] as Map<String, dynamic>? ?? {};
    final macros = meta['macros'] as Map<String, dynamic>? ?? {};
    final targetCal = toNullableInt(meta['dailyCalories']) ?? 2000;
    final targetPro = toNullableInt(macros['protein']) ?? (targetCal * 0.30 ~/ 4);
    final targetCarb = toNullableInt(macros['carbs']) ?? (targetCal * 0.40 ~/ 4);
    final targetFat = toNullableInt(macros['fat'] ?? macros['fats']) ?? (targetCal * 0.30 ~/ 9);

    final flatDaysJson = planData['days'] as List?;
    final weeksJson = planData['weeks'] as List? ?? [];

    if (flatDaysJson != null && flatDaysJson.isNotEmpty) {
      // Base the 7-day template linearly starting TODAY (unanchored calendar)
      final List<Map<String, dynamic>> templateDays = [];
      if (flatDaysJson.length == 4) {
        templateDays.add(flatDaysJson[0] as Map<String, dynamic>); // Day 1
        templateDays.add(flatDaysJson[1] as Map<String, dynamic>); // Day 2
        templateDays.add(flatDaysJson[2] as Map<String, dynamic>); // Day 3
        templateDays.add(flatDaysJson[0] as Map<String, dynamic>); // Day 4 (Mirror 1)
        templateDays.add(flatDaysJson[1] as Map<String, dynamic>); // Day 5 (Mirror 2)
        templateDays.add(flatDaysJson[2] as Map<String, dynamic>); // Day 6 (Mirror 3)
        templateDays.add(flatDaysJson[3] as Map<String, dynamic>); // Day 7
      } else {
        templateDays.addAll(flatDaysJson.map((e) => e as Map<String, dynamic>).take(7));
      }
      
      // Ensure exactly 7 days
      while (templateDays.length < 7) {
        templateDays.add({});
      }

      // Repeat the 7-day template over 4 weeks to create a 28-day monthly plan
      const numWeeks = 4;
      for (int w = 0; w < numWeeks; w++) {
        final List<DailyPlanEntity> days = [];
        final weekStart = startDate.add(Duration(days: w * 7));

        for (int d = 0; d < 7; d++) {
          final dayJson = templateDays[d];
          final dayDate = weekStart.add(Duration(days: d));
          final meals = parseMealsFromDayJson(dayJson, dayDate);

          days.add(DailyPlanEntity(
            id: 'day_${dayDate.millisecondsSinceEpoch}',
            date: dayDate,
            meals: meals,
            targetCalories: targetCal,
            targetProtein: targetPro,
            targetCarbs: targetCarb,
            targetFats: targetFat,
          ));
        }
        weeks.add(WeeklyPlanEntity(
          weekNumber: w + 1,
          startDate: weekStart,
          endDate: weekStart.add(const Duration(days: 6)),
          days: days,
        ));
      }
    } else {
      // Nested weeks format
      for (var weekJson in weeksJson) {
        final wNum = weekJson['week'] as int? ?? 1;
        final List<DailyPlanEntity> days = [];
        final daysJson = weekJson['days'] as List? ?? [];

        for (int i = 0; i < daysJson.length; i++) {
          final dayJson = daysJson[i] as Map<String, dynamic>;
          final dayOffset = ((wNum - 1) * 7) + i;
          final dayDate = startDate.add(Duration(days: dayOffset));
          final meals = parseMealsFromDayJson(dayJson, dayDate);

          days.add(DailyPlanEntity(
            id: 'day_${dayDate.millisecondsSinceEpoch}',
            date: dayDate,
            meals: meals,
            targetCalories: toInt0(dayJson['totalCalories'] ?? dayJson['targetCalories']) > 0
                ? toInt0(dayJson['totalCalories'] ?? dayJson['targetCalories'])
                : targetCal,
            targetProtein: targetPro,
            targetCarbs: targetCarb,
            targetFats: targetFat,
          ));
        }

        weeks.add(WeeklyPlanEntity(
          weekNumber: wNum,
          startDate: startDate.add(Duration(days: (wNum - 1) * 7)),
          endDate: startDate.add(Duration(days: (wNum * 7) - 1)),
          days: days,
        ));
      }
    }

    return MonthlyDietPlanEntity(
      id: 'plan_${now.millisecondsSinceEpoch}',
      odUserId: odUserId,
      startDate: startDate,
      endDate: endDate,
      goal: prefs.goal,
      macroTarget: DailyMacroTargetEntity(
        calories: targetCal,
        protein: targetPro,
        carbs: targetCarb,
        fats: targetFat,
      ),
      shoppingLists: buildShoppingLists(weeks),
      weeks: weeks,
      createdAt: now,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // OFFLINE DIET PLAN GENERATION
  // ════════════════════════════════════════════════════════════════════════════

  MonthlyDietPlanEntity _generateDietPlanOffline(
    DietPreferencesEntity prefs,
    String odUserId, {
    UserBodyMetrics? userMetrics,
  }) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(const Duration(days: 27));

    // Compute real calorie target using Mifflin-St Jeor if metrics available
    int targetCal = 2000;
    int targetPro = 150;
    int targetCarb = 200;
    int targetFat = 65;

    if (userMetrics != null && userMetrics.weightKg != null &&
        userMetrics.heightCm != null && userMetrics.age != null) {
      final wt = userMetrics.weightKg!;
      final ht = userMetrics.heightCm!;
      final age = userMetrics.age!;
      final isMale = userMetrics.isMale;

      // Mifflin-St Jeor BMR
      final bmr = isMale
          ? (10 * wt) + (6.25 * ht) - (5 * age) + 5
          : (10 * wt) + (6.25 * ht) - (5 * age) - 161;
      final tdee = bmr * 1.55; // Moderate activity default

      final rawCal = switch (prefs.goal) {
        DietGoal.weightLoss => (tdee - 500).round().clamp(1200, 3500),
        DietGoal.muscleGain => (tdee + 300).round(),
        DietGoal.performance => (tdee + 200).round(),
        _ => tdee.round(),
      };
      targetCal = rawCal;
      // Macros from calorie target
      targetPro = (wt * 1.8).round().clamp(100, 250);
      final remainingCal = targetCal - (targetPro * 4);
      targetFat = (remainingCal * 0.35 / 9).round();
      targetCarb = ((remainingCal - (targetFat * 9)) / 4).round();
    }

    final macroTarget = DailyMacroTargetEntity(
      calories: targetCal,
      protein: targetPro,
      carbs: targetCarb,
      fats: targetFat,
    );

    // 7-day rotating meal templates (scales by targetCal)
    final mealTemplates = _buildOfflineMealTemplates(prefs, targetCal, targetPro, targetCarb, targetFat);

    // Build 4 weeks
    final weeks = <WeeklyPlanEntity>[];
    for (int w = 0; w < 4; w++) {
      final weekStart = startDate.add(Duration(days: w * 7));
      final days = <DailyPlanEntity>[];
      for (int d = 0; d < 7; d++) {
        final dayDate = weekStart.add(Duration(days: d));
        final dayMeals = mealTemplates[d % mealTemplates.length];
        days.add(DailyPlanEntity(
          id: 'day_offline_${dayDate.toIso8601String().split('T').first}',
          date: dayDate,
          meals: dayMeals,
          targetCalories: targetCal,
          targetProtein: targetPro,
          targetCarbs: targetCarb,
          targetFats: targetFat,
        ));
      }
      weeks.add(WeeklyPlanEntity(
        weekNumber: w + 1,
        startDate: weekStart,
        endDate: weekStart.add(const Duration(days: 6)),
        days: days,
      ));
    }

    return MonthlyDietPlanEntity(
      id: 'offline_diet_${now.millisecondsSinceEpoch}',
      odUserId: odUserId,
      startDate: startDate,
      endDate: endDate,
      goal: prefs.goal,
      macroTarget: macroTarget,
      shoppingLists: buildShoppingLists(weeks),
      weeks: weeks,
      createdAt: now,
    );
  }

  List<List<PlannedMealEntity>> _buildOfflineMealTemplates(
    DietPreferencesEntity prefs,
    int targetCal,
    int targetPro,
    int targetCarb,
    int targetFat,
  ) {
    // 7 day templates rotating breakfast/lunch/dinner/snack
    // Using goal-appropriate meal patterns
    final breakfastCal = (targetCal * 0.25).round();
    final lunchCal = (targetCal * 0.35).round();
    final dinnerCal = (targetCal * 0.30).round();
    final snackCal = targetCal - breakfastCal - lunchCal - dinnerCal;

    PlannedMealEntity breakfast(String name, String desc) => PlannedMealEntity(
      id: 'meal_offline_b_${name.hashCode.abs()}',
      type: MealType.breakfast,
      name: 'Breakfast',
      description: name,
      ingredients: [],
      instructions: desc,
      prepTimeMinutes: 10,
      nutrition: NutritionInfoEntity(
        calories: breakfastCal,
        protein: (targetPro * 0.25).round(),
        carbs: (targetCarb * 0.25).round(),
        fats: (targetFat * 0.25).round(),
      ),
    );

    PlannedMealEntity lunch(String name, String desc) => PlannedMealEntity(
      id: 'meal_offline_l_${name.hashCode.abs()}',
      type: MealType.lunch,
      name: 'Lunch',
      description: name,
      ingredients: [],
      instructions: desc,
      prepTimeMinutes: 15,
      nutrition: NutritionInfoEntity(
        calories: lunchCal,
        protein: (targetPro * 0.35).round(),
        carbs: (targetCarb * 0.35).round(),
        fats: (targetFat * 0.35).round(),
      ),
    );

    PlannedMealEntity dinner(String name, String desc) => PlannedMealEntity(
      id: 'meal_offline_d_${name.hashCode.abs()}',
      type: MealType.dinner,
      name: 'Dinner',
      description: name,
      ingredients: [],
      instructions: desc,
      prepTimeMinutes: 25,
      nutrition: NutritionInfoEntity(
        calories: dinnerCal,
        protein: (targetPro * 0.30).round(),
        carbs: (targetCarb * 0.30).round(),
        fats: (targetFat * 0.30).round(),
      ),
    );

    PlannedMealEntity snack(String name) => PlannedMealEntity(
      id: 'meal_offline_s_${name.hashCode.abs()}',
      type: MealType.snack,
      name: 'Snack',
      description: name,
      ingredients: [],
      instructions: 'Quick and easy.',
      prepTimeMinutes: 5,
      nutrition: NutritionInfoEntity(
        calories: snackCal,
        protein: (targetPro * 0.10).round(),
        carbs: (targetCarb * 0.10).round(),
        fats: (targetFat * 0.10).round(),
      ),
    );

    return [
      [breakfast('Oats & berries with protein shake', 'Cook rolled oats, top with blueberries and a side protein shake.'), lunch('Grilled chicken breast with brown rice & vegetables', 'Season chicken, grill 6 min each side. Serve with 150g brown rice and steamed broccoli.'), dinner('Salmon fillet with quinoa & asparagus', 'Bake salmon at 200°C for 18 min. Serve with 100g quinoa and roasted asparagus.'), snack('Greek yogurt with almonds')],
      [breakfast('Scrambled eggs with whole grain toast', '3 eggs scrambled with spinach. Serve with 2 slices whole grain toast.'), lunch('Turkey wrap with lettuce, tomato & hummus', 'Spread hummus on a whole grain wrap, add turkey slices and vegetables.'), dinner('Beef stir-fry with mixed vegetables & rice', 'Stir-fry lean beef strips 5 min, add peppers and broccoli, serve with rice.'), snack('Apple with peanut butter')],
      [breakfast('Protein smoothie bowl', 'Blend protein powder, banana, frozen berries. Top with granola and seeds.'), lunch('Tuna salad with mixed greens & avocado', 'Mix canned tuna with lemon juice. Serve on mixed greens with sliced avocado.'), dinner('Chicken stir-fry with noodles', 'Stir-fry chicken strips with snap peas, carrots, soy sauce over udon noodles.'), snack('Cottage cheese with fruit')],
      [breakfast('Avocado toast with poached eggs', 'Toast whole grain bread, spread avocado, top with 2 poached eggs.'), lunch('Lentil soup with crusty bread', 'Simmer lentils with carrots, celery, cumin 30 min. Serve with bread.'), dinner('Grilled sea bass with sweet potato & green beans', 'Grill sea bass 4 min each side. Serve with roasted sweet potato and green beans.'), snack('Mixed nuts & dried fruit')],
      [breakfast('Overnight oats with chia seeds', 'Mix oats, chia, milk, protein powder. Refrigerate overnight.'), lunch('Grilled chicken Caesar salad (light dressing)', 'Grill chicken breast, slice over romaine, parmesan, croutons, light Caesar.'), dinner('Lamb chops with roasted vegetables', 'Season lamb, grill 4 min each side. Serve with oven-roasted Mediterranean veg.'), snack('Protein bar or rice cakes with nut butter')],
      [breakfast('Greek yogurt parfait with granola', 'Layer Greek yogurt, granola, and fresh mixed berries in a glass.'), lunch('Chicken & vegetable pasta', 'Cook pasta al dente. Toss with grilled chicken, olive oil, cherry tomatoes, basil.'), dinner('Baked cod with lemon, rice & salad', 'Bake cod with lemon zest 20 min. Serve with white rice and garden salad.'), snack('Edamame or hummus & vegetables')],
      [breakfast('Whole grain pancakes with berries & maple syrup', 'Make pancakes with whole grain flour. Top with fresh berries and a drizzle of maple syrup.'), lunch('Beef & vegetable soup with bread roll', 'Slow-cook beef cubes with carrots, potatoes, onion in broth. Serve with bread.'), dinner('Chicken tikka masala with basmati rice', 'Cook chicken in spiced tomato-cream sauce. Serve over basmati rice with naan.'), snack('Dark chocolate & walnuts')],
    ];
  }

  MealType _parseMealTypeByIndexAndTime(String name, String time, int index, int total) {
    // 1. Name-based keywords (AI may use these for fasting/explicit meal types)
    final n = name.toLowerCase().trim();
    if (n.contains('breakfast')) return MealType.breakfast;
    if (n.contains('lunch')) return MealType.lunch;
    if (n.contains('dinner') || n.contains('supper')) return MealType.dinner;
    // Check specific snack types BEFORE the generic 'snack' catch
    if (n == 'snack 1' || n == 'morning snack' || n == 'morning_snack' ||
        n.contains('pre-workout') || n.contains('pre workout')) {
      return MealType.morningSnack;
    }
    if (n == 'snack 2' || n == 'afternoon snack' || n == 'afternoon_snack' ||
        n.contains('post-workout') || n.contains('post workout')) {
      return MealType.afternoonSnack;
    }
    if (n.contains('snack')) return MealType.snack;

    // 2. Time-based: parse "HH:MM" and map to meal slot
    if (time.isNotEmpty) {
      final parts = time.split(':');
      final hour = int.tryParse(parts[0]) ?? -1;
      if (hour >= 5 && hour < 11) return MealType.breakfast;
      if (hour >= 11 && hour < 14) return MealType.lunch;
      if (hour >= 14 && hour < 17) return MealType.morningSnack;
      if (hour >= 17 && hour < 20) return MealType.dinner;
      if (hour >= 20 || hour < 5) return MealType.afternoonSnack;
    }

    // 3. Position-based fallback using total meal count
    switch (total) {
      case 2:
        return index == 0 ? MealType.lunch : MealType.dinner;
      case 3:
        if (index == 0) return MealType.breakfast;
        if (index == 1) return MealType.lunch;
        return MealType.dinner;
      case 4:
        if (index == 0) return MealType.breakfast;
        if (index == 1) return MealType.lunch;
        if (index == 2) return MealType.morningSnack;
        return MealType.dinner;
      case 5:
        if (index == 0) return MealType.breakfast;
        if (index == 1) return MealType.morningSnack;
        if (index == 2) return MealType.lunch;
        if (index == 3) return MealType.afternoonSnack;
        return MealType.dinner;
      default:
        if (index == 0) return MealType.breakfast;
        if (index == total - 1) return MealType.dinner;
        return MealType.snack;
    }
  }

  Future<List<PlannedExerciseEntity>> _swapExercisesViaAPI(
    DailyWorkoutPlanEntity currentDay,
    WorkoutPreferencesEntity preferences,
    int count, {
    String languageCode = 'en',
  }) async {
    try {
      final strategy = ApiGenerationStrategy(
        dio: dio,
        timeout: config.timeout,
      );

      final exercisesData = await strategy.fetchSwappedExercisesFromApi(
        currentDay.workoutName,
        currentDay.exercises.map((e) => e.name).toList(),
        currentDay.targetMuscleGroups.map((m) => m.name).toList(),
        preferences,
        count,
        languageCode: languageCode,
      );

      if (exercisesData != null && exercisesData.isNotEmpty) {
        return _parseExercisesFromApiResponse(exercisesData, preferences);
      }
      return _swapExercisesOffline(currentDay, preferences, count);
    } catch (e) {
      return _swapExercisesOffline(currentDay, preferences, count);
    }
  }

  MonthlyWorkoutPlanEntity _parsePlanFromApiResponse(
    Map<String, dynamic> data,
    WorkoutPreferencesEntity prefs,
    String odUserId,
  ) {
    final now = DateTime.now();
    // Monday of the current week — professional calendar alignment
    final mondayOfThisWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    if (data['planMeta'] == null && data['days'] == null && data['weeks'] == null && data['routines'] == null) {
      throw Exception('Invalid API response: missing plan data structure');
    }

    final parsedStart = DateTime.tryParse(data['start_date'] as String? ?? '');
    final localStart = (parsedStart ?? mondayOfThisWeek).toLocal();
    final startDate = DateTime(localStart.year, localStart.month, localStart.day);
    final endDate = DateTime.tryParse(data['end_date'] as String? ?? '') ??
        startDate.add(const Duration(days: 27));

    final weeksData = data['weeks'] as List?;
    final daysData = data['days'] as List?;
    List<WeeklyWorkoutPlanEntity> weeks = [];

    if (weeksData != null && weeksData.isNotEmpty) {
      weeks = weeksData.asMap().entries.map((entry) {
        final weekNum = entry.key + 1;
        final weekData = entry.value as Map<String, dynamic>;
        final weekStart = startDate.add(Duration(days: (weekNum - 1) * 7));
        final weekEnd = weekStart.add(const Duration(days: 6));

        final weekDaysData = weekData['days'] as List? ?? [];
        final days = weekDaysData.asMap().entries.map((dayEntry) {
          final dayData = dayEntry.value as Map<String, dynamic>;
          final dayOffset = dayEntry.key;
          final dayDate = weekStart.add(Duration(days: dayOffset));
          return _buildDailyWorkoutFromBlueprint(dayData, dayDate, prefs);
        }).toList();

        return WeeklyWorkoutPlanEntity(
          weekNumber: weekNum,
          startDate: weekStart,
          endDate: weekEnd,
          days: days,
        );
      }).toList();
    } else if (daysData != null && daysData.isNotEmpty) {
      final templateDays = List<Map<String, dynamic>?>.filled(7, null);
      for (int i = 0; i < daysData.length; i++) {
        final d = daysData[i] as Map<String, dynamic>;
        final dayStr = d['dayOfWeek']?.toString() ?? d['dayName']?.toString();
        int targetIdx = i % 7;
        
        if (dayStr != null) {
          final s = dayStr.toUpperCase();
          if (s.contains('MON')) { targetIdx = 0; }
          else if (s.contains('TUE')) { targetIdx = 1; }
          else if (s.contains('WED')) { targetIdx = 2; }
          else if (s.contains('THU')) { targetIdx = 3; }
          else if (s.contains('FRI')) { targetIdx = 4; }
          else if (s.contains('SAT')) { targetIdx = 5; }
          else if (s.contains('SUN')) { targetIdx = 6; }
        }
        templateDays[targetIdx] = d;
      }

      // -- Solar 4-Week Logic: W1 starts at startDate, W2+3 are full weeks, W4 ends on anniversary --
      
      // -- Week 1: startDate -> Sunday --
      final int daysInW1 = 8 - startDate.weekday; 
      final List<DailyWorkoutPlanEntity> w1Days = [];
      for (int d = 0; d < daysInW1; d++) {
        final dayDate = startDate.add(Duration(days: d));
        final blueprintIdx = dayDate.weekday - 1;
        final dayData = templateDays[blueprintIdx] ?? {};
        w1Days.add(_buildDailyWorkoutFromBlueprint(dayData, dayDate, prefs));
      }
      weeks.add(WeeklyWorkoutPlanEntity(
        weekNumber: 1,
        startDate: startDate,
        endDate: startDate.add(Duration(days: daysInW1 - 1)),
        days: w1Days,
      ));

      // -- Week 2 & 3: Monday -> Sunday --
      final DateTime week2Start = startDate.add(Duration(days: daysInW1));
      for (int w = 0; w < 2; w++) {
        final List<DailyWorkoutPlanEntity> wDaysList = [];
        final wStart = week2Start.add(Duration(days: w * 7));
        for (int d = 0; d < 7; d++) {
          final dayDate = wStart.add(Duration(days: d));
          final blueprintIdx = d; // 0=Mon, ..., 6=Sun
          final dayData = templateDays[blueprintIdx] ?? {};
          wDaysList.add(_buildDailyWorkoutFromBlueprint(dayData, dayDate, prefs));
        }
        weeks.add(WeeklyWorkoutPlanEntity(
          weekNumber: w + 2,
          startDate: wStart,
          endDate: wStart.add(const Duration(days: 6)),
          days: wDaysList,
        ));
      }

      // -- Week 4: Monday -> Anniversary Day --
      final DateTime week4Start = week2Start.add(const Duration(days: 14));
      final int daysInW4 = startDate.weekday; // e.g. Wed(3) -> Mon, Tue, Wed (3 days)
      final List<DailyWorkoutPlanEntity> w4Days = [];
      for (int d = 0; d < daysInW4; d++) {
        final dayDate = week4Start.add(Duration(days: d));
        final blueprintIdx = d;
        final dayData = templateDays[blueprintIdx] ?? {};
        w4Days.add(_buildDailyWorkoutFromBlueprint(dayData, dayDate, prefs));
      }
      weeks.add(WeeklyWorkoutPlanEntity(
        weekNumber: 4,
        startDate: week4Start,
        endDate: week4Start.add(Duration(days: daysInW4 - 1)),
        days: w4Days,
      ));
    } else {
      final routinesData = data['routines'] as List? ?? [];
      final List<DailyWorkoutPlanEntity> days = routinesData.asMap().entries.map((entry) {
        final idx = entry.key;
        final routineData = entry.value as Map<String, dynamic>;
        final dayDate = startDate.add(Duration(days: idx));
        return DailyWorkoutPlanEntity(
          id: 'day_${dayDate.toIso8601String()}',
          date: dayDate,
          workoutName: routineData['name'] as String? ?? 'Workout',
          exercises: const [],
          estimatedDurationMinutes: routineData['estimatedMinutes'] as int? ?? 45,
          estimatedCaloriesBurned: 300,
          targetMuscleGroups: _parseMuscleGroups(routineData['target_muscles'] as List?),
          isRestDay: false,
        );
      }).toList();

      // Simple 4-week structure with same days for now or just first 7 days
      weeks = [
        WeeklyWorkoutPlanEntity(
          weekNumber: 1,
          startDate: startDate,
          endDate: startDate.add(const Duration(days: 6)),
          days: days.take(7).toList(),
        )
      ];
    }

    return MonthlyWorkoutPlanEntity(
      id: data['id'] as String? ?? 'plan_${now.millisecondsSinceEpoch}',
      odUserId: odUserId,
      startDate: startDate,
      endDate: endDate,
      goal: prefs.goal,
      location: prefs.location,
      split: prefs.trainingSplit,
      dailyTarget: DailyWorkoutTargetEntity(
        exercisesPerSession: _getExerciseCountForGoal(prefs.goal),
        durationMinutes: prefs.sessionDurationMinutes,
        caloriesBurned: _estimateCaloriesBurned(prefs),
        setsPerMuscleGroup: _getSetsForGoal(prefs.goal),
      ),
      weeks: weeks,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<PlannedExerciseEntity> _parseExercisesFromApiResponse(
    List<dynamic> exercisesData,
    WorkoutPreferencesEntity prefs,
  ) {
    return exercisesData.map((exData) {
      final data = exData as Map<String, dynamic>;
      // Support 'exerciseName' (from AI) and 'name'
      final name = (data['exerciseName'] ?? data['name']) as String? ?? 'Exercise';
      final setsCount = data['sets'] as int? ?? 3;
      final repsRaw = data['reps'];
      int reps = 10;
      int? targetSeconds;

      if (repsRaw is int) {
        reps = repsRaw;
      } else if (repsRaw is String) {
        // Handle "10-12" -> 10
        final match = RegExp(r'(\d+)').firstMatch(repsRaw);
        if (match != null) {
          reps = int.parse(match.group(1)!);
        } else if (repsRaw.toLowerCase().contains('sec')) {
          // Handle "30 sec" -> 30 seconds
          final secMatch = RegExp(r'(\d+)').firstMatch(repsRaw);
          if (secMatch != null) targetSeconds = int.parse(secMatch.group(1)!);
        }
      }

      final restSecondsRaw = data['restSeconds'] ?? data['rest_seconds'] ?? 60;
      final restSeconds = restSecondsRaw is int ? restSecondsRaw : 60;

      return PlannedExerciseEntity(
        id: 'ex_${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: (data['description'] ?? data['progressionNote'] ?? '') as String,
        targetMuscles: _parseMuscleGroups(
            data['target_muscles'] as List? ??
            (data['muscleGroupPrimary'] != null ? [data['muscleGroupPrimary']] : null)),
        difficulty: _parseDifficulty(data['difficulty'] as String?),
        sets: List.generate(
          setsCount,
          (i) => ExerciseSetEntity(
            setNumber: i + 1,
            targetReps: reps,
            targetSeconds: targetSeconds ?? (data['target_seconds'] is int ? data['target_seconds'] as int : null),
            restSeconds: restSeconds,
            rpe: (data['rpe'] as num?)?.toDouble(),
            tempoEccentric: data['tempoEccentric'] as int?,
            tempoPause: data['tempoPause'] as int?,
            tempoConcentric: data['tempoConcentric'] as int?,
          ),
        ),
        requiredEquipment: _parseEquipment(data['equipment'] as List?),
      );
    }).toList();
  }

  /// Builds a [DailyWorkoutPlanEntity] from a single day blueprint map.
  /// Used when the API returns a flat days-array structure (no nested weeks).
  DailyWorkoutPlanEntity _buildDailyWorkoutFromBlueprint(
    Map<String, dynamic> dayData,
    DateTime dayDate,
    WorkoutPreferencesEntity prefs,
  ) {
    final sessionType = (dayData['sessionType'] as String? ?? '').toUpperCase();
    final isRest = dayData['isRestDay'] as bool? ??
        sessionType == 'REST' ||
        (dayData['type'] as String?)?.toLowerCase().contains('rest') == true;

    final workoutName = dayData['workoutName'] as String? ??
        dayData['name'] as String? ??
        dayData['dayName'] as String? ??
        (isRest ? 'Rest Day' : 'Workout');

    // AI schema uses 'mainWork' + 'warmup'; legacy/custom schemas use 'exercises'.
    // Combine all three so nothing is dropped regardless of which key the AI chose.
    final mainWork  = dayData['mainWork']  as List? ?? [];
    final warmup    = dayData['warmup']    as List? ?? [];
    final legacy    = dayData['exercises'] as List? ?? [];
    final rawExercises = [
      ...mainWork,
      ...warmup,
      ...legacy,
    ];
    final exercises = rawExercises.isEmpty
        ? <PlannedExerciseEntity>[]
        : _parseExercisesFromApiResponse(rawExercises, prefs);

    // Derive target muscles from parsed exercises first; fall back to day-level keys.
    final targetMuscles = exercises.isNotEmpty
        ? exercises.expand((e) => e.targetMuscles).toSet().toList()
        : _parseMuscleGroups(
            dayData['target_muscles'] as List? ??
            dayData['targetMuscles']  as List?);

    return DailyWorkoutPlanEntity(
      id: 'day_${dayDate.millisecondsSinceEpoch}',
      date: dayDate,
      workoutName: workoutName,
      exercises: exercises,
      estimatedDurationMinutes:
          dayData['estimatedDurationMinutes'] as int? ??
          dayData['duration'] as int? ??
          prefs.sessionDurationMinutes,
      estimatedCaloriesBurned:
          dayData['estimatedCaloriesBurned'] as int? ??
          _estimateCaloriesBurned(prefs),
      targetMuscleGroups: targetMuscles,
      scheduledTime: dayData['scheduledTime'] as String?,
      isRestDay: isRest,
    );
  }

  List<MuscleGroup> _parseMuscleGroups(List<dynamic>? muscles) {
    if (muscles == null || muscles.isEmpty) {
      return [MuscleGroup.fullBody];
    }
    return muscles.map((m) {
      final name = (m as String).toLowerCase().trim();
      // Handle common pluralization/aliasing
      if (name == 'abs' || name == 'abdominals' || name == 'core') return MuscleGroup.abs;
      if (name == 'chest' || name == 'pectorals' || name == 'pecs') return MuscleGroup.chest;
      if (name == 'biceps' || name == 'bicep') return MuscleGroup.biceps;
      if (name == 'triceps' || name == 'tricep') return MuscleGroup.triceps;
      if (name == 'back' || name == 'upper back' || name == 'mid back') return MuscleGroup.back;
      if (name == 'lats' || name == 'latissimus' || name == 'latissimus dorsi') return MuscleGroup.back;
      if (name == 'shoulders' || name == 'deltoids' || name == 'delts') return MuscleGroup.shoulders;
      if (name == 'quads' || name == 'quadriceps') return MuscleGroup.quads;
      if (name == 'hamstrings' || name == 'hammies') return MuscleGroup.hamstrings;
      if (name == 'glutes' || name == 'butt' || name == 'gluteus maximus') return MuscleGroup.glutes;
      if (name == 'calves' || name == 'calf' || name == 'gastrocnemius') return MuscleGroup.calves;
      if (name == 'forearms' || name == 'forearm') return MuscleGroup.forearms;
      if (name == 'traps' || name == 'trapezius') return MuscleGroup.traps;
      if (name == 'obliques' || name == 'oblique') return MuscleGroup.obliques;
      if (name == 'adductors' || name == 'inner thighs' || name == 'adductor') return MuscleGroup.adductors;
      if (name == 'neck' || name == 'neck flexors') return MuscleGroup.neck;
      if (name == 'cardio' || name == 'cardiovascular') return MuscleGroup.cardio;

      return MuscleGroup.values.firstWhere(
        (mg) => mg.name.toLowerCase() == name,
        orElse: () => MuscleGroup.fullBody,
      );
    }).toList();
  }

  ExerciseDifficulty _parseDifficulty(String? difficulty) {
    if (difficulty == null) return ExerciseDifficulty.intermediate;
    return ExerciseDifficulty.values.firstWhere(
      (d) => d.name.toLowerCase() == difficulty.toLowerCase(),
      orElse: () => ExerciseDifficulty.intermediate,
    );
  }

  List<Equipment> _parseEquipment(List<dynamic>? equipment) {
    if (equipment == null || equipment.isEmpty) return [];
    final result = <Equipment>[];
    for (final e in equipment) {
      final name = (e as String).toLowerCase().replaceAll('_', '').replaceAll('-', '');
      for (final eq in Equipment.values) {
        if (eq.name.toLowerCase() == name) {
          result.add(eq);
          break;
        }
      }
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIRECT AI GENERATION (DeepSeek API)
  // ════════════════════════════════════════════════════════════════════════════

  Future<MonthlyWorkoutPlanEntity> _generateWorkoutPlanViaDirectAI(
    WorkoutPreferencesEntity prefs,
    String odUserId, {
    UserBodyMetrics? userMetrics,
    List<String> targetMuscleNames = const [],
  }) async {
    if (config.apiKey == null || config.apiKey!.isEmpty) {
      return _generateWorkoutPlanOffline(
        prefs,
        odUserId,
        userMetrics: userMetrics,
      );
    }

    try {
      final strategy = DeepSeekGenerationStrategy(
        apiBaseUrl: config.apiBaseUrl ?? 'https://api.deepseek.com',
        apiKey: config.apiKey!,
        model: config.model,
        timeout: config.timeout,
        dio: dio,
      );

      // Compute per-day muscle assignments BEFORE calling AI, so prompt is day-specific
      final dayMuscleAssignments = _assignMusclesPerDay(
          prefs.targetMuscles, prefs.preferredDays);

      // Pass both the flat muscle list AND per-day assignments to the AI
      final result = await strategy.getRecommendations(prefs,
          userMetrics: userMetrics,
          targetMuscles: targetMuscleNames,
          dayMuscleAssignments: dayMuscleAssignments);
      
      final recommendations = result['recommendations'] as Map<String, dynamic>;
      final usage = result['usage'] as Map<String, dynamic>?;

      if (usage != null) {
        debugPrint('AI Usage (Workout): ${usage['total_tokens']} tokens (${usage['prompt_tokens']} prompt, ${usage['completion_tokens']} completion)');
      }

      return _generateWorkoutPlanWithAI(prefs, odUserId, recommendations);
    } catch (e) {
      debugPrint('AI Generation Error: $e');
      return _generateWorkoutPlanOffline(
        prefs,
        odUserId,
      );
    }
  }

  Future<MonthlyWorkoutPlanEntity> _generateWorkoutPlanWithAI(
    WorkoutPreferencesEntity prefs,
    String odUserId,
    Map<String, dynamic> aiRecommendations,
  ) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(const Duration(days: 27));

    // Extract AI recommendations
    final weeklyProgression =
        aiRecommendations['weeklyProgression'] as Map<String, dynamic>? ?? {};
    final priorityExercises =
        (aiRecommendations['exercisePriority'] as List?)?.cast<String>() ?? [];
    final restSeconds = aiRecommendations['restBetweenSets'] as int? ?? 60;

    final weeks = <WeeklyWorkoutPlanEntity>[];
    // Compute muscle→day assignments once for the whole plan
    final dayMuscleAssignments = _assignMusclesPerDay(
        prefs.targetMuscles, prefs.preferredDays);

    for (int weekNum = 1; weekNum <= 4; weekNum++) {
      final weekStart = startDate.add(Duration(days: (weekNum - 1) * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      // Get AI progression for this week
      final weekKey = 'week$weekNum';
      final repsMultiplier =
          (weeklyProgression[weekKey]?['repsMultiplier'] as num?)?.toDouble() ??
              1.0;
      final setsMultiplier =
          (weeklyProgression[weekKey]?['setsMultiplier'] as num?)?.toDouble() ??
              1.0;

      final days = <DailyWorkoutPlanEntity>[];

      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final dayDate = weekStart.add(Duration(days: dayOffset));
        final dayOfWeek = dayDate.weekday - 1;
        final isWorkoutDay = prefs.preferredDays.contains(dayOfWeek);

        if (isWorkoutDay) {
          days.add(_generateAIEnhancedDayPlan(
            date: dayDate,
            prefs: prefs,
            weekNumber: weekNum,
            dayOfWeek: dayOfWeek,
            repsMultiplier: repsMultiplier,
            setsMultiplier: setsMultiplier,
            priorityExercises: priorityExercises,
            restSeconds: restSeconds,
            dayMuscles: dayMuscleAssignments[dayOfWeek],
          ));
        } else {
          days.add(DailyWorkoutPlanEntity(
            id: 'day_${dayDate.toIso8601String()}',
            date: dayDate,
            workoutName: 'Rest Day',
            exercises: [],
            estimatedDurationMinutes: 0,
            estimatedCaloriesBurned: 0,
            targetMuscleGroups: [],
            isRestDay: true,
          ));
        }
      }

      weeks.add(WeeklyWorkoutPlanEntity(
        weekNumber: weekNum,
        startDate: weekStart,
        endDate: weekEnd,
        days: days,
      ));
    }

    return MonthlyWorkoutPlanEntity(
      id: 'plan_${now.millisecondsSinceEpoch}',
      odUserId: odUserId,
      startDate: startDate,
      endDate: endDate,
      goal: prefs.goal,
      location: prefs.location,
      split: prefs.trainingSplit,
      dailyTarget: DailyWorkoutTargetEntity(
        exercisesPerSession: _getExerciseCountForGoal(prefs.goal),
        durationMinutes: prefs.sessionDurationMinutes,
        caloriesBurned: _estimateCaloriesBurned(prefs),
        setsPerMuscleGroup: _getSetsForGoal(prefs.goal),
      ),
      weeks: weeks,
      createdAt: now,
      updatedAt: now,
    );
  }

  DailyWorkoutPlanEntity _generateAIEnhancedDayPlan({
    required DateTime date,
    required WorkoutPreferencesEntity prefs,
    required int weekNumber,
    required int dayOfWeek,
    required double repsMultiplier,
    required double setsMultiplier,
    required List<String> priorityExercises,
    required int restSeconds,
    List<String>? dayMuscles,
  }) {
    final String workoutName;
    final List<MuscleGroup> muscleGroups;
    final List<PlannedExerciseEntity> exercises;

    if (dayMuscles != null && dayMuscles.isNotEmpty) {
      // MUSCLE-AWARE PATH: use per-day muscle assignment
      workoutName = _getWorkoutLabelForMuscles(dayMuscles);
      muscleGroups = _expandMusclesForQuery(dayMuscles)
          .map((n) => _parseMuscleGroups([n]).first)
          .toSet()
          .toList();
      final raw = _selectExercisesForDayMuscles(
        dayMuscles: dayMuscles,
        prefs: prefs,
        count: _getExerciseCountForGoal(prefs.goal),
      );
      exercises = raw.map((ex) {
        return _applyAIProgression(ex, repsMultiplier, setsMultiplier, restSeconds);
      }).toList();
    } else {
      // FALLBACK: AI priority list across split bucket
      workoutName = _getWorkoutNameForSplit(prefs.trainingSplit, dayOfWeek);
      muscleGroups = _getMuscleGroupsForWorkout(workoutName);
      exercises = _getAIEnhancedExercises(
        workoutName: workoutName,
        prefs: prefs,
        repsMultiplier: repsMultiplier,
        setsMultiplier: setsMultiplier,
        priorityExercises: priorityExercises,
        restSeconds: restSeconds,
        dayVariation: date.day % 3,
      );
    }

    return DailyWorkoutPlanEntity(
      id: 'day_${date.toIso8601String()}',
      date: date,
      workoutName: workoutName,
      exercises: exercises,
      estimatedDurationMinutes: prefs.sessionDurationMinutes,
      estimatedCaloriesBurned: _estimateCaloriesBurned(prefs),
      targetMuscleGroups: muscleGroups,
      scheduledTime: prefs.reminderTime,
    );
  }

  List<PlannedExerciseEntity> _getAIEnhancedExercises({
    required String workoutName,
    required WorkoutPreferencesEntity prefs,
    required double repsMultiplier,
    required double setsMultiplier,
    required List<String> priorityExercises,
    required int restSeconds,
    required int dayVariation,
  }) {
    final database = _getExerciseDatabase(prefs.location);
    final workoutExercises =
        database[workoutName] ?? database['Full Body'] ?? [];

    // Filter by equipment and preferences
    var filtered = workoutExercises.where((e) {
      if (e.requiredEquipment.isNotEmpty) {
        final hasEquipment = e.requiredEquipment
            .any((eq) => prefs.availableEquipment.contains(eq));
        if (!hasEquipment) return false;
      }
      if (prefs.dislikedExercises.contains(e.name)) return false;
      return true;
    }).toList();

    // Sort: user-selected target muscles first, then AI priority, then liked
    if (prefs.targetMuscles.isNotEmpty) {
      final targetSet = prefs.targetMuscles.toSet();
      filtered.sort((a, b) {
        final aTargets = a.targetMuscles.any((m) => targetSet.contains(m.name));
        final bTargets = b.targetMuscles.any((m) => targetSet.contains(m.name));
        if (aTargets && !bTargets) return -1;
        if (!aTargets && bTargets) return 1;
        // Secondary: AI priority list
        final aPriority = priorityExercises.indexOf(a.name);
        final bPriority = priorityExercises.indexOf(b.name);
        final aLiked = prefs.likedExercises.contains(a.name) ? -10 : 0;
        final bLiked = prefs.likedExercises.contains(b.name) ? -10 : 0;
        final aScore = (aPriority >= 0 ? aPriority : 100) + aLiked;
        final bScore = (bPriority >= 0 ? bPriority : 100) + bLiked;
        return aScore.compareTo(bScore);
      });
    } else {
      // No muscle target — use AI priority + user likes
      filtered.sort((a, b) {
        final aPriority = priorityExercises.indexOf(a.name);
        final bPriority = priorityExercises.indexOf(b.name);
        final aLiked = prefs.likedExercises.contains(a.name) ? -10 : 0;
        final bLiked = prefs.likedExercises.contains(b.name) ? -10 : 0;
        final aScore = (aPriority >= 0 ? aPriority : 100) + aLiked;
        final bScore = (bPriority >= 0 ? bPriority : 100) + bLiked;
        return aScore.compareTo(bScore);
      });
    }

    // Apply day variation
    if (dayVariation > 0 && filtered.length > 3) {
      final shuffled = List<PlannedExerciseEntity>.from(filtered);
      for (int i = 0; i < dayVariation && shuffled.length > 1; i++) {
        final first = shuffled.removeAt(0);
        shuffled.insert(shuffled.length ~/ 2, first);
      }
      filtered = shuffled;
    }

    // Apply AI-recommended progression
    final count = _getExerciseCountForGoal(prefs.goal);
    return filtered.take(count).map((exercise) {
      return _applyAIProgression(
          exercise, repsMultiplier, setsMultiplier, restSeconds);
    }).toList();
  }

  PlannedExerciseEntity _applyAIProgression(
    PlannedExerciseEntity exercise,
    double repsMultiplier,
    double setsMultiplier,
    int restSeconds,
  ) {
    final baseReps =
        exercise.sets.isNotEmpty ? exercise.sets.first.targetReps : 10;
    final baseSets = exercise.sets.length;

    final newReps = (baseReps * repsMultiplier).round();
    final newSets = (baseSets * setsMultiplier).round().clamp(1, 6);

    final newSetsList = List.generate(newSets, (index) {
      final originalSet = index < exercise.sets.length
          ? exercise.sets[index]
          : exercise.sets.last;
      return ExerciseSetEntity(
        setNumber: index + 1,
        targetReps: newReps,
        targetSeconds: originalSet.targetSeconds,
        targetWeight: originalSet.targetWeight,
        restSeconds: restSeconds,
      );
    });

    return exercise.copyWith(sets: newSetsList);
  }

  PlannedExerciseEntity _applyBodyAwareLogic(
    PlannedExerciseEntity exercise,
    int weekNumber,
    WorkoutGoal goal,
    UserBodyMetrics? metrics,
  ) {
    // 1. Base Progressive Overload (Weekly Intensity)
    var updated = _applyProgressiveOverload(exercise, weekNumber, goal);

    // 2. Age-Based Scaling (Premium Experience)
    if (metrics != null && metrics.age != null && metrics.age! > 45) {
      // For older users, reduce intensity slightly and increase rest
      final ageFactor = (metrics.age! - 45) / 50.0; // 0.0 at 45, 0.5 at 70
      
      final scaledSets = updated.sets.map((s) {
        // Increase rest time for recovery
        final newRest = (s.restSeconds * (1.0 + ageFactor)).round().clamp(60, 180);
        // Slightly lower reps if age is high
        final newReps = metrics.age! > 60 ? (s.targetReps * 0.8).round().clamp(5, 20) : s.targetReps;
        
        return s.copyWith(
          restSeconds: newRest,
          targetReps: newReps,
        );
      }).toList();

      updated = updated.copyWith(sets: scaledSets);
    }

    // 3. Experience Level Scaling
    if (updated.difficulty == ExerciseDifficulty.advanced && metrics?.age != null && metrics!.age! > 60) {
      // Safety: Mark advanced exercises as intermediate-load for seniors
      updated = updated.copyWith(difficulty: ExerciseDifficulty.intermediate);
    }

    return updated;
  }

  Future<List<PlannedExerciseEntity>> _swapExercisesViaDirectAI(
    DailyWorkoutPlanEntity currentDay,
    WorkoutPreferencesEntity preferences,
    int count,
  ) async {
    // For swapping, use offline logic (fast and reliable)
    // AI enhancement is better for initial plan generation
    return _swapExercisesOffline(currentDay, preferences, count);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ════════════════════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════════════════════
  // MUSCLE-AWARE DAY ASSIGNMENT ENGINE
  // ════════════════════════════════════════════════════════════════════════════

  /// Maps each muscle name to its synergy category (push/pull/legs/core)
  static const Map<String, String> _muscleSynergyCategory = {
    // Push
    'chest': 'push', 'pectorals': 'push', 'pecs': 'push', 'chest_muscles': 'push', 'pec': 'push',
    'shoulders': 'push', 'deltoids': 'push', 'delts': 'push', 'front_delts': 'push', 'side_delts': 'push', 'shoulder': 'push',
    'triceps': 'push', 'tricep': 'push',
    // Pull
    'back': 'pull', 'lats': 'pull', 'latissimus': 'pull', 'upper_back': 'pull', 'lower_back': 'pull',
    'traps': 'pull', 'trapezius': 'pull', 'rear_delts': 'pull', 'bicep': 'pull', 'biceps': 'pull',
    'forearms': 'pull', 'forearm': 'pull',
    // Legs
    'legs': 'legs', 'lower_body': 'legs', 'leg': 'legs',
    'quads': 'legs', 'quadriceps': 'legs', 'thighs': 'legs', 'quad': 'legs',
    'hamstrings': 'legs', 'hams': 'legs', 'glutes': 'legs', 'gluteus': 'legs', 'butt': 'legs',
    'calves': 'legs', 'calf': 'legs', 'adductors': 'legs', 'hamstring': 'legs', 'glute': 'legs',
    // Core
    'core': 'core', 'abs': 'core', 'abdominals': 'core', 'upper_abs': 'core', 'lower_abs': 'core', 'obliques': 'core', 'oblique': 'core',
  };

  /// Expand composite muscle names for DB queries (e.g., 'legs' → quads/hamstrings/glutes/calves)
  List<String> _expandMusclesForQuery(List<String> muscles) {
    final expanded = <String>{};
    for (final m in muscles) {
      if (m.toLowerCase() == 'legs') {
        expanded.addAll(['quads', 'hamstrings', 'glutes', 'calves']);
      } else {
        expanded.add(m.toLowerCase());
      }
    }
    return expanded.toList();
  }

  /// Generate a human-readable workout name from assigned muscles
  String _getWorkoutLabelForMuscles(List<String> muscles) {
    if (muscles.isEmpty) return 'Full Body Split';
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    final focus = muscles.map(cap).take(3).join(' & ');
    return '$focus Focus';
  }

  /// Assign user-selected muscles to available workout days using synergy grouping.
  /// Groups: Push (chest/shoulders/triceps), Pull (back/biceps), Legs, Core.
  /// Scales to any number of days and any muscle combination.
  Map<int, List<String>> _assignMusclesPerDay(
    List<String> targetMuscles,
    List<int> preferredDays,
  ) {
    if (targetMuscles.isEmpty || preferredDays.isEmpty) {
      return {for (final d in preferredDays) d: targetMuscles};
    }
    final push = <String>[], pull = <String>[], legs = <String>[], core = <String>[];
    for (final m in targetMuscles) {
      final normalized = m.toLowerCase().trim().replaceAll(' ', '_');
      switch (_muscleSynergyCategory[normalized]) {
        case 'push': push.add(m); break;
        case 'pull': pull.add(m); break;
        case 'legs': legs.add(m); break;
        case 'core': core.add(m); break;
        default: 
          // Re-check normalized name as a key directly
          if (normalized.contains('abs') || normalized.contains('core')) {
            core.add(m);
          } else if (normalized.contains('chest') || normalized.contains('shoul')) {
            push.add(m);
          } else if (normalized.contains('back') || normalized.contains('pull')) {
            pull.add(m);
          } else if (normalized.contains('leg') || normalized.contains('squat')) {
            legs.add(m);
          } else {
            push.add(m); // unknown → assign to push
          }
      }
    }
    // Build ordered groups — Push first, Pull second, Legs third, Core last
    final groups = <List<String>>[
      if (push.isNotEmpty) push,
      if (pull.isNotEmpty) pull,
      if (legs.isNotEmpty) legs,
      if (core.isNotEmpty) core,
    ];
    if (groups.isEmpty) {
      return {for (final d in preferredDays) d: targetMuscles};
    }
    // Merge excess groups into the smallest existing day if more groups than days
    while (groups.length > preferredDays.length) {
      final last = groups.removeLast();
      int minIdx = 0;
      for (int i = 1; i < groups.length; i++) {
        if (groups[i].length < groups[minIdx].length) minIdx = i;
      }
      groups[minIdx].addAll(last);
    }
    final sortedDays = [...preferredDays]..sort();
    return {
      for (int i = 0; i < sortedDays.length; i++)
        sortedDays[i]: i < groups.length ? groups[i] : groups[i % groups.length],
    };
  }

  /// Select exercises from the ENTIRE database that match the given day's muscles.
  /// Deduplicates across all bucket keys. Distributes evenly per muscle.
  List<PlannedExerciseEntity> _selectExercisesForDayMuscles({
    required List<String> dayMuscles,
    required WorkoutPreferencesEntity prefs,
    int count = 5,
  }) {
    final db = _getExerciseDatabase(prefs.location);
    // Flatten and deduplicate entire DB by exercise ID
    final allById = <String, PlannedExerciseEntity>{};
    for (final exList in db.values) {
      for (final ex in exList) {
        allById[ex.id] = ex;
      }
    }

    // Expand composite names (legs → quads/hamstrings/glutes/calves)
    final queryMuscles = _expandMusclesForQuery(dayMuscles).map((m) => m.toLowerCase().trim()).toSet();
    
    // Filter by equipment + dislikes
    final available = allById.values.where((ex) {
      // 1. Equipment check
      if (ex.requiredEquipment.isNotEmpty) {
        final hasRequired = ex.requiredEquipment.any((eq) => prefs.availableEquipment.contains(eq));
        if (!hasRequired) return false;
      }
      
      // 2. Disliked check
      if (prefs.preferredDays.isEmpty && prefs.dislikedExercises.contains(ex.name)) return false;

      // 3. Muscle Match Performance Hardening: 
      // Ensure we check BOTH primary/target muscles for exact OR substring matches
      final muscleMatch = ex.targetMuscles.any((m) {
        final mName = m.name.toLowerCase();
        return queryMuscles.any((q) => mName.contains(q) || q.contains(mName));
      });
      
      return muscleMatch;
    }).toList();

    // If we have NO matches for the specific muscles (too strict), fallback to a split bucket
    if (available.isEmpty) {
      final category = dayMuscles.isNotEmpty ? _muscleSynergyCategory[dayMuscles.first.toLowerCase().trim()] : 'Full Body';
      final fallbackExercises = db[category] ?? db['Full Body'] ?? [];
      return fallbackExercises.take(count).toList();
    }

    // Distribute exercises evenly across the requested muscles for variety
    final selected = <PlannedExerciseEntity>[];
    final musclesToCycle = queryMuscles.toList();
    
    int mIdx = 0;
    while (selected.length < count && available.isNotEmpty) {
      final target = musclesToCycle[mIdx % musclesToCycle.length];
      final match = available.firstWhere(
        (ex) => ex.targetMuscles.any((m) => m.name.toLowerCase().contains(target)),
        orElse: () => available.first,
      );
      selected.add(match);
      available.remove(match);
      mIdx++;
    }

    return selected;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SPLIT-BASED HELPERS (fallback when no muscle preference set)
  // ════════════════════════════════════════════════════════════════════════════

  String _getWorkoutNameForSplit(TrainingSplit split, int dayOfWeek) {
    switch (split) {
      case TrainingSplit.fullBody:
        return 'Full Body';
      case TrainingSplit.upperLower:
        return dayOfWeek % 2 == 0 ? 'Upper Body' : 'Lower Body';
      case TrainingSplit.pushPullLegs:
        final cycle = dayOfWeek % 3;
        return cycle == 0 ? 'Push' : (cycle == 1 ? 'Pull' : 'Legs');
      case TrainingSplit.broSplit:
        final names = ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs'];
        return names[dayOfWeek % names.length];
      case TrainingSplit.custom:
        return 'Full Body'; // custom falls back to full body until user sets muscles
    }
  }

  List<MuscleGroup> _getMuscleGroupsForWorkout(String workoutName) {
    switch (workoutName) {
      case 'Full Body':
        return [MuscleGroup.fullBody];
      case 'Upper Body':
        return [
          MuscleGroup.chest,
          MuscleGroup.back,
          MuscleGroup.shoulders,
          MuscleGroup.biceps,
          MuscleGroup.triceps
        ];
      case 'Lower Body':
        return [
          MuscleGroup.quads,
          MuscleGroup.hamstrings,
          MuscleGroup.glutes,
          MuscleGroup.calves
        ];
      case 'Push':
        return [MuscleGroup.chest, MuscleGroup.shoulders, MuscleGroup.triceps];
      case 'Pull':
        return [MuscleGroup.back, MuscleGroup.biceps];
      case 'Legs':
        return [
          MuscleGroup.quads,
          MuscleGroup.hamstrings,
          MuscleGroup.glutes,
          MuscleGroup.calves
        ];
      case 'Chest':
        return [MuscleGroup.chest];
      case 'Back':
        return [MuscleGroup.back];
      case 'Shoulders':
        return [MuscleGroup.shoulders];
      case 'Arms':
        return [MuscleGroup.biceps, MuscleGroup.triceps];
      default:
        return [MuscleGroup.fullBody];
    }
  }

  int _getExerciseCountForGoal(WorkoutGoal goal) {
    switch (goal) {
      case WorkoutGoal.weightLoss:
        return 6;
      case WorkoutGoal.muscleGain:
        return 5;
      case WorkoutGoal.strength:
        return 4;
      case WorkoutGoal.endurance:
        return 8;
      case WorkoutGoal.flexibility:
        return 6;
      case WorkoutGoal.generalFitness:
        return 5;
    }
  }

  int _getSetsForGoal(WorkoutGoal goal) {
    switch (goal) {
      case WorkoutGoal.strength:
        return 5;
      case WorkoutGoal.muscleGain:
        return 4;
      case WorkoutGoal.weightLoss:
      case WorkoutGoal.endurance:
        return 3;
      case WorkoutGoal.flexibility:
      case WorkoutGoal.generalFitness:
        return 3;
    }
  }

  int _estimateCaloriesBurned(WorkoutPreferencesEntity prefs) {
    final baseRate = switch (prefs.goal) {
      WorkoutGoal.weightLoss => 10,
      WorkoutGoal.endurance => 9,
      WorkoutGoal.muscleGain => 7,
      WorkoutGoal.strength => 6,
      WorkoutGoal.flexibility => 4,
      WorkoutGoal.generalFitness => 7,
    };
    return prefs.sessionDurationMinutes * baseRate;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // EXERCISE DATABASE
  // ════════════════════════════════════════════════════════════════════════════

  Map<String, List<PlannedExerciseEntity>> _getExerciseDatabase(
      TrainingLocation location) {
    if (location == TrainingLocation.home) {
      return _homeExerciseDatabase;
    } else {
      return _gymExerciseDatabase;
    }
  }

  PlannedExerciseEntity _createExercise(
    String name,
    String description,
    List<MuscleGroup> muscles,
    int sets,
    int reps,
    List<Equipment> equipment, {
    int? targetSeconds,
  }) {
    return PlannedExerciseEntity(
      // Deterministic ID based on name — NEVER use timestamps here.
      // Timestamp IDs break Hive completion tracking when plans are re-parsed.
      id: 'ex_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: name,
      description: description,
      targetMuscles: muscles,
      difficulty: ExerciseDifficulty.intermediate,
      sets: List.generate(
          sets,
          (i) => ExerciseSetEntity(
                setNumber: i + 1,
                targetReps: reps,
                targetSeconds: targetSeconds,
                restSeconds: 60,
              )),
      requiredEquipment: equipment,
    );
  }

  Map<String, List<PlannedExerciseEntity>> get _homeExerciseDatabase => {
        'Full Body': [
          _createExercise('Pushups', 'Chest, triceps, shoulders',
              [MuscleGroup.chest, MuscleGroup.triceps], 3, 12, []),
          _createExercise('Air Squats', 'Quads, glutes',
              [MuscleGroup.quads, MuscleGroup.glutes], 3, 15, []),
          _createExercise(
              'Plank', 'Core stability', [MuscleGroup.abs], 3, 0, [],
              targetSeconds: 60),
          _createExercise('Lunges', 'Legs unilateral',
              [MuscleGroup.quads, MuscleGroup.glutes], 3, 10, []),
          _createExercise('Mountain Climbers', 'Cardio and core',
              [MuscleGroup.abs, MuscleGroup.cardio], 3, 20, []),
          _createExercise(
              'Burpees', 'Full body cardio', [MuscleGroup.fullBody], 3, 10, []),
          _createExercise('Glute Bridges', 'Glutes and hamstrings',
              [MuscleGroup.glutes, MuscleGroup.hamstrings], 3, 15, []),
          _createExercise(
              'Superman', 'Lower back', [MuscleGroup.back], 3, 12, []),
          _createExercise('Jumping Jacks', 'Cardio warmup',
              [MuscleGroup.cardio], 3, 30, []),
          _createExercise('High Knees', 'Cardio',
              [MuscleGroup.cardio, MuscleGroup.quads], 3, 20, []),
          _createExercise('Diamond Pushups', 'Triceps focus', [MuscleGroup.triceps], 3, 10, []),
          _createExercise('Bird Dog', 'Core and balance', [MuscleGroup.abs, MuscleGroup.back], 3, 12, []),
          _createExercise('Calf Raises', 'Lower legs', [MuscleGroup.calves], 3, 20, []),
          _createExercise('Wall Sit', 'Quads endurance', [MuscleGroup.quads], 3, 0, [], targetSeconds: 45),
          _createExercise('Russian Twists', 'Obliques', [MuscleGroup.abs], 3, 20, []),
          _createExercise('Pike Pushups', 'Shoulders focus', [MuscleGroup.shoulders], 3, 10, []),
          _createExercise('Bicycle Crunches', 'Abs and obliques', [MuscleGroup.abs], 3, 20, []),
          _createExercise('Side Plank', 'Lateral core', [MuscleGroup.abs], 3, 0, [], targetSeconds: 30),
        ],
        'Upper Body': [
          _createExercise('Pushups', 'Chest, triceps, shoulders',
              [MuscleGroup.chest], 3, 12, []),
          _createExercise('Diamond Pushups', 'Triceps focus',
              [MuscleGroup.triceps], 3, 10, []),
          _createExercise(
              'Wide Pushups', 'Chest width', [MuscleGroup.chest], 3, 12, []),
          _createExercise(
              'Pike Pushups', 'Shoulders', [MuscleGroup.shoulders], 3, 10, []),
          _createExercise(
              'Dips (Chair)', 'Triceps', [MuscleGroup.triceps], 3, 12, []),
          _createExercise(
              'Inverted Rows', 'Back', [MuscleGroup.back], 3, 10, []),
          _createExercise('Arm Circles', 'Shoulder mobility',
              [MuscleGroup.shoulders], 3, 15, []),
        ],
        'Lower Body': [
          _createExercise(
              'Air Squats', 'Quads, glutes', [MuscleGroup.quads], 4, 15, []),
          _createExercise(
              'Lunges', 'Unilateral legs', [MuscleGroup.quads], 3, 12, []),
          _createExercise(
              'Glute Bridges', 'Glutes', [MuscleGroup.glutes], 3, 15, []),
          _createExercise(
              'Calf Raises', 'Calves', [MuscleGroup.calves], 3, 20, []),
          _createExercise(
              'Wall Sit', 'Isometric quads', [MuscleGroup.quads], 3, 0, [],
              targetSeconds: 45),
          _createExercise('Jump Squats', 'Power',
              [MuscleGroup.quads, MuscleGroup.glutes], 3, 10, []),
          _createExercise('Bulgarian Split Squats', 'Unilateral',
              [MuscleGroup.quads], 3, 10, []),
          _createExercise('Step Ups', 'Functional',
              [MuscleGroup.quads, MuscleGroup.glutes], 3, 12, []),
        ],
        'Push': [
          _createExercise(
              'Pushups', 'Chest focus', [MuscleGroup.chest], 4, 12, []),
          _createExercise(
              'Wide Pushups', 'Chest width', [MuscleGroup.chest], 3, 12, []),
          _createExercise(
              'Pike Pushups', 'Shoulders', [MuscleGroup.shoulders], 3, 10, []),
          _createExercise(
              'Diamond Pushups', 'Triceps', [MuscleGroup.triceps], 3, 10, []),
          _createExercise(
              'Decline Pushups', 'Upper chest', [MuscleGroup.chest], 3, 10, []),
        ],
        'Pull': [
          _createExercise(
              'Inverted Rows', 'Back', [MuscleGroup.back], 4, 10, []),
          _createExercise(
              'Superman', 'Lower back', [MuscleGroup.back], 3, 12, []),
          _createExercise('Reverse Snow Angels', 'Rear delts',
              [MuscleGroup.back], 3, 12, []),
          _createExercise(
              'Prone Y Raises', 'Upper back', [MuscleGroup.back], 3, 12, []),
        ],
        'Legs': [
          _createExercise(
              'Air Squats', 'Quads', [MuscleGroup.quads], 4, 15, []),
          _createExercise('Bulgarian Split Squats', 'Unilateral',
              [MuscleGroup.quads], 3, 10, []),
          _createExercise('Romanian Deadlift (Single Leg)', 'Hamstrings',
              [MuscleGroup.hamstrings], 3, 10, []),
          _createExercise(
              'Glute Bridges', 'Glutes', [MuscleGroup.glutes], 4, 15, []),
          _createExercise(
              'Calf Raises', 'Calves', [MuscleGroup.calves], 3, 20, []),
          _createExercise('Sumo Squats', 'Inner thighs',
              [MuscleGroup.quads, MuscleGroup.glutes], 3, 12, []),
        ],
        'Chest': [
          _createExercise(
              'Pushups', 'Standard', [MuscleGroup.chest], 4, 12, []),
          _createExercise(
              'Wide Pushups', 'Width', [MuscleGroup.chest], 3, 12, []),
          _createExercise(
              'Diamond Pushups', 'Inner chest', [MuscleGroup.chest], 3, 10, []),
          _createExercise(
              'Decline Pushups', 'Upper chest', [MuscleGroup.chest], 3, 10, []),
        ],
        'Back': [
          _createExercise(
              'Inverted Rows', 'Lats', [MuscleGroup.back], 4, 10, []),
          _createExercise(
              'Superman', 'Lower back', [MuscleGroup.back], 3, 12, []),
          _createExercise('Reverse Snow Angels', 'Upper back',
              [MuscleGroup.back], 3, 12, []),
        ],
        'Shoulders': [
          _createExercise('Pike Pushups', 'Front delts',
              [MuscleGroup.shoulders], 4, 10, []),
          _createExercise(
              'Arm Circles', 'All delts', [MuscleGroup.shoulders], 3, 20, []),
          _createExercise('Wall Handstand Hold', 'Stability',
              [MuscleGroup.shoulders], 3, 0, [],
              targetSeconds: 30),
        ],
        'Arms': [
          _createExercise(
              'Diamond Pushups', 'Triceps', [MuscleGroup.triceps], 4, 12, []),
          _createExercise(
              'Dips (Chair)', 'Triceps', [MuscleGroup.triceps], 3, 12, []),
          _createExercise('Chin Up Hold', 'Biceps isometric',
              [MuscleGroup.biceps], 3, 0, [],
              targetSeconds: 20),
        ],
      };

  Map<String, List<PlannedExerciseEntity>> get _gymExerciseDatabase => {
        'Full Body': [
          _createExercise(
              'Barbell Squat',
              'Compound leg',
              [MuscleGroup.quads, MuscleGroup.glutes],
              4,
              8,
              [Equipment.barbell]),
          _createExercise('Bench Press', 'Chest compound', [MuscleGroup.chest],
              4, 8, [Equipment.barbell, Equipment.bench]),
          _createExercise(
              'Deadlift',
              'Full posterior',
              [MuscleGroup.back, MuscleGroup.hamstrings],
              3,
              6,
              [Equipment.barbell]),
          _createExercise('Overhead Press', 'Shoulders',
              [MuscleGroup.shoulders], 3, 8, [Equipment.barbell]),
          _createExercise('Barbell Row', 'Back', [MuscleGroup.back], 3, 8,
              [Equipment.barbell]),
          _createExercise('Dumbbell Lunges', 'Legs', [MuscleGroup.quads], 3, 10,
              [Equipment.dumbbells]),
        ],
        'Upper Body': [
          _createExercise('Bench Press', 'Chest', [MuscleGroup.chest], 4, 8,
              [Equipment.barbell]),
          _createExercise('Incline Dumbbell Press', 'Upper chest',
              [MuscleGroup.chest], 3, 10, [Equipment.dumbbells]),
          _createExercise('Lat Pulldown', 'Back width', [MuscleGroup.back], 4,
              10, [Equipment.machines]),
          _createExercise('Cable Rows', 'Back thickness', [MuscleGroup.back], 3,
              10, [Equipment.cables]),
          _createExercise('Lateral Raises', 'Side delts',
              [MuscleGroup.shoulders], 3, 12, [Equipment.dumbbells]),
          _createExercise('Bicep Curls', 'Biceps', [MuscleGroup.biceps], 3, 12,
              [Equipment.dumbbells]),
          _createExercise('Tricep Pushdown', 'Triceps', [MuscleGroup.triceps],
              3, 12, [Equipment.cables]),
          _createExercise('Face Pulls', 'Rear delts', [MuscleGroup.shoulders],
              3, 15, [Equipment.cables]),
        ],
        'Lower Body': [
          _createExercise('Barbell Squat', 'Quads', [MuscleGroup.quads], 4, 8,
              [Equipment.barbell]),
          _createExercise('Romanian Deadlift', 'Hamstrings',
              [MuscleGroup.hamstrings], 4, 10, [Equipment.barbell]),
          _createExercise('Leg Press', 'Quads', [MuscleGroup.quads], 3, 12,
              [Equipment.machines]),
          _createExercise('Leg Curl', 'Hamstrings', [MuscleGroup.hamstrings], 3,
              12, [Equipment.machines]),
          _createExercise('Calf Raises', 'Calves', [MuscleGroup.calves], 4, 15,
              [Equipment.machines]),
          _createExercise('Hip Thrust', 'Glutes', [MuscleGroup.glutes], 3, 12,
              [Equipment.barbell]),
          _createExercise('Leg Extension', 'Quads isolation',
              [MuscleGroup.quads], 3, 12, [Equipment.machines]),
        ],
        'Push': [
          _createExercise('Bench Press', 'Chest compound', [MuscleGroup.chest], 4, 8, [Equipment.barbell, Equipment.bench]),
          _createExercise('Overhead Press', 'Shoulders compound', [MuscleGroup.shoulders], 4, 8, [Equipment.barbell]),
          _createExercise('Incline Dumbbell Press', 'Upper chest', [MuscleGroup.chest], 3, 10, [Equipment.dumbbells]),
          _createExercise('Lateral Raises', 'Side delts', [MuscleGroup.shoulders], 3, 12, [Equipment.dumbbells]),
          _createExercise('Tricep Pushdown', 'Triceps isolation', [MuscleGroup.triceps], 3, 12, [Equipment.cables]),
          _createExercise('Dumbbell Flyes', 'Chest stretch', [MuscleGroup.chest], 3, 12, [Equipment.dumbbells]),
          _createExercise('Close-Grip Bench Press', 'Triceps compound', [MuscleGroup.triceps], 3, 8, [Equipment.barbell, Equipment.bench]),
          _createExercise('Seated Dumbbell Press', 'Shoulders', [MuscleGroup.shoulders], 3, 10, [Equipment.dumbbells]),
          _createExercise('Skull Crushers', 'Triceps', [MuscleGroup.triceps], 3, 10, [Equipment.barbell, Equipment.bench]),
          _createExercise('Arnold Press', 'All deltoid heads', [MuscleGroup.shoulders], 3, 10, [Equipment.dumbbells]),
          _createExercise('Cable Chest Fly', 'Chest isolation', [MuscleGroup.chest], 3, 12, [Equipment.cables]),
          _createExercise('Overhead Tricep Extension', 'Triceps long head', [MuscleGroup.triceps], 3, 12, [Equipment.dumbbells]),
        ],
        'Pull': [
          _createExercise('Deadlift', 'Full back compound', [MuscleGroup.back], 4, 5, [Equipment.barbell]),
          _createExercise('Barbell Row', 'Back thickness', [MuscleGroup.back], 4, 8, [Equipment.barbell]),
          _createExercise('Lat Pulldown', 'Back width', [MuscleGroup.back], 3, 10, [Equipment.machines]),
          _createExercise('Face Pulls', 'Rear delts', [MuscleGroup.shoulders], 3, 15, [Equipment.cables]),
          _createExercise('Bicep Curls', 'Biceps classic', [MuscleGroup.biceps], 3, 12, [Equipment.dumbbells]),
          _createExercise('Hammer Curls', 'Brachialis', [MuscleGroup.biceps], 3, 12, [Equipment.dumbbells]),
          _createExercise('T-Bar Row', 'Back thickness', [MuscleGroup.back], 3, 8, [Equipment.barbell]),
          _createExercise('Single-Arm Dumbbell Row', 'Lats unilateral', [MuscleGroup.back], 3, 10, [Equipment.dumbbells]),
          _createExercise('Seated Cable Row', 'Mid back', [MuscleGroup.back], 3, 10, [Equipment.cables]),
          _createExercise('Preacher Curl', 'Biceps peak', [MuscleGroup.biceps], 3, 10, [Equipment.machines]),
          _createExercise('EZ Bar Curl', 'Biceps wrist-friendly', [MuscleGroup.biceps], 3, 10, [Equipment.barbell]),
          _createExercise('Cable Curl', 'Biceps constant tension', [MuscleGroup.biceps], 3, 12, [Equipment.cables]),
          _createExercise('Chest-Supported Row', 'Back isolation', [MuscleGroup.back], 3, 10, [Equipment.machines]),
          _createExercise('Rear Delt Fly', 'Rear deltoids', [MuscleGroup.shoulders], 3, 15, [Equipment.dumbbells]),
        ],
        'Legs': [
          _createExercise('Barbell Squat', 'Quads', [MuscleGroup.quads], 4, 8,
              [Equipment.barbell]),
          _createExercise('Romanian Deadlift', 'Hamstrings',
              [MuscleGroup.hamstrings], 4, 10, [Equipment.barbell]),
          _createExercise('Leg Press', 'Quads', [MuscleGroup.quads], 3, 12,
              [Equipment.machines]),
          _createExercise('Walking Lunges', 'Unilateral', [MuscleGroup.quads],
              3, 12, [Equipment.dumbbells]),
          _createExercise('Leg Curl', 'Hamstrings', [MuscleGroup.hamstrings], 3,
              12, [Equipment.machines]),
          _createExercise('Calf Raises', 'Calves', [MuscleGroup.calves], 4, 15,
              [Equipment.machines]),
        ],
        'Chest': [
          _createExercise('Bench Press', 'Flat press', [MuscleGroup.chest], 4, 8, [Equipment.barbell, Equipment.bench]),
          _createExercise('Incline Dumbbell Press', 'Upper chest', [MuscleGroup.chest], 3, 10, [Equipment.dumbbells]),
          _createExercise('Dumbbell Flyes', 'Chest stretch', [MuscleGroup.chest], 3, 12, [Equipment.dumbbells]),
          _createExercise('Cable Crossover', 'Inner chest', [MuscleGroup.chest], 3, 12, [Equipment.cables]),
          _createExercise('Decline Bench Press', 'Lower chest', [MuscleGroup.chest], 3, 8, [Equipment.barbell, Equipment.bench]),
          _createExercise('Chest Dips', 'Lower chest', [MuscleGroup.chest], 3, 10, [Equipment.parallelBars]),
          _createExercise('Pec Deck', 'Chest isolation', [MuscleGroup.chest], 3, 12, [Equipment.machines]),
          _createExercise('Low Cable Fly', 'Upper chest', [MuscleGroup.chest], 3, 12, [Equipment.cables]),
        ],
        'Back': [
          _createExercise('Deadlift', 'Full back', [MuscleGroup.back], 4, 5, [Equipment.barbell]),
          _createExercise('Barbell Row', 'Thickness', [MuscleGroup.back], 4, 8, [Equipment.barbell]),
          _createExercise('Lat Pulldown', 'Width', [MuscleGroup.back], 3, 10, [Equipment.machines]),
          _createExercise('Cable Rows', 'Mid back', [MuscleGroup.back], 3, 10, [Equipment.cables]),
          _createExercise('T-Bar Row', 'Back thickness', [MuscleGroup.back], 3, 8, [Equipment.barbell]),
          _createExercise('Single-Arm Dumbbell Row', 'Lats unilateral', [MuscleGroup.back], 3, 10, [Equipment.dumbbells]),
          _createExercise('Seated Cable Row', 'Mid back isolation', [MuscleGroup.back], 3, 10, [Equipment.cables]),
          _createExercise('Chest-Supported Row', 'Back isolation', [MuscleGroup.back], 3, 10, [Equipment.machines]),
        ],
        'Shoulders': [
          _createExercise('Overhead Press', 'Front delts', [MuscleGroup.shoulders], 4, 8, [Equipment.barbell]),
          _createExercise('Lateral Raises', 'Side delts', [MuscleGroup.shoulders], 4, 12, [Equipment.dumbbells]),
          _createExercise('Face Pulls', 'Rear delts', [MuscleGroup.shoulders], 3, 15, [Equipment.cables]),
          _createExercise('Front Raises', 'Front delts', [MuscleGroup.shoulders], 3, 12, [Equipment.dumbbells]),
          _createExercise('Arnold Press', 'All deltoid heads', [MuscleGroup.shoulders], 3, 10, [Equipment.dumbbells]),
          _createExercise('Seated Dumbbell Press', 'Shoulders', [MuscleGroup.shoulders], 3, 10, [Equipment.dumbbells]),
          _createExercise('Rear Delt Fly', 'Posterior deltoid', [MuscleGroup.shoulders], 3, 15, [Equipment.dumbbells]),
          _createExercise('Upright Row', 'Traps and delts', [MuscleGroup.shoulders, MuscleGroup.traps], 3, 12, [Equipment.barbell]),
        ],
        'Arms': [
          _createExercise('Barbell Curl', 'Biceps', [MuscleGroup.biceps], 4, 10, [Equipment.barbell]),
          _createExercise('Tricep Pushdown', 'Triceps', [MuscleGroup.triceps], 4, 12, [Equipment.cables]),
          _createExercise('Hammer Curls', 'Brachialis', [MuscleGroup.biceps], 3, 12, [Equipment.dumbbells]),
          _createExercise('Skull Crushers', 'Triceps long head', [MuscleGroup.triceps], 3, 10, [Equipment.barbell, Equipment.bench]),
          _createExercise('Preacher Curl', 'Biceps peak', [MuscleGroup.biceps], 3, 10, [Equipment.machines]),
          _createExercise('Close-Grip Bench Press', 'Triceps compound', [MuscleGroup.triceps], 3, 8, [Equipment.barbell, Equipment.bench]),
          _createExercise('EZ Bar Curl', 'Biceps', [MuscleGroup.biceps], 3, 10, [Equipment.barbell]),
          _createExercise('Overhead Tricep Extension', 'Triceps long head', [MuscleGroup.triceps], 3, 12, [Equipment.dumbbells]),
          _createExercise('Cable Curl', 'Biceps constant tension', [MuscleGroup.biceps], 3, 12, [Equipment.cables]),
          _createExercise('Tricep Dips', 'Triceps bodyweight', [MuscleGroup.triceps], 3, 12, [Equipment.parallelBars]),
          _createExercise('Concentration Curl', 'Biceps isolation', [MuscleGroup.biceps], 3, 12, [Equipment.dumbbells]),
          _createExercise('Tricep Kickback', 'Triceps isolation', [MuscleGroup.triceps], 3, 12, [Equipment.dumbbells]),
        ],
      };


  Future<MonthlyDietPlanEntity> _generateDietPlanViaDirectAI(
    DietPreferencesEntity prefs,
    String odUserId, {
    UserBodyMetrics? userMetrics,
  }) async {
    if (config.apiKey == null || config.apiKey!.isEmpty) {
      throw Exception('Direct AI strategy requires an API key');
    }

    try {
      final strategy = DeepSeekGenerationStrategy(
        apiBaseUrl: config.apiBaseUrl ?? 'https://api.deepseek.com',
        apiKey: config.apiKey!,
        model: config.model,
        timeout: config.timeout,
        dio: dio,
      );

      final result = await strategy.getDietRecommendations(prefs,
          userMetrics: userMetrics);

      final recommendations = result['recommendations'] as Map<String, dynamic>;
      final usage = result['usage'] as Map<String, dynamic>?;

      if (usage != null) {
        debugPrint('AI Usage (Diet): ${usage['total_tokens']} tokens (${usage['prompt_tokens']} prompt, ${usage['completion_tokens']} completion)');
      }

      // Add required IDs and dates that the AI doesn't generate
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 27));

      final List<WeeklyPlanEntity> weeks = [];

      for (var weekJson in recommendations['weeklyPlans'] as List<dynamic>) {
        final wNum = weekJson['weekNumber'] as int;
        final List<DailyPlanEntity> days = [];

        for (var dayJson in weekJson['dailySuggestions'] as List<dynamic>) {
          final offset = ((wNum - 1) * 7) + (dayJson['dayOfWeek'] as int);
          final dayDate = startDate.add(Duration(days: offset));
          
          final List<PlannedMealEntity> meals = [];
          for (var mealJson in dayJson['meals'] as List<dynamic>) {
            final List<IngredientEntity> ingredients = [];
            for (var ingJson in mealJson['ingredients'] as List<dynamic>) {
              ingredients.add(IngredientEntity(
                name: ingJson['name'] as String,
                amount: ingJson['amount'] as String,
                unit: ingJson['unit'] as String,
                // W4: macros are now @Default(0) int — use null-safe cast with fallback
                calories: (ingJson['calories'] as num?)?.toInt() ?? 0,
                protein: (ingJson['protein'] as num?)?.toInt() ?? 0,
                carbs: (ingJson['carbs'] as num?)?.toInt() ?? 0,
                fats: (ingJson['fat'] as num?)?.toInt() ?? 0,
              ));
            }

            meals.add(PlannedMealEntity(
              id: 'meal_${dayDate.millisecondsSinceEpoch}_${mealJson["type"]}',
              type: MealType.values.firstWhere((e) => e.name == mealJson['type'], orElse: () => MealType.breakfast),
              name: mealJson['name'] as String,
              description: mealJson['description'] as String,
              ingredients: ingredients,
              instructions: mealJson['instructions'] as String,
              prepTimeMinutes: mealJson['prepTime'] as int? ?? 15,
              nutrition: const NutritionInfoEntity(calories: 0, protein: 0, carbs: 0, fats: 0),
            ));
          }

          days.add(DailyPlanEntity(
            id: 'day_${dayDate.millisecondsSinceEpoch}',
            date: dayDate,
            meals: meals,
            targetCalories: 0,
            targetProtein: 0,
            targetCarbs: 0,
            targetFats: 0,
          ));
        }

        weeks.add(WeeklyPlanEntity(
          weekNumber: wNum,
          startDate: startDate.add(Duration(days: (wNum - 1) * 7)),
          endDate: startDate.add(Duration(days: (wNum * 7) - 1)),
          days: days,
        ));
      }

      return MonthlyDietPlanEntity(
        id: 'plan_${now.millisecondsSinceEpoch}',
        odUserId: odUserId,
        startDate: startDate,
        endDate: endDate,
        goal: prefs.goal,
        macroTarget: DailyMacroTargetEntity(
          calories: 2000,
          protein: (2000 * (recommendations['macroRatios']['protein'] as num) / 4).round(),
          carbs: (2000 * (recommendations['macroRatios']['carbs'] as num) / 4).round(),
          fats: (2000 * (recommendations['macroRatios']['fat'] as num) / 9).round(),
        ),
        shoppingLists: buildShoppingLists(weeks),
        weeks: weeks,
        createdAt: now,
      );
    } catch (e) {
      debugPrint('AI Generation Error: $e');
      throw Exception('Failed to generate diet plan via Direct AI: $e');
    }
  }
} // End of AIOrchestrationService

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

/// Provider for AI configuration.
/// ALWAYS uses the backend API strategy — the backend owns AI provider selection
/// (DeepSeek/Anthropic/OpenAI) and persists plans to DB for sync/trainer visibility.
/// directAI bypasses BullMQ, generates nothing in DB, and breaks sync after reinstall.
final aiConfigProvider = Provider<AIConfig>((ref) {
  return const AIConfig(
    strategy: AIStrategy.api,
  );
});

/// Provider for AI orchestration service.
/// Wires job storage refs immediately after creation so W8 (job ID persistence
/// across app kills during polling) is functional from first use.
final aiOrchestrationProvider = Provider<AIOrchestrationService>((ref) {
  final config = ref.watch(aiConfigProvider);
  final dio = ref.watch(dioProvider);
  final service = AIOrchestrationService(config: config, dio: dio);
  // Issue 4: inject storage services so _pollJobStatus can persist/clear job IDs
  // without callers needing to manage this themselves.
  final dietStorage    = ref.read(dietPlanStorageProvider);
  final workoutStorage = ref.read(workoutPlanStorageProvider);
  service.setJobStorageRefs(diet: dietStorage, workout: workoutStorage);
  return service;
});
