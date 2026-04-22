import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/storage_providers.dart';

class WaterTrackerState {
  final int consumedMl;
  final int goalMl;
  final DateTime date;

  const WaterTrackerState({
    required this.consumedMl,
    required this.goalMl,
    required this.date,
  });

  WaterTrackerState copyWith({int? consumedMl, int? goalMl, DateTime? date}) {
    return WaterTrackerState(
      consumedMl: consumedMl ?? this.consumedMl,
      goalMl: goalMl ?? this.goalMl,
      date: date ?? this.date,
    );
  }
}

class WaterTrackerNotifier extends StateNotifier<WaterTrackerState> {
  static const _keyConsumed = 'water_consumed_ml';
  static const _keyGoal = 'water_goal_ml';
  static const _keyDate = 'water_date';

  final SharedPreferences _prefs;

  WaterTrackerNotifier(this._prefs)
      : super(WaterTrackerState(
          consumedMl: 0,
          goalMl: 2500,
          date: DateTime.now(),
        )) {
    _load();
  }

  void _load() {
    final today = _dateKey(DateTime.now());
    final savedDate = _prefs.getString(_keyDate);

    // Reset daily count if it's a new day
    final consumed = savedDate == today ? (_prefs.getInt(_keyConsumed) ?? 0) : 0;
    final goal = _prefs.getInt(_keyGoal) ?? 2500;

    state = WaterTrackerState(
      consumedMl: consumed,
      goalMl: goal,
      date: DateTime.now(),
    );
  }

  Future<void> logMl(int ml) async {
    final today = _dateKey(DateTime.now());
    final newTotal = state.consumedMl + ml;
    state = state.copyWith(consumedMl: newTotal);
    await _prefs.setInt(_keyConsumed, newTotal);
    await _prefs.setString(_keyDate, today);
  }

  Future<void> setGoal(int goalMl) async {
    state = state.copyWith(goalMl: goalMl);
    await _prefs.setInt(_keyGoal, goalMl);
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}

final waterTrackerProvider =
    StateNotifierProvider<WaterTrackerNotifier, WaterTrackerState>((ref) {
  return WaterTrackerNotifier(ref.watch(sharedPreferencesProvider));
});
