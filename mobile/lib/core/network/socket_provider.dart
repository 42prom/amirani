import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:amirani_app/core/network/dio_provider.dart';

final socketStorageProvider = Provider((ref) => const FlutterSecureStorage());

class SocketService {
  final String baseUrl;
  final String? token;

  // One socket per namespace — shared across all notifiers that need it.
  // Prevents duplicate TCP connections on every room/chat open.
  io.Socket? _roomSocket;
  io.Socket? _trainerChatSocket;

  SocketService({required this.baseUrl, this.token});

  io.Socket getRoomSocket() {
    _roomSocket ??= io.io(
      '$baseUrl/challenge-rooms',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );
    return _roomSocket!;
  }

  io.Socket getTrainerChatSocket() {
    _trainerChatSocket ??= io.io(
      '$baseUrl/trainer-chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );
    return _trainerChatSocket!;
  }

  void dispose() {
    _roomSocket?.dispose();
    _roomSocket = null;
    _trainerChatSocket?.dispose();
    _trainerChatSocket = null;
  }
}

final socketServiceProvider = FutureProvider<SocketService>((ref) async {
  final storage = ref.watch(socketStorageProvider);
  final token = await storage.read(key: 'jwt_token');

  final dio = ref.watch(dioProvider);
  final baseUrl = dio.options.baseUrl.replaceAll('/api', '');

  final service = SocketService(baseUrl: baseUrl, token: token);
  ref.onDispose(service.dispose);
  return service;
});
