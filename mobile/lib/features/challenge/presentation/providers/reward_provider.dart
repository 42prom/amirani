import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/datasources/gamification_data_source.dart';
import '../../data/models/reward_model.dart';

final gamificationDataSourceProvider = Provider<GamificationDataSource>((ref) {
  return GamificationDataSourceImpl(ref.watch(dioProvider));
});

// ── Store State ───────────────────────────────────────────────────────────────

class RewardStoreState {
  final bool isLoading;
  final String? error;
  final int totalPoints;
  final List<RewardModel> rewards;
  final String? redeemingId;
  final String? successMessage;

  const RewardStoreState({
    this.isLoading = false,
    this.error,
    this.totalPoints = 0,
    this.rewards = const [],
    this.redeemingId,
    this.successMessage,
  });

  RewardStoreState copyWith({
    bool? isLoading,
    String? error,
    int? totalPoints,
    List<RewardModel>? rewards,
    String? redeemingId,
    String? successMessage,
    bool clearRedeeming = false,
    bool clearSuccess = false,
    bool clearError = false,
  }) =>
      RewardStoreState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        totalPoints: totalPoints ?? this.totalPoints,
        rewards: rewards ?? this.rewards,
        redeemingId: clearRedeeming ? null : (redeemingId ?? this.redeemingId),
        successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      );
}

class RewardStoreNotifier extends StateNotifier<RewardStoreState> {
  final GamificationDataSource _ds;
  RewardStoreNotifier(this._ds) : super(const RewardStoreState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _ds.getRewards();
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        totalPoints: result.totalPoints,
        rewards: result.rewards,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load rewards. Pull to retry.',
      );
    }
  }

  Future<void> redeem(String rewardId) async {
    if (state.redeemingId != null) return;
    state = state.copyWith(redeemingId: rewardId, clearSuccess: true, clearError: true);
    try {
      final redemption = await _ds.redeemReward(rewardId);
      if (!mounted) return;
      final reward = state.rewards.where((r) => r.id == rewardId).firstOrNull;
      state = state.copyWith(
        clearRedeeming: true,
        totalPoints: state.totalPoints - (reward?.pointsCost ?? 0),
        successMessage: 'Redeemed: ${redemption.rewardName ?? 'Reward'}!',
        rewards: state.rewards
            .map((r) =>
                r.id != rewardId || r.stock == null ? r : r.copyWith(stock: r.stock! - 1))
            .toList(),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      state = state.copyWith(
        clearRedeeming: true,
        error: msg.contains('Insufficient') || msg.contains('points')
            ? 'Not enough points'
            : 'Redemption failed. Try again.',
      );
    }
  }

  void clearMessages() => state = state.copyWith(clearSuccess: true, clearError: true);
}

final rewardStoreProvider =
    StateNotifierProvider.autoDispose<RewardStoreNotifier, RewardStoreState>((ref) {
  return RewardStoreNotifier(ref.watch(gamificationDataSourceProvider));
});

// ── Redemption History ────────────────────────────────────────────────────────

final redemptionHistoryProvider =
    FutureProvider.autoDispose<List<RedemptionModel>>((ref) {
  return ref.watch(gamificationDataSourceProvider).getRedemptionHistory();
});
