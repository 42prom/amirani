import 'package:hive_flutter/hive_flutter.dart';
import '../../../features/workout/domain/entities/monthly_workout_plan_entity.dart';
import '../../../features/diet/domain/entities/monthly_plan_entity.dart';

/// Service responsible for persisting and retrieving AI plans and job states.
class PlanStorageOrchestrator {
  static const String workoutBoxName = 'ai_workout_plans';
  static const String dietBoxName = 'ai_diet_plans';
  static const String jobStorageBoxName = 'ai_job_storage';

  late Box<MonthlyWorkoutPlanEntity> _workoutBox;
  late Box<MonthlyDietPlanEntity> _dietBox;
  late Box<String> _jobBox;

  Future<void> init() async {
    _workoutBox = await Hive.openBox<MonthlyWorkoutPlanEntity>(workoutBoxName);
    _dietBox = await Hive.openBox<MonthlyDietPlanEntity>(dietBoxName);
    _jobBox = await Hive.openBox<String>(jobStorageBoxName);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // WORKOUT STORAGE
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> saveWorkoutPlan(String userId, MonthlyWorkoutPlanEntity plan) async {
    await _workoutBox.put(userId, plan);
  }

  MonthlyWorkoutPlanEntity? getWorkoutPlan(String userId) {
    return _workoutBox.get(userId);
  }

  Future<void> clearWorkoutPlan(String userId) async {
    await _workoutBox.delete(userId);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIET STORAGE
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> saveDietPlan(String userId, MonthlyDietPlanEntity plan) async {
    await _dietBox.put(userId, plan);
  }

  MonthlyDietPlanEntity? getDietPlan(String userId) {
    return _dietBox.get(userId);
  }

  Future<void> clearDietPlan(String userId) async {
    await _dietBox.delete(userId);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // JOB STORAGE
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> saveJobId(String type, String userId, String jobId) async {
    await _jobBox.put('${type}_$userId', jobId);
  }

  String? getJobId(String type, String userId) {
    return _jobBox.get('${type}_$userId');
  }

  Future<void> clearJobId(String type, String userId) async {
    await _jobBox.delete('${type}_$userId');
  }
}
