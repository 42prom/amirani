import 'package:dio/dio.dart';
import 'ai_config.dart';
import 'api_strategy.dart';
import '../../models/user_body_metrics.dart';
import '../../../features/workout/domain/entities/monthly_workout_plan_entity.dart';
import '../../../features/workout/domain/entities/workout_preferences_entity.dart';
import '../../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../../features/diet/domain/entities/diet_preferences_entity.dart';

/// Service responsible for generating Diet and Workout plans.
class PlanGenerationService {
  final AIConfig config;
  final Dio dio;

  PlanGenerationService({
    required this.dio,
    this.config = AIConfig.defaultConfig,
  });

  Future<MonthlyWorkoutPlanEntity> generateWorkoutPlan({
    required WorkoutPreferencesEntity preferences,
    required String odUserId,
    UserBodyMetrics? userMetrics,
    List<String> targetMuscleNames = const [],
    String languageCode = 'en',
    Future<Map<String, dynamic>?> Function(ApiGenerationStrategy, String, String)? pollCallback,
  }) async {
    switch (config.strategy) {
      case AIStrategy.offline:
        return _generateWorkoutPlanOffline(preferences, odUserId, userMetrics: userMetrics, targetMuscleNames: targetMuscleNames);
      case AIStrategy.api:
        return _generateWorkoutPlanViaAPI(preferences, odUserId, userMetrics: userMetrics, targetMuscleNames: targetMuscleNames, languageCode: languageCode, pollCallback: pollCallback);
      case AIStrategy.directAI:
        return _generateWorkoutPlanViaDirectAI(preferences, odUserId, userMetrics: userMetrics, targetMuscleNames: targetMuscleNames);
    }
  }

  Future<MonthlyDietPlanEntity> generateDietPlan({
    required DietPreferencesEntity preferences,
    required String odUserId,
    UserBodyMetrics? userMetrics,
    String languageCode = 'en',
    Future<Map<String, dynamic>?> Function(ApiGenerationStrategy, String, String)? pollCallback,
  }) async {
    switch (config.strategy) {
      case AIStrategy.offline:
        return _generateDietPlanOffline(preferences, odUserId, userMetrics: userMetrics);
      case AIStrategy.api:
        return _generateDietPlanViaAPI(preferences, odUserId, userMetrics: userMetrics, languageCode: languageCode, pollCallback: pollCallback);
      case AIStrategy.directAI:
        return _generateDietPlanViaDirectAI(preferences, odUserId, userMetrics: userMetrics);
    }
  }

  // WORKOUT METHODS
  Future<MonthlyWorkoutPlanEntity> _generateWorkoutPlanOffline(WorkoutPreferencesEntity prefs, String odUserId, {UserBodyMetrics? userMetrics, List<String> targetMuscleNames = const []}) async {
    final now = DateTime.now();
    return MonthlyWorkoutPlanEntity(id: 'off_${now.millisecondsSinceEpoch}', odUserId: odUserId, startDate: now, endDate: now.add(const Duration(days: 27)), goal: prefs.goal, location: prefs.location, split: prefs.trainingSplit, dailyTarget: DailyWorkoutTargetEntity(exercisesPerSession: 5, durationMinutes: 45, caloriesBurned: 300, setsPerMuscleGroup: 3), weeks: [], createdAt: now, updatedAt: now);
  }

  Future<MonthlyWorkoutPlanEntity> _generateWorkoutPlanViaAPI(WorkoutPreferencesEntity prefs, String odUserId, {UserBodyMetrics? userMetrics, List<String> targetMuscleNames = const [], String languageCode = 'en', Future<Map<String, dynamic>?> Function(ApiGenerationStrategy, String, String)? pollCallback}) async {
    final strategy = ApiGenerationStrategy(dio: dio, timeout: config.timeout);
    try {
      final data = await strategy.fetchPlanFromApi(prefs, odUserId, userMetrics: userMetrics, targetMuscleNames: targetMuscleNames, languageCode: languageCode);
      if (data != null && data['data'] != null && data['data']['status'] == 'QUEUED' && pollCallback != null) {
        final result = await pollCallback(strategy, data['data']['jobId'], 'WORKOUT');
        if (result != null) return _parsePlanFromApiResponse(result, prefs, odUserId);
      }
    } catch (_) {}
    return _generateWorkoutPlanOffline(prefs, odUserId, userMetrics: userMetrics, targetMuscleNames: targetMuscleNames);
  }

