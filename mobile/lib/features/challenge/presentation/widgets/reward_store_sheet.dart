import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import 'package:amirani_app/design_system/components/glass_card.dart';
import '../providers/reward_provider.dart';
import '../../data/models/reward_model.dart';

class RewardStoreSheet extends ConsumerStatefulWidget {
  const RewardStoreSheet._();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (_) => const RewardStoreSheet._(),
      );

  @override
  ConsumerState<RewardStoreSheet> createState() => _RewardStoreSheetState();
}

class _RewardStoreSheetState extends ConsumerState<RewardStoreSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(rewardStoreProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(rewardStoreProvider);

    ref.listen(rewardStoreProvider.select((s) => s.successMessage), (_, msg) {
      if (msg == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTokens.colorSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius12)),
        ),
      );
      ref.read(rewardStoreProvider.notifier).clearMessages();
    });

    ref.listen(rewardStoreProvider.select((s) => s.error), (prev, err) {
      if (err == null || prev == err || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppTokens.colorError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius12)),
        ),
      );
      ref.read(rewardStoreProvider.notifier).clearMessages();
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.92],
      builder: (ctx, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: AppTokens.colorBgSurface,
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTokens.space20, AppTokens.space4, AppTokens.space20, AppTokens.space12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reward Store',
                            style: AppTokens.textDisplayMd,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Spend your points on gym perks',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Points balance badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTokens.colorBrandDim,
                        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                        border: Border.all(color: AppTokens.colorBrandBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, color: AppTokens.colorBrand, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${store.totalPoints} pts',
                            style: const TextStyle(
                              color: AppTokens.colorBrand,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tab bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTokens.space20, 0, AppTokens.space20, AppTokens.space12),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTokens.colorBgPrimary.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppTokens.radius12),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      color: AppTokens.colorBrandDim,
                      borderRadius: BorderRadius.circular(AppTokens.radius10),
                      border: Border.all(color: AppTokens.colorBrandBorder),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AppTokens.colorBrand,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    tabs: const [Tab(text: 'Rewards'), Tab(text: 'History')],
                  ),
                ),
              ),
              // Body — switches without TabBarView to share the sheet's scrollController
              Expanded(
                child: _tabs.index == 0
                    ? _RewardsBody(store: store, scrollCtrl: scrollCtrl)
                    : _HistoryBody(scrollCtrl: scrollCtrl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rewards Body ──────────────────────────────────────────────────────────────

class _RewardsBody extends ConsumerWidget {
  final RewardStoreState store;
  final ScrollController scrollCtrl;

  const _RewardsBody({required this.store, required this.scrollCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (store.isLoading && store.rewards.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTokens.colorBrand,
          strokeWidth: 2.5,
        ),
      );
    }

    if (!store.isLoading && store.rewards.isEmpty) {
      return _EmptyState(
        icon: Icons.storefront_outlined,
        message: store.error ?? 'No rewards available yet',
        onRetry: store.error != null
            ? () => ref.read(rewardStoreProvider.notifier).load()
            : null,
      );
    }

    return GridView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
          AppTokens.space16, AppTokens.space4, AppTokens.space16, AppTokens.space32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.76,
      ),
      itemCount: store.rewards.length,
      itemBuilder: (ctx, i) {
        final reward = store.rewards[i];
        return _RewardCard(
          reward: reward,
          userPoints: store.totalPoints,
          isRedeeming: store.redeemingId == reward.id,
          anyRedeeming: store.redeemingId != null,
          onRedeem: () => ref.read(rewardStoreProvider.notifier).redeem(reward.id),
        );
      },
    );
  }
}

class _RewardCard extends StatelessWidget {
  final RewardModel reward;
  final int userPoints;
  final bool isRedeeming;
  final bool anyRedeeming;
  final VoidCallback onRedeem;

