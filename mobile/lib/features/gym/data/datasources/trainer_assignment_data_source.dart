import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../gym/data/datasources/support_remote_data_source.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class AssignedTrainerModel {
  final String id;
  final String fullName;
  final String? specialization;
  final String? avatarUrl;
  final String? bio;
  final bool isAvailable;

  AssignedTrainerModel({
    required this.id,
    required this.fullName,
    this.specialization,
    this.avatarUrl,
    this.bio,
    this.isAvailable = true,
  });

  factory AssignedTrainerModel.fromJson(Map<String, dynamic> j) =>
      AssignedTrainerModel(
        id:             j['id']?.toString() ?? '',
        fullName:       j['fullName']?.toString() ?? '',
        specialization: j['specialization'] as String?,
        avatarUrl:      j['avatarUrl'] as String?,
        bio:            j['bio'] as String?,
        isAvailable:    j['isAvailable'] as bool? ?? true,
      );
}

class PendingRequestModel {
  final String id;
  final String trainerId;
  final String trainerName;
  final String status;
  final DateTime createdAt;

  PendingRequestModel({
    required this.id,
    required this.trainerId,
    required this.trainerName,
    required this.status,
    required this.createdAt,
  });

  factory PendingRequestModel.fromJson(Map<String, dynamic> j) {
    final trainer = j['trainer'] as Map<String, dynamic>?;
    return PendingRequestModel(
      id:          j['id']?.toString() ?? '',
      trainerId:   j['trainerId']?.toString() ?? '',
      trainerName: trainer?['fullName']?.toString() ?? '',
      status:      j['status']?.toString() ?? '',
      createdAt:   DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Data Source ──────────────────────────────────────────────────────────────

class TrainerAssignmentDataSource {
  final Dio _dio;
  TrainerAssignmentDataSource(this._dio);

  /// Fetch current assignment status for a gym (assigned trainer + pending request)
  Future<Map<String, dynamic>> getMyStatus(String gymId) async {
    try {
      final res = await _dio.get('/assignment/gyms/$gymId/my-status');
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to load assignment status'));
    }
  }

  /// Member requests a specific trainer
  Future<void> requestTrainer(String gymId, String trainerId, {String? message}) async {
    try {
      await _dio.post('/assignment/gyms/$gymId/request', data: {
        'trainerId': trainerId,
        if (message != null) 'message': message,
      });
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to send request'));
    }
  }

  /// Member removes their trainer assignment
  Future<void> removeAssignment(String gymId) async {
    try {
      await _dio.delete('/assignment/gyms/$gymId/remove');
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to remove assignment'));
    }
  }

  /// Open or get existing trainer conversation ticket
  Future<SupportTicketModel> openTrainerConversation(String gymId, String trainerId) async {
    try {
      final res = await _dio.post(
        '/support/gyms/$gymId/trainer-conversation',
        data: {'trainerId': trainerId},
      );
      return SupportTicketModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to open chat'));
    }
  }

  String _msg(DioException e, String fallback) =>
      e.response?.data?['error'] as String? ?? fallback;
}

// ─── Provider ──────────────────────────────────────────────────────────────────

final trainerAssignmentDataSourceProvider = Provider<TrainerAssignmentDataSource>((ref) {
  return TrainerAssignmentDataSource(ref.watch(dioProvider));
});