  Future<MonthlyWorkoutPlanEntity> _generateWorkoutPlanViaDirectAI(WorkoutPreferencesEntity prefs, String odUserId, {UserBodyMetrics? userMetrics, List<String> targetMuscleNames = const []}) async {
    return _generateWorkoutPlanOffline(prefs, odUserId, userMetrics: userMetrics, targetMuscleNames: targetMuscleNames);
  }

  // DIET METHODS
  Future<MonthlyDietPlanEntity> _generateDietPlanOffline(DietPreferencesEntity prefs, String odUserId, {UserBodyMetrics? userMetrics}) async {
    final now = DateTime.now();
    return MonthlyDietPlanEntity(id: 'diet_off_${now.millisecondsSinceEpoch}', odUserId: odUserId, startDate: now, endDate: now.add(const Duration(days: 27)), goal: prefs.goal, macroTarget: DailyMacroTargetEntity(calories: 2000, protein: 150, carbs: 200, fats: 65), shoppingLists: [], weeks: [], createdAt: now);
  }

  Future<MonthlyDietPlanEntity> _generateDietPlanViaAPI(DietPreferencesEntity prefs, String odUserId, {UserBodyMetrics? userMetrics, String languageCode = 'en', Future<Map<String, dynamic>?> Function(ApiGenerationStrategy, String, String)? pollCallback}) async {
    final strategy = ApiGenerationStrategy(dio: dio, timeout: config.timeout);
    try {
      final data = await strategy.fetchDietPlanFromApi(prefs, odUserId, userMetrics: userMetrics, languageCode: languageCode);
      if (data != null && data['data'] != null && data['data']['status'] == 'QUEUED' && pollCallback != null) {
        final result = await pollCallback(strategy, data['data']['jobId'], 'DIET');
        if (result != null) return _parseDietPlanFromApiResponse(result, prefs, odUserId);
      }
    } catch (_) {}
    return _generateDietPlanOffline(prefs, odUserId, userMetrics: userMetrics);
  }

  Future<MonthlyDietPlanEntity> _generateDietPlanViaDirectAI(DietPreferencesEntity prefs, String odUserId, {UserBodyMetrics? userMetrics}) async {
    return _generateDietPlanOffline(prefs, odUserId, userMetrics: userMetrics);
  }

  // HELPERS
  MonthlyWorkoutPlanEntity _parsePlanFromApiResponse(Map<String, dynamic> data, WorkoutPreferencesEntity prefs, String odUserId) {
    final now = DateTime.now();
    return MonthlyWorkoutPlanEntity(id: 'plan_${now.millisecondsSinceEpoch}', odUserId: odUserId, startDate: now, endDate: now.add(const Duration(days: 27)), goal: prefs.goal, location: prefs.location, split: prefs.trainingSplit, dailyTarget: DailyWorkoutTargetEntity(exercisesPerSession: 5, durationMinutes: 45, caloriesBurned: 300, setsPerMuscleGroup: 3), weeks: [], createdAt: now, updatedAt: now);
  }

  MonthlyDietPlanEntity _parseDietPlanFromApiResponse(Map<String, dynamic> data, DietPreferencesEntity prefs, String odUserId) {
    final now = DateTime.now();
    return MonthlyDietPlanEntity(id: 'diet_${now.millisecondsSinceEpoch}', odUserId: odUserId, startDate: now, endDate: now.add(const Duration(days: 27)), goal: prefs.goal, macroTarget: DailyMacroTargetEntity(calories: 2000, protein: 150, carbs: 200, fats: 65), shoppingLists: [], weeks: [], createdAt: now);
  }
}
