import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_progress_provider.dart';
import 'storage_providers.dart';

const _kPointsKey = 'user_points_total';
const _kStreakKey = 'user_streak_days';
const _kLastActivityKey = 'user_last_activity_date';

/// Points awarded per action.
const kPointsPerMeal = 10;
const kPointsPerWorkout = 50;
const kPointsPerSet = 2;
const kPointsStreakBonus = 20; // Awarded when a daily streak continues.

class PointsState {
  final int totalPoints;
  final int streakDays;
  final int? lastAwardedPoints; // For transient "you earned X!" UI.

  const PointsState({
    this.totalPoints = 0,
    this.streakDays = 0,
    this.lastAwardedPoints,
  });

  PointsState copyWith({
    int? totalPoints,
    int? streakDays,
    int? lastAwardedPoints,
  }) =>
      PointsState(
        totalPoints: totalPoints ?? this.totalPoints,
        streakDays: streakDays ?? this.streakDays,
        lastAwardedPoints: lastAwardedPoints,
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

  /// Check if the streak should continue or reset, then update last-activity date.
  Future<int> _updateStreak() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final lastStr = prefs.getString(_kLastActivityKey);
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    int streak = state.streakDays;
    int bonus = 0;

    if (lastStr != null && lastStr != todayStr) {
      // Check if last activity was yesterday.
      final last = DateTime.tryParse(lastStr);
      if (last != null) {
        final diff = today.difference(last).inDays;
        if (diff == 1) {
          streak += 1;
          bonus = kPointsStreakBonus; // Streak continues!
        } else if (diff > 1) {
          streak = 1; // Streak broken, restart.
        }
      }
    } else if (lastStr == null) {
      streak = 1;
    }

    await prefs.setString(_kLastActivityKey, todayStr);
    state = state.copyWith(streakDays: streak);
    return bonus;
  }

  Future<void> awardMealLogged() async {
    final streakBonus = await _updateStreak();
    final earned = kPointsPerMeal + streakBonus;
    state = state.copyWith(
      totalPoints: state.totalPoints + earned,
      lastAwardedPoints: earned,
    );
    await _save();
    _ref.read(sessionProgressProvider.notifier).triggerCloudSync();
  }

  Future<void> awardWorkoutCompleted({required int setsLogged}) async {
    final streakBonus = await _updateStreak();
    final earned = kPointsPerWorkout + streakBonus;
    state = state.copyWith(
      totalPoints: state.totalPoints + earned,
      lastAwardedPoints: earned,
    );
    await _save();
    _ref.read(sessionProgressProvider.notifier).triggerCloudSync();
  }

  Future<void> awardSetCompleted() async {
    state = state.copyWith(
      totalPoints: state.totalPoints + kPointsPerSet,
      lastAwardedPoints: kPointsPerSet,
    );
    await _save();
    _ref.read(sessionProgressProvider.notifier).triggerCloudSync();
  }

  /// Clear the last-awarded transient badge.
  void clearLastAwarded() {
    state = state.copyWith(lastAwardedPoints: null);
  }

  /// Hydrate from Cloud sync
  void updateFromSync(int totalPoints, int streakDays) {
    // Only update if server has something newer/different
    // or if local is empty.
    if (totalPoints != state.totalPoints || streakDays != state.streakDays) {
      state = state.copyWith(
        totalPoints: totalPoints,
        streakDays: streakDays,
      );
      _save();
    }
  }
}

final pointsProvider =
    StateNotifierProvider<PointsNotifier, PointsState>((ref) {
  return PointsNotifier(ref);
});
