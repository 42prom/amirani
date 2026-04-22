import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../datasources/profile_remote_data_source.dart';
import '../datasources/profile_local_data_source.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, void>> syncProfile(UserEntity profile) async {
    try {
      final model = UserModel(
        id: profile.id,
        email: profile.email,
        role: profile.role,
        managedGymId: profile.managedGymId,
        firstName: profile.firstName,
        lastName: profile.lastName,
        gender: profile.gender,
        dob: profile.dob,
        weight: profile.weight,
        height: profile.height,
        medicalConditions: profile.medicalConditions,
        noMedicalConditions: profile.noMedicalConditions,
        personalNumber: profile.personalNumber,
        address: profile.address,
        phoneNumber: profile.phoneNumber,
        fullName: profile.fullName,
        avatarUrl: profile.avatarUrl,
        idPhotoUrl: profile.idPhotoUrl,
        targetWeightKg: profile.targetWeightKg,
      );

      await localDataSource.saveProfile(model);

      try {
        await remoteDataSource.syncProfile(model);
      } catch (e) {
        // We still return success (Right(null)) because it's saved locally
        // Background sync or next attempt will heal the server state
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getLatestProfile() async {
    try {
      final remoteModel = await remoteDataSource.getLatestProfile();
      if (remoteModel != null) {
        
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
      }
      return const Right(null);
    } catch (e) {
      final cached = await localDataSource.getProfile();
      if (cached != null) {
        return Right(cached.toEntity());
      }
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCachedProfile() async {
    try {
      final model = await localDataSource.getProfile();
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
