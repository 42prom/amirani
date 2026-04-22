import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/datasources/door_access_remote_data_source.dart';
import '../../data/models/door_access_model.dart';
import '../../domain/entities/door_access_entity.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final doorAccessDataSourceProvider = Provider<DoorAccessRemoteDataSource>(
  (ref) => DoorAccessRemoteDataSource(ref.watch(dioProvider)),
);

// ─── Check-in state ───────────────────────────────────────────────────────────

sealed class DoorAccessState {}

class DoorAccessIdle extends DoorAccessState {}

class DoorAccessLoading extends DoorAccessState {}

class DoorAccessGranted extends DoorAccessState {
  final DoorAccessResult result;
  DoorAccessGranted(this.result);
}

class DoorAccessDenied extends DoorAccessState {
  final String message;
  DoorAccessDenied(this.message);
}

class DoorAccessNotifier extends StateNotifier<DoorAccessState> {
  final DoorAccessRemoteDataSource _ds;
  DoorAccessNotifier(this._ds) : super(DoorAccessIdle());

  Future<void> checkIn(String gymId) async {
    state = DoorAccessLoading();
    try {
      final result = await _ds.checkIn(gymId);
      state = result.success
          ? DoorAccessGranted(result)
          : DoorAccessDenied(result.message ?? 'Access denied');
    } catch (e) {
      state = DoorAccessDenied(e.toString());
    }
  }

  void reset() => state = DoorAccessIdle();
}

final doorAccessProvider =
    StateNotifierProvider.autoDispose<DoorAccessNotifier, DoorAccessState>(
  (ref) => DoorAccessNotifier(ref.watch(doorAccessDataSourceProvider)),
);

// ─── History state ────────────────────────────────────────────────────────────

class HistoryNotifier extends StateNotifier<AsyncValue<List<DoorAccessModel>>> {
  final DoorAccessRemoteDataSource _ds;
  HistoryNotifier(this._ds) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final list = await _ds.getHistory();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final doorAccessHistoryProvider = StateNotifierProvider.autoDispose<
    HistoryNotifier, AsyncValue<List<DoorAccessModel>>>(
  (ref) => HistoryNotifier(ref.watch(doorAccessDataSourceProvider)),
);
