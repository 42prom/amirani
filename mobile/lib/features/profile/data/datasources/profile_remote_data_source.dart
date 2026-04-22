import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<void> syncProfile(UserModel profile);
  Future<UserModel?> getLatestProfile();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio dio;

  ProfileRemoteDataSourceImpl({required this.dio});

  @override
  Future<void> syncProfile(UserModel profile) async {
    try {
      // Strip null values — the backend Zod schema uses .optional() which
      // accepts undefined but rejects null, so we must omit null fields.
      final profileJson = Map<String, dynamic>.from(profile.toJson())
        ..removeWhere((_, v) => v == null);
      await dio.post('/sync/up', data: {
        'lastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
        'changes': {
          'profile': profileJson,
        }
      });
    } on DioException catch (e) {
      throw ServerException(e.response?.data['error'] ?? 'Sync failed');
    }
  }

  @override
  Future<UserModel?> getLatestProfile() async {
    try {
      // DateTime(0) is year 0000 in Dart — use Unix epoch instead so
      // Node.js new Date() receives a well-known, always-valid string.
      final response = await dio.get('/sync/down', queryParameters: {
        'since': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
            .toIso8601String(),
      });

      final changes = response.data['changes'];
      if (changes != null && changes['user'] != null) {
        final userJson = Map<String, dynamic>.from(changes['user'] as Map);
        // DB stores targetWeightKg as String; coerce to double for our model.
        if (userJson['targetWeightKg'] is String) {
          userJson['targetWeightKg'] =
              double.tryParse(userJson['targetWeightKg'] as String);
        }
        return UserModel.fromJson(userJson);
      }
      return null;
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data['error'] ?? 'Failed to fetch profile');
    }
  }
}
