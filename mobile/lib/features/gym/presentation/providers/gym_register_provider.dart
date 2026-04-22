import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/utils/error_messages.dart';
import '../../domain/entities/registration_requirements_entity.dart';

// ─── States ───────────────────────────────────────────────────────────────────

abstract class GymRegisterState {}

class GymRegisterIdle extends GymRegisterState {}

class GymRegisterLoadingConfig extends GymRegisterState {}

class GymRegisterConfigLoaded extends GymRegisterState {
  final String gymId;
  final String registrationCode;
  final String gymName;
  final RegistrationRequirementsEntity requirements;
  GymRegisterConfigLoaded({
    required this.gymId,
    required this.registrationCode,
    required this.gymName,
    required this.requirements,
  });
}

class GymRegisterSubmitting extends GymRegisterState {}

class GymRegisterSuccess extends GymRegisterState {
  final String gymName;
  final bool isNewUser;
  GymRegisterSuccess({required this.gymName, required this.isNewUser});
}

class GymRegisterError extends GymRegisterState {
  final String message;
  GymRegisterError(this.message);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class GymRegisterNotifier extends StateNotifier<GymRegisterState> {
  final Dio _dio;

  GymRegisterNotifier(this._dio) : super(GymRegisterIdle());

  /// Called when the QR is scanned — fetches gym config/requirements
  Future<void> loadConfig(String gymId, String registrationCode) async {
    state = GymRegisterLoadingConfig();
    try {
      // Fetch gym details (public endpoint — gym info includes registrationRequirements)
      final response = await _dio.get(
        '/gym-management/public/registration-config/$gymId',
        options: Options(
          validateStatus: (_) => true,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final reqs = data['requirements'] as Map<String, dynamic>? ?? {};

        state = GymRegisterConfigLoaded(
          gymId: gymId,
          registrationCode: registrationCode,
          gymName: data['gymName'] as String? ?? 'Gym',
          requirements: RegistrationRequirementsEntity(
            dateOfBirth: reqs['dateOfBirth'] == true,
            personalNumber: reqs['personalNumber'] == true,
            phoneNumber: reqs['phoneNumber'] == true,
            address: reqs['address'] == true,
            selfiePhoto: reqs['selfiePhoto'] == true,
            idPhoto: reqs['idPhoto'] == true,
            healthInfo: reqs['healthInfo'] == true,
          ),
        );
      } else {
        // Fall back: gym ID is valid but we can't load requirements
        // Show minimal form (fullName, email, password only)
        state = GymRegisterConfigLoaded(
          gymId: gymId,
          registrationCode: registrationCode,
          gymName: 'Gym',
          requirements: const RegistrationRequirementsEntity(),
        );
      }
    } catch (e) {
      state = GymRegisterConfigLoaded(
        gymId: gymId,
        registrationCode: registrationCode,
        gymName: 'Gym',
        requirements: const RegistrationRequirementsEntity(),
      );
    }
  }

  Future<void> submitRegistration({
    required String gymId,
    required String registrationCode,
    required Map<String, dynamic> formData,
    File? selfieFile,
    File? idFile,
    String? existingSelfieUrl,
    String? existingIdUrl,
  }) async {
    state = GymRegisterSubmitting();
    try {
      // Upload photos if provided
      String? selfiePhotoUrl;
      String? idPhotoUrl;

      if (selfieFile != null) {
        selfiePhotoUrl = await _uploadFile(selfieFile, 'avatars');
      } else if (existingSelfieUrl != null) {
        // Strip base URL if present to send only the relative path
        selfiePhotoUrl = existingSelfieUrl;
        if (selfiePhotoUrl.contains('/uploads/')) {
          selfiePhotoUrl = '/uploads/${selfiePhotoUrl.split('/uploads/').last}';
        }
      }

      if (idFile != null) {
        idPhotoUrl = await _uploadFile(idFile, 'gyms');
      } else if (existingIdUrl != null) {
        // Strip base URL if present to send only the relative path
        idPhotoUrl = existingIdUrl;
        if (idPhotoUrl.contains('/uploads/')) {
          idPhotoUrl = '/uploads/${idPhotoUrl.split('/uploads/').last}';
        }
      }

      final payload = {
        'code': registrationCode,
        ...formData,
        if (selfiePhotoUrl != null) 'selfiePhotoUrl': selfiePhotoUrl,
        if (idPhotoUrl != null) 'idPhotoUrl': idPhotoUrl,
      };

      final response = await _dio.post(
        '/gym-management/$gymId/self-register',
        data: payload,
        options: Options(validateStatus: (_) => true),
      );

      if (response.statusCode == 201) {
        final data = response.data['data'];
        state = GymRegisterSuccess(
          gymName: data['gymName'] as String? ?? 'Gym',
          isNewUser: data['isNewUser'] == true,
        );
      } else {
        final error = response.data['error'] ?? 'Registration failed';
        state = GymRegisterError(error.toString());
      }
    } catch (e) {
      state = GymRegisterError(
        e is String ? e : ErrorMessages.from(e, fallback: 'An unexpected error occurred. Please try again.'),
      );
    }
  }

  Future<String?> _uploadFile(File file, String category) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });
      
      // Use 'Bearer public' if not authenticated to allow registration uploads
      final response = await _dio.post(
        '/upload/$category',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer public'}, // Allow via public-aware middleware
          validateStatus: (_) => true
        ),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        return data['url'] as String?;
      } else {
        final errorObj = response.data['error'];
        String errorMessage = 'Upload failed';
        
        if (errorObj is Map) {
          errorMessage = errorObj['message']?.toString() ?? errorMessage;
          final details = errorObj['details'];
          if (details is List && details.isNotEmpty) {
            errorMessage = details[0]['message']?.toString() ?? errorMessage;
          }
        }
        
        throw 'Failed to upload $category: $errorMessage';
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.connectionTimeout) {
        throw 'Upload timed out. Please check your connection.';
      }
      rethrow;
    }
  }

  void reset() => state = GymRegisterIdle();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final gymRegisterProvider =
    StateNotifierProvider<GymRegisterNotifier, GymRegisterState>((ref) {
  final dio = ref.watch(dioProvider);
  return GymRegisterNotifier(dio);
});
