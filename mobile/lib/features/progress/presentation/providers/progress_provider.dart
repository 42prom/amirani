import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/utils/error_messages.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

class WeightLog {
  final DateTime date;
  final double weightKg;
  const WeightLog({required this.date, required this.weightKg});
}

class HabitScorePoint {
  final DateTime date;
  final double workout;
  final double diet;
  final double hydration;
  final double sleep;
  const HabitScorePoint({
    required this.date,
    required this.workout,
    required this.diet,
    required this.hydration,
    required this.sleep,
  });
}

class TodayMacros {
  final int calories;
  final int targetCalories;
  final int proteinG;
  final int targetProtein;
  final int carbsG;
  final int targetCarbs;
  final int fatG;
  final int targetFat;

  const TodayMacros({
    required this.calories,
    this.targetCalories = 2000,
    required this.proteinG,
    this.targetProtein = 150,
    required this.carbsG,
    this.targetCarbs = 200,
    required this.fatG,
    this.targetFat = 65,
  });

  static const empty = TodayMacros(
    calories: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
  );
}

class MeasurementEntry {
  final String label;
  final double value;
  final String unit;
  const MeasurementEntry(
      {required this.label, required this.value, required this.unit});
}

// ─── State ───────────────────────────────────────────────────────────────────

class ProgressState {
  final bool isLoading;
  final String? error;

  // Body tab
  final List<WeightLog> weightLogs;
  final TodayMacros todayMacros;
  final List<MeasurementEntry> measurements;

  // Activity tab
  final List<double> caloriesBurned;
  final int workoutsThisWeek;
  final int activeMinutesThisWeek;
  final int caloriesBurnedThisWeek;

  // Habits tab
  final double workoutScore;
  final double dietScore;
  final double hydrationScore;
  final double sleepScore;
  final List<HabitScorePoint> habitTimeline;

  const ProgressState({
    this.isLoading = false,
    this.error,
    this.weightLogs = const [],
    this.todayMacros = TodayMacros.empty,
    this.measurements = const [],
    this.caloriesBurned = const [],
    this.workoutsThisWeek = 0,
    this.activeMinutesThisWeek = 0,
    this.caloriesBurnedThisWeek = 0,
    this.workoutScore = 0,
    this.dietScore = 0,
    this.hydrationScore = 0,
    this.sleepScore = 0,
    this.habitTimeline = const [],
  });

