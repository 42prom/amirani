import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_provider.dart';

class TrainerRemoteDataSource {
  final Dio _dio;
  TrainerRemoteDataSource(this._dio);

  /// Fetch trainer profile
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final res = await _dio.get('/trainers/me');
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to load trainer profile'));
    }
  }

  /// Fetch dashboard quick stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final res = await _dio.get('/trainers/me/dashboard');
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to load dashboard stats'));
    }
  }

  /// Fetch list of assigned members
  Future<List<dynamic>> getAssignedMembers() async {
    try {
      final res = await _dio.get('/trainers/me/members');
      return res.data['data'] as List<dynamic>;
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to load assigned members'));
    }
  }

  /// Fetch specific member stats (attendance, BMI, etc.)
  Future<Map<String, dynamic>> getMemberStats(String memberId) async {
    try {
      final res = await _dio.get('/trainers/me/members/$memberId/stats');
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to load member stats'));
    }
  }

  String _msg(DioException e, String fallback) =>
      e.response?.data?['error'] as String? ?? fallback;
}

final trainerRemoteDataSourceProvider = Provider<TrainerRemoteDataSource>((ref) {
  return TrainerRemoteDataSource(ref.watch(dioProvider));
});
