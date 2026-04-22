import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/app_config.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/utils/app_notifications.dart';
import '../providers/support_provider.dart';
import '../../data/datasources/support_remote_data_source.dart';

/// Full-screen trainer conversation page — reuses the support ticket thread UI.
class TrainerChatPage extends ConsumerStatefulWidget {
  final String gymId;
  final String trainerId;
  final String trainerName;
  final String? trainerAvatarUrl;
  final String? trainerSpecialization;
  final String ticketId; // pre-opened ticket from assignment data source

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
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(supportProvider.notifier).loadDetail(widget.gymId, widget.ticketId));
  }

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
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _replyCtrl.clear();
    final ok = await ref.read(supportProvider.notifier).reply(
          gymId: widget.gymId,
          ticketId: widget.ticketId,
          body: body,
        );
    setState(() => _sending = false);
    if (ok) {
      _scrollToBottom();
    } else {
      if (mounted) AppNotifications.showError(context, 'Failed to send message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportProvider);

    SupportTicketModel? ticket;
    if (supportState is SupportDetailLoaded) {
      ticket = supportState.detail;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.4), width: 1.5),
              ),
              child: ClipOval(
                child: (widget.trainerAvatarUrl?.isNotEmpty == true)
                    ? CachedNetworkImage(
                        imageUrl: AppConfig.resolveMediaUrl(widget.trainerAvatarUrl) ?? '',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.person, color: Colors.white24, size: 18),
                      )
                    : const Icon(Icons.person, color: Colors.white24, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trainerName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (widget.trainerSpecialization != null)
                  Text(
                    widget.trainerSpecialization!,
                    style: TextStyle(
                        color: AppTheme.primaryBrand, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ticket == null
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBrand))
                : ticket.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: Colors.white.withValues(alpha: 0.2), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Start a conversation with ${widget.trainerName}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: ticket.messages.length,
                        itemBuilder: (_, i) => _buildBubble(ticket!.messages[i]),
                      ),
          ),
          _buildReplyBar(),
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
              backgroundColor: AppTheme.primaryBrand.withValues(alpha: 0.2),
              backgroundImage: msg.senderAvatarUrl != null
                  ? CachedNetworkImageProvider(
                      AppConfig.resolveMediaUrl(msg.senderAvatarUrl) ?? '')
                  : null,
              child: msg.senderAvatarUrl == null
                  ? Icon(Icons.fitness_center,
                      color: AppTheme.primaryBrand, size: 14)
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
                          color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isTrainer
                        ? AppTheme.primaryBrand.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isTrainer ? 4 : 14),
                      bottomRight: Radius.circular(isTrainer ? 14 : 4),
                    ),
                    border: Border.all(
                      color: isTrainer
                          ? AppTheme.primaryBrand.withValues(alpha: 0.2)
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

  Widget _buildReplyBar() {
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
                    color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _sendReply,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand.withValues(alpha: _sending ? 0.3 : 0.9),
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.send_rounded, color: Colors.black, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
