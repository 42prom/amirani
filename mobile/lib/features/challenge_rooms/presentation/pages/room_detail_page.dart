import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../../data/models/room_model.dart';
import '../providers/room_provider.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBrand)),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceAll('Exception: ', ''),
          onRetry: () => ref.read(roomDetailProvider(widget.roomId).notifier).load(),
          onBack: () => Navigator.of(context).pop(),
        ),
        data: (detail) => _DetailBody(detail: detail, roomId: widget.roomId),
      ),
    );
  }
}

// ── Detail body ───────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final RoomDetail detail;
  final String roomId;
  const _DetailBody({required this.detail, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = detail.room;
    final metricColor = _metricColor(room.metric);
    // Always pass exactly 3 slots (null = empty slot)
    final slots = List<LeaderboardEntry?>.generate(
      3,
      (i) => detail.leaderboard.length > i ? detail.leaderboard[i] : null,
    );
    final rest = detail.leaderboard.skip(3).toList();

    return RefreshIndicator(
      color: AppTheme.primaryBrand,
      backgroundColor: AppTheme.surfaceDark,
      onRefresh: () => ref.read(roomDetailProvider(roomId).notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── App bar ───────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppTheme.backgroundDark,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(room.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                overflow: TextOverflow.ellipsis),
            actions: [
              // Share invite code (accessible to any member of private room)
              if (!room.isPublic && detail.isMember)
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  onPressed: () => _showInviteCodeSheet(context, room.inviteCode),
                  tooltip: 'Share Invite Code',
                ),
              // Creator-only menu
              if (detail.isCreator)
                PopupMenuButton<_RoomAction>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: AppTheme.surfaceDark,
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
          ),

          // ── Stats + description ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  // Leaderboard header
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

          // ── Podium — always 3 slots ───────────────────────────────────────
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

          // ── Rank 4+ list ──────────────────────────────────────────────────
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

          // ── Creator: Manage Members ───────────────────────────────────────
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

          // ── Bottom CTA ────────────────────────────────────────────────────
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

  // ── Actions ──────────────────────────────────────────────────────────────

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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.vpn_key_outlined, color: AppTheme.primaryBrand, size: 32),
            const SizedBox(height: 12),
            const Text('Invite Code',
                style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Share this code with people you want to invite',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: AppTheme.primaryBrand,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Invite code copied!'),
                        backgroundColor: AppTheme.surfaceDark,
                        duration: Duration(seconds: 2)),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Code',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBrand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
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
        backgroundColor: AppTheme.surfaceDark,
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

  void _confirmKick(BuildContext context, WidgetRef ref, LeaderboardEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
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
        backgroundColor: AppTheme.surfaceDark,
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
            fillColor: AppTheme.backgroundDark,
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
              borderSide: BorderSide(color: AppTheme.primaryBrand),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                style: TextStyle(
                    color: AppTheme.primaryBrand, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _metricColor(String metric) {
    switch (metric) {
      case 'SESSIONS': return Colors.blueAccent;
      case 'STREAK':   return Colors.orangeAccent;
      default:         return AppTheme.primaryBrand;
    }
  }
}

enum _RoomAction { shareCode, delete }

// ── Podium (always 3 slots, empty shown as placeholder) ───────────────────────

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry?> slots; // exactly 3 items (null = empty slot)
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
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // Avatar + name row — order: 2, 1, 3
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _PodiumColumn(
                  entry: second,
                  rank: 2,
                  avatarSize: 52,
                  metricColor: metricColor,
                  isCreator: isCreator,
                  onKick: second != null && isCreator && !(second.isMe)
                      ? () => onKick(second)
                      : null,
                  onRename: second != null && second.isMe
                      ? () => onRename?.call(second)
                      : null,
                ),
              ),
              Expanded(
                child: _PodiumColumn(
                  entry: first,
                  rank: 1,
                  avatarSize: 64,
                  metricColor: metricColor,
                  isCreator: isCreator,
                  onKick: first != null && isCreator && !(first.isMe)
                      ? () => onKick(first)
                      : null,
                  onRename: first != null && first.isMe
                      ? () => onRename?.call(first)
                      : null,
                ),
              ),
              Expanded(
                child: _PodiumColumn(
                  entry: third,
                  rank: 3,
                  avatarSize: 44,
                  metricColor: metricColor,
                  isCreator: isCreator,
                  onKick: third != null && isCreator && !(third.isMe)
                      ? () => onKick(third)
                      : null,
                  onRename: third != null && third.isMe
                      ? () => onRename?.call(third)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Podium bars
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
    required this.entry,
    required this.rank,
    required this.avatarSize,
    required this.metricColor,
    required this.isCreator,
    this.onKick,
    this.onRename,
  });

  static const _rankColors = {
    1: Color(0xFFFFD700),
    2: Color(0xFFC0C0C0),
    3: Color(0xFFCD7F32),
  };

  static const _rankLabels = {1: '1st', 2: '2nd', 3: '3rd'};

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColors[rank]!;

    // Empty slot
    if (entry == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1)
            Icon(Icons.emoji_events, color: rankColor.withValues(alpha: 0.2), size: 22)
          else
            const SizedBox(height: 22),
          const SizedBox(height: 4),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                  color: rankColor.withValues(alpha: 0.15), width: 2, style: BorderStyle.solid),
            ),
            child: Center(
              child: Text(_rankLabels[rank]!,
                  style: TextStyle(
                      color: rankColor.withValues(alpha: 0.3),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Text('—',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('—',
              style: TextStyle(
                  color: rankColor.withValues(alpha: 0.2),
                  fontSize: rank == 1 ? 18 : 15,
                  fontWeight: FontWeight.w900)),
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
          if (rank == 1)
            Icon(Icons.emoji_events, color: rankColor, size: 22)
          else
            const SizedBox(height: 22),
          const SizedBox(height: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMe
                      ? AppTheme.primaryBrand.withValues(alpha: 0.2)
                      : rankColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: isMe ? AppTheme.primaryBrand : rankColor.withValues(alpha: 0.5),
                    width: isMe ? 2.5 : 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    entry!.fullName.isNotEmpty ? entry!.fullName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isMe ? AppTheme.primaryBrand : rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: avatarSize * 0.35,
                    ),
                  ),
                ),
              ),
              // Edit pencil for "You"
              if (isMe && onRename != null)
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBrand,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.backgroundDark, width: 1.5),
                    ),
                    child: const Icon(Icons.edit, color: Colors.black, size: 11),
                  ),
                ),
              // Kick X button (creator only, not self)
              if (onKick != null)
                Positioned(
                  right: -4, top: -4,
                  child: GestureDetector(
                    onTap: onKick,
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.backgroundDark, width: 2),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isMe ? 'You' : entry!.fullName.split(' ').first,
            style: TextStyle(
              color: isMe ? AppTheme.primaryBrand : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: rank == 1 ? 13 : 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${entry!.score}',
            style: TextStyle(
              color: rankColor,
              fontWeight: FontWeight.w900,
              fontSize: rank == 1 ? 18 : 15,
            ),
          ),
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

  static const _rankColors = {
    1: Color(0xFFFFD700),
    2: Color(0xFFC0C0C0),
    3: Color(0xFFCD7F32),
  };
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
        child: Center(
          child: Text(
            _rankLabels[rank]!,
            style: TextStyle(
              color: color.withValues(alpha: 0.6 * opacity),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Leaderboard row (rank 4+) ─────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final Color metricColor;
  final VoidCallback? onKick;
  final VoidCallback? onRename;

  const _LeaderboardRow({
    required this.entry,
    required this.metricColor,
    this.onKick,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: entry.isMe && onRename != null ? onRename : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: entry.isMe
              ? AppTheme.primaryBrand.withValues(alpha: 0.07)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: entry.isMe
                ? AppTheme.primaryBrand.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text('#${entry.rank}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry.isMe
                    ? AppTheme.primaryBrand.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
              ),
              child: Center(
                child: Text(
                  entry.fullName.isNotEmpty ? entry.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: entry.isMe ? AppTheme.primaryBrand : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(entry.fullName,
                        style: TextStyle(
                          color: entry.isMe ? AppTheme.primaryBrand : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (entry.isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBrand.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('You',
                          style: TextStyle(
                              color: AppTheme.primaryBrand,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (onRename != null) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.edit,
                          size: 12, color: AppTheme.primaryBrand.withValues(alpha: 0.5)),
                    ],
                  ],
                ],
              ),
            ),
            Text('${entry.score}',
                style: TextStyle(
                    color: metricColor, fontSize: 16, fontWeight: FontWeight.bold)),
            if (onKick != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onKick,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.1),
                  ),
                  child: const Icon(Icons.person_remove_outlined,
                      color: Colors.redAccent, size: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Manage Members section (creator only) ─────────────────────────────────────

class _ManageMembersSection extends ConsumerStatefulWidget {
  final List<LeaderboardEntry> entries;
  final String roomId;
  final void Function(LeaderboardEntry) onKick;

  const _ManageMembersSection({
    required this.entries,
    required this.roomId,
    required this.onKick,
  });

  @override
  ConsumerState<_ManageMembersSection> createState() => _ManageMembersSectionState();
}

class _ManageMembersSectionState extends ConsumerState<_ManageMembersSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final others = widget.entries.where((e) => !e.isMe).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // Header — tap to expand
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.manage_accounts_outlined,
                      color: Colors.white54, size: 20),
                  const SizedBox(width: 10),
                  const Text('Manage Members',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${others.length}',
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white38, size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Member list
          if (_expanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            ...others.map((entry) => _MemberRow(
                  entry: entry,
                  onKick: () => widget.onKick(entry),
                )),
          ],
        ],
      ),
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            child: Center(
              child: Text(
                widget.entry.fullName.isNotEmpty
                    ? widget.entry.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.entry.fullName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text('Rank #${widget.entry.rank} · ${widget.entry.score} pts',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loading ? null : () async {
              setState(() => _loading = true);
              widget.onKick();
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) setState(() => _loading = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.redAccent))
                  : const Text('Remove',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final RoomModel room;
  final Color metricColor;
  const _StatsRow({required this.room, required this.metricColor});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatPill(icon: _metricIcon(room.metric), label: room.metricLabel, color: metricColor),
        _StatPill(icon: Icons.refresh, label: room.periodLabel, color: Colors.white38),
        _StatPill(
          icon: Icons.people_outline,
          label: '${room.memberCount}/${room.maxMembers}',
          color: Colors.white38,
        ),
        if (!room.isPublic)
          _StatPill(icon: Icons.lock_outline, label: 'Private', color: Colors.orange),
        if (room.isExpired)
          _StatPill(icon: Icons.timer_off_outlined, label: 'Ended', color: Colors.red),
      ],
    );
  }

  IconData _metricIcon(String metric) {
    switch (metric) {
      case 'SESSIONS': return Icons.fitness_center;
      case 'STREAK':   return Icons.local_fire_department;
      default:         return Icons.bolt;
    }
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Bottom CTA ────────────────────────────────────────────────────────────────

class _BottomCTA extends ConsumerStatefulWidget {
  final RoomDetail detail;
  final String roomId;
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
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _join,
          icon: const Icon(Icons.emoji_events, size: 18),
          label: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Join Room',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBrand,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _leave,
        icon: const Icon(Icons.exit_to_app, size: 18),
        label: _loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
            : const Text('Leave Room',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white54,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _join() async {
    setState(() => _loading = true);
    try {
      await ref.read(myRoomsProvider.notifier).joinRoom(widget.roomId);
      await ref.read(roomDetailProvider(widget.roomId).notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red.withValues(alpha: 0.8)),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _leave() async {
    setState(() => _loading = true);
    try {
      await ref.read(myRoomsProvider.notifier).leaveRoom(widget.roomId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red.withValues(alpha: 0.8)),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  const _ErrorBody({required this.message, required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: PremiumStateCard(
          icon: Icons.error_rounded,
          title: 'Access Error',
          subtitle: message,
          onAction: onRetry,
          actionLabel: 'Retry',
        ),
      ),
    );
  }
}
