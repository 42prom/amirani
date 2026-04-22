import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../../core/services/workout_plan_storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';
import '../../domain/usecases/workout_usecases.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/workout_remote_data_source.dart';
import '../../data/repositories/workout_repository_impl.dart';
import 'active_workout_session_provider.dart';

abstract class WorkoutState {}

class WorkoutInitial extends WorkoutState {}

class WorkoutLoading extends WorkoutState {}

class WorkoutLoaded extends WorkoutState {
  final WorkoutPlanEntity plan;
  WorkoutLoaded(this.plan);
}

class WorkoutEmpty extends WorkoutState {}

/// User tapped "Later" on the new-trainer-plan dialog.
class WorkoutDismissed extends WorkoutState {}

class WorkoutError extends WorkoutState {
  final String message;
  /// True when the user can tap "Try Again" to re-trigger generation.
  final bool canRetry;
  WorkoutError(this.message, {this.canRetry = false});
}

/// AI workout generation job enqueued — polling in progress.
class WorkoutGenerating extends WorkoutState {
  final String jobId;
  WorkoutGenerating(this.jobId);
}

/// A trainer has assigned a new plan not yet acknowledged by the member.
class WorkoutNewTrainerPlan extends WorkoutState {
  final WorkoutPlanEntity plan;
  final MonthlyWorkoutPlanEntity monthly;
  WorkoutNewTrainerPlan(this.plan, this.monthly);
}

class WorkoutNotifier extends StateNotifier<WorkoutState> {
  final GetActiveWorkoutUseCase _getActiveWorkoutUseCase;
  final GenerateAIWorkoutUseCase _generateAIWorkoutUseCase;
  final GetWorkoutJobStatusUseCase _getJobStatusUseCase;
  final WorkoutPlanStorageService _storage;
  final String? _userId;
  final Ref _ref;

  Timer? _pollTimer;

  WorkoutNotifier(
    this._getActiveWorkoutUseCase,
    this._generateAIWorkoutUseCase,
    this._getJobStatusUseCase,
    this._storage,
    this._userId,
    this._ref,
  ) : super(WorkoutInitial());

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchActivePlan() async {
    // CX-3: Resume polling if a job was in-flight when the app was last closed.
    // But first verify the job is still actually running — if it completed or
    // failed while the app was closed, clear the stale jobId immediately.
    final pendingJobId = await _storage.loadJobId();
    if (!mounted) return;
    if (pendingJobId != null) {
      final statusResult = await _getJobStatusUseCase(GetWorkoutJobStatusParams(pendingJobId));
      if (!mounted) return;
      final stillPending = statusResult.fold(
        (_) => true, // network error — assume still pending, will poll
        (statusMap) {
          final status = statusMap['status'] as String? ?? '';
          return status != 'COMPLETED' && status != 'FAILED';
        },
      );
      if (stillPending) {
        state = WorkoutGenerating(pendingJobId);
        _startPolling(pendingJobId);
        return;
      }
      // Job finished while app was closed — clear stale id and load the plan normally.
      await _storage.clearJobId();
    }

    // Offline-first: keep plan visible while fetching.
    final cached = await _storage.loadPlan();
    if (!mounted) return;
    if (cached == null) {
      state = WorkoutLoading();
    }

    final result = await _getActiveWorkoutUseCase(NoParams());
    if (!mounted) return;

    await result.fold(
      (failure) async {
        if (!mounted) return;
        if (cached != null) return; // Silently keep cached plan offline.
        // New user with no cache: show empty state so the "Generate Plan" CTA
        // is visible rather than a raw error message.
        state = WorkoutEmpty();
      },
      (plan) async {
        if (!mounted) return;
        if (plan == null) {
          if (cached == null) state = WorkoutEmpty();
          return;
        }

        final monthly = plan.toMonthlyEntity(_userId ?? plan.id);
        final existing = await _storage.loadPlan();
        if (!mounted) return;

        if (!plan.isAIGenerated && plan.isActive) {
          if (existing == null || existing.id != monthly.id) {
            state = WorkoutNewTrainerPlan(plan, monthly);
            return;
          }
          // ID is same, but content might have changed (structural update)
          await _savePlan(monthly);
        } else if (plan.isAIGenerated) {
          // Also overwrite if the cached plan has no exercises (stale/corrupt cache).
          final cachedHasNoExercises = existing != null &&
              existing.weeks.every((w) => w.days.every((d) => d.isRestDay || d.exercises.isEmpty));
          if (existing == null || existing.id != monthly.id || cachedHasNoExercises) {
            await _savePlan(monthly);
            if (!mounted) return;
          }
        }

        if (state is! WorkoutNewTrainerPlan) {
          state = WorkoutLoaded(plan);
        }
      },
    );
  }

