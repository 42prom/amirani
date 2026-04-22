import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../../../core/error/exceptions.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

import '../models/platform_config_model.dart';

abstract class AuthRemoteDataSource {
  /// Returns (AuthResponse, mustChangePassword).
  Future<(AuthResponse, bool)> login(String email, String password);
  Future<AuthResponse> loginWithOAuth(String provider, String idToken);
  Future<UserModel> getUserProfile();
  Future<PlatformConfigModel> getAuthConfig();
  Future<void> changePassword(String currentPassword, String newPassword);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final Logger _logger = Logger();

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<PlatformConfigModel> getAuthConfig() async {
    try {
      final response = await dio.get('/auth/config');
      if (response.statusCode == 200) {
        return PlatformConfigModel.fromJson(response.data['data']);
      } else {
        throw const ServerException('Failed to fetch platform config');
      }
    } catch (e) {
      _logger.e('Error fetching platform config: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthResponse> loginWithOAuth(String provider, String idToken) async {
    try {
      final response = await dio.post('/auth/oauth', data: {
        'provider': provider,
        'idToken': idToken,
      });
      if (response.statusCode == 200) {
        return AuthResponse.fromJson(response.data['data']);
      } else {
        throw const ServerException('OAuth sign-in failed');
      }
    } on DioException catch (e) {
      String message = 'OAuth sign-in failed';
      if (e.response?.data is Map) {
        final data = e.response?.data as Map;
        message = (data['error'] is String ? data['error'] : null) ?? message;
      }
      throw ServerException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<(AuthResponse, bool)> login(String email, String password) async {
    try {
      final response = await dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final mustChange =
            (data['user']?['mustChangePassword'] as bool?) ?? false;
        return (AuthResponse.fromJson(data), mustChange);
      } else {
        throw const ServerException('Invalid credentials');
      }
    } on DioException catch (e) {
      _logger.e('Login DioException: ${e.message}');
      _logger.e('Response status: ${e.response?.statusCode}');
      _logger.e('Response data: ${e.response?.data}');

      String message = 'Server error';
      if (e.response?.data is Map) {
        final data = e.response?.data as Map;
        if (data['error'] is Map) {
          message = data['error']['message'] ?? 'Server error';
        } else if (data['error'] is String) {
          message = data['error'];
        }
      }

      throw ServerException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      _logger.e('Login Generic Error: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<UserModel> getUserProfile() async {
    try {
      final response = await dio.get('/auth/me');
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['data']);
      } else {
        throw const ServerException('Session invalid');
      }
    } on DioException catch (e) {
      String message = 'Server error';
      if (e.response?.data is Map) {
        final data = e.response?.data as Map;
        if (data['error'] is Map) {
          message = data['error']['message'] ?? 'Server error';
        } else if (data['error'] is String) {
          message = data['error'];
        }
      }
      throw ServerException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      if (response.statusCode != 200) {
        throw const ServerException('Failed to change password');
      }
    } on DioException catch (e) {
      String message = 'Failed to change password';
      if (e.response?.data is Map) {
        final data = e.response?.data as Map;
        if (data['error'] is Map) {
          message = data['error']['message'] ?? message;
        } else if (data['error'] is String) {
          message = data['error'] as String;
        }
      }
      throw ServerException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
