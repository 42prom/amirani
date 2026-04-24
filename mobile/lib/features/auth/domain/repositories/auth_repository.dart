import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../../data/models/platform_config_model.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login(String email, String password);
  Future<Either<Failure, UserEntity>> loginWithOAuth(String provider, String idToken, {String? countryCode});
  Future<Either<Failure, UserEntity?>> checkAuthStatus();
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, PlatformConfigModel>> getAuthConfig();
  Future<bool> checkMustChangePassword();
  Future<Either<Failure, void>> changePassword(String currentPassword, String newPassword);
}
