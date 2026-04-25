import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../../../../core/utils/app_notifications.dart';
import '../../data/models/session_model.dart';
import '../providers/sessions_provider.dart';

class SessionBookingSheet extends ConsumerStatefulWidget {
  final TrainingSessionModel session;

  const SessionBookingSheet({super.key, required this.session});

  @override
  ConsumerState<SessionBookingSheet> createState() => _SessionBookingSheetState();
}

class _SessionBookingSheetState extends ConsumerState<SessionBookingSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEE, MMM d');

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.radius32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Type chip + title
          Row(
            children: [
              _TypeChip(label: session.typeLabel, color: _typeColor(session.type)),
              if (session.isFull) ...[
                const SizedBox(width: 8),
                _TypeChip(label: 'Full', color: Colors.red.shade700),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (session.description != null && session.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              session.description!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14, height: 1.4),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),

          // Details grid
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label: dateFormat.format(session.startTime.toLocal()),
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.access_time_rounded,
            label: '${timeFormat.format(session.startTime.toLocal())} – ${timeFormat.format(session.endTime.toLocal())}',
          ),
          if (session.trainer != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.person_outline_rounded,
              label: session.trainer!.fullName,
            ),
          ],
          if (session.location != null && session.location!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: session.location!,
            ),
          ],
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.group_outlined,
            label: session.maxCapacity == null
                ? 'Open capacity'
                : '${session.confirmedCount} / ${session.maxCapacity} booked'
                    '${session.spotsLeft > 0 ? ' · ${session.spotsLeft} spot${session.spotsLeft == 1 ? '' : 's'} left' : ''}',
            valueColor: session.isFull
                ? Colors.red.shade400
                : session.spotsLeft <= 3
                    ? Colors.orange.shade400
                    : Colors.white70,
          ),

          const SizedBox(height: 28),

          // CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTokens.colorBrand),
                    ),
                  )
                : session.isBooked
                    ? OutlinedButton.icon(
                        onPressed: _cancelBooking,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel Booking'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          side: BorderSide(color: Colors.red.shade400.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: session.isFull ? null : _bookSession,
                        icon: const Icon(Icons.event_available_rounded, size: 18),
                        label: Text(session.isFull ? 'Session Full' : 'Book Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: session.isFull ? Colors.grey.shade800 : AppTokens.colorBrand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          disabledBackgroundColor: Colors.grey.shade800,
                        ),
                      ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _bookSession() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    final ok = await ref.read(sessionsProvider.notifier).bookSession(widget.session.id);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      AppNotifications.showSuccess(context, 'Session booked!');
      Navigator.of(context).pop();
    } else {
      final err = ref.read(sessionsProvider).actionError ?? 'Failed to book session';
      AppNotifications.showError(context, err);
    }
  }

  Future<void> _cancelBooking() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.colorBgSurface,
        title: const Text('Cancel Booking', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to cancel your booking for this session?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Booking', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    final ok = await ref.read(sessionsProvider.notifier).cancelBooking(widget.session.id);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      AppNotifications.showSuccess(context, 'Booking cancelled');
      Navigator.of(context).pop();
    } else {
      final err = ref.read(sessionsProvider).actionError ?? 'Failed to cancel';
      AppNotifications.showError(context, err);
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'GROUP_CLASS': return Colors.blue.shade600;
      case 'ONE_ON_ONE': return AppTokens.colorBrand;
      case 'WORKSHOP': return Colors.purple.shade500;
      default: return Colors.grey;
    }
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? valueColor;
  const _DetailRow({required this.icon, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: valueColor ?? Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
