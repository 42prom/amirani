import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mobile_sync_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/workout/presentation/providers/workout_provider.dart';
import '../../features/workout/data/datasources/workout_history_remote_data_source.dart';
import '../../features/diet/presentation/providers/diet_provider.dart';
import '../services/workout_plan_storage_service.dart';
import '../services/diet_plan_storage_service.dart';
import '../providers/session_progress_provider.dart';
import '../services/daily_snapshot_service.dart';
import '../../features/gym/presentation/providers/gym_access_provider.dart';

/// Observes the app lifecycle and drives background sync automatically.
///
/// Tiered refresh strategy:
/// • **Full refresh** (≥ 15 min since last sync) — re-fetches active plans
///   directly from their dedicated network endpoints via the notifiers.
///   Guarantees the member always sees up-to-date trainer content.
///
/// • **Delta sync** (3 – 15 min) — calls [MobileSyncService.syncDown] which
///   queries the `/sync/down?since=` endpoint and only processes records that
///   changed since the last sync. If a brand-new plan was assigned, the local
///   Hive/SharedPreferences store is updated and the notifiers are refreshed.
///
/// • **Idle** (< 3 min) — no network call; local Hive data serves the UI.
///
/// On [AppLifecycleState.paused] any pending local progress is flushed to the
/// cloud via [MobileSyncService.syncUp].
class AppLifecycleSyncService with WidgetsBindingObserver {
  final Ref _ref;

  DateTime? _lastSyncAt;

  static const _fullRefreshThreshold = Duration(minutes: 15);
  static const _deltaThreshold = Duration(minutes: 3);

  AppLifecycleSyncService(this._ref);

  // ── Lifecycle management ──────────────────────────────────────────────────

  void register() => WidgetsBinding.instance.addObserver(this);

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  // ── WidgetsBindingObserver ────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onForeground();
        break;
      case AppLifecycleState.paused:
        _onBackground();
        break;
      default:
        break;
    }
  }

  // ── Foreground ────────────────────────────────────────────────────────────

  void _onForeground() {
    if (!_isAuthenticated) return;

    // Flush any workout sessions that failed to sync while offline.
    _ref.read(workoutHistoryDataSourceProvider).flushPendingSessions();

    final now = DateTime.now();
    final elapsed =
        _lastSyncAt == null ? null : now.difference(_lastSyncAt!);

    if (elapsed == null || elapsed >= _fullRefreshThreshold) {
      // ── Full refresh from network ────────────────────────────────────────
      _lastSyncAt = now;
      _ref.read(workoutNotifierProvider.notifier).fetchActivePlan();
      _ref.read(dietNotifierProvider.notifier).fetchActivePlan();
    } else if (elapsed >= _deltaThreshold) {
      // ── Delta sync only ──────────────────────────────────────────────────
      _lastSyncAt = now;
      _runDeltaSync();
    }
    // else: < 3 min — local cache is fresh enough, do nothing
  }

  Future<void> _runDeltaSync() async {
    final result =
        await _ref.read(mobileSyncServiceProvider).syncDown();

    if (result.workoutPlanChanged) {
      // Invalidate storage caches so FutureProviders re-read from Hive.
      _ref.invalidate(savedWorkoutPlanProvider);
      _ref.invalidate(hasWorkoutPlanProvider);
      // Also drive the notifier so it can detect a trainer-assigned plan and
      // surface the "New Plan Assigned" acceptance dialog.
      _ref.read(workoutNotifierProvider.notifier).fetchActivePlan();
    }

    if (result.dietPlanChanged) {
      _ref.invalidate(savedDietPlanProvider);
      _ref.invalidate(hasSavedPlanProvider);
      // Same: let the notifier detect trainer plans and show the dialog.
      _ref.read(dietNotifierProvider.notifier).fetchActivePlan();
    }
  }

  // ── Background ────────────────────────────────────────────────────────────

  void _onBackground() {
    if (!_isAuthenticated) return;
    
    // ── PROACTIVE FLUSH ─────────────────────────────────────────────────────
    // Instead of waiting for the debouncer, we flush current progress now.
    final session = _ref.read(sessionProgressProvider);
    // No pointsProvider needed here for basic sync

    final payload = {
      'date': session.date.toIso8601String(),
      'caloriesConsumed': session.consumedCalories,
      'proteinConsumed': session.consumedProtein,
      'carbsConsumed': session.consumedCarbs,
      'fatsConsumed': session.consumedFats,
      'waterConsumed': session.hydration.completedCups,
      'activeMinutes': session.activityMinutes,
      'tasksTotal': session.totalTasks,
      'tasksCompleted': session.completedTasks,
      'score': session.dailyScore,
    };

    _ref.read(mobileSyncServiceProvider).syncUp(
      dailyProgress: [payload],
    );

    _saveSnapshot();
  }

  void _saveSnapshot() {
    final session = _ref.read(sessionProgressProvider);
    final gymState = _ref.read(gymAccessProvider);

    int? gymMinutes;
    if (gymState is GymAccessAdmitted && gymState.checkIn.isActive) {
      final minutes = DateTime.now().difference(gymState.checkIn.admittedAt).inMinutes;
      if (minutes > 0) gymMinutes = minutes;
    }

    final snapshot = DailySnapshot(
      date: DateTime.now(),
      overallScore: session.dailyScore,
      dietScore: session.isDietPlanActive && session.totalMeals > 0
          ? (session.dietProgress * 100).round().clamp(0, 100)
          : null,
      workoutScore: session.isWorkoutPlanActive && session.totalExercises > 0
          ? (session.workoutProgress * 100).round().clamp(0, 100)
          : null,
      gymMinutes: gymMinutes,
    );

    _ref.read(dailySnapshotServiceProvider).save(snapshot);
  }

  // ── Initial sync on login ─────────────────────────────────────────────────

  /// Call this immediately after the user authenticates so the first session
  /// is always populated with the latest trainer-assigned plans.
  void onAuthenticated() {
    _lastSyncAt = null; // Force full refresh on next foreground / explicit call
    _onForeground();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isAuthenticated =>
      _ref.read(authNotifierProvider) is AuthAuthenticated;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final appLifecycleSyncProvider =
    Provider<AppLifecycleSyncService>((ref) => AppLifecycleSyncService(ref));
