import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_provider.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class TicketMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String body;
  final bool isStaff;
  final DateTime createdAt;

  TicketMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.body,
    required this.isStaff,
    required this.createdAt,
  });

  factory TicketMessageModel.fromJson(Map<String, dynamic> j) =>
      TicketMessageModel(
        id: j['id']?.toString() ?? '',
        senderId: j['senderId']?.toString() ?? '',
        senderName: (j['sender']?['fullName'] ?? j['sender']?['name'] ?? 'Unknown').toString(),
        senderAvatarUrl: j['sender']?['avatarUrl'] as String?,
        body: j['body']?.toString() ?? '',
        isStaff: j['isStaff'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class SupportTicketModel {
  final String id;
  final String gymId;
  final String subject;
  final String status;   // OPEN | IN_PROGRESS | RESOLVED | CLOSED
  final String priority; // LOW | MEDIUM | HIGH | URGENT
  final String ticketType; // Added to fix UI error
  final String? trainerId; // Added to fix UI error
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketMessageModel> messages;

  SupportTicketModel({
    required this.id,
    required this.gymId,
    required this.subject,
    required this.status,
    required this.priority,
    this.ticketType = 'GENERAL',
    this.trainerId,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> j) =>
      SupportTicketModel(
        id: j['id']?.toString() ?? '',
        gymId: j['gymId']?.toString() ?? '',
        subject: j['subject']?.toString() ?? '',
        status: j['status']?.toString() ?? 'OPEN',
        priority: j['priority']?.toString() ?? 'LOW',
        ticketType: j['ticketType']?.toString() ?? 'GENERAL',
        trainerId: j['trainerId'] as String?,
        messageCount: (j['_count']?['messages'] as num?)?.toInt() ?? (j['messages'] as List?)?.length ?? 0,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? '') ?? DateTime.now(),
        messages: (j['messages'] as List<dynamic>?)
                ?.map((m) => TicketMessageModel.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
      );

  SupportTicketModel copyWithMessages(List<TicketMessageModel> msgs) =>
      SupportTicketModel(
        id: id,
        gymId: gymId,
        subject: subject,
        status: status,
        priority: priority,
        ticketType: ticketType,
        trainerId: trainerId,
        messageCount: msgs.length,
        createdAt: createdAt,
        updatedAt: updatedAt,
        messages: msgs,
      );
}

// ─── Data Source ──────────────────────────────────────────────────────────────

class SupportRemoteDataSource {
  final Dio _dio;
  SupportRemoteDataSource(this._dio);

  Future<List<SupportTicketModel>> getMyTickets(String gymId) async {
    try {
      final res = await _dio.get('/support/gyms/$gymId/my-tickets');
      return (res.data['data'] as List)
          .map((t) => SupportTicketModel.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to load tickets'));
    }
  }

  Future<SupportTicketModel> getTicket(String gymId, String ticketId) async {
    try {
      final res = await _dio.get('/support/gyms/$gymId/tickets/$ticketId');
      return SupportTicketModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to load ticket'));
    }
  }

  Future<SupportTicketModel> createTicket({
    required String gymId,
    required String subject,
    required String body,
    required String priority,
  }) async {
    try {
      final res = await _dio.post(
        '/support/gyms/$gymId/tickets',
        data: {'subject': subject, 'body': body, 'priority': priority},
      );
      return SupportTicketModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to create ticket'));
    }
  }

  Future<TicketMessageModel> reply({
    required String gymId,
    required String ticketId,
    required String body,
  }) async {
    try {
      final res = await _dio.post(
        '/support/gyms/$gymId/tickets/$ticketId/reply',
        data: {'body': body},
      );
      return TicketMessageModel.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(_msg(e, 'Failed to send reply'));
    }
  }

  String _msg(DioException e, String fallback) {
    return e.response?.data?['error'] as String? ?? fallback;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final supportDataSourceProvider = Provider<SupportRemoteDataSource>((ref) {
  return SupportRemoteDataSource(ref.watch(dioProvider));
});
