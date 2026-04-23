import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class TrainerRepository {
  /// Fetch trainer profile data
  Future<Either<Failure, Map<String, dynamic>>> getMyProfile();

  /// Fetch aggregate dashboard stats
  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats();

  /// Fetch list of assigned gym members
  Future<Either<Failure, List<dynamic>>> getAssignedMembers();

  /// Fetch detailed progress stats for a specific member
  Future<Either<Failure, Map<String, dynamic>>> getMemberStats(String memberId);
}