  /// Called when the member accepts a newly assigned trainer plan.
  Future<void> acceptNewPlan(
      WorkoutPlanEntity plan, MonthlyWorkoutPlanEntity monthly) async {
    await _savePlan(monthly);
    state = WorkoutLoaded(plan);
  }

  /// Called when the member dismisses the new trainer plan prompt.
  void dismissNewPlan() {
    state = WorkoutDismissed();
  }

  /// Enqueues an AI workout plan generation job and begins polling.
  Future<void> generatePlan(String goals, String level, {int daysPerWeek = 4, List<String>? targetMuscles}) async {
    state = WorkoutLoading();
    final result = await _generateAIWorkoutUseCase(
        GenerateAIWorkoutParams(
          goals: goals, 
          level: level, 
          daysPerWeek: daysPerWeek,
          targetMuscles: targetMuscles,
        ));

    await result.fold(
      (failure) async => state = WorkoutError(failure.message, canRetry: true),
      (jobId) async {
        await _storage.saveJobId(jobId);
        state = WorkoutGenerating(jobId);
        _startPolling(jobId);
      },
    );
  }

  void _startPolling(String jobId) {
    _pollTimer?.cancel();
    int pollCount = 0;
    const maxPolls = 75; // 75 × 4s = 5 min max before surfacing timeout error
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) { _pollTimer?.cancel(); return; }
      if (pollCount++ >= maxPolls) {
        _pollTimer?.cancel();
        await _storage.clearJobId();
        state = WorkoutError('Plan generation is taking too long. Please try again.', canRetry: true);
        return;
      }
      final result =
          await _getJobStatusUseCase(GetWorkoutJobStatusParams(jobId));
      if (!mounted) { _pollTimer?.cancel(); return; }
      await result.fold(
        (_) async {/* keep polling on transient errors */},
        (statusMap) async {
          final status = statusMap['status'] as String? ?? '';
          if (status == 'COMPLETED') {
            _pollTimer?.cancel();
            await _storage.clearJobId();
            await fetchActivePlan();
          } else if (status == 'FAILED') {
            _pollTimer?.cancel();
            await _storage.clearJobId();
            state = WorkoutError(
                statusMap['error'] as String? ?? 'Workout plan generation failed',
                canRetry: true);
          }
        },
      );
    });
  }

  Future<void> _savePlan(MonthlyWorkoutPlanEntity monthly) async {
    await _storage.savePlan(monthly);
    _ref.invalidate(savedWorkoutPlanProvider);
    // CX-4: If trainer pushed a new plan while a session was active, drop the
    // stale session so the user sees the updated exercises next time they open it.
    _ref.invalidate(activeWorkoutSessionProvider);
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final workoutRemoteDataSourceProvider =
    Provider<WorkoutRemoteDataSource>((ref) {
  return WorkoutRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepositoryImpl(
      remoteDataSource: ref.watch(workoutRemoteDataSourceProvider));
});

final getActiveWorkoutUseCaseProvider =
    Provider<GetActiveWorkoutUseCase>((ref) {
  return GetActiveWorkoutUseCase(ref.watch(workoutRepositoryProvider));
});

final generateAIWorkoutUseCaseProvider =
    Provider<GenerateAIWorkoutUseCase>((ref) {
  return GenerateAIWorkoutUseCase(ref.watch(workoutRepositoryProvider));
});

final getWorkoutJobStatusUseCaseProvider =
    Provider<GetWorkoutJobStatusUseCase>((ref) {
  return GetWorkoutJobStatusUseCase(ref.watch(workoutRepositoryProvider));
});

final workoutNotifierProvider =
    StateNotifierProvider<WorkoutNotifier, WorkoutState>((ref) {
  // ref.read — prevents notifier recreation (and poll timer cancellation)
  // on token refresh or other auth state changes.
  final user = ref.read(currentUserProvider);
  return WorkoutNotifier(
    ref.watch(getActiveWorkoutUseCaseProvider),
    ref.watch(generateAIWorkoutUseCaseProvider),
    ref.watch(getWorkoutJobStatusUseCaseProvider),
    ref.watch(workoutPlanStorageProvider),
    user?.id,
    ref,
  );
});
