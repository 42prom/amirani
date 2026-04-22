import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';

import '../../domain/entities/dashboard_entity.dart';
import '../../domain/usecases/dashboard_usecases.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../data/datasources/dashboard_remote_data_source.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../../../core/usecases/usecase.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardEntity metrics;
  DashboardLoaded(this.metrics);
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final GetDashboardMetricsUseCase _getDashboardMetricsUseCase;

  DashboardNotifier(this._getDashboardMetricsUseCase)
      : super(DashboardInitial());

  Future<void> fetchDashboardMetrics() async {
    state = DashboardLoading();
    final result = await _getDashboardMetricsUseCase(NoParams());

    result.fold(
      (failure) => state = DashboardError(failure.message),
      (metrics) => state = DashboardLoaded(metrics),
    );
  }
}

// Global Providers

final dashboardRemoteDataSourceProvider =
    Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
      remoteDataSource: ref.watch(dashboardRemoteDataSourceProvider));
});

final getDashboardMetricsUseCaseProvider =
    Provider<GetDashboardMetricsUseCase>((ref) {
  return GetDashboardMetricsUseCase(ref.watch(dashboardRepositoryProvider));
});

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref.watch(getDashboardMetricsUseCaseProvider));
});
