import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, void>> syncProfile(UserEntity profile);
  Future<Either<Failure, UserEntity?>> getLatestProfile();
  Future<Either<Failure, UserEntity?>> getCachedProfile();
}
