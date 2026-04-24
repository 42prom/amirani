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
  final String _roomId;
  io.Socket? _socket;

  RoomChatNotifier({
    required RoomRemoteDataSource ds,
    required SocketService? socketService,
    required String roomId,
  })  : _ds = ds,
        _roomId = roomId,
        super(RoomChatState()) {
    if (socketService != null) {
      _init(socketService);
    } else {
      _loadInitialMessages();
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Called when socketServiceProvider resolves after provider was created
  /// with a null socket. Connects without re-fetching messages.
  void upgradeToSocket(SocketService svc) {
    if (!mounted || _socket != null) return;
    _connectSocket(svc.getRoomSocket());
  }

  Future<void> sendMessage(String body, {String? imageUrl}) async {
    if (body.trim().isEmpty && imageUrl == null) return;
    if (mounted) state = state.copyWith(isSending: true);

    _socket?.emit('send_message', {
      'roomId': _roomId,
      'body': body.trim(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    });

    // Clear sending flag after server echo window
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) state = state.copyWith(isSending: false);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _loadInitialMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _ds.getRoomMessages(_roomId);
      if (mounted) state = state.copyWith(messages: messages, isLoading: false, isConnected: false);
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _init(SocketService socketService) async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _ds.getRoomMessages(_roomId);
      if (!mounted) return;
      state = state.copyWith(messages: messages, isLoading: false);
      _connectSocket(socketService.getRoomSocket());
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _connectSocket(io.Socket socket) {
    _socket = socket;

    _socket!.onConnect((_) {
      _socket!.emit('join_room', _roomId);
      if (mounted) state = state.copyWith(isConnected: true);
    });

    _socket!.onDisconnect((_) {
      if (mounted) state = state.copyWith(isConnected: false);
    });

    _socket!.on('new_message', (data) {
      final msg = RoomMessage.fromJson(data as Map<String, dynamic>);
      if (msg.roomId == _roomId && mounted) {
        state = state.copyWith(
          messages: [msg, ...state.messages.where((m) => m.id != msg.id)],
        );
      }
    });

    _socket!.on('error', (data) {
      if (mounted) state = state.copyWith(error: data['message']?.toString());
    });

    // connect() is a no-op if the shared socket is already connected
    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.emit('leave_room', _roomId);
    // Do NOT disconnect or dispose — SocketService owns the socket lifecycle
    super.dispose();
  }
}

final roomChatProvider =
    StateNotifierProvider.family<RoomChatNotifier, RoomChatState, String>((ref, roomId) {
  final ds = ref.watch(roomDataSourceProvider);
  // ref.read prevents provider rebuild when the FutureProvider resolves,
  // eliminating the double REST fetch on every room open.
  final socketService = ref.read(socketServiceProvider).value;

  final notifier = RoomChatNotifier(
    ds: ds,
    socketService: socketService,
    roomId: roomId,
  );

  // If socket wasn't ready yet, upgrade when it resolves — no new notifier created.
  if (socketService == null) {
    ref.listen<AsyncValue<SocketService>>(socketServiceProvider, (_, next) {
      next.whenData((svc) => notifier.upgradeToSocket(svc));
    });
  }

  return notifier;
});
