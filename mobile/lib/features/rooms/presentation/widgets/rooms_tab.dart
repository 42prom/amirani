import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/app_theme.dart';
import '../../data/models/room_model.dart';
import '../providers/room_provider.dart';
import '../pages/room_detail_page.dart';
import 'create_room_sheet.dart';
import 'join_by_code_sheet.dart';

class RoomsTab extends ConsumerStatefulWidget {
  const RoomsTab({super.key});

  @override
  ConsumerState<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends ConsumerState<RoomsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myRoomsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myRoomsProvider);

    return state.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBrand),
      ),
      error: (e, _) => _ErrorView(
        message: e.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.read(myRoomsProvider.notifier).load(),
      ),
      data: (data) => _RoomsContent(data: data),
    );
  }
}

class _RoomsContent extends ConsumerWidget {
  final MyRoomsData data;
  const _RoomsContent({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAny = data.myRooms.isNotEmpty ||
        data.gymRooms.isNotEmpty ||
        data.availableRooms.isNotEmpty;

    return RefreshIndicator(
      color: AppTheme.primaryBrand,
      backgroundColor: AppTheme.surfaceDark,
      onRefresh: () => ref.read(myRoomsProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add,
                  label: 'Create Room',
                  onTap: () => CreateRoomSheet.show(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.vpn_key_outlined,
                  label: 'Join by Code',
                  onTap: () => JoinByCodeSheet.show(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Gym Rooms (featured) ──────────────────────────────────────────
          if (data.gymRooms.isNotEmpty) ...[
            _GymRoomsHeader(),
            const SizedBox(height: 12),
            ...data.gymRooms.map((r) => _GymRoomCard(room: r)),
            const SizedBox(height: 24),
          ],

          // ── My Rooms ──────────────────────────────────────────────────────
          if (data.myRooms.isNotEmpty) ...[
            _SectionHeader(title: 'My Rooms', count: data.myRooms.length),
            const SizedBox(height: 12),
            ...data.myRooms.map((r) => _RoomCard(room: r, isMyRoom: true)),
            const SizedBox(height: 24),
          ],

          // ── Browse / Public ───────────────────────────────────────────────
          if (data.availableRooms.isNotEmpty) ...[
            _SectionHeader(title: 'Browse Rooms', count: data.availableRooms.length),
            const SizedBox(height: 12),
            ...data.availableRooms.map((r) => _RoomCard(room: r, isMyRoom: false)),
          ],

          if (!hasAny) _EmptyState(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Gym Rooms header ─────────────────────────────────────────────────────────

class _GymRoomsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryBrand, Color(0xFFB8860B)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, color: Colors.black, size: 13),
              SizedBox(width: 4),
              Text(
                'GYM OFFICIAL',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Gym Challenges',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Gym Room Card (featured style) ───────────────────────────────────────────

class _GymRoomCard extends ConsumerWidget {
  final RoomModel room;
  const _GymRoomCard({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricColor = _metricColor(room.metric);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomDetailPage(roomId: room.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBrand.withValues(alpha: 0.12),
              AppTheme.surfaceDark,
            ],
          ),
          border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: metricColor.withValues(alpha: 0.15),
                      border: Border.all(color: metricColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(_metricIcon(room.metric), color: metricColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _Chip(label: room.metricLabel, color: metricColor),
                            const SizedBox(width: 6),
                            _Chip(label: room.periodLabel, color: Colors.white38),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _JoinButton(roomId: room.id),
                ],
              ),
              if (room.description != null && room.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  room.description!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 14, color: AppTheme.primaryBrand.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    '${room.memberCount} / ${room.maxMembers} members',
                    style: TextStyle(color: AppTheme.primaryBrand.withValues(alpha: 0.7), fontSize: 12),
                  ),
                  const Spacer(),
                  Icon(Icons.verified, size: 13, color: AppTheme.primaryBrand.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    'Official Challenge',
                    style: TextStyle(color: AppTheme.primaryBrand.withValues(alpha: 0.6), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  IconData _metricIcon(String metric) {
    switch (metric) {
      case 'SESSIONS': return Icons.fitness_center;
      case 'STREAK':   return Icons.local_fire_department;
      default:         return Icons.bolt;
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryBrand, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryBrand.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: AppTheme.primaryBrand, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _RoomCard extends ConsumerWidget {
  final RoomModel room;
  final bool isMyRoom;
  const _RoomCard({required this.room, required this.isMyRoom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricColor = _metricColor(room.metric);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomDetailPage(roomId: room.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: metricColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(_metricIcon(room.metric), color: metricColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        _Chip(label: room.metricLabel, color: metricColor),
                        const SizedBox(width: 6),
                        _Chip(label: room.periodLabel, color: Colors.white38),
                      ]),
                    ],
                  ),
                ),
                if (!isMyRoom) _JoinButton(roomId: room.id),
              ],
            ),
            if (room.description != null && room.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                room.description!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people_outline, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text('${room.memberCount} / ${room.maxMembers}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                if (!room.isPublic)
                  Row(children: [
                    Icon(Icons.lock_outline, size: 13, color: Colors.orange.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text('Private', style: TextStyle(color: Colors.orange.withValues(alpha: 0.7), fontSize: 12)),
                  ])
                else
                  Row(children: [
                    Icon(Icons.public, size: 13, color: Colors.white38),
                    const SizedBox(width: 4),
                    const Text('Public', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ]),
              ],
            ),
          ],
        ),
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

  IconData _metricIcon(String metric) {
    switch (metric) {
      case 'SESSIONS': return Icons.fitness_center;
      case 'STREAK':   return Icons.local_fire_department;
      default:         return Icons.bolt;
    }
  }
}

class _JoinButton extends ConsumerStatefulWidget {
  final String roomId;
  const _JoinButton({required this.roomId});

  @override
  ConsumerState<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends ConsumerState<_JoinButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _join,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.primaryBrand.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.4)),
        ),
        child: _loading
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBrand),
              )
            : const Text('Join',
                style: TextStyle(
                    color: AppTheme.primaryBrand, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _join() async {
    setState(() => _loading = true);
    try {
      await ref.read(myRoomsProvider.notifier).joinRoom(widget.roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryBrand.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.emoji_events, color: AppTheme.primaryBrand, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('No rooms yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Create a room or join one\nto start competing with gym members',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.4)),
                ),
                child: const Text('Retry',
                    style: TextStyle(color: AppTheme.primaryBrand, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
