import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';
import '../../features/workout/domain/entities/monthly_workout_plan_entity.dart';
import '../../features/workout/domain/entities/workout_preferences_entity.dart';
import '../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../features/diet/domain/entities/diet_preferences_entity.dart';
import '../models/user_body_metrics.dart';

import 'ai/ai_config.dart';
import 'ai/plan_generation_service.dart';
import 'ai/plan_polling_service.dart';
import 'ai/plan_storage_orchestrator.dart';

export 'ai/ai_config.dart';

/// AI Orchestration Service (Decomposed Facade)
///
/// Orchestrates the AI pipeline by delegating to specialized services:
/// - PlanGenerationService: Logic for creating plans (Offline/API/Direct)
/// - PlanPollingService: Logic for waiting for async backend jobs
/// - PlanStorageOrchestrator: Logic for persisting plans locally
class AIOrchestrationService {
  final AIConfig config;
  final PlanGenerationService _generation;
  final PlanPollingService _polling;
  final PlanStorageOrchestrator _storage;

  AIOrchestrationService({
    required Dio dio,
    this.config = AIConfig.defaultConfig,
    PlanPollingService? polling,
    PlanStorageOrchestrator? storage,
  })  : _generation = PlanGenerationService(dio: dio, config: config),
        _polling = polling ?? PlanPollingService(),
        _storage = storage ?? PlanStorageOrchestrator();

  Future<void> init() async {
    await _storage.init();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // WORKOUT PLAN GENERATION
  // ════════════════════════════════════════════════════════════════════════════

  Future<MonthlyWorkoutPlanEntity> generateWorkoutPlan({
    required WorkoutPreferencesEntity preferences,
    required String odUserId,
    UserBodyMetrics? userMetrics,
    List<String> targetMuscleNames = const [],
    String languageCode = 'en',
    void Function(double)? onProgress,
  }) async {
    final plan = await _generation.generateWorkoutPlan(
      preferences: preferences,
      odUserId: odUserId,
      userMetrics: userMetrics,
      targetMuscleNames: targetMuscleNames,
      languageCode: languageCode,
      pollCallback: (strategy, jobId, type) => _polling.pollJobStatus(
        strategy,
        jobId,
        type,
        onProgress: onProgress,
      ),
    );

    await _storage.saveWorkoutPlan(odUserId, plan);
    return plan;
  }

  MonthlyWorkoutPlanEntity? getStoredWorkoutPlan(String userId) {
    return _storage.getWorkoutPlan(userId);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIET PLAN GENERATION
  // ════════════════════════════════════════════════════════════════════════════

  Future<MonthlyDietPlanEntity> generateDietPlan({
    required DietPreferencesEntity preferences,
    required String odUserId,
    UserBodyMetrics? userMetrics,
    String languageCode = 'en',
    void Function(double)? onProgress,
  }) async {
    final plan = await _generation.generateDietPlan(
      preferences: preferences,
      odUserId: odUserId,
      userMetrics: userMetrics,
      languageCode: languageCode,
      pollCallback: (strategy, jobId, type) => _polling.pollJobStatus(
        strategy,
        jobId,
        type,
        onProgress: onProgress,
      ),
    );

    await _storage.saveDietPlan(odUserId, plan);
    return plan;
  }

  MonthlyDietPlanEntity? getStoredDietPlan(String userId) {
    return _storage.getDietPlan(userId);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> clearAllPlans(String userId) async {
    await _storage.clearWorkoutPlan(userId);
    await _storage.clearDietPlan(userId);
  }
}

/// Provider for the AI Orchestration Service
final aiOrchestrationProvider = Provider<AIOrchestrationService>((ref) {
  final dio = ref.watch(dioProvider);
  return AIOrchestrationService(dio: dio);
});
