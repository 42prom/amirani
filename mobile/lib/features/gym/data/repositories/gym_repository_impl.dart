import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/gym_entity.dart';
import '../../domain/entities/check_in_entity.dart';
import '../../domain/entities/qr_check_in_entity.dart';
import '../../domain/repositories/gym_repository.dart';
import '../datasources/gym_remote_data_source.dart';
import '../models/gym_model.dart';
import '../models/check_in_model.dart';

class GymRepositoryImpl implements GymRepository {
  final GymRemoteDataSource remoteDataSource;

  GymRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, GymEntity>> getGymDetails(String gymId) async {
    try {
      final model = await remoteDataSource.getGymDetails(gymId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CheckInEntity>> checkInNfc(String gymId) async {
    try {
      final model = await remoteDataSource.checkInNfc(gymId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, QrCheckInEntity>> checkInQr(
      String gymId, String token) async {
    try {
      final model = await remoteDataSource.checkInQr(gymId, token);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getGymQrToken(String gymId) async {
    try {
      final token = await remoteDataSource.getGymQrToken(gymId);
      return Right(token);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
