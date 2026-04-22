import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_db_service.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class DailySnapshot {
  final DateTime date;
  final int overallScore;  // 0–100, always saved
  final int? dietScore;    // null when member has no diet plan that day
  final int? workoutScore; // null when member has no workout plan that day
  final int? gymMinutes;   // null when member had no gym visit that day

  const DailySnapshot({
    required this.date,
    required this.overallScore,
    this.dietScore,
    this.workoutScore,
    this.gymMinutes,
  });

  String get storageKey => 'snap_${_fmt(date)}';

  Map<String, dynamic> toJson() => {
        'date': _fmt(date),
        'overall': overallScore,
        if (dietScore != null) 'diet': dietScore,
        if (workoutScore != null) 'workout': workoutScore,
        if (gymMinutes != null) 'gym': gymMinutes,
      };

  factory DailySnapshot.fromJson(Map<String, dynamic> json) => DailySnapshot(
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        overallScore: (json['overall'] as num?)?.toInt() ?? 0,
        dietScore: json['diet'] != null ? (json['diet'] as num?)?.toInt() : null,
        workoutScore: json['workout'] != null ? (json['workout'] as num?)?.toInt() : null,
        gymMinutes: json['gym'] != null ? (json['gym'] as num?)?.toInt() : null,
      );

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── Service ──────────────────────────────────────────────────────────────────

class DailySnapshotService {
  static const _prefix = 'snap_';
  static const _maxDays = 366;

  /// Save snapshot for today. Merges with any existing entry — takes max gym
  /// minutes and preserves non-null scores so multiple background saves during
  /// the same day always accumulate rather than overwrite.
  void save(DailySnapshot snapshot) {
    final box = LocalDBService.kvBox;
    final existing = _load(snapshot.date);
    final merged = DailySnapshot(
      date: snapshot.date,
      overallScore: snapshot.overallScore,
      dietScore: snapshot.dietScore ?? existing?.dietScore,
      workoutScore: snapshot.workoutScore ?? existing?.workoutScore,
      gymMinutes: _maxNullable(snapshot.gymMinutes, existing?.gymMinutes),
    );
    box.put(merged.storageKey, jsonEncode(merged.toJson()));
    _prune();
  }

  /// Record gym session duration without touching score fields.
  /// Safe to call when a QR session expires or the member manually checks out.
  void recordGymMinutes(DateTime date, int minutes) {
    if (minutes <= 0) return;
    final box = LocalDBService.kvBox;
    final existing = _load(date);
    final merged = DailySnapshot(
      date: date,
      overallScore: existing?.overallScore ?? 0,
      dietScore: existing?.dietScore,
      workoutScore: existing?.workoutScore,
      gymMinutes: _maxNullable(minutes, existing?.gymMinutes),
    );
    box.put(merged.storageKey, jsonEncode(merged.toJson()));
  }

  /// Load a single day's snapshot. Returns null if no data for that day.
  DailySnapshot? loadDay(DateTime date) => _load(date);

  /// Load all snapshots in [from]..[to] inclusive. Days with no data are skipped.
  List<DailySnapshot> loadRange(DateTime from, DateTime to) {
    final result = <DailySnapshot>[];
    var cursor = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!cursor.isAfter(end)) {
      final snap = _load(cursor);
      if (snap != null) result.add(snap);
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  DailySnapshot? _load(DateTime date) {
    final raw = LocalDBService.kvBox.get('snap_${DailySnapshot._fmt(date)}');
    if (raw == null) return null;
    try {
      return DailySnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  int? _maxNullable(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a > b ? a : b;
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(Duration(days: _maxDays));
    final cutoffKey = 'snap_${DailySnapshot._fmt(cutoff)}';
    final toDelete = LocalDBService.kvBox.keys
        .where((k) =>
            k.toString().startsWith(_prefix) &&
            k.toString().compareTo(cutoffKey) < 0)
        .toList();
    for (final k in toDelete) {
      LocalDBService.kvBox.delete(k);
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final dailySnapshotServiceProvider = Provider<DailySnapshotService>((ref) {
  return DailySnapshotService();
});

// ─── History period ───────────────────────────────────────────────────────────

enum HistoryPeriod { week, month, year }

/// Aggregated bar data for one time bucket (day, week-avg, or month-avg).
class SnapshotBar {
  final String label;      // 'Mon', 'W1', 'Jan', etc.
  final int overall;       // 0–100
  final int? diet;
  final int? workout;
  final int? gymMinutes;
  final bool hasAnyData;

  const SnapshotBar({
    required this.label,
    required this.overall,
    this.diet,
    this.workout,
    this.gymMinutes,
    required this.hasAnyData,
  });
}

class ScoreHistoryState {
  final HistoryPeriod period;
  final List<SnapshotBar> bars;
  final int totalGymMinutes;
  final int avgScore;
  final int bestScore;

  const ScoreHistoryState({
    this.period = HistoryPeriod.week,
    this.bars = const [],
    this.totalGymMinutes = 0,
    this.avgScore = 0,
    this.bestScore = 0,
  });

  ScoreHistoryState copyWith({
    HistoryPeriod? period,
    List<SnapshotBar>? bars,
    int? totalGymMinutes,
    int? avgScore,
    int? bestScore,
  }) =>
      ScoreHistoryState(
        period: period ?? this.period,
        bars: bars ?? this.bars,
        totalGymMinutes: totalGymMinutes ?? this.totalGymMinutes,
        avgScore: avgScore ?? this.avgScore,
        bestScore: bestScore ?? this.bestScore,
      );
}

class ScoreHistoryNotifier extends StateNotifier<ScoreHistoryState> {
  final DailySnapshotService _service;

  ScoreHistoryNotifier(this._service) : super(const ScoreHistoryState()) {
    load(HistoryPeriod.week);
  }

  void load(HistoryPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<SnapshotBar> bars;

    switch (period) {
      case HistoryPeriod.week:
        // Mon–Sun of the current week
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final snapshots = _service.loadRange(monday, today);
        final snapMap = {for (final s in snapshots) _fmt(s.date): s};
        const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        bars = List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          if (day.isAfter(today)) {
            return SnapshotBar(label: dayLabels[i], overall: 0, hasAnyData: false);
          }
          final snap = snapMap[_fmt(day)];
          return SnapshotBar(
            label: dayLabels[i],
            overall: snap?.overallScore ?? 0,
            diet: snap?.dietScore,
            workout: snap?.workoutScore,
            gymMinutes: snap?.gymMinutes,
            hasAnyData: snap != null,
          );
        });

      case HistoryPeriod.month:
        // Last 4 complete weeks as weekly averages
        bars = List.generate(4, (i) {
          final weekEnd = today.subtract(Duration(days: i * 7));
          final weekStart = weekEnd.subtract(const Duration(days: 6));
          final snaps = _service.loadRange(weekStart, weekEnd);
          final label = 'W${4 - i}';
          if (snaps.isEmpty) {
            return SnapshotBar(label: label, overall: 0, hasAnyData: false);
          }
          return SnapshotBar(
            label: label,
            overall: _avg(snaps.map((s) => s.overallScore).toList()),
            diet: _avgNullable(snaps.map((s) => s.dietScore).toList()),
            workout: _avgNullable(snaps.map((s) => s.workoutScore).toList()),
            gymMinutes: snaps.fold<int>(0, (sum, s) => sum + (s.gymMinutes ?? 0)),
            hasAnyData: true,
          );
        }).reversed.toList();

      case HistoryPeriod.year:
        // Jan–Dec monthly averages for current year
        const monthLabels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        bars = List.generate(12, (i) {
          final monthStart = DateTime(now.year, i + 1, 1);
          final monthEnd = DateTime(now.year, i + 2, 0); // last day of month
          if (monthStart.isAfter(today)) {
            return SnapshotBar(label: monthLabels[i], overall: 0, hasAnyData: false);
          }
          final snaps = _service.loadRange(monthStart, monthEnd.isAfter(today) ? today : monthEnd);
          if (snaps.isEmpty) {
            return SnapshotBar(label: monthLabels[i], overall: 0, hasAnyData: false);
          }
          return SnapshotBar(
            label: monthLabels[i],
            overall: _avg(snaps.map((s) => s.overallScore).toList()),
            diet: _avgNullable(snaps.map((s) => s.dietScore).toList()),
            workout: _avgNullable(snaps.map((s) => s.workoutScore).toList()),
            gymMinutes: snaps.fold<int>(0, (sum, s) => sum + (s.gymMinutes ?? 0)),
            hasAnyData: true,
          );
        });
    }

    final withData = bars.where((b) => b.hasAnyData).toList();
    final totalGym = bars.fold<int>(0, (sum, b) => sum + (b.gymMinutes ?? 0));
    final avgScore = withData.isEmpty ? 0 : _avg(withData.map((b) => b.overall).toList());
    final bestScore = withData.isEmpty ? 0 : withData.map((b) => b.overall).reduce((a, b) => a > b ? a : b);

    state = ScoreHistoryState(
      period: period,
      bars: bars,
      totalGymMinutes: totalGym,
      avgScore: avgScore,
      bestScore: bestScore,
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _avg(List<int> values) =>
      values.isEmpty ? 0 : (values.reduce((a, b) => a + b) / values.length).round();

  static int? _avgNullable(List<int?> values) {
    final nonNull = values.whereType<int>().toList();
    if (nonNull.isEmpty) return null;
    return _avg(nonNull);
  }
}

final scoreHistoryProvider =
    StateNotifierProvider<ScoreHistoryNotifier, ScoreHistoryState>((ref) {
  return ScoreHistoryNotifier(ref.watch(dailySnapshotServiceProvider));
});
