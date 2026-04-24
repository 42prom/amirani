import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../data/datasources/support_remote_data_source.dart';
import '../../../../core/network/socket_provider.dart';

// ─── Params ───────────────────────────────────────────────────────────────────

class TrainerChatParams {
  final String gymId;
  final String ticketId;

  const TrainerChatParams({required this.gymId, required this.ticketId});

  @override
  bool operator ==(Object other) =>
      other is TrainerChatParams &&
      other.gymId == gymId &&
      other.ticketId == ticketId;

  @override
  int get hashCode => Object.hash(gymId, ticketId);
}

// ─── State ────────────────────────────────────────────────────────────────────

class TrainerChatState {
  final List<TicketMessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final bool isConnected;
  final String? error;

  const TrainerChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isConnected = false,
    this.error,
  });

  TrainerChatState copyWith({
    List<TicketMessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isConnected,
    String? error,
  }) {
    return TrainerChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TrainerChatNotifier extends StateNotifier<TrainerChatState> {
  final SupportRemoteDataSource _ds;
  final String _gymId;
  final String _ticketId;
  io.Socket? _socket;

  TrainerChatNotifier({
    required SupportRemoteDataSource ds,
    required SocketService? socketService,
    required String gymId,
    required String ticketId,
  })  : _ds = ds,
        _gymId = gymId,
        _ticketId = ticketId,
        super(const TrainerChatState()) {
    if (socketService != null) {
      _init(socketService);
    } else {
      _loadInitialMessages();
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Called when socketServiceProvider resolves after provider was created
  /// with a null socket. Connects without re-fetching messages.
  void upgradeToSocket(SocketService svc) {
    if (!mounted || _socket != null) return;
    _connectSocket(svc.getTrainerChatSocket());
  }

  Future<void> sendMessage(String body) async {
    if (body.trim().isEmpty) return;
    if (mounted) state = state.copyWith(isSending: true);

    if (_socket != null && state.isConnected) {
      _socket!.emit('send_message', {
        'ticketId': _ticketId,
        'gymId': _gymId,
        'body': body.trim(),
      });
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      // REST fallback when socket is unavailable
      try {
        await _ds.reply(gymId: _gymId, ticketId: _ticketId, body: body.trim());
        await _loadInitialMessages();
      } catch (e) {
        if (mounted) state = state.copyWith(error: e.toString());
      }
    }

    if (mounted) state = state.copyWith(isSending: false);
  }

  Future<void> refresh() => _loadInitialMessages();

  // ── Private ─────────────────────────────────────────────────────────────────

  Future<void> _loadInitialMessages() async {
    if (mounted) state = state.copyWith(isLoading: true);
    try {
      final ticket = await _ds.getTicket(_gymId, _ticketId);
      if (mounted) {
        state = state.copyWith(
          messages: ticket.messages,
          isLoading: false,
          isConnected: false,
        );
      }
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _init(SocketService socketService) async {
    if (mounted) state = state.copyWith(isLoading: true);
    try {
      final ticket = await _ds.getTicket(_gymId, _ticketId);
      if (!mounted) return;
      state = state.copyWith(messages: ticket.messages, isLoading: false);
      _connectSocket(socketService.getTrainerChatSocket());
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _connectSocket(io.Socket socket) {
    _socket = socket;

    _socket!.onConnect((_) {
      _socket!.emit('join_ticket', _ticketId);
      if (mounted) state = state.copyWith(isConnected: true);
    });

    _socket!.onDisconnect((_) {
      if (mounted) state = state.copyWith(isConnected: false);
    });

    _socket!.on('new_message', (data) {
      try {
        final msg = TicketMessageModel.fromJson(data as Map<String, dynamic>);
        if (mounted) {
          state = state.copyWith(
            messages: [...state.messages.where((m) => m.id != msg.id), msg],
          );
        }
      } catch (_) {}
    });

    _socket!.on('error', (data) {
      if (mounted) state = state.copyWith(error: data['message']?.toString());
    });

    // connect() is a no-op if the shared socket is already connected
    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.emit('leave_ticket', _ticketId);
    // Do NOT disconnect or dispose — SocketService owns the socket lifecycle
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final trainerChatProvider = StateNotifierProvider.family<TrainerChatNotifier,
    TrainerChatState, TrainerChatParams>((ref, params) {
  final ds = ref.watch(supportDataSourceProvider);
  // ref.read prevents provider rebuild when the FutureProvider resolves,
  // eliminating the double REST fetch on every chat open.
  final socketService = ref.read(socketServiceProvider).value;

  final notifier = TrainerChatNotifier(
    ds: ds,
    socketService: socketService,
    gymId: params.gymId,
    ticketId: params.ticketId,
  );

  // If socket wasn't ready yet, upgrade when it resolves — no new notifier created.
  if (socketService == null) {
    ref.listen<AsyncValue<SocketService>>(socketServiceProvider, (_, next) {
      next.whenData((svc) => notifier.upgradeToSocket(svc));
    });
  }

  return notifier;
});
