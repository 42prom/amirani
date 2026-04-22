import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_provider.dart';
import '../providers/storage_providers.dart';
import '../services/diet_plan_storage_service.dart';
import '../services/workout_plan_storage_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/diet/data/models/diet_plan_model.dart';
import '../../features/workout/data/models/workout_plan_model.dart';
import '../../features/workout/domain/entities/workout_plan_entity.dart';
import '../../features/profile/presentation/providers/profile_sync_provider.dart';
import '../data/local_db_service.dart';

// ── Sync Result ───────────────────────────────────────────────────────────────

/// Describes what changed during a syncDown call.
class SyncResult {
  final bool workoutPlanChanged;
  final bool dietPlanChanged;
  final bool profileChanged;
  final List<Map<String, dynamic>> dailyProgress;
  final Map<String, dynamic>? userData;

  const SyncResult({
    this.workoutPlanChanged = false,
    this.dietPlanChanged = false,
    this.profileChanged = false,
    this.dailyProgress = const [],
    this.userData,
  });

  bool get anyChanged =>
      workoutPlanChanged ||
      dietPlanChanged ||
      profileChanged ||
      dailyProgress.isNotEmpty;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Handles bidirectional synchronization between the mobile client and backend.
///
/// • [syncUp]   — pushes local changes (progress, sets, profile) to the cloud.
/// • [syncDown] — pulls remote changes into local storage; returns a
///                [SyncResult] describing what was updated so callers can decide
///                whether to refresh their providers.
class MobileSyncService {
  final Dio _dio;
  final Ref _ref;
  final DietPlanStorageService _dietStorage;
  final WorkoutPlanStorageService _workoutStorage;

  MobileSyncService(
      this._dio, this._ref, this._dietStorage, this._workoutStorage);

  // W11: Update lastSyncTimestamp on successful syncUp so the next push
  // doesn't re-upload already-synced progress records.
  Future<bool> syncUp({
    List<Map<String, dynamic>>? dailyProgress,
    List<Map<String, dynamic>>? completedSets,
    List<String>? deletedIds,
    Map<String, dynamic>? profileChanges,
  }) async {
    try {
      final lastSync = await _getLastSyncTimestamp() ??
          DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 1))
              .toIso8601String();

      final response = await _dio.post('/sync/up', data: {
        'lastSyncTimestamp': lastSync,
        'changes': {
          if (dailyProgress != null) 'dailyProgress': dailyProgress,
          if (completedSets != null) 'completedSets': completedSets,
          if (deletedIds != null) 'deletedIds': deletedIds,
          'profile': {
              if (profileChanges != null) ...profileChanges,
              'timezone': DateTime.now().timeZoneName,
          },
        }
      });

