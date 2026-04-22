import 'package:dio/dio.dart';
import '../models/door_access_model.dart';
import '../../domain/entities/door_access_entity.dart';

class DoorAccessRemoteDataSource {
  final Dio _dio;
  DoorAccessRemoteDataSource(this._dio);

  /// Called after member scans gym QR — triggers server check-in.
  Future<DoorAccessResult> checkIn(String gymId) async {
    final res = await _dio.post('/gym-entry/check-in', data: {'gymId': gymId});
    return DoorAccessResult.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// Fetch check-in history for the logged-in member.
  Future<List<DoorAccessModel>> getHistory() async {
    final res  = await _dio.get('/gym-entry/history');
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((e) => DoorAccessModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
