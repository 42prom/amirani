import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/design_system.dart';
import 'package:amirani_app/core/providers/session_progress_provider.dart';

/// Compact water tracker bar shown on the home dashboard.
/// Unified with the SessionProgress system for real-time cloud sync.
class WaterTrackerWidget extends ConsumerWidget {
  const WaterTrackerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProgressProvider);
    final hydration = session.hydration;
    
    // We display in ml. Logic: 1 cup = 250ml. 
    // targetCups defaults to 10 (2.5L) or 12 (3L).
    final goalMl = hydration.targetCups * 250;
    final consumedMl = hydration.completedCups * 250;
    
    final pct = (consumedMl / (goalMl > 0 ? goalMl : 1)).clamp(0.0, 1.0);
    final liters = (consumedMl / 1000).toStringAsFixed(1);
    final goal = (goalMl / 1000).toStringAsFixed(1);

    return GlassCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.water_drop,
                color: AppTokens.colorScoreHydration,
                size: 36,
                iconSize: 16,
              ),
              const SizedBox(width: AppTokens.space10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water Intake', style: AppTokens.textHeadingMd),
                    Text(
                      '$liters L / $goal L',
                      style: AppTokens.textBodyMd.copyWith(
                        color: AppTokens.colorScoreHydration,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: AppTokens.textHeadingMd.copyWith(
                  color: AppTokens.colorScoreHydration,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTokens.space12),

          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radius8),
            child: SizedBox(
              height: 8,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: AppTokens.animNormal,
                curve: Curves.easeOut,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor:
                        AppTokens.colorScoreHydration.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTokens.colorScoreHydration,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: AppTokens.space12),

          // Quick-log bubbles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ...[250, 500, 750].map(
                (ml) => _QuickLogBubble(
                  ml: ml,
                  onTap: () {
                    // Logic: ml to cups. 250ml = 1 cup.
                    final cups = (ml / 250).ceil();
                    ref.read(sessionProgressProvider.notifier).updateHydration(
                      hydration.completedCups + cups
                    );
                  },
                ),
              ),
              _QuickLogBubble(
                ml: null,
                label: 'Custom',
                onTap: () => _showCustomDialog(context, ref, hydration.completedCups),
              ),
            ],
          ),

          // Smart reminder hint
          if (pct < 0.5) ...[
            const SizedBox(height: AppTokens.space10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space10,
                vertical: AppTokens.space6,
              ),
              decoration: BoxDecoration(
                color: AppTokens.colorScoreHydration.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTokens.radius8),
                border: Border.all(
                  color: AppTokens.colorScoreHydration.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 12,
                      color:
                          AppTokens.colorScoreHydration.withValues(alpha: 0.8)),
                  const SizedBox(width: AppTokens.space6),
                  Text(
                    'Stay hydrated — you\'re under 50% of your daily goal',
                    style: AppTokens.textCaption.copyWith(
                      color:
                          AppTokens.colorScoreHydration.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCustomDialog(BuildContext context, WidgetRef ref, int currentCups) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.colorBgSurface,
        title: const Text('Log custom amount',
            style: TextStyle(color: AppTokens.colorTextPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: AppTokens.colorTextPrimary),
          decoration: InputDecoration(
            hintText: 'ml',
            hintStyle: const TextStyle(color: AppTokens.colorTextMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radius12),
              borderSide: const BorderSide(color: AppTokens.colorBorderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radius12),
              borderSide: const BorderSide(color: AppTokens.colorBrand),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTokens.colorTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              final ml = int.tryParse(controller.text.trim());
              if (ml != null && ml > 0) {
                final extraCups = (ml / 250).ceil();
                ref.read(sessionProgressProvider.notifier).updateHydration(
                  currentCups + extraCups
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add',
                style: TextStyle(color: AppTokens.colorBrand)),
          ),
        ],
      ),
    );
  }
}

class _QuickLogBubble extends StatelessWidget {
  const _QuickLogBubble({
    required this.onTap,
    this.ml,
    this.label,
  });

  final int? ml;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = ml != null ? '${ml}ml' : (label ?? '');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space8,
        ),
        decoration: BoxDecoration(
          color: AppTokens.colorScoreHydration.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          border: Border.all(
            color: AppTokens.colorScoreHydration.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppTokens.colorScoreHydration,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
