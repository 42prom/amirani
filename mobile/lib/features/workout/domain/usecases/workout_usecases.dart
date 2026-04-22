import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/workout_plan_entity.dart';
import '../repositories/workout_repository.dart';

class GetActiveWorkoutUseCase implements UseCase<WorkoutPlanEntity?, NoParams> {
  final WorkoutRepository repository;

  GetActiveWorkoutUseCase(this.repository);

  @override
  Future<Either<Failure, WorkoutPlanEntity?>> call(NoParams params) async {
    return await repository.getActiveWorkoutPlan();
  }
}

class GenerateAIWorkoutParams {
  final String goals;
  final String level;
  final int daysPerWeek;
  final List<String>? targetMuscles;

  GenerateAIWorkoutParams({
    required this.goals,
    required this.level,
    this.daysPerWeek = 4,
    this.targetMuscles,
  });
}

/// Enqueues an AI workout plan generation job.
/// Returns a jobId String to be polled via [GetWorkoutJobStatusUseCase].
class GenerateAIWorkoutUseCase
    implements UseCase<String, GenerateAIWorkoutParams> {
  final WorkoutRepository repository;

  GenerateAIWorkoutUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(GenerateAIWorkoutParams params) async {
    return await repository.generateAIPlan(
      params.goals,
      params.level,
      daysPerWeek: params.daysPerWeek,
      targetMuscles: params.targetMuscles,
    );
  }
}

class GetWorkoutJobStatusParams {
  final String jobId;
  GetWorkoutJobStatusParams(this.jobId);
}

class GetWorkoutJobStatusUseCase
    implements UseCase<Map<String, dynamic>, GetWorkoutJobStatusParams> {
  final WorkoutRepository repository;

  GetWorkoutJobStatusUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
      GetWorkoutJobStatusParams params) async {
    return await repository.getJobStatus(params.jobId);
  }
}
