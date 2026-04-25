import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../../data/models/room_model.dart';
import '../providers/room_provider.dart';
import '../providers/room_chat_provider.dart';
import 'package:intl/intl.dart';
import 'package:amirani_app/core/widgets/premium_state_card.dart';

class RoomDetailPage extends ConsumerStatefulWidget {
  final String roomId;
  const RoomDetailPage({super.key, required this.roomId});

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomDetailProvider(widget.roomId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomDetailProvider(widget.roomId));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTokens.colorBgPrimary,
        body: state.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTokens.colorBrand)),
          error: (e, _) => _ErrorBody(
            message: e.toString().replaceAll('Exception: ', ''),
            onRetry: () => ref.read(roomDetailProvider(widget.roomId).notifier).load(),
            onBack: () => Navigator.of(context).pop(),
          ),
          data: (detail) => _DetailBody(detail: detail, roomId: widget.roomId),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final RoomDetail detail;
  final String roomId;
  const _DetailBody({required this.detail, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = detail.room;
    
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          backgroundColor: AppTokens.colorBgPrimary,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          floating: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(room.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              overflow: TextOverflow.ellipsis),
          actions: [
            if (detail.isMember)
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () => _showInviteCodeSheet(context, room.inviteCode),
                tooltip: 'Share Room',
              ),
            if (detail.isCreator)
              PopupMenuButton<_RoomAction>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: AppTokens.colorBgSurface,
                onSelected: (action) => _handleAction(context, ref, action),
                itemBuilder: (_) => [
                  if (!room.isPublic)
                    const PopupMenuItem(
                      value: _RoomAction.shareCode,
                      child: Row(children: [
                        Icon(Icons.vpn_key_outlined, color: Colors.white54, size: 18),
                        SizedBox(width: 10),
                        Text('Share Invite Code', style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: _RoomAction.delete,
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      SizedBox(width: 10),
                      Text('Delete Room', style: TextStyle(color: Colors.redAccent)),
                    ]),
                  ),
                ],
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              decoration: BoxDecoration(
                color: AppTokens.colorBgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppTokens.colorBrand,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Leaderboard'),
                  Tab(text: 'Challenges'),
                  Tab(text: 'Chat'),
                ],
              ),
            ),
          ),
        ),
      ],
      body: TabBarView(
        children: [
          _LeaderboardView(
            detail: detail,
            roomId: roomId,
            onShare: () => _showInviteCodeSheet(context, detail.room.inviteCode),
          ),
          _ChallengesView(roomId: roomId, isMember: detail.isMember),
          _ChatView(roomId: roomId),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, _RoomAction action) {
    switch (action) {
      case _RoomAction.shareCode:
        _showInviteCodeSheet(context, detail.room.inviteCode);
        break;
      case _RoomAction.delete:
        _confirmDelete(context, ref);
        break;
    }
  }

  void _showInviteCodeSheet(BuildContext context, String code) {
    final deeplink = 'amirani://rooms/join?code=$code';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        decoration: const BoxDecoration(
          color: AppTokens.colorBgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.share_outlined, color: AppTokens.colorBrand, size: 28),
            const SizedBox(height: 10),
            const Text('Share Room',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Invite friends to join and compete',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                textAlign: TextAlign.center),
            if (detail.myEntry != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTokens.colorBrand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, color: AppTokens.colorBrand, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'You\'re ranked #${detail.myEntry!.rank} · ${detail.myEntry!.score} pts',
                      style: const TextStyle(color: AppTokens.colorBrand, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTokens.colorBrand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  Text('INVITE CODE',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text(code,
                      style: const TextStyle(color: AppTokens.colorBrand, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 10)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(deeplink,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!'), backgroundColor: AppTokens.colorBgSurface, duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: deeplink));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied!'), backgroundColor: AppTokens.colorBgSurface, duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Copy Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTokens.colorBrand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.colorBgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Room?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Permanently delete "${detail.room.name}" and remove all members.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(roomDetailProvider(roomId).notifier).deleteRoom();
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red.withValues(alpha: 0.8)),
                  );
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardView extends ConsumerWidget {
  final RoomDetail detail;
  final String roomId;
  final VoidCallback? onShare;
  const _LeaderboardView({required this.detail, required this.roomId, this.onShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = detail.room;
    final metricColor = _metricColor(room.metric);
    final slots = List<LeaderboardEntry?>.generate(
      3,
      (i) => detail.leaderboard.length > i ? detail.leaderboard[i] : null,
    );
    final rest = detail.leaderboard.skip(3).toList();

    return RefreshIndicator(
      color: AppTokens.colorBrand,
      backgroundColor: AppTokens.colorBgSurface,
      onRefresh: () => ref.read(roomDetailProvider(roomId).notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (detail.myEntry != null && detail.myEntry!.rank == 1) ...[
                    _WinnerBanner(score: detail.myEntry!.score, onShare: onShare),
                    const SizedBox(height: 12),
                  ],
                  _StatsRow(room: room, metricColor: metricColor),
                  if (room.description != null && room.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      room.description!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Leaderboard',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: metricColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(room.metricLabel,
                            style: TextStyle(
                                color: metricColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(
                        '${detail.leaderboard.length} member${detail.leaderboard.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Podium(
                slots: slots,
                metricColor: metricColor,
                isCreator: detail.isCreator,
                onKick: (entry) => _confirmKick(context, ref, entry),
                onRename: detail.isMember
                    ? (entry) => _showRenameDialog(context, ref, entry)
                    : null,
              ),
            ),
          ),
          if (rest.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LeaderboardRow(
                      entry: rest[i],
                      metricColor: metricColor,
                      onKick: detail.isCreator && !rest[i].isMe
                          ? () => _confirmKick(context, ref, rest[i])
                          : null,
                      onRename: rest[i].isMe
                          ? () => _showRenameDialog(context, ref, rest[i])
                          : null,
                    ),
                  ),
                  childCount: rest.length,
                ),
              ),
            ),
          if (detail.isCreator && detail.leaderboard.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _ManageMembersSection(
                  entries: detail.leaderboard,
                  roomId: roomId,
                  onKick: (entry) => _confirmKick(context, ref, entry),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: _BottomCTA(detail: detail, roomId: roomId),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmKick(BuildContext context, WidgetRef ref, LeaderboardEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.colorBgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${entry.fullName} from this room?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(roomDetailProvider(roomId).notifier).kickMember(entry.userId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red.withValues(alpha: 0.8)),
                  );
                }
              }
            },
            child: const Text('Remove',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, LeaderboardEntry entry) {
    final ctrl = TextEditingController(text: entry.fullName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.colorBgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Your Display Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter nickname',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: AppTokens.colorBgPrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: AppTokens.colorBrand),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(roomDetailProvider(roomId).notifier).updateDisplayName(name);
                await ref.read(roomDetailProvider(roomId).notifier).refresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red.withValues(alpha: 0.8)),
                  );
                }
              }
            },
            child: const Text('Save',
                style: TextStyle(color: AppTokens.colorBrand, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _metricColor(String metric) {
    switch (metric) {
      case 'SESSIONS':  return Colors.blueAccent;
      case 'STREAK':    return Colors.orangeAccent;
      case 'COMPOSITE': return Colors.purpleAccent;
      default:          return AppTokens.colorBrand;
    }
  }
}

class _ChatView extends ConsumerStatefulWidget {
  final String roomId;
  const _ChatView({required this.roomId});

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(roomChatProvider(widget.roomId));

    return Column(
      children: [
        Expanded(
          child: chatState.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTokens.colorBrand))
              : chatState.messages.isEmpty
                  ? _buildEmptyChat()
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, i) => _ChatMessageBubble(
                        message: chatState.messages[i],
                      ),
                    ),
        ),
        _buildInputArea(chatState),
      ],
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.white.withValues(alpha: 0.1), size: 64),
          const SizedBox(height: 16),
          Text(
            'No messages yet.\nBe the first to say hi!',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(RoomChatState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: AppTokens.colorBgPrimary,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTokens.colorBgSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              height: 44,
              width: 44,
              decoration: const BoxDecoration(
                color: AppTokens.colorBrand,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(roomChatProvider(widget.roomId).notifier).sendMessage(text);
    _msgCtrl.clear();
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final RoomMessage message;
  const _ChatMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTokens.colorBrand.withValues(alpha: 0.1),
              border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                message.user.fullName.isNotEmpty ? message.user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTokens.colorBrand, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.user.fullName,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTokens.colorBgSurface,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    message.body,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Components ───────────────────────────────────────────────────────────────

enum _RoomAction { shareCode, delete }

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry?> slots;
  final Color metricColor;
  final bool isCreator;
  final void Function(LeaderboardEntry) onKick;
  final void Function(LeaderboardEntry)? onRename;

  const _Podium({
    required this.slots,
    required this.metricColor,
    required this.isCreator,
    required this.onKick,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final first  = slots[0];
    final second = slots[1];
    final third  = slots[2];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _PodiumColumn(
                  entry: second, rank: 2, avatarSize: 52,
                  metricColor: metricColor, isCreator: isCreator,
                  onKick: second != null && isCreator && !(second.isMe) ? () => onKick(second) : null,
                  onRename: second != null && second.isMe ? () => onRename?.call(second) : null,
                ),
              ),
              Expanded(
                child: _PodiumColumn(
                  entry: first, rank: 1, avatarSize: 64,
                  metricColor: metricColor, isCreator: isCreator,
                  onKick: first != null && isCreator && !(first.isMe) ? () => onKick(first) : null,
                  onRename: first != null && first.isMe ? () => onRename?.call(first) : null,
                ),
              ),
              Expanded(
                child: _PodiumColumn(
                  entry: third, rank: 3, avatarSize: 44,
                  metricColor: metricColor, isCreator: isCreator,
                  onKick: third != null && isCreator && !(third.isMe) ? () => onKick(third) : null,
                  onRename: third != null && third.isMe ? () => onRename?.call(third) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PodiumBar(rank: 2, height: 52, filled: second != null),
              _PodiumBar(rank: 1, height: 72, filled: first != null),
              _PodiumBar(rank: 3, height: 36, filled: third != null),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final LeaderboardEntry? entry;
  final int rank;
  final double avatarSize;
  final Color metricColor;
  final bool isCreator;
  final VoidCallback? onKick;
  final VoidCallback? onRename;

  const _PodiumColumn({
    required this.entry, required this.rank, required this.avatarSize,
    required this.metricColor, required this.isCreator, this.onKick, this.onRename,
  });

  static const _rankColors = {1: Color(0xFFFFD700), 2: Color(0xFFC0C0C0), 3: Color(0xFFCD7F32)};
  static const _rankLabels = {1: '1st', 2: '2nd', 3: '3rd'};

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColors[rank]!;
    if (entry == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1) Icon(Icons.emoji_events, color: rankColor.withValues(alpha: 0.2), size: 22)
          else const SizedBox(height: 22),
          const SizedBox(height: 4),
          Container(
            width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: rankColor.withValues(alpha: 0.15), width: 2),
            ),
            child: Center(
              child: Text(_rankLabels[rank]!,
                  style: TextStyle(color: rankColor.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Text('—', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('—', style: TextStyle(color: rankColor.withValues(alpha: 0.2), fontSize: rank == 1 ? 18 : 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
        ],
      );
    }

    final isMe = entry!.isMe;
    return GestureDetector(
      onTap: isMe && onRename != null ? onRename : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1) Icon(Icons.emoji_events, color: rankColor, size: 22) else const SizedBox(height: 22),
          const SizedBox(height: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize, height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMe ? AppTokens.colorBrand.withValues(alpha: 0.2) : rankColor.withValues(alpha: 0.12),
                  border: Border.all(color: isMe ? AppTokens.colorBrand : rankColor.withValues(alpha: 0.5), width: isMe ? 2.5 : 2),
                ),
                child: Center(
                  child: Text(
                    entry!.fullName.isNotEmpty ? entry!.fullName[0].toUpperCase() : '?',
                    style: TextStyle(color: isMe ? AppTokens.colorBrand : rankColor, fontWeight: FontWeight.bold, fontSize: avatarSize * 0.35),
                  ),
                ),
              ),
              if (isMe && onRename != null)
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(color: AppTokens.colorBrand, shape: BoxShape.circle, border: Border.all(color: AppTokens.colorBgPrimary, width: 1.5)),
                    child: const Icon(Icons.edit, color: Colors.black, size: 11),
                  ),
                ),
              if (onKick != null)
                Positioned(
                  right: -4, top: -4,
                  child: GestureDetector(
                    onTap: onKick,
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: const Color(0xFFD32F2F), shape: BoxShape.circle, border: Border.all(color: AppTokens.colorBgPrimary, width: 2)),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(isMe ? 'You' : entry!.fullName.split(' ').first, style: TextStyle(color: isMe ? AppTokens.colorBrand : Colors.white, fontWeight: FontWeight.bold, fontSize: rank == 1 ? 13 : 12), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('${entry!.score}', style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: rank == 1 ? 18 : 15)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PodiumBar extends StatelessWidget {
  final int rank;
  final double height;
  final bool filled;
  const _PodiumBar({required this.rank, required this.height, required this.filled});
  static const _rankColors = {1: Color(0xFFFFD700), 2: Color(0xFFC0C0C0), 3: Color(0xFFCD7F32)};
  static const _rankLabels = {1: '1st', 2: '2nd', 3: '3rd'};
  @override
  Widget build(BuildContext context) {
    final color = _rankColors[rank]!;
    final opacity = filled ? 1.0 : 0.3;
    return Expanded(
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: filled ? 0.12 : 0.04),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border(
            top: BorderSide(color: color.withValues(alpha: 0.4 * opacity), width: 1.5),
            left: BorderSide(color: color.withValues(alpha: 0.2 * opacity)),
            right: BorderSide(color: color.withValues(alpha: 0.2 * opacity)),
          ),
        ),
        child: Center(child: Text(_rankLabels[rank]!, style: TextStyle(color: color.withValues(alpha: 0.6 * opacity), fontSize: 11, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final Color metricColor;
  final VoidCallback? onKick;
  final VoidCallback? onRename;
  const _LeaderboardRow({required this.entry, required this.metricColor, this.onKick, this.onRename});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: entry.isMe && onRename != null ? onRename : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: entry.isMe ? AppTokens.colorBrand.withValues(alpha: 0.07) : AppTokens.colorBgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: entry.isMe ? AppTokens.colorBrand.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text('#${entry.rank}', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: entry.isMe ? AppTokens.colorBrand.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06)),
              child: Center(child: Text(entry.fullName.isNotEmpty ? entry.fullName[0].toUpperCase() : '?', style: TextStyle(color: entry.isMe ? AppTokens.colorBrand : Colors.white54, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Row(children: [
              Flexible(child: Text(entry.fullName, style: TextStyle(color: entry.isMe ? AppTokens.colorBrand : Colors.white, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
              if (entry.isMe) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppTokens.colorBrand.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: const Text('You', style: TextStyle(color: AppTokens.colorBrand, fontSize: 9, fontWeight: FontWeight.bold))),
                if (onRename != null) ...[const SizedBox(width: 5), Icon(Icons.edit, size: 12, color: AppTokens.colorBrand.withValues(alpha: 0.5))],
              ],
            ])),
            Text('${entry.score}', style: TextStyle(color: metricColor, fontSize: 16, fontWeight: FontWeight.bold)),
            if (onKick != null) ...[
              const SizedBox(width: 8),
              GestureDetector(onTap: onKick, child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withValues(alpha: 0.1)), child: const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 14))),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManageMembersSection extends ConsumerStatefulWidget {
  final List<LeaderboardEntry> entries;
  final String roomId;
  final void Function(LeaderboardEntry) onKick;
  const _ManageMembersSection({required this.entries, required this.roomId, required this.onKick});
  @override
  ConsumerState<_ManageMembersSection> createState() => _ManageMembersSectionState();
}

class _ManageMembersSectionState extends ConsumerState<_ManageMembersSection> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final others = widget.entries.where((e) => !e.isMe).toList();
    return Container(
      decoration: BoxDecoration(color: AppTokens.colorBgSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const Icon(Icons.manage_accounts_outlined, color: Colors.white54, size: 20),
              const SizedBox(width: 10),
              const Text('Manage Members', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('${others.length}', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
              const Spacer(),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white38, size: 20),
            ]),
          ),
        ),
        if (_expanded) ...[
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ...others.map((entry) => _MemberRow(entry: entry, onKick: () => widget.onKick(entry))),
        ],
      ]),
    );
  }
}

class _MemberRow extends StatefulWidget {
  final LeaderboardEntry entry;
  final VoidCallback onKick;
  const _MemberRow({required this.entry, required this.onKick});
  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)), child: Center(child: Text(widget.entry.fullName.isNotEmpty ? widget.entry.fullName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.entry.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
          Text('Rank #${widget.entry.rank} · ${widget.entry.score} pts', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
        ])),
        GestureDetector(
          onTap: _loading ? null : () async { setState(() => _loading = true); widget.onKick(); await Future.delayed(const Duration(milliseconds: 300)); if (mounted) setState(() => _loading = false); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.25))), child: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)) : const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
        ),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final RoomModel room;
  final Color metricColor;
  const _StatsRow({required this.room, required this.metricColor});
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _StatPill(icon: _metricIcon(room.metric), label: room.metricLabel, color: metricColor),
      _StatPill(icon: Icons.refresh, label: room.periodLabel, color: Colors.white38),
      _StatPill(icon: Icons.people_outline, label: '${room.memberCount}/${room.maxMembers}', color: Colors.white38),
      if (!room.isPublic) _StatPill(icon: Icons.lock_outline, label: 'Private', color: Colors.orange),
      if (room.isExpired) _StatPill(icon: Icons.timer_off_outlined, label: 'Ended', color: Colors.red),
    ]);
  }
  IconData _metricIcon(String metric) {
    switch (metric) {
      case 'SESSIONS':  return Icons.fitness_center;
      case 'STREAK':    return Icons.local_fire_department;
      case 'COMPOSITE': return Icons.workspace_premium;
      default:          return Icons.bolt;
    }
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 12), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))]),
    );
  }
}

