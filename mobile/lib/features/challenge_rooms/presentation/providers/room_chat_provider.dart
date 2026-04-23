import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../data/datasources/room_remote_data_source.dart';
import '../../data/models/room_model.dart';
import '../../../../core/network/socket_provider.dart';
import 'room_provider.dart';

class RoomChatState {
  final List<RoomMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final bool isConnected;

  RoomChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.isConnected = false,
  });

  RoomChatState copyWith({
    List<RoomMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool? isConnected,
  }) {
    return RoomChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class RoomChatNotifier extends StateNotifier<RoomChatState> {
  final RoomRemoteDataSource _ds;
  final SocketService? _socketService;
  final String _roomId;
  io.Socket? _socket;

  RoomChatNotifier({
    required RoomRemoteDataSource ds,
    required SocketService? socketService,
    required String roomId,
  }) : _ds = ds, _socketService = socketService, _roomId = roomId, super(RoomChatState()) {
    if (_socketService != null) {
      _init();
    }
  }

  void _init() async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Fetch initial messages
      final initialMessages = await _ds.getRoomMessages(_roomId);
      state = state.copyWith(messages: initialMessages, isLoading: false);

      // 2. Connect socket
      _socket = _socketService!.getRoomSocket();
      
      _socket?.onConnect((_) {
        _socket?.emit('join_room', _roomId);
        if (mounted) state = state.copyWith(isConnected: true);
      });

      _socket?.onDisconnect((_) {
        if (mounted) state = state.copyWith(isConnected: false);
      });

      _socket?.on('new_message', (data) {
        final msg = RoomMessage.fromJson(data as Map<String, dynamic>);
        if (msg.roomId == _roomId) {
          if (mounted) {
            state = state.copyWith(
              messages: [msg, ...state.messages.where((m) => m.id != msg.id)],
            );
          }
        }
      });

      _socket?.on('error', (data) {
        if (mounted) state = state.copyWith(error: data['message']?.toString());
      });

      _socket?.connect();
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String body, {String? imageUrl}) async {
    if (body.trim().isEmpty && imageUrl == null) return;
    
    // Optimistic UI could be added here if needed
    
    _socket?.emit('send_message', {
      'roomId': _roomId,
      'body': body.trim(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

  @override
  void dispose() {
    _socket?.emit('leave_room', _roomId);
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}

final roomChatProvider = StateNotifierProvider.family<RoomChatNotifier, RoomChatState, String>((ref, roomId) {
  final ds = ref.watch(roomDataSourceProvider);
  final socketServiceAsync = ref.watch(socketServiceProvider);
  
  return RoomChatNotifier(
    ds: ds, 
    socketService: socketServiceAsync.value, 
    roomId: roomId,
  );
});
