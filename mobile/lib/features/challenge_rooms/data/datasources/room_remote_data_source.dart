import 'package:dio/dio.dart';
import '../models/room_model.dart';

class RoomRemoteDataSource {
  final Dio dio;
  const RoomRemoteDataSource({required this.dio});

  Future<MyRoomsData> getMyRooms() async {
    final res = await dio.get('/rooms/mine');
    return MyRoomsData.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<RoomDetail> getRoom(String roomId) async {
    final res = await dio.get('/rooms/$roomId');
    return RoomDetail.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<RoomModel> createRoom({
    required String name,
    String? description,
    required String metric,
    required String period,
    String? endDate,
    bool isPublic = true,
    int maxMembers = 30,
  }) async {
    final res = await dio.post('/rooms', data: {
      'name': name,
      if (description != null) 'description': description,
      'metric': metric,
      'period': period,
      if (endDate != null) 'endDate': endDate,
      'isPublic': isPublic,
      'maxMembers': maxMembers,
    });
    return RoomModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> joinRoom(String roomId) async {
    await dio.post('/rooms/$roomId/join');
  }

  Future<String> joinByCode(String code) async {
    final res = await dio.post('/rooms/join-by-code', data: {'code': code});
    return res.data['data']['roomId']?.toString() ?? '';
  }

  Future<void> leaveRoom(String roomId) async {
    await dio.delete('/rooms/$roomId/leave');
  }

  Future<void> deleteRoom(String roomId) async {
    await dio.delete('/rooms/$roomId');
  }

  Future<void> kickMember(String roomId, String userId) async {
    await dio.delete('/rooms/$roomId/members/$userId');
  }

  Future<void> updateDisplayName(String fullName) async {
    await dio.patch('/users/me', data: {'fullName': fullName});
  }
}
