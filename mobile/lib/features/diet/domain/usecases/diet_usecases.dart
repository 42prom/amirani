import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/user_body_metrics.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/daily_macro_entity.dart';
import '../entities/diet_preferences_entity.dart';
import '../entities/meal_entity.dart';
import '../entities/diet_plan_entity.dart';
import '../repositories/diet_repository.dart';

class GetDailyMacrosParams {
  final DateTime date;
  GetDailyMacrosParams(this.date);
}

class GetDailyMacrosUseCase
    implements UseCase<DailyMacroEntity, GetDailyMacrosParams> {
  final DietRepository repository;

  GetDailyMacrosUseCase(this.repository);

  @override
  Future<Either<Failure, DailyMacroEntity>> call(
      GetDailyMacrosParams params) async {
    return await repository.getDailyMacros(params.date);
  }
}

class LogMealParams {
  final MealEntity meal;
  LogMealParams(this.meal);
}

class LogMealUseCase implements UseCase<void, LogMealParams> {
  final DietRepository repository;

  LogMealUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(LogMealParams params) async {
    return await repository.logMeal(params.meal);
  }
}

class GenerateAIDietPlanParams {
  final DietPreferencesEntity prefs;
  final UserBodyMetrics? userMetrics;
  GenerateAIDietPlanParams(this.prefs, {this.userMetrics});
}

/// Enqueues an AI diet plan generation job with the full user preferences.
/// Returns a jobId String to be polled via [GetDietJobStatusUseCase].
class GenerateAIDietPlanUseCase
    implements UseCase<String, GenerateAIDietPlanParams> {
  final DietRepository repository;

  GenerateAIDietPlanUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(
      GenerateAIDietPlanParams params) async {
    return await repository.generateAIDietPlan(
      params.prefs,
      userMetrics: params.userMetrics,
    );
  }
}

class GetDietJobStatusParams {
  final String jobId;
  GetDietJobStatusParams(this.jobId);
}

class GetDietJobStatusUseCase
    implements UseCase<Map<String, dynamic>, GetDietJobStatusParams> {
  final DietRepository repository;

  GetDietJobStatusUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
      GetDietJobStatusParams params) async {
    return await repository.getJobStatus(params.jobId);
  }
}

class GetActiveDietPlanUseCase implements UseCase<DietPlanEntity?, NoParams> {
  final DietRepository repository;

  GetActiveDietPlanUseCase(this.repository);

  @override
  Future<Either<Failure, DietPlanEntity?>> call(NoParams params) async {
    return await repository.getActiveDietPlan();
  }
}
