import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../../data/models/room_model.dart';
import '../providers/room_provider.dart';

class RoomsListPage extends ConsumerStatefulWidget {
  const RoomsListPage({super.key});

  @override
  ConsumerState<RoomsListPage> createState() => _RoomsListPageState();
}

class _RoomsListPageState extends ConsumerState<RoomsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myRoomsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(myRoomsProvider);
    final notifier   = ref.read(myRoomsProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
            title: const Text('Challenge Rooms',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_rounded, color: Colors.white70),
                tooltip: 'Join by code',
                onPressed: () => _showJoinByCodeSheet(context, notifier),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: Colors.white70),
                tooltip: 'Create room',
                onPressed: () => _showCreateRoomSheet(context, notifier),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: AppTheme.primaryBrand,
              labelColor: AppTheme.primaryBrand,
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(text: 'My Rooms'),
                Tab(text: 'Gym'),
                Tab(text: 'Discover'),
              ],
            ),
          ),
        ],
        body: roomsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBrand),
          ),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => notifier.load(),
          ),
          data: (data) => TabBarView(
            controller: _tabs,
            children: [
              _RoomGrid(rooms: data.myRooms,        isJoined: true,  notifier: notifier),
              _RoomGrid(rooms: data.gymRooms,       isJoined: false, notifier: notifier),
              _RoomGrid(rooms: data.availableRooms, isJoined: false, notifier: notifier),
            ],
          ),
        ),
      ),
    );
  }

  // ── Join by code bottom sheet ───────────────────────────────────────────────

  void _showJoinByCodeSheet(BuildContext context, MyRoomsNotifier notifier) {
    _codeController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white24,
            )),
            const SizedBox(height: 20),
            const Text('Join by Invite Code',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, letterSpacing: 6, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'ABC123',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), letterSpacing: 6),
                counterText: '',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryBrand.withValues(alpha: 0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBrand),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBrand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final code = _codeController.text.trim();
                  if (code.length != 6) return;
                  Navigator.pop(context);
                  try {
                    final roomId = await notifier.joinByCode(code);
                    if (context.mounted) context.push('/rooms/$roomId');
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not join: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Create room bottom sheet ────────────────────────────────────────────────

  void _showCreateRoomSheet(BuildContext context, MyRoomsNotifier notifier) {
    final nameCtrl = TextEditingController();
    String metric = 'CHECKINS';
    String period  = 'WEEKLY';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2), color: Colors.white24))),
                const SizedBox(height: 20),
                const Text('Create Room',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Room name',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryBrand)),
                  ),
                ),
                const SizedBox(height: 14),
                _SegmentRow(
                  label: 'Compete by',
                  options: const {'CHECKINS': 'Check-ins', 'SESSIONS': 'Sessions', 'STREAK': 'Streak'},
                  selected: metric,
                  onSelected: (v) => setModal(() => metric = v),
                ),
                const SizedBox(height: 12),
                _SegmentRow(
                  label: 'Period',
                  options: const {'WEEKLY': 'Weekly', 'MONTHLY': 'Monthly', 'ONGOING': 'Ongoing'},
                  selected: period,
                  onSelected: (v) => setModal(() => period = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      await notifier.createRoom(
                        name: nameCtrl.text.trim(),
                        metric: metric,
                        period: period,
                      );
                    },
                    child: const Text('Create Room', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Room Grid ──────────────────────────────────────────────────────────────────

class _RoomGrid extends StatelessWidget {
  final List<RoomModel> rooms;
  final bool isJoined;
  final MyRoomsNotifier notifier;
  const _RoomGrid({required this.rooms, required this.isJoined, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.groups_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(isJoined ? 'You haven\'t joined any rooms yet.' : 'No rooms available.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
        ]),
      ).animate().fadeIn(duration: 500.ms);
    }

    return RefreshIndicator(
      color: AppTheme.primaryBrand,
      onRefresh: () => notifier.load(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemCount: rooms.length,
        itemBuilder: (ctx, i) => _RoomCard(
          room: rooms[i],
          isJoined: isJoined,
          onTap: () => ctx.push('/rooms/${rooms[i].id}'),
          onJoin: isJoined ? null : () => notifier.joinRoom(rooms[i].id),
        ).animate().fadeIn(delay: (60 * i).ms).slideY(begin: 0.08, end: 0),
      ),
    );
  }
}

// ── Room Card ──────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final bool isJoined;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  const _RoomCard({required this.room, required this.isJoined, this.onTap, this.onJoin});

  Color get _metricColor {
    switch (room.metric) {
      case 'SESSIONS': return const Color(0xFF7C3AED);
      case 'STREAK':   return const Color(0xFFEF4444);
      default:         return AppTheme.primaryBrand;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: _metricColor.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _metricColor.withValues(alpha: 0.15),
                  ),
                  child: Text(room.metricLabel,
                      style: TextStyle(color: _metricColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (isJoined)
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
              ],
            ),
            const Spacer(),
            Text(room.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${room.memberCount}/${room.maxMembers} members',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
            const SizedBox(height: 4),
            Text(room.periodLabel,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
            if (!isJoined && onJoin != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: FilledButton(
                  onPressed: onJoin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBrand,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Join', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SegmentRow extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String selected;
  final void Function(String) onSelected;
  const _SegmentRow({required this.label, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: options.entries.map((e) => Expanded(
            child: GestureDetector(
              onTap: () => onSelected(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: selected == e.key
                      ? AppTheme.primaryBrand.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                      color: selected == e.key ? AppTheme.primaryBrand : Colors.transparent),
                ),
                child: Text(e.value,
                    style: TextStyle(
                        color: selected == e.key ? AppTheme.primaryBrand : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: AppTheme.primaryBrand))),
    ]),
  );
}
