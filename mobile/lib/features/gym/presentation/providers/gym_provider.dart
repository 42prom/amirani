import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';

import '../../domain/entities/gym_entity.dart';
import '../../domain/entities/check_in_entity.dart';
import '../../domain/usecases/gym_usecases.dart';
import '../../data/datasources/gym_remote_data_source.dart';
import '../../domain/repositories/gym_repository.dart';
import '../../data/repositories/gym_repository_impl.dart';

abstract class GymState {}

class GymInitial extends GymState {}

class GymLoading extends GymState {}

class GymLoaded extends GymState {
  final GymEntity gym;
  final CheckInEntity? lastCheckIn;
  GymLoaded(this.gym, {this.lastCheckIn});
}

class GymError extends GymState {
  final String message;
  GymError(this.message);
}

class GymNotifier extends StateNotifier<GymState> {
  final GetGymDetailsUseCase _getGymDetailsUseCase;
  final CheckInNfcUseCase _checkInNfcUseCase;

  GymNotifier(this._getGymDetailsUseCase, this._checkInNfcUseCase)
      : super(GymInitial());

  Future<void> fetchGymDetails(String gymId) async {
    state = GymLoading();
    final result = await _getGymDetailsUseCase(GetGymDetailsParams(gymId));

    result.fold(
      (failure) => state = GymError(failure.message),
      (gym) => state = GymLoaded(gym),
    );
  }

  Future<void> performNfcCheckIn(String gymId) async {
    if (state is! GymLoaded) return;

    final currentState = state as GymLoaded;
    state = GymLoading();

    final result = await _checkInNfcUseCase(CheckInNfcParams(gymId));

    result.fold(
      (failure) => state = GymError(failure.message),
      (checkIn) => state = GymLoaded(currentState.gym, lastCheckIn: checkIn),
    );
  }
}

// Global Providers

final gymRemoteDataSourceProvider = Provider<GymRemoteDataSource>((ref) {
  return GymRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return GymRepositoryImpl(
      remoteDataSource: ref.watch(gymRemoteDataSourceProvider));
});

final getGymDetailsUseCaseProvider = Provider<GetGymDetailsUseCase>((ref) {
  return GetGymDetailsUseCase(ref.watch(gymRepositoryProvider));
});

final checkInNfcUseCaseProvider = Provider<CheckInNfcUseCase>((ref) {
  return CheckInNfcUseCase(ref.watch(gymRepositoryProvider));
});

final gymNotifierProvider = StateNotifierProvider<GymNotifier, GymState>((ref) {
  return GymNotifier(
    ref.watch(getGymDetailsUseCaseProvider),
    ref.watch(checkInNfcUseCaseProvider),
  );
});
