import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../../../profile/data/datasources/profile_local_data_source.dart';
import '../models/user_model.dart';
import '../models/platform_config_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;
  final FlutterSecureStorage secureStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.secureStorage,
  });

  @override
  Future<Either<Failure, PlatformConfigModel>> getAuthConfig() async {
    try {
      final config = await remoteDataSource.getAuthConfig();
      return Right(config);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> login(
      String email, String password) async {
    try {
      final (authResponse, mustChange) =
          await remoteDataSource.login(email, password);

      await secureStorage.write(key: 'jwt_token', value: authResponse.token);
      await localDataSource.saveProfile(authResponse.user);
      await secureStorage.write(
        key: 'must_change_password',
        value: mustChange ? 'true' : 'false',
      );

      return Right(authResponse.user.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithOAuth(String provider, String idToken, {String? countryCode}) async {
    try {
      final authResponse = await remoteDataSource.loginWithOAuth(provider, idToken, countryCode: countryCode);
      await secureStorage.write(key: 'jwt_token', value: authResponse.token);
      await localDataSource.saveProfile(authResponse.user);
      return Right(authResponse.user.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await secureStorage.delete(key: 'jwt_token');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> checkAuthStatus() async {
    try {
      final token = await secureStorage.read(key: 'jwt_token');
      if (token == null) {
        return const Right(null);
      }

      try {
        final remoteModel = await remoteDataSource.getUserProfile();
        
        // Defensive Merge: Load local cache and only overwrite fields that are non-empty in remote
        final cached = await localDataSource.getProfile();
        if (cached != null) {
          String? clean(String? s) => (s != null && s.trim().isNotEmpty) ? s : null;
          
          // Unified Merge: Only use remote if it has data. Otherwise, keep cached.
          final mCond = clean(remoteModel.medicalConditions);
          final noMed = remoteModel.noMedicalConditions;
          bool hasHealthMsg = mCond != null || noMed == true;

          final mergedModel = cached.copyWith(
            firstName: clean(remoteModel.firstName) ?? cached.firstName,
            lastName: clean(remoteModel.lastName) ?? cached.lastName,
            fullName: clean(remoteModel.fullName) ?? cached.fullName,
            phoneNumber: clean(remoteModel.phoneNumber) ?? cached.phoneNumber,
            gender: clean(remoteModel.gender) ?? cached.gender,
            dob: clean(remoteModel.dob) ?? cached.dob,
            weight: clean(remoteModel.weight) ?? cached.weight,
            height: clean(remoteModel.height) ?? cached.height,
            medicalConditions: hasHealthMsg ? (noMed ? '' : mCond) : cached.medicalConditions,
            noMedicalConditions: hasHealthMsg ? noMed : cached.noMedicalConditions,
            personalNumber: clean(remoteModel.personalNumber) ?? cached.personalNumber,
            address: clean(remoteModel.address) ?? cached.address,
            avatarUrl: clean(remoteModel.avatarUrl) ?? cached.avatarUrl,
            idPhotoUrl: clean(remoteModel.idPhotoUrl) ?? cached.idPhotoUrl,
            targetWeightKg: remoteModel.targetWeightKg ?? cached.targetWeightKg,
          );
          
          await localDataSource.saveProfile(mergedModel);
          return Right(mergedModel.toEntity());
        } else {
          await localDataSource.saveProfile(remoteModel);
          return Right(remoteModel.toEntity());
        }
      } on ServerException catch (e) {
        // ONLY delete the token if it's a 401 (Unauthorized)
        if (e.statusCode == 401) {
          await secureStorage.delete(key: 'jwt_token');
          await localDataSource.clearProfile(); // Also clear cached profile
          return const Right(null);
        }
        
        // Otherwise, try to return cached profile if we have one
        final cached = await localDataSource.getProfile();
        if (cached != null) {
          return Right(cached.toEntity());
        }
        
        // If no cache, return the error
        return Left(ServerFailure(e.message));
      } catch (e) {
        // Generic error (network, etc) - try to return cached profile
        final cached = await localDataSource.getProfile();
        if (cached != null) {
          return Right(cached.toEntity());
        }
        return Left(ServerFailure(e.toString()));
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<bool> checkMustChangePassword() async {
    final val = await secureStorage.read(key: 'must_change_password');
    return val == 'true';
  }

  @override
  Future<Either<Failure, void>> changePassword(
      String currentPassword, String newPassword) async {
    try {
      await remoteDataSource.changePassword(currentPassword, newPassword);
      await secureStorage.write(key: 'must_change_password', value: 'false');
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
