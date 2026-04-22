import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/datasources/gamification_remote_data_source.dart';
import '../../domain/entities/gamification_profile.dart';

final gamificationDataSourceProvider = Provider<GamificationRemoteDataSource>(
  (ref) => GamificationRemoteDataSource(ref.watch(dioProvider)),
);

class GamificationNotifier extends StateNotifier<AsyncValue<GamificationProfile>> {
  final GamificationRemoteDataSource _ds;
  GamificationNotifier(this._ds) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final profile = await _ds.getProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final gamificationProvider =
    StateNotifierProvider<GamificationNotifier, AsyncValue<GamificationProfile>>(
  (ref) => GamificationNotifier(ref.watch(gamificationDataSourceProvider)),
);
