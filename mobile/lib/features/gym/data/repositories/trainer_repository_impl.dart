import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/repositories/trainer_repository.dart';
import '../datasources/trainer_remote_data_source.dart';

class TrainerRepositoryImpl implements TrainerRepository {
  final TrainerRemoteDataSource _remoteDataSource;

  TrainerRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMyProfile() async {
    try {
      final res = await _remoteDataSource.getMyProfile();
      return Right(res);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats() async {
    try {
      final res = await _remoteDataSource.getDashboardStats();
      return Right(res);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<dynamic>>> getAssignedMembers() async {
    try {
      final res = await _remoteDataSource.getAssignedMembers();
      return Right(res);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMemberStats(String memberId) async {
    try {
      final res = await _remoteDataSource.getMemberStats(memberId);
      return Right(res);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}

final trainerRepositoryProvider = Provider<TrainerRepository>((ref) {
  return TrainerRepositoryImpl(ref.watch(trainerRemoteDataSourceProvider));
});
