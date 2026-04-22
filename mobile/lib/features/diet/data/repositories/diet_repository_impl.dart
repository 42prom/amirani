import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/user_body_metrics.dart';
import '../../domain/entities/daily_macro_entity.dart';
import '../../domain/entities/diet_preferences_entity.dart';
import '../../domain/entities/meal_entity.dart';
import '../../domain/entities/diet_plan_entity.dart';
import '../../domain/repositories/diet_repository.dart';
import '../datasources/diet_remote_data_source.dart';

class DietRepositoryImpl implements DietRepository {
  final DietRemoteDataSource remoteDataSource;

  DietRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, DailyMacroEntity>> getDailyMacros(
      DateTime date) async {
    try {
      final model = await remoteDataSource.getDailyMacros(date);
      return Right(model.toEntity(date));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logMeal(MealEntity meal) async {
    try {
      await remoteDataSource.logMeal(meal);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Enqueues an AI diet plan generation job with full user preferences.
  /// Returns the jobId string which should be polled via [getJobStatus].
  @override
  Future<Either<Failure, String>> generateAIDietPlan(
    DietPreferencesEntity prefs, {
    UserBodyMetrics? userMetrics,
  }) async {
    try {
      final jobId = await remoteDataSource.generateAIDietPlan(
        prefs: prefs,
        userMetrics: userMetrics,
      );
      return Right(jobId);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Poll job status for an in-progress diet plan generation.
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

  @override
  Future<Either<Failure, DietPlanEntity?>> getActiveDietPlan() async {
    try {
      final model = await remoteDataSource.getActiveDietPlan();
      return Right(model?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