      if (response.statusCode == 200) {
        // W11: Update timestamp on success so next push is incremental
        await _updateLastSyncTimestamp(DateTime.now().toUtc().toIso8601String());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Sync] syncUp error: $e');
      return false;
    }
  }

  // ── syncDown ───────────────────────────────────────────────────────────────

  /// Pulls remote changes and hydrates local storage.
  Future<SyncResult> syncDown() async {
    try {
      final lastSyncStr = await _getLastSyncTimestamp();
      final response = await _dio.get('/sync/down', queryParameters: {
        if (lastSyncStr != null) 'since': lastSyncStr,
      });

      if (response.statusCode != 200) return const SyncResult();

      final data = response.data['changes'] as Map<String, dynamic>;
      final serverTimestamp = response.data['serverTimestamp']?.toString() ?? '';

      final userId = _ref.read(currentUserProvider)?.id ?? '';

      bool workoutChanged = false;
      bool dietChanged = false;
      bool profileChanged = false;

      // 1. Workout plans
      final rawWorkout = data['workoutPlans'] as List?;
      if (rawWorkout != null && rawWorkout.isNotEmpty) {
        final activePlanMap = rawWorkout
            .cast<Map<String, dynamic>>()
            .where((p) => p['isActive'] == true && p['deletedAt'] == null)
            .firstOrNull;

        // Handle deletion if the active plan was soft-deleted on server
        if (activePlanMap == null && rawWorkout.any((p) => p['deletedAt'] != null)) {
           await _workoutStorage.deletePlan();
           workoutChanged = true;
        } else if (activePlanMap != null) {
          workoutChanged =
              await _handleIncomingWorkoutPlan(activePlanMap, userId);
        }
      }

      // 2. Diet plans
      final rawDiet = data['dietPlans'] as List?;
      if (rawDiet != null && rawDiet.isNotEmpty) {
        final activeDietMap = rawDiet
            .cast<Map<String, dynamic>>()
            .where((p) => p['isActive'] == true && p['deletedAt'] == null)
            .firstOrNull;

        // Handle deletion if the active plan was soft-deleted on server
        if (activeDietMap == null && rawDiet.any((p) => p['deletedAt'] != null)) {
           await _dietStorage.deletePlan();
           dietChanged = true;
        } else if (activeDietMap != null) {
          dietChanged = await _handleIncomingDietPlan(activeDietMap, userId);
        }
      }

      // 3. Profile
      if (data['user'] != null) {
        _ref
            .read(profileSyncProvider.notifier)
            .updateFromSync(data['user'] as Map<String, dynamic>);
        profileChanged = true;
      }

      // 4. Daily Progress
      final rawProgress = (data['dailyProgress'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      await _updateLastSyncTimestamp(serverTimestamp);

      debugPrint(
          '[Sync] syncDown complete — workout:$workoutChanged diet:$dietChanged profile:$profileChanged progress:${rawProgress.length}');

      return SyncResult(
        workoutPlanChanged: workoutChanged,
        dietPlanChanged: dietChanged,
        profileChanged: profileChanged,
        dailyProgress: rawProgress,
        userData: data['user'] as Map<String, dynamic>?,
      );
    } catch (e) {
      if (e is DioException) {
        debugPrint('[Sync] syncDown error body: ${e.response?.data}');
      }
      debugPrint('[Sync] syncDown error: $e');
      return const SyncResult();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  // W9+W10: Trainer plan pending ID — prevents the Accept dialog from
  // appearing on every app open until the user explicitly accepts or declines.
  // The plan JSON is also cached so the dialog renders without a network call.
  static const String _pendingTrainerWorkoutKey  = 'pending_trainer_workout_plan_id';
  static const String _pendingTrainerDietKey     = 'pending_trainer_diet_plan_id';
  static const String _pendingTrainerWorkoutJson = 'pending_trainer_workout_plan_json';
  static const String _pendingTrainerDietJson    = 'pending_trainer_diet_plan_json';

  Future<bool> _handleIncomingWorkoutPlan(
      Map<String, dynamic> planMap, String userId) async {
    try {
      final model = WorkoutPlanModel.fromJson(planMap);
      final entity = model.toEntity();

      final localPlan = await _workoutStorage.loadPlan();
      // Already on this plan
      if (localPlan != null && localPlan.id == entity.id) return false;

      if (entity.isAIGenerated) {
        // Auto-accept AI plans
        final monthly = entity.toMonthlyEntity(userId);
        final saved = await _workoutStorage.savePlan(monthly);
        if (saved) debugPrint('[Sync] Auto-saved new AI workout plan: ${entity.id}');
        return saved;
      }

      // W9: Trainer plan — check if we've already notified to avoid harassment loop
      final prefs = _ref.read(sharedPreferencesProvider);
      final pendingId = prefs.getString(_pendingTrainerWorkoutKey);
      if (pendingId == entity.id) return false; // Already pending, dialog shown

      // W9: Mark as pending (dialog shown once per assignment)
      await prefs.setString(_pendingTrainerWorkoutKey, entity.id);
      // W10: Cache plan JSON so dialog renders offline without extra network call
      await LocalDBService.kvBox.put(
        _pendingTrainerWorkoutJson,
        jsonEncode(planMap),
      );
      debugPrint('[Sync] Trainer workout plan pending: ${entity.id}');
      return true; // Signal UI to show Accept dialog
    } catch (e) {
      debugPrint('[Sync] Workout plan parse/save error: $e');
      return false;
    }
  }

  Future<bool> _handleIncomingDietPlan(
      Map<String, dynamic> planMap, String userId) async {
    try {
      final model = DietPlanModel.fromJson(planMap);
      final entity = model.toEntity();

      final localPlan = await _dietStorage.loadPlan();
      // Already on this plan
      if (localPlan != null && localPlan.id == entity.id) return false;

      if (entity.isAIGenerated) {
        // Auto-accept AI plans
        final monthly = entity.toMonthlyEntity(userId);
        final saved = await _dietStorage.savePlan(monthly);
        if (saved) debugPrint('[Sync] Auto-saved new AI diet plan: ${entity.id}');
        return saved;
      }

      // W9: Trainer plan — check if we've already notified
      final prefs = _ref.read(sharedPreferencesProvider);
      final pendingId = prefs.getString(_pendingTrainerDietKey);
      if (pendingId == entity.id) return false; // Already pending, dialog shown

      // W9: Mark as pending
      await prefs.setString(_pendingTrainerDietKey, entity.id);
      // W10: Cache plan JSON for offline dialog rendering
      await LocalDBService.kvBox.put(
        _pendingTrainerDietJson,
        jsonEncode(planMap),
      );
      debugPrint('[Sync] Trainer diet plan pending: ${entity.id}');
      return true;
    } catch (e) {
      debugPrint('[Sync] Diet plan parse/save error: $e');
      return false;
    }
  }

  /// Call this after the user accepts a trainer workout plan.
  /// Returns true on successful save. On failure, pending state is NOT cleared
  /// so the UI can show a retry option instead of silently losing the plan.
  Future<bool> acceptTrainerWorkoutPlan(String userId) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final jsonStr = LocalDBService.kvBox.get(_pendingTrainerWorkoutJson);
    if (jsonStr == null) return false;
    try {
      final planMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entity = WorkoutPlanModel.fromJson(planMap).toEntity();
      await _workoutStorage.savePlan(entity.toMonthlyEntity(userId));
      // Only clear pending state after a confirmed save — preserves retry on failure.
      await prefs.remove(_pendingTrainerWorkoutKey);
      await LocalDBService.kvBox.delete(_pendingTrainerWorkoutJson);
      return true;
    } catch (e) {
      debugPrint('[Sync] Error accepting trainer workout plan: $e');
      return false;
    }
  }

  /// Call this when the user declines a trainer workout plan.
  /// Removes the cached JSON (prevents Hive storage leak) but keeps the
  /// pending ID in SharedPreferences so the dialog never re-appears for
  /// this same plan assignment.
  Future<void> declineTrainerWorkoutPlan() async {
    await LocalDBService.kvBox.delete(_pendingTrainerWorkoutJson);
    debugPrint('[Sync] Trainer workout plan declined \u2014 JSON cleared, pending ID retained');
  }

  /// Call this after the user accepts a trainer diet plan.
  /// Returns true on successful save. On failure, pending state is NOT cleared
  /// so the UI can show a retry option instead of silently losing the plan.
  Future<bool> acceptTrainerDietPlan(String userId) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final jsonStr = LocalDBService.kvBox.get(_pendingTrainerDietJson);
    if (jsonStr == null) return false;
    try {
      final planMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entity = DietPlanModel.fromJson(planMap).toEntity();
      await _dietStorage.savePlan(entity.toMonthlyEntity(userId));
      // Only clear pending state after a confirmed save — preserves retry on failure.
      await prefs.remove(_pendingTrainerDietKey);
      await LocalDBService.kvBox.delete(_pendingTrainerDietJson);
      return true;
    } catch (e) {
      debugPrint('[Sync] Error accepting trainer diet plan: $e');
      return false;
    }
  }

  /// Call this when the user declines a trainer diet plan.
  /// Removes the cached JSON (prevents Hive storage leak) but keeps the
  /// pending ID in SharedPreferences so the dialog never re-appears for
  /// this same plan assignment.
  Future<void> declineTrainerDietPlan() async {
    await LocalDBService.kvBox.delete(_pendingTrainerDietJson);
    debugPrint('[Sync] Trainer diet plan declined \u2014 JSON cleared, pending ID retained');
  }

  /// Retrieves cached trainer plan JSON for offline dialog rendering (W10).
  /// Returns null if no pending trainer plan exists.
  Future<Map<String, dynamic>?> getPendingTrainerWorkoutPlanJson() async {
    final jsonStr = LocalDBService.kvBox.get(_pendingTrainerWorkoutJson);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getPendingTrainerDietPlanJson() async {
    final jsonStr = LocalDBService.kvBox.get(_pendingTrainerDietJson);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>?;
  }

  Future<String?> _getLastSyncTimestamp() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    return prefs.getString('mobile_last_sync_timestamp');
  }

  Future<void> _updateLastSyncTimestamp(String timestamp) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString('mobile_last_sync_timestamp', timestamp);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final mobileSyncServiceProvider = Provider<MobileSyncService>((ref) {
  final dietStorage = ref.watch(dietPlanStorageProvider);
  final workoutStorage = ref.watch(workoutPlanStorageProvider);
  return MobileSyncService(
      ref.watch(dioProvider), ref, dietStorage, workoutStorage);
});
