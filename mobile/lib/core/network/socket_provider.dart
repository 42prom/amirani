import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:amirani_app/core/network/dio_provider.dart';

final socketStorageProvider = Provider((ref) => const FlutterSecureStorage());

class SocketService {
  final String baseUrl;
  final String? token;

  SocketService({required this.baseUrl, this.token});

  io.Socket getRoomSocket() {
    return io.io('$baseUrl/challenge-rooms', 
      io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableAutoConnect()
        .enableForceNew()
        .build()
    );
  }

  void dispose() {
    // We don't dispose global socket here if it was reused, 
    // but specific namespace sockets should be managed by their providers.
  }
}

final socketServiceProvider = FutureProvider<SocketService>((ref) async {
  final storage = ref.watch(socketStorageProvider);
  final token = await storage.read(key: 'jwt_token');
  
  // Use same base URL as Dio
  final dio = ref.watch(dioProvider);
  final baseUrl = dio.options.baseUrl.replaceAll('/api', '');

  return SocketService(baseUrl: baseUrl, token: token);
});
