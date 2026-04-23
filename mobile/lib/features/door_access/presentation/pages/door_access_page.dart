import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../design_system/design_system.dart';
import '../../data/models/door_access_model.dart';
import '../providers/door_access_provider.dart';

class DoorAccessPage extends ConsumerWidget {
  const DoorAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(doorAccessProvider);
    final notifier = ref.read(doorAccessProvider.notifier);

    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: AppTokens.colorBgPrimary,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Door Access',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTokens.colorTextPrimary,
                ),
              ),
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
              child: Text(
                'Check-in History',
                style: TextStyle(
                  color: AppTokens.colorTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                        strokeWidth: 2, color: AppTokens.colorBrand),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Could not load history: $e',
                        style: const TextStyle(
                            color: AppTokens.colorError, fontSize: 13)),
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

          Text(
            _headline,
            style: const TextStyle(
                color: AppTokens.colorTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),
          Text(
            _subtitle,
            style: TextStyle(
                color: AppTokens.colorTextPrimary.withValues(alpha: 0.55),
                fontSize: 13),
            textAlign: TextAlign.center,
          ),

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
                  foregroundColor: AppTokens.colorTextSecondary,
                  side: const BorderSide(color: AppTokens.colorBorderMedium),
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
                  backgroundColor: AppTokens.colorBrand,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],

          if (state is DoorAccessLoading) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTokens.colorTextSecondary),
          ],
        ],
      ),
    );
  }

  void _triggerCheckIn(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QRScannerView(
        onScan: (gymId, token) {
          Navigator.pop(ctx);
          notifier.checkInQr(gymId, token);
        },
      ),
    );
  }

  List<Color> get _gradientColors {
    if (state is DoorAccessGranted) {
      return [
        AppTokens.colorSuccess.withValues(alpha: 0.25),
        AppTokens.colorSuccess.withValues(alpha: 0.12),
      ];
    }
    if (state is DoorAccessDenied) {
      return [
        AppTokens.colorError.withValues(alpha: 0.3),
        AppTokens.colorError.withValues(alpha: 0.15),
      ];
    }
    return [
      AppTokens.colorBrand.withValues(alpha: 0.2),
      AppTokens.colorBgSurface.withValues(alpha: 0.6),
    ];
  }

  Color get _borderColor {
    if (state is DoorAccessGranted) {
      return AppTokens.colorSuccess.withValues(alpha: 0.4);
    }
    if (state is DoorAccessDenied) {
      return AppTokens.colorError.withValues(alpha: 0.4);
    }
    return AppTokens.colorBrand.withValues(alpha: 0.3);
  }

  IconData get _icon {
    if (state is DoorAccessGranted) return Icons.check_circle_rounded;
    if (state is DoorAccessDenied) return Icons.cancel_rounded;
    if (state is DoorAccessLoading) return Icons.hourglass_top_rounded;
    return Icons.door_back_door_rounded;
  }

  Color get _iconColor {
    if (state is DoorAccessGranted) return AppTokens.colorSuccess;
    if (state is DoorAccessDenied) return AppTokens.colorError;
    return AppTokens.colorTextSecondary;
  }

  String get _headline {
    if (state is DoorAccessGranted) return 'Access Granted!';
    if (state is DoorAccessDenied) return 'Access Denied';
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
        color: AppTokens.colorBorderSubtle,
      ),
      child: Column(
        children: [
          _Row(label: 'Member', value: result.memberName),
          const Divider(color: AppTokens.colorBorderSubtle, height: 16),
          _Row(label: 'Plan', value: result.planName),
          const Divider(color: AppTokens.colorBorderSubtle, height: 16),
          _Row(label: 'Days Left', value: '${result.daysRemaining} days'),
          const Divider(color: AppTokens.colorBorderSubtle, height: 16),
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
            style: const TextStyle(
                color: AppTokens.colorTextSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppTokens.colorTextPrimary,
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

    final statusColor =
        entry.success ? AppTokens.colorSuccess : AppTokens.colorError;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTokens.colorBorderSubtle,
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            entry.success
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.gymName,
                    style: const TextStyle(
                        color: AppTokens.colorTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(
                        color: AppTokens.colorTextMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(
            entry.success ? 'Granted' : 'Denied',
            style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
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
              size: 48,
              color: AppTokens.colorTextPrimary.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          const Text('No check-ins yet.',
              style: TextStyle(
                  color: AppTokens.colorTextMuted, fontSize: 14)),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

// ── QR Scanner View ───────────────────────────────────────────────────────────

class _QRScannerView extends StatefulWidget {
  final Function(String gymId, String token) onScan;
  const _QRScannerView({required this.onScan});

  @override
  State<_QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<_QRScannerView> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTokens.colorBgPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTokens.colorBorderMedium,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scan Gym QR',
            style: TextStyle(
                color: AppTokens.colorTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Point your camera at the entrance QR code',
            style: TextStyle(
                color: AppTokens.colorTextSecondary, fontSize: 13),
          ),
          const Spacer(),

          // Scanner area
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTokens.colorBrand, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      if (_isScanned) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final rawValue = barcode.rawValue;
                        if (rawValue != null) {
                          _handleScan(rawValue);
                        }
                      }
                    },
                  ),
                  // Scanning animation
                  const _ScannerOverlay(),
                ],
              ),
            ),
          ),

          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTokens.colorTextPrimary,
                  side: const BorderSide(color: AppTokens.colorBorderMedium),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleScan(String raw) {
    try {
      // QR payload is base64url-encoded JSON — decode to extract gymId
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(raw)));
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      final gymId = data['gymId'] as String?;
      if (gymId != null && gymId.isNotEmpty) {
        setState(() => _isScanned = true);
        widget.onScan(gymId, raw);
      }
    } catch (_) {
      // Invalid format
    }
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
      ),
      child: Center(
        child: Container(
          width: 200,
          height: 2,
          color: AppTokens.colorBrand,
        )
            .animate(onPlay: (controller) => controller.repeat())
            .moveY(begin: -80, end: 80, duration: 2000.ms, curve: Curves.easeInOut)
            .fadeIn(duration: 300.ms)
            .then()
            .fadeOut(delay: 1400.ms),
      ),
    );
  }
}
