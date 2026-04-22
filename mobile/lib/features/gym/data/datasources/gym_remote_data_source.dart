import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../models/gym_model.dart';
import '../models/check_in_model.dart';
import '../models/qr_check_in_model.dart';

abstract class GymRemoteDataSource {
  Future<GymModel> getGymDetails(String gymId);
  Future<CheckInModel> checkInNfc(String gymId);
  Future<QrCheckInModel> checkInQr(String gymId, String token);
  Future<String> getGymQrToken(String gymId);
  /// Enroll this phone's NFC credential as a PHONE_HCE card for the member.
  Future<String> enrollPhoneKey({
    required String gymId,
    required String userId,
    required String credentialHex,
    String? label,
  });
  /// Revoke phone key: looks up card by credential then deletes it.
  Future<void> revokePhoneKey({
    required String gymId,
    required String userId,
    required String credentialHex,
  });
}

class GymRemoteDataSourceImpl implements GymRemoteDataSource {
  final Dio dio;

  GymRemoteDataSourceImpl({required this.dio});

  @override
  Future<GymModel> getGymDetails(String gymId) async {
    try {
      final response = await dio.get('/gym/details/$gymId');
      return GymModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(_extractMessage(e, 'Failed to load gym details'));
    }
  }

  @override
  Future<CheckInModel> checkInNfc(String gymId) async {
    try {
      final response = await dio.post(
        '/gym/check-in/nfc',
        data: {'gymId': gymId},
      );
      return CheckInModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(_extractMessage(e, 'NFC check-in failed'));
    }
  }

  @override
  Future<QrCheckInModel> checkInQr(String gymId, String token) async {
    try {
      final response = await dio.post(
        '/gym/check-in/qr',
        data: {'gymId': gymId, 'token': token},
      );
      return QrCheckInModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(_extractMessage(e, 'QR check-in failed'));
    }
  }

  @override
  Future<String> getGymQrToken(String gymId) async {
    try {
      final response = await dio.get('/gyms/$gymId/qr-token');
      return response.data['data']['token']?.toString() ?? '';
    } on DioException catch (e) {
      throw ServerException(_extractMessage(e, 'Failed to load QR token'));
    }
  }

  @override
  Future<String> enrollPhoneKey({
    required String gymId,
    required String userId,
    required String credentialHex,
    String? label,
  }) async {
    try {
      final response = await dio.post('/hardware/cards', data: {
        'gymId': gymId,
        'userId': userId,
        'cardUid': credentialHex,
        'cardType': 'PHONE_HCE',
        'label': label ?? 'Phone NFC Key',
      });
      return response.data['data']['id']?.toString() ?? '';
    } on DioException catch (e) {
      throw ServerException(_extractMessage(e, 'Failed to enroll phone key'));
    }
  }

  @override
  Future<void> revokePhoneKey({
    required String gymId,
    required String userId,
    required String credentialHex,
  }) async {
    try {
      // Find the card by listing cards for user, match by cardUid
      final listResp = await dio.get(
        '/hardware/cards',
        queryParameters: {'gymId': gymId, 'userId': userId},
      );
      final cards = listResp.data['data'] as List<dynamic>;
      final card = cards.firstWhere(
        (c) => (c['cardUid'] as String?)?.toUpperCase() == credentialHex.toUpperCase(),
        orElse: () => null,
      );
      if (card == null) return; // Already removed
      final cardId = card['id']?.toString() ?? '';
      await dio.delete('/hardware/cards/$cardId', queryParameters: {'gymId': gymId});
    } on DioException catch (e) {
      throw ServerException(_extractMessage(e, 'Failed to revoke phone key'));
    }
  }

  // Extracts the error message from the standardised { error: { message } } envelope.
  String _extractMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error']['message'] as String?) ?? fallback;
    }
    return fallback;
  }
}
