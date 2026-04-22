import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/workout_plan_entity.dart';

abstract class WorkoutRepository {
  Future<Either<Failure, WorkoutPlanEntity?>> getActiveWorkoutPlan();

  /// Enqueues an AI workout plan generation job.
  /// Returns a jobId String to be polled via [getJobStatus].
  Future<Either<Failure, String>> generateAIPlan(
    String goals,
    String level, {
    int daysPerWeek = 4,
    List<String>? targetMuscles,
  });

  /// Poll the status of an in-progress workout plan job.
  Future<Either<Failure, Map<String, dynamic>>> getJobStatus(String jobId);
}
