import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../data/models/door_access_model.dart';
import '../providers/door_access_provider.dart';

class DoorAccessPage extends ConsumerWidget {
  const DoorAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(doorAccessProvider);
    final notifier = ref.read(doorAccessProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text('Door Access',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),

          // ── Check-in card ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _CheckInCard(state: state, notifier: notifier),
            ),
          ),

          // ── History section ────────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Text('Check-in History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),

          Consumer(
            builder: (ctx, ref, _) {
              final historyAsync = ref.watch(doorAccessHistoryProvider);
              return historyAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryBrand),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Could not load history: $e',
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                  ),
                ),
                data: (history) {
                  if (history.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        child: _EmptyHistory(),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _HistoryTile(entry: history[i])
                            .animate()
                            .fadeIn(delay: (40 * i).ms)
                            .slideY(begin: 0.08, end: 0),
                        childCount: history.length,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Check-in card ──────────────────────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  final DoorAccessState state;
  final DoorAccessNotifier notifier;
  const _CheckInCard({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Icon(
              _icon,
              key: ValueKey(state.runtimeType),
              size: 64,
              color: _iconColor,
            ),
          ).animate().scale(begin: const Offset(0.8, 0.8), duration: 400.ms),

          const SizedBox(height: 16),

          Text(_headline,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),

          const SizedBox(height: 6),
          Text(_subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
              textAlign: TextAlign.center),

          // Granted detail
          if (state is DoorAccessGranted) ...[
            const SizedBox(height: 20),
            _GrantedDetails(result: (state as DoorAccessGranted).result),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: notifier.reset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done'),
              ),
            ),
          ],

          // Check-in button
          if (state is DoorAccessIdle || state is DoorAccessDenied) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _triggerCheckIn(context),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Check In',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBrand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],

          if (state is DoorAccessLoading) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white70),
          ],
        ],
      ),
    );
  }

  void _triggerCheckIn(BuildContext context) {
    // In a real app, show a QR scanner and extract gymId from QR payload.
    // For now, we use a mock gym lookup from auth state.
    // TODO: integrate mobile_scanner package for QR reading.
    notifier.checkIn('default');
  }

  List<Color> get _gradientColors {
    if (state is DoorAccessGranted) {
      return [const Color(0xFF064E3B), const Color(0xFF065F46)];
    }
    if (state is DoorAccessDenied) {
      return [const Color(0xFF7F1D1D), const Color(0xFF991B1B)];
    }
    return [
      AppTheme.primaryBrand.withValues(alpha: 0.2),
      Colors.white.withValues(alpha: 0.04),
    ];
  }

  Color get _borderColor {
    if (state is DoorAccessGranted) {
      return Colors.greenAccent.withValues(alpha: 0.4);
    }
    if (state is DoorAccessDenied) {
      return Colors.redAccent.withValues(alpha: 0.4);
    }
    return AppTheme.primaryBrand.withValues(alpha: 0.3);
  }

  IconData get _icon {
    if (state is DoorAccessGranted) return Icons.check_circle_rounded;
    if (state is DoorAccessDenied) return Icons.cancel_rounded;
    if (state is DoorAccessLoading) return Icons.hourglass_top_rounded;
    return Icons.door_back_door_rounded;
  }

  Color get _iconColor {
    if (state is DoorAccessGranted) return Colors.greenAccent;
    if (state is DoorAccessDenied) return Colors.redAccent;
    return Colors.white54;
  }

  String get _headline {
    if (state is DoorAccessGranted) return 'Access Granted! 🎉';
    if (state is DoorAccessDenied) {
      return 'Access Denied';
    }
    if (state is DoorAccessLoading) return 'Verifying...';
    return 'Gym Door Access';
  }

  String get _subtitle {
    if (state is DoorAccessDenied) {
      return (state as DoorAccessDenied).message;
    }
    if (state is DoorAccessGranted) return 'Welcome in!';
    if (state is DoorAccessLoading) return 'Checking your membership...';
    return 'Scan the QR code at the gym entrance to check in.';
  }
}

// ── Granted details ────────────────────────────────────────────────────────────

class _GrantedDetails extends StatelessWidget {
  final dynamic result;
  const _GrantedDetails({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Column(
        children: [
          _Row(label: 'Member', value: result.memberName),
          const Divider(color: Colors.white12, height: 16),
          _Row(label: 'Plan', value: result.planName),
          const Divider(color: Colors.white12, height: 16),
          _Row(label: 'Days Left', value: '${result.daysRemaining} days'),
          const Divider(color: Colors.white12, height: 16),
          _Row(label: 'Expires', value: _formatDate(result.membershipEndsAt)),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── History tile ───────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final DoorAccessModel entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(entry.checkInTime);
    final time = dt != null
        ? '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : entry.checkInTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: entry.success
              ? Colors.greenAccent.withValues(alpha: 0.2)
              : Colors.redAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            entry.success
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            color: entry.success ? Colors.greenAccent : Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.gymName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(time,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
              ],
            ),
          ),
          Text(entry.success ? 'Granted' : 'Denied',
              style: TextStyle(
                  color: entry.success ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Empty history ──────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text('No check-ins yet.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}