  ProgressState copyWith({
    bool? isLoading,
    String? error,
    List<WeightLog>? weightLogs,
    TodayMacros? todayMacros,
    List<MeasurementEntry>? measurements,
    List<double>? caloriesBurned,
    int? workoutsThisWeek,
    int? activeMinutesThisWeek,
    int? caloriesBurnedThisWeek,
    double? workoutScore,
    double? dietScore,
    double? hydrationScore,
    double? sleepScore,
    List<HabitScorePoint>? habitTimeline,
  }) {
    return ProgressState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      weightLogs: weightLogs ?? this.weightLogs,
      todayMacros: todayMacros ?? this.todayMacros,
      measurements: measurements ?? this.measurements,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      workoutsThisWeek: workoutsThisWeek ?? this.workoutsThisWeek,
      activeMinutesThisWeek:
          activeMinutesThisWeek ?? this.activeMinutesThisWeek,
      caloriesBurnedThisWeek:
          caloriesBurnedThisWeek ?? this.caloriesBurnedThisWeek,
      workoutScore: workoutScore ?? this.workoutScore,
      dietScore: dietScore ?? this.dietScore,
      hydrationScore: hydrationScore ?? this.hydrationScore,
      sleepScore: sleepScore ?? this.sleepScore,
      habitTimeline: habitTimeline ?? this.habitTimeline,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ProgressNotifier extends StateNotifier<ProgressState> {
  final Ref _ref;
  ProgressNotifier(this._ref) : super(const ProgressState());

  Future<void> load({int days = 30}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get('/sync/progress', queryParameters: {'days': days});

      final responseData = res.data;
      if (responseData == null || responseData['data'] == null) {
        state = state.copyWith(isLoading: false, error: 'No data received from server');
        return;
      }

      final data = responseData['data'] as Map<String, dynamic>;

      // ── Body ──────────────────────────────────────────────────────────────
      final body = (data['body'] as Map<String, dynamic>?) ?? {};
      final weightLogsJson = (body['weightLogs'] as List?) ?? [];
      final weightLogs = weightLogsJson.map((w) {
        final m = w as Map<String, dynamic>;
        return WeightLog(
          date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          weightKg: (m['weightKg'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      final currentWeight = (body['currentWeightKg'] as num?)?.toDouble();
      final heightCm = (body['heightCm'] as num?)?.toDouble();

      final measurements = <MeasurementEntry>[];
      if (currentWeight != null && currentWeight > 0) {
        measurements.add(MeasurementEntry(label: 'Weight', value: currentWeight, unit: 'kg'));
      }
      if (heightCm != null && heightCm > 0) {
        measurements.add(MeasurementEntry(label: 'Height', value: heightCm, unit: 'cm'));
      }
      if (currentWeight != null && heightCm != null && currentWeight > 0 && heightCm > 0) {
        final heightM = heightCm / 100;
        final bmi = currentWeight / (heightM * heightM);
        measurements.add(MeasurementEntry(
          label: 'BMI',
          value: double.parse(bmi.toStringAsFixed(1)),
          unit: '',
        ));
      }

      // ── Today's macros ────────────────────────────────────────────────────
      final today = (data['today'] as Map<String, dynamic>?) ?? {};
      final todayMacros = TodayMacros(
        calories: (today['caloriesConsumed'] as num?)?.toInt() ?? 0,
        targetCalories: (today['targetCalories'] as num?)?.toInt() ?? 2000,
        proteinG: (today['proteinConsumed'] as num?)?.toInt() ?? 0,
        targetProtein: (today['targetProtein'] as num?)?.toInt() ?? 150,
        carbsG: (today['carbsConsumed'] as num?)?.toInt() ?? 0,
        targetCarbs: (today['targetCarbs'] as num?)?.toInt() ?? 200,
        fatG: (today['fatsConsumed'] as num?)?.toInt() ?? 0,
        targetFat: (today['targetFats'] as num?)?.toInt() ?? 65,
      );

      // ── Activity ──────────────────────────────────────────────────────────
      final activity = (data['activity'] as Map<String, dynamic>?) ?? {};
      final caloriesBurnedRaw = (activity['caloriesBurnedLast7Days'] as List?) ?? [];
      final caloriesBurned =
          caloriesBurnedRaw.map((v) => (v as num?)?.toDouble() ?? 0.0).toList();

      // ── Habits ────────────────────────────────────────────────────────────
      final habits = (data['habits'] as Map<String, dynamic>?) ?? {};
      final timelineJson = (habits['timeline'] as List?) ?? [];
      final habitTimeline = timelineJson.map((t) {
        final m = t as Map<String, dynamic>;
        return HabitScorePoint(
          date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          workout: (m['workout'] as num?)?.toDouble() ?? 0,
          diet: (m['diet'] as num?)?.toDouble() ?? 0,
          hydration: (m['hydration'] as num?)?.toDouble() ?? 0,
          sleep: (m['sleep'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      state = state.copyWith(
        isLoading: false,
        weightLogs: weightLogs,
        todayMacros: todayMacros,
        measurements: measurements,
        caloriesBurned: caloriesBurned,
        workoutsThisWeek: (activity['workoutsThisWeek'] as num?)?.toInt() ?? 0,
        activeMinutesThisWeek: (activity['activeMinutesThisWeek'] as num?)?.toInt() ?? 0,
        caloriesBurnedThisWeek: (activity['caloriesBurnedThisWeek'] as num?)?.toInt() ?? 0,
        workoutScore: (habits['workoutScore'] as num?)?.toDouble() ?? 0,
        dietScore: (habits['dietScore'] as num?)?.toDouble() ?? 0,
        hydrationScore: (habits['hydrationScore'] as num?)?.toDouble() ?? 0,
        sleepScore: (habits['sleepScore'] as num?)?.toDouble() ?? 0,
        habitTimeline: habitTimeline,
      );
    } catch (e, st) {
      debugPrint('[ProgressProvider] load error: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        error: ErrorMessages.from(e, fallback: 'Could not load your progress. Pull down to retry.'),
      );
    }
  }

  void reset() => state = const ProgressState();
}

final progressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier(ref);
});