class _BottomCTA extends ConsumerStatefulWidget {
  final RoomDetail detail; final String roomId;
  const _BottomCTA({required this.detail, required this.roomId});
  @override
  ConsumerState<_BottomCTA> createState() => _BottomCTAState();
}

class _BottomCTAState extends ConsumerState<_BottomCTA> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    if (widget.detail.isCreator) return const SizedBox.shrink();
    if (!widget.detail.isMember) {
      return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _loading ? null : _join, icon: const Icon(Icons.emoji_events, size: 18), label: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), style: ElevatedButton.styleFrom(backgroundColor: AppTokens.colorBrand, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))));
    }
    return SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _loading ? null : _leave, icon: const Icon(Icons.exit_to_app, size: 18), label: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)) : const Text('Leave Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: BorderSide(color: Colors.white.withValues(alpha: 0.15)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));
  }
  Future<void> _join() async { setState(() => _loading = true); try { await ref.read(myRoomsProvider.notifier).joinRoom(widget.roomId); await ref.read(roomDetailProvider(widget.roomId).notifier).refresh(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red.withValues(alpha: 0.8))); } if (mounted) setState(() => _loading = false); }
  Future<void> _leave() async { setState(() => _loading = true); try { await ref.read(myRoomsProvider.notifier).leaveRoom(widget.roomId); if (mounted) Navigator.of(context).pop(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red.withValues(alpha: 0.8))); } if (mounted) setState(() => _loading = false); }
}

