import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dashboard_entity.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardMetricsUseCase implements UseCase<DashboardEntity, NoParams> {
  final DashboardRepository repository;

  GetDashboardMetricsUseCase(this.repository);

  @override
  Future<Either<Failure, DashboardEntity>> call(NoParams params) async {
    return await repository.getDashboardMetrics();
  }
}
