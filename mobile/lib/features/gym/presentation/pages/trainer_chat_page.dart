import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:amirani_app/core/config/app_config.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import 'package:amirani_app/core/utils/app_notifications.dart';
import '../providers/trainer_chat_provider.dart';
import '../../data/datasources/support_remote_data_source.dart';

/// Full-screen trainer conversation page with Socket.IO real-time messaging.
class TrainerChatPage extends ConsumerStatefulWidget {
  final String gymId;
  final String trainerId;
  final String trainerName;
  final String? trainerAvatarUrl;
  final String? trainerSpecialization;
  final String ticketId;

  const TrainerChatPage({
    super.key,
    required this.gymId,
    required this.trainerId,
    required this.trainerName,
    this.trainerAvatarUrl,
    this.trainerSpecialization,
    required this.ticketId,
  });

  @override
  ConsumerState<TrainerChatPage> createState() => _TrainerChatPageState();
}

class _TrainerChatPageState extends ConsumerState<TrainerChatPage> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  TrainerChatParams get _params =>
      TrainerChatParams(gymId: widget.gymId, ticketId: widget.ticketId);

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty) return;
    _replyCtrl.clear();
    await ref.read(trainerChatProvider(_params).notifier).sendMessage(body);
    final state = ref.read(trainerChatProvider(_params));
    if (state.error != null && mounted) {
      AppNotifications.showError(context, 'Failed to send message');
    } else {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(trainerChatProvider(_params));

    if (chatState.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      appBar: AppBar(
        backgroundColor: AppTokens.colorBgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTokens.colorBrand.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: ClipOval(
                    child: (widget.trainerAvatarUrl?.isNotEmpty == true)
                        ? CachedNetworkImage(
                            imageUrl:
                                AppConfig.resolveMediaUrl(widget.trainerAvatarUrl) ??
                                    '',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white24,
                                size: 18),
                          )
                        : const Icon(Icons.person,
                            color: Colors.white24, size: 18),
                  ),
                ),
                if (chatState.isConnected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTokens.colorBgSurface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trainerName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                if (widget.trainerSpecialization != null)
                  Text(
                    widget.trainerSpecialization!,
                    style: TextStyle(
                        color: AppTokens.colorBrand,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTokens.colorBrand))
                : chatState.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: Colors.white.withValues(alpha: 0.2),
                                size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Start a conversation with ${widget.trainerName}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: chatState.messages.length,
                        itemBuilder: (_, i) =>
                            _buildBubble(chatState.messages[i]),
                      ),
          ),
          _buildReplyBar(chatState.isSending),
        ],
      ),
    );
  }

  Widget _buildBubble(TicketMessageModel msg) {
    final isTrainer = msg.isStaff;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isTrainer ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isTrainer) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTokens.colorBrand.withValues(alpha: 0.2),
              backgroundImage: msg.senderAvatarUrl != null
                  ? CachedNetworkImageProvider(
                      AppConfig.resolveMediaUrl(msg.senderAvatarUrl) ?? '')
                  : null,
              child: msg.senderAvatarUrl == null
                  ? Icon(Icons.fitness_center,
                      color: AppTokens.colorBrand, size: 14)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isTrainer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isTrainer ? msg.senderName : 'You',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _fmtDate(msg.createdAt),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isTrainer
                        ? AppTokens.colorBrand.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isTrainer ? 4 : 14),
                      bottomRight: Radius.circular(isTrainer ? 14 : 4),
                    ),
                    border: Border.all(
                      color: isTrainer
                          ? AppTokens.colorBrand.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    msg.body,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          if (!isTrainer) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildReplyBar(bool isSending) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Message your trainer…',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 14),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : _sendReply,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTokens.colorBrand
                    .withValues(alpha: isSending ? 0.3 : 0.9),
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.send_rounded,
                      color: Colors.black, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