  const _RewardCard({
    required this.reward,
    required this.userPoints,
    required this.isRedeeming,
    required this.anyRedeeming,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = userPoints >= reward.pointsCost;
    final outOfStock = reward.stock != null && reward.stock! <= 0;
    final enabled = canAfford && !outOfStock && !anyRedeeming;

    return GlassCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      borderRadius: BorderRadius.circular(AppTokens.radius20),
      borderColor: canAfford && !outOfStock
          ? AppTokens.colorBrandBorder
          : AppTokens.colorBorderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cost badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: canAfford ? AppTokens.colorBrandDim : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTokens.radius8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt,
                  size: 11,
                  color: canAfford ? AppTokens.colorBrand : AppTokens.colorTextMuted,
                ),
                const SizedBox(width: 3),
                Text(
                  '${reward.pointsCost}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: canAfford ? AppTokens.colorBrand : AppTokens.colorTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space10),
          // Name
          Text(
            reward.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (reward.description != null && reward.description!.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space4),
            Text(
              reward.description!,
              style: const TextStyle(
                color: AppTokens.colorTextMuted,
                fontSize: 10,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (reward.stock != null) ...[
            const SizedBox(height: AppTokens.space6),
            Text(
              outOfStock ? 'Out of stock' : '${reward.stock} left',
              style: TextStyle(
                color: outOfStock ? AppTokens.colorError : AppTokens.colorTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          // Redeem button
          SizedBox(
            width: double.infinity,
            height: 34,
            child: TextButton(
              onPressed: enabled ? onRedeem : null,
              style: TextButton.styleFrom(
                backgroundColor: enabled
                    ? AppTokens.colorBrandDim
                    : Colors.white.withValues(alpha: 0.04),
                foregroundColor: enabled ? AppTokens.colorBrand : Colors.white24,
                disabledForegroundColor: Colors.white24,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius10),
                  side: BorderSide(
                    color: enabled ? AppTokens.colorBrandBorder : Colors.transparent,
                  ),
                ),
                padding: EdgeInsets.zero,
              ),
              child: isRedeeming
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTokens.colorBrand,
                      ),
                    )
                  : Text(
                      outOfStock
                          ? 'Sold Out'
                          : canAfford
                              ? 'Redeem'
                              : 'Need ${reward.pointsCost - userPoints} more',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History Body ──────────────────────────────────────────────────────────────

class _HistoryBody extends ConsumerWidget {
  final ScrollController scrollCtrl;

  const _HistoryBody({required this.scrollCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(redemptionHistoryProvider);

    return history.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTokens.colorBrand, strokeWidth: 2.5),
      ),
      error: (_, __) => _EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'Could not load history',
        onRetry: () => ref.invalidate(redemptionHistoryProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'No redemptions yet',
          );
        }
        return ListView.separated(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(
              AppTokens.space16, AppTokens.space4, AppTokens.space16, AppTokens.space32),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space8),
          itemBuilder: (ctx, i) => _HistoryItem(item: items[i]),
        );
      },
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final RedemptionModel item;

  const _HistoryItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      'FULFILLED' => AppTokens.colorSuccess,
      'CANCELLED' => AppTokens.colorError,
      _ => AppTokens.colorBrand,
    };

    return GlassCardCompact(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTokens.radius10),
            ),
            child: Icon(Icons.card_giftcard, color: statusColor, size: 20),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.rewardName ?? 'Reward',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(item.redeemedAt),
                  style: const TextStyle(color: AppTokens.colorTextMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${item.pointsSpent} pts',
                style: const TextStyle(
                  color: AppTokens.colorBrand,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radius8),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Shared Empty State ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const _EmptyState({required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Colors.white12),
          const SizedBox(height: AppTokens.space12),
          Text(message, style: const TextStyle(color: AppTokens.colorTextMuted, fontSize: 14)),
          if (onRetry != null) ...[
            const SizedBox(height: AppTokens.space16),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppTokens.colorBrand),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
