import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/user_body_metrics.dart';
import '../entities/daily_macro_entity.dart';
import '../entities/meal_entity.dart';
import '../entities/diet_plan_entity.dart';
import '../entities/diet_preferences_entity.dart';

abstract class DietRepository {
  Future<Either<Failure, DailyMacroEntity>> getDailyMacros(DateTime date);
  Future<Either<Failure, void>> logMeal(MealEntity meal);

  /// Enqueues an AI diet plan generation job with the full user preferences.
  /// Returns a jobId String to be polled via [getJobStatus].
  Future<Either<Failure, String>> generateAIDietPlan(
    DietPreferencesEntity prefs, {
    UserBodyMetrics? userMetrics,
  });

  /// Poll the status of an in-progress diet plan job.
  Future<Either<Failure, Map<String, dynamic>>> getJobStatus(String jobId);

  /// Fetches the currently active diet plan (Trainer or AI)
  Future<Either<Failure, DietPlanEntity?>> getActiveDietPlan();
}
