import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_provider.dart';
import 'storage_providers.dart';

const _kPointsKey = 'user_points_total';
const _kStreakKey = 'user_streak_days';

class PointsState {
  final int totalPoints;
  final int streakDays;
  // Kept for UI compatibility — always null after P0-1 (backend is authoritative).
  final int? lastAwardedPoints;

  const PointsState({
    this.totalPoints = 0,
    this.streakDays = 0,
    this.lastAwardedPoints,
  });

  PointsState copyWith({
    int? totalPoints,
    int? streakDays,
  }) =>
      PointsState(
        totalPoints: totalPoints ?? this.totalPoints,
        streakDays: streakDays ?? this.streakDays,
      );

  String get levelLabel {
    if (totalPoints < 100) return 'Beginner';
    if (totalPoints < 500) return 'Active';
    if (totalPoints < 1500) return 'Dedicated';
    if (totalPoints < 4000) return 'Athlete';
    return 'Champion';
  }
}

class PointsNotifier extends StateNotifier<PointsState> {
  final Ref _ref;

  PointsNotifier(this._ref) : super(const PointsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final points = prefs.getInt(_kPointsKey) ?? 0;
    final streak = prefs.getInt(_kStreakKey) ?? 0;
    state = state.copyWith(totalPoints: points, streakDays: streak);
  }

  Future<void> _save() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kPointsKey, state.totalPoints);
    await prefs.setInt(_kStreakKey, state.streakDays);
  }

  /// Sync the authoritative balance from the backend gamification profile.
  /// Fire-and-forget — callers should not await unless they need the result.
  Future<void> syncFromBackend() async {
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get('/gamification/profile');
      final data = res.data['data'] as Map<String, dynamic>;
      updateFromSync(
        (data['totalPoints'] as num).toInt(),
        (data['streakDays'] as num).toInt(),
      );
    } catch (_) {
      // Keep cached value on network failure.
    }
  }

  /// Hydrate from cloud sync response — also called by syncFromBackend.
  void updateFromSync(int totalPoints, int streakDays) {
    if (totalPoints != state.totalPoints || streakDays != state.streakDays) {
      state = state.copyWith(totalPoints: totalPoints, streakDays: streakDays);
      _save();
    }
  }
}

final pointsProvider =
    StateNotifierProvider<PointsNotifier, PointsState>((ref) {
  return PointsNotifier(ref);
});
