import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/data/local_db_service.dart';
import '../../presentation/providers/active_workout_session_provider.dart';

// ─── Response Model ───────────────────────────────────────────────────────────

class WorkoutSyncResult {
  final String historyId;
  final int setsLogged;

  const WorkoutSyncResult({required this.historyId, required this.setsLogged});

  factory WorkoutSyncResult.fromJson(Map<String, dynamic> json) {
    return WorkoutSyncResult(
      historyId: json['historyId']?.toString() ?? '',
      setsLogged: json['setsLogged'] as int? ?? 0,
    );
  }
}

// ─── Data Source ──────────────────────────────────────────────────────────────

class WorkoutHistoryRemoteDataSource {
  final Dio _dio;

  WorkoutHistoryRemoteDataSource(this._dio);

  static const String _pendingKeyPrefix = 'pending_ws_';

  Map<String, dynamic> _buildBody(ActiveWorkoutSessionState session) {
    final endTime = session.completedAt ?? DateTime.now();
    final durationSeconds = endTime.difference(session.startedAt).inSeconds;
    final durationMinutes = (durationSeconds / 60).ceil().clamp(1, 600);
    return {
      if (session.routineId.isNotEmpty) 'routineId': session.routineId,
      'durationMinutes': durationMinutes,
      'exercises': session.exercises
          .where((ex) => ex.loggedSets.isNotEmpty)
          .map((ex) => {
                'exerciseName': ex.entity.exerciseName,
                'sets': ex.loggedSets
                    .map((s) => {
                          'weightKg': s.weightKg,
                          'reps': s.reps,
                          if (s.rpe != null) 'rpe': s.rpe,
                        })
                    .toList(),
              })
          .toList(),
    };
  }

  /// Save a completed workout session to the backend.
  Future<WorkoutSyncResult> saveSession(
    ActiveWorkoutSessionState session,
  ) async {
    final response =
        await _dio.post('/sync/workout-session', data: _buildBody(session));
    final data = response.data['data'] as Map<String, dynamic>;
    return WorkoutSyncResult.fromJson(data);
  }

  /// Persist a failed session to local storage for retry.
  void queueSession(ActiveWorkoutSessionState session) {
    final key = '$_pendingKeyPrefix${DateTime.now().millisecondsSinceEpoch}';
    LocalDBService.kvBox.put(key, jsonEncode(_buildBody(session)));
  }

  /// Retry all queued sessions; remove each one on success.
  Future<void> flushPendingSessions() async {
    final box = LocalDBService.kvBox;
    final pendingKeys = box.keys
        .where((k) => k.toString().startsWith(_pendingKeyPrefix))
        .toList();
    for (final key in pendingKeys) {
      try {
        final json = box.get(key);
        if (json == null) continue;
        await _dio.post('/sync/workout-session',
            data: jsonDecode(json) as Map<String, dynamic>);
        await box.delete(key);
      } catch (_) {
        // Keep in queue for next flush attempt
      }
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final workoutHistoryDataSourceProvider =
    Provider<WorkoutHistoryRemoteDataSource>((ref) {
  return WorkoutHistoryRemoteDataSource(ref.watch(dioProvider));
});