// ── Challenges view ──────────────────────────────────────────────────────────

class _ChallengesView extends ConsumerStatefulWidget {
  final String roomId;
  final bool isMember;
  const _ChallengesView({required this.roomId, required this.isMember});

  @override
  ConsumerState<_ChallengesView> createState() => _ChallengesViewState();
}

class _ChallengesViewState extends ConsumerState<_ChallengesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomChallengesProvider(widget.roomId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomChallengesProvider(widget.roomId));
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTokens.colorBrand)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.6), size: 48),
              const SizedBox(height: 16),
              Text(e.toString().replaceAll('Exception: ', ''),
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => ref.read(roomChallengesProvider(widget.roomId).notifier).load(),
                child: const Text('Retry', style: TextStyle(color: AppTokens.colorBrand)),
              ),
            ],
          ),
        ),
      ),
      data: (challenges) => RefreshIndicator(
        color: AppTokens.colorBrand,
        backgroundColor: AppTokens.colorBgSurface,
        onRefresh: () => ref.read(roomChallengesProvider(widget.roomId).notifier).load(),
        child: challenges.isEmpty
            ? _buildEmpty()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: challenges.length,
                itemBuilder: (_, i) => _ChallengeCard(
                  challenge: challenges[i],
                  isMember: widget.isMember,
                  onLog: () => _logProgress(challenges[i].id),
                ),
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: Colors.white.withValues(alpha: 0.1), size: 64),
                const SizedBox(height: 16),
                Text('No challenges yet',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('The room creator can add challenges\nfor members to complete.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _logProgress(String challengeId) async {
    try {
      await ref.read(roomChallengesProvider(widget.roomId).notifier).logProgress(challengeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Progress logged!'),
            backgroundColor: AppTokens.colorBgSurface,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

class _ChallengeCard extends StatefulWidget {
  final RoomChallenge challenge;
  final bool isMember;
  final VoidCallback onLog;
  const _ChallengeCard({required this.challenge, required this.isMember, required this.onLog});

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _logging = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final progress = c.progressFraction;
    final completed = c.myProgress.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed
            ? AppTokens.colorBrand.withValues(alpha: 0.06)
            : AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? AppTokens.colorBrand.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed
                      ? AppTokens.colorBrand.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                child: Icon(
                  completed ? Icons.check_circle : Icons.flag_outlined,
                  color: completed ? AppTokens.colorBrand : Colors.white38,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: TextStyle(
                            color: completed ? AppTokens.colorBrand : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    if (c.description != null && c.description!.isNotEmpty)
                      Text(c.description!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTokens.colorBrand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: AppTokens.colorBrand, size: 12),
                    const SizedBox(width: 3),
                    Text('${c.pointsReward}',
                        style: const TextStyle(
                            color: AppTokens.colorBrand,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${c.myProgress.currentValue} / ${c.targetValue} ${c.unit}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: completed
                                  ? AppTokens.colorBrand
                                  : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completed ? AppTokens.colorBrand : Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isMember && !completed) ...[
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: _logging ? null : () async {
                    setState(() => _logging = true);
                    await Future.microtask(widget.onLog);
                    if (mounted) setState(() => _logging = false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _logging
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppTokens.colorBrand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTokens.colorBrand.withValues(alpha: _logging ? 0.1 : 0.4)),
                    ),
                    child: _logging
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTokens.colorBrand))
                        : const Text('+1',
                            style: TextStyle(
                                color: AppTokens.colorBrand,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
          if (c.endDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.timer_outlined,
                    color: Colors.white.withValues(alpha: 0.25), size: 12),
                const SizedBox(width: 4),
                Text(
                  'Ends ${DateFormat('MMM d').format(c.endDate!)}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  final int score;
  final VoidCallback? onShare;
  const _WinnerBanner({required this.score, this.onShare});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onShare,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTokens.colorBrand.withValues(alpha: 0.18), AppTokens.colorBrand.withValues(alpha: 0.06)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: AppTokens.colorBrand, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("You're leading!",
                      style: TextStyle(color: AppTokens.colorBrand, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Score: $score pts · Challenge friends to beat you',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
                ],
              ),
            ),
            if (onShare != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTokens.colorBrand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Invite', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message; final VoidCallback onRetry; final VoidCallback onBack;
  const _ErrorBody({required this.message, required this.onRetry, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: PremiumStateCard(icon: Icons.error_rounded, title: 'Access Error', subtitle: message, onAction: onRetry, actionLabel: 'Retry')));
  }
}
