import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/workout_remote_data_source.dart';
import '../models/workout_plan_model.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutRemoteDataSource remoteDataSource;

  WorkoutRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, WorkoutPlanEntity?>> getActiveWorkoutPlan() async {
    try {
      final model = await remoteDataSource.getActiveWorkoutPlan();
      return Right(model?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Enqueues an AI workout plan generation job.
  /// Returns the jobId string which should be polled via [getJobStatus].
  @override
  Future<Either<Failure, String>> generateAIPlan(
    String goals,
    String level, {
    int daysPerWeek = 4,
    List<String>? targetMuscles,
  }) async {
    try {
      final jobId = await remoteDataSource.generateAIPlan(
        goals: goals,
        level: level,
        daysPerWeek: daysPerWeek,
        targetMuscles: targetMuscles,
      );
      return Right(jobId);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Poll job status for an in-progress workout plan generation.
  @override
  Future<Either<Failure, Map<String, dynamic>>> getJobStatus(String jobId) async {
    try {
      final status = await remoteDataSource.getJobStatus(jobId);
      return Right(status);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
