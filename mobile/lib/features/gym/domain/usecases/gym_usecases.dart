import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/gym_entity.dart';
import '../entities/check_in_entity.dart';
import '../entities/qr_check_in_entity.dart';
import '../repositories/gym_repository.dart';

class GetGymDetailsParams {
  final String gymId;
  GetGymDetailsParams(this.gymId);
}

class GetGymDetailsUseCase implements UseCase<GymEntity, GetGymDetailsParams> {
  final GymRepository repository;

  GetGymDetailsUseCase(this.repository);

  @override
  Future<Either<Failure, GymEntity>> call(GetGymDetailsParams params) async {
    return await repository.getGymDetails(params.gymId);
  }
}

class CheckInNfcParams {
  final String gymId;
  CheckInNfcParams(this.gymId);
}

class CheckInNfcUseCase implements UseCase<CheckInEntity, CheckInNfcParams> {
  final GymRepository repository;

  CheckInNfcUseCase(this.repository);

  @override
  Future<Either<Failure, CheckInEntity>> call(CheckInNfcParams params) async {
    return await repository.checkInNfc(params.gymId);
  }
}

class QrCheckInParams {
  final String gymId;
  final String token;
  QrCheckInParams(this.gymId, this.token);
}

class QrCheckInUseCase implements UseCase<QrCheckInEntity, QrCheckInParams> {
  final GymRepository repository;

  QrCheckInUseCase(this.repository);

  @override
  Future<Either<Failure, QrCheckInEntity>> call(QrCheckInParams params) async {
    return await repository.checkInQr(params.gymId, params.token);
  }
}

class GetGymQrTokenParams {
  final String gymId;
  GetGymQrTokenParams(this.gymId);
}

class GetGymQrTokenUseCase implements UseCase<String, GetGymQrTokenParams> {
  final GymRepository repository;

  GetGymQrTokenUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(GetGymQrTokenParams params) async {
    return await repository.getGymQrToken(params.gymId);
  }
}

class EnrollPhoneKeyParams {
  final String gymId;
  final String userId;
  final String credentialHex;
  EnrollPhoneKeyParams(this.gymId, this.userId, this.credentialHex);
}

class EnrollPhoneKeyUseCase implements UseCase<String, EnrollPhoneKeyParams> {
  final GymRepository repository;
  EnrollPhoneKeyUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(EnrollPhoneKeyParams params) async {
    return await repository.enrollPhoneKey(params.gymId, params.userId, params.credentialHex);
  }
}

class RevokePhoneKeyParams {
  final String gymId;
  final String userId;
  final String credentialHex;
  RevokePhoneKeyParams(this.gymId, this.userId, this.credentialHex);
}

class RevokePhoneKeyUseCase implements UseCase<void, RevokePhoneKeyParams> {
  final GymRepository repository;
  RevokePhoneKeyUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(RevokePhoneKeyParams params) async {
    return await repository.revokePhoneKey(params.gymId, params.userId, params.credentialHex);
  }
}

