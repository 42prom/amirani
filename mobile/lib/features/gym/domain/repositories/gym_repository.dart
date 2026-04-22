import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/gym_entity.dart';
import '../entities/check_in_entity.dart';
import '../entities/qr_check_in_entity.dart';

abstract class GymRepository {
  Future<Either<Failure, GymEntity>> getGymDetails(String gymId);
  Future<Either<Failure, CheckInEntity>> checkInNfc(String gymId);
  Future<Either<Failure, QrCheckInEntity>> checkInQr(String gymId, String token);
  Future<Either<Failure, String>> getGymQrToken(String gymId);
}
