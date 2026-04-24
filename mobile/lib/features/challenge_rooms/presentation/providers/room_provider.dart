import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/datasources/room_remote_data_source.dart';
import '../../data/models/room_model.dart';

export '../../data/models/room_model.dart' show RoomChallenge, ChallengeProgress;

// ─── Data source provider ─────────────────────────────────────────────────────

final roomDataSourceProvider = Provider<RoomRemoteDataSource>((ref) {
  return RoomRemoteDataSource(dio: ref.watch(dioProvider));
});

// ─── My rooms state ───────────────────────────────────────────────────────────

class MyRoomsNotifier extends StateNotifier<AsyncValue<MyRoomsData>> {
  final RoomRemoteDataSource _ds;
  MyRoomsNotifier(this._ds) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ds.getMyRooms();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> joinRoom(String roomId) async {
    await _ds.joinRoom(roomId);
    await load();
  }

  Future<String> joinByCode(String code) async {
    final roomId = await _ds.joinByCode(code);
    await load();
    return roomId;
  }

  Future<void> leaveRoom(String roomId) async {
    await _ds.leaveRoom(roomId);
    await load();
  }

  Future<void> createRoom({
    required String name,
    String? description,
    required String metric,
    required String period,
    String? endDate,
    bool isPublic = true,
    int maxMembers = 30,
  }) async {
    await _ds.createRoom(
      name: name,
      description: description,
      metric: metric,
      period: period,
      endDate: endDate,
      isPublic: isPublic,
      maxMembers: maxMembers,
    );
    await load();
  }
}

final myRoomsProvider = StateNotifierProvider<MyRoomsNotifier, AsyncValue<MyRoomsData>>((ref) {
  return MyRoomsNotifier(ref.watch(roomDataSourceProvider));
});

// ─── Room detail state ────────────────────────────────────────────────────────

class RoomDetailNotifier extends StateNotifier<AsyncValue<RoomDetail>> {
  final RoomRemoteDataSource _ds;
  final String _roomId;
  RoomDetailNotifier(this._ds, this._roomId) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ds.getRoom(_roomId);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load();

  Future<void> kickMember(String userId) async {
    await _ds.kickMember(_roomId, userId);
    await load();
  }

  Future<void> deleteRoom() async {
    await _ds.deleteRoom(_roomId);
  }

  Future<void> updateDisplayName(String fullName) async {
    await _ds.updateDisplayName(fullName);
  }
}

final roomDetailProvider = StateNotifierProvider.family<RoomDetailNotifier, AsyncValue<RoomDetail>, String>(
  (ref, roomId) => RoomDetailNotifier(ref.watch(roomDataSourceProvider), roomId),
);

// ─── Room challenges state ────────────────────────────────────────────────────

class RoomChallengesNotifier extends StateNotifier<AsyncValue<List<RoomChallenge>>> {
  final RoomRemoteDataSource _ds;
  final String _roomId;
  RoomChallengesNotifier(this._ds, this._roomId) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ds.getChallenges(_roomId);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logProgress(String challengeId, {int increment = 1}) async {
    await _ds.logChallengeProgress(_roomId, challengeId, increment: increment);
    await load();
  }
}

final roomChallengesProvider = StateNotifierProvider.family.autoDispose<RoomChallengesNotifier, AsyncValue<List<RoomChallenge>>, String>(
  (ref, roomId) => RoomChallengesNotifier(ref.watch(roomDataSourceProvider), roomId),
);
