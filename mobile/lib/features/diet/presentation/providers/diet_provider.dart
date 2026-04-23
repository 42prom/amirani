import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_date.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

import '../../domain/entities/daily_macro_entity.dart';
import '../../domain/entities/diet_plan_entity.dart';
import '../../domain/entities/monthly_plan_entity.dart' as plan_entity;
import '../../domain/entities/monthly_plan_entity.dart' show DailyPlanEntity;
import '../../domain/usecases/diet_usecases.dart';
import '../../domain/repositories/diet_repository.dart';
import '../../data/datasources/diet_remote_data_source.dart';
import '../../data/repositories/diet_repository_impl.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/services/diet_plan_storage_service.dart';

abstract class DietState {}

class DietInitial extends DietState {}

class DietLoading extends DietState {}

class DietLoaded extends DietState {
  final DailyMacroEntity macros;
  DietLoaded(this.macros);
}

/// AI plan generation job enqueued — polling in progress.
class DietGenerating extends DietState {
  final String jobId;
  DietGenerating(this.jobId);
}

/// A trainer has assigned a new diet plan not yet acknowledged by the member.
class DietNewTrainerPlan extends DietState {
  final DietPlanEntity plan;
  final plan_entity.MonthlyDietPlanEntity monthly;
  DietNewTrainerPlan(this.plan, this.monthly);
}

class DietError extends DietState {
  final String message;
  /// True when the user can tap "Try Again" to re-trigger generation.
  final bool canRetry;
  DietError(this.message, {this.canRetry = false});
}

class DietNotifier extends StateNotifier<DietState> {
  final GetDailyMacrosUseCase _getDailyMacrosUseCase;
  final GenerateAIDietPlanUseCase _generateAIDietPlanUseCase;
  final GetActiveDietPlanUseCase _getActiveDietPlanUseCase;
  final GetDietJobStatusUseCase _getJobStatusUseCase;
  final DietPlanStorageService _storage;
  final String? _userId;
  final Ref _ref;

  Timer? _pollTimer;

  DietNotifier(
    this._getDailyMacrosUseCase,
    this._generateAIDietPlanUseCase,
    this._getActiveDietPlanUseCase,
    this._getJobStatusUseCase,
    this._storage,
    this._userId,
    this._ref,
  ) : super(DietInitial());

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Fetches the active diet plan from backend (Trainer or AI).
  Future<void> fetchActivePlan() async {
    // CX-3: Resume polling if a job was in-flight when the app was last closed.
    // Verify the job is still running before entering Generating state.
    final pendingJobId = await _storage.loadJobId();
    if (!mounted) return;
    if (pendingJobId != null) {
      final statusResult = await _getJobStatusUseCase(GetDietJobStatusParams(pendingJobId));
      if (!mounted) return;
      final stillPending = statusResult.fold(
        (_) => true,
        (statusMap) {
          final status = statusMap['status'] as String? ?? '';
          return status != 'COMPLETED' && status != 'FAILED';
        },
      );
      if (stillPending) {
        state = DietGenerating(pendingJobId);
        _startPolling(pendingJobId);
        return;
      }
      await _storage.clearJobId();
    }

    // Offline-first: load cache immediately so UI is never blank.
    final cached = await _storage.loadPlan();
    if (!mounted) return;
    if (cached != null) {
      _ref.read(generatedDietPlanProvider.notifier).state = cached;
      _updateStateFromPlan(cached);
      await fetchDailyMacros(DateTime.now(), useCacheOnly: true);
      if (!mounted) return;
    } else {
      state = DietLoading();
    }

    final result = await _getActiveDietPlanUseCase(NoParams());
    if (!mounted) return;

        await result.fold(
          (failure) async {
            if (!mounted) return;
            debugPrint('[Diet] fetchActivePlan failed: ${failure.message}');
            if (cached == null) {
              state = DietError(failure.message);
            } else {
              await fetchDailyMacros(DateTime.now());
            }
          },
          (plan) async {
            if (!mounted) return;
            if (plan == null) {
              debugPrint('[Diet] fetchActivePlan returned null plan');
              if (cached == null) state = DietInitial();
              return;
            }

            debugPrint('[Diet] fetchActivePlan success. Plan ID: ${plan.id} | isAI: ${plan.isAIGenerated}');
            final monthly = plan.toMonthlyEntity(_userId ?? plan.id);
        if (!plan.isAIGenerated && plan.isActive) {
          final existing = await _storage.loadPlan();
          if (!mounted) return;
          if (existing == null || existing.id != monthly.id) {
            state = DietNewTrainerPlan(plan, monthly);
            return;
          }
          await _persistPlan(monthly, isAI: false);
          _updateStateFromPlan(monthly);
        } else if (plan.isAIGenerated) {
          final existing = await _storage.loadPlan();
          if (!mounted) return;
          if (existing == null || existing.id != monthly.id) {
            await _persistPlan(monthly, isAI: true);
            _updateStateFromPlan(monthly);
          }
        }
        
        if (!mounted) return;
        // Background update for live consumption data
        unawaited(fetchDailyMacros(DateTime.now()));
      },
    );
  }

  /// Called when the member accepts a newly assigned trainer diet plan.
  Future<void> acceptNewPlan(
      DietPlanEntity plan, plan_entity.MonthlyDietPlanEntity monthly) async {
    // Instant UI update matching Workout experience
    _updateStateFromPlan(monthly);
    await _persistPlan(monthly, isAI: false);
    // Refresh consumption progress in background
    unawaited(fetchDailyMacros(DateTime.now()));
  }

  /// Helper to immediately transition to DietLoaded state from local plan data
  void _updateStateFromPlan(plan_entity.MonthlyDietPlanEntity plan) {
    if (!mounted) return;
    final todayKey = AppDate.todayKey();
    final today    = AppDate.today();

    // Find today's plan entry using YYYY-MM-DD string comparison —
    // timezone-agnostic, consistent with DietPlanMapper key strategy.
    final dayPlan = plan.weeks
        .expand((w) => w.days)
        .firstWhere(
          (d) => AppDate.toKey(d.date) == todayKey,
          orElse: () => plan_entity.DailyPlanEntity(
            id: 'initial_$todayKey',
            date: today,
            meals: const [],
            targetCalories: plan.macroTarget.calories,
            targetProtein: plan.macroTarget.protein,
            targetCarbs: plan.macroTarget.carbs,
            targetFats: plan.macroTarget.fats,
          ),
        );

    // Transition to Loaded state immediately with correctly formatted macro targets.
    // Progress (consumed calories) will be 0 initially and filled by fetchDailyMacros.
    state = DietLoaded(DailyMacroEntity(
      id: 'initial_macros_$todayKey',
      date: today,
      currentCalories: 0,
      currentProtein: 0,
      currentCarbs: 0,
      currentFats: 0,
      targetCalories: dayPlan.targetCalories,
      targetProtein: dayPlan.targetProtein,
      targetCarbs: dayPlan.targetCarbs,
      targetFats: dayPlan.targetFats,
      meals: const [],
    ));
  }

  /// Called when the member dismisses the new trainer diet plan prompt.
  /// Restores the previously cached plan so the screen is not left blank.
  Future<void> dismissNewPlan() async {
    final cached = await _storage.loadPlan();
    if (!mounted) return;
    if (cached != null) {
      _ref.read(generatedDietPlanProvider.notifier).state = cached;
      _updateStateFromPlan(cached);
      unawaited(fetchDailyMacros(DateTime.now()));
    } else {
      state = DietInitial();
    }
  }

  Future<void> fetchDailyMacros(DateTime date,
      {bool useCacheOnly = false}) async {
    // PROTECT: Do not overwrite the New Trainer Plan dialog with loading/macros.
    // The dialog must take priority until the user accepts or dismisses it.
    if (state is DietNewTrainerPlan) {
      debugPrint('[Sync] Skipping macro refresh; Trainer Dialog is active');
      return;
    }

    if (useCacheOnly) {
      final plan = await _storage.loadPlan();
      if (!mounted) return;
      if (plan != null) {
        final dateKey   = AppDate.toKey(date);
        final localDate = AppDate.localMidnight(date);
        final dayPlan = plan.weeks
            .expand((w) => w.days)
            .firstWhere(
              (d) => AppDate.toKey(d.date) == dateKey,
              // Return a synthetic day with correct macro targets rather than a wrong day's data
              orElse: () => DailyPlanEntity(
                id: 'synthetic_$dateKey',
                date: localDate,
                meals: const [],
                targetCalories: plan.macroTarget.calories,
                targetProtein: plan.macroTarget.protein,
                targetCarbs: plan.macroTarget.carbs,
                targetFats: plan.macroTarget.fats,
              ),
            );
        state = DietLoaded(DailyMacroEntity(
          id: 'macros_$dateKey',
          date: localDate,
          currentCalories: 0,
          currentProtein: 0,
          currentCarbs: 0,
          currentFats: 0,
          targetCalories: dayPlan.targetCalories,
          targetProtein: dayPlan.targetProtein,
          targetCarbs: dayPlan.targetCarbs,
          targetFats: dayPlan.targetFats,
          meals: const [],
        ));
      }
      return;
    }

    state = DietLoading();
    final result = await _getDailyMacrosUseCase(GetDailyMacrosParams(date));
    if (!mounted) return;

    await result.fold(
      (failure) async {
        final plan = await _storage.loadPlan();
        if (!mounted) return;
        if (plan != null) {
          await fetchDailyMacros(date, useCacheOnly: true);
        } else {
          state = DietError(failure.message);
        }
      },
      (macros) async {
        // P1-D: backend getDailyMacros returns plan-level average targets.
        // Override with per-rotation-day targets from the cached plan so the
        // macro ring shows the correct daily goal, not the average.
        final dateKey = AppDate.toKey(date);
        final plan    = await _storage.loadPlan();
        if (!mounted) return;
        if (plan != null) {
          final dayPlan = plan.weeks
              .expand((w) => w.days)
              .cast<DailyPlanEntity?>()
              .firstWhere(
                (d) => d != null && AppDate.toKey(d.date) == dateKey,
                orElse: () => null,
              );
          if (dayPlan != null) {
            state = DietLoaded(macros.copyWith(
              targetCalories: dayPlan.targetCalories,
              targetProtein:  dayPlan.targetProtein,
              targetCarbs:    dayPlan.targetCarbs,
              targetFats:     dayPlan.targetFats,
            ));
            return;
          }
        }
        state = DietLoaded(macros);
      },
    );
  }

  /// Toggle a planned meal's logged state and keep DailyProgress in sync.
  /// Returns true on success, false on error.
  Future<bool> markMealDone(String mealRefId, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final ds = _ref.read(dietRemoteDataSourceProvider);
      // Optimistic: assume currently not logged → mark as done.
      // For undo flows the caller passes a second call with logged: false.
      await ds.markMealDone(mealRefId, dateStr, logged: true);
      // Refresh macro progress so the ring updates immediately.
      unawaited(fetchDailyMacros(date));
      return true;
    } catch (e) {
      debugPrint('[Diet] markMealDone error: $e');
      return false;
    }
  }

  /// Toggle a planned meal to un-logged state.
  Future<bool> unmarkMealDone(String mealRefId, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final ds = _ref.read(dietRemoteDataSourceProvider);
      await ds.markMealDone(mealRefId, dateStr, logged: false);
      unawaited(fetchDailyMacros(date));
      return true;
    } catch (e) {
      debugPrint('[Diet] unmarkMealDone error: $e');
      return false;
    }
  }

  /// Enqueues an AI diet plan generation job and begins polling for completion.
  /// Loads the full [DietPreferencesEntity] saved during onboarding so the
  /// regenerate path sends the same rich payload as the initial generation.
  Future<void> generateDietPlan() async {
    state = DietLoading();

    final prefs = await _storage.loadPreferences();
    if (!mounted) return;
    if (prefs == null) {
      state = DietError('No preferences found. Please complete onboarding first.');
      return;
    }

    final result = await _generateAIDietPlanUseCase(GenerateAIDietPlanParams(prefs));
    if (!mounted) return;

    result.fold(
      (failure) {
        debugPrint('[Diet] AI Job enqueuing failed: ${failure.message}');
        state = DietError(failure.message, canRetry: true);
      },
      (jobId) async {
        debugPrint('[Diet] AI Job enqueuing success. Job ID: $jobId');
        await _storage.saveJobId(jobId);
        state = DietGenerating(jobId);
        _startPolling(jobId);
      },
    );
  }

  void _startPolling(String jobId) {
    _pollTimer?.cancel();
    int pollCount = 0;
    // INCREASED: Diet generation with 7-day meal plans + ingredients can take 7-9 minutes.
    // 150 × 5s = 12.5 min max before surfacing timeout error.
    const maxPolls = 150;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) { _pollTimer?.cancel(); return; }
      if (pollCount++ >= maxPolls) {
        _pollTimer?.cancel();
        await _storage.clearJobId();
        state = DietError('Plan generation is taking too long. Please try again.', canRetry: true);
        return;
      }
      final result = await _getJobStatusUseCase(GetDietJobStatusParams(jobId));
      if (!mounted) { _pollTimer?.cancel(); return; }
      await result.fold(
        (failure) async {
          // Log transient poll failure — keeps polling, but at least visible in debug console
          debugPrint('[Diet] Poll #$pollCount transient error (will retry): ${failure.message}');
        },
        (statusMap) async {
          final status = statusMap['status'] as String? ?? '';
          if (status == 'COMPLETED') {
            debugPrint('[Diet] Poll #$pollCount - COMPLETE. Refreshing plan.');
            _pollTimer?.cancel();
            await _storage.clearJobId();
            unawaited(fetchActivePlan());
          } else if (status == 'FAILED') {
            final error = statusMap['error'] as String? ?? 'Diet plan generation failed';
            debugPrint('[Diet] Poll #$pollCount - FAILED. Error: $error');
            _pollTimer?.cancel();
            await _storage.clearJobId();
            state = DietError(error, canRetry: true);
          }
          // QUEUED / PROCESSING: keep polling.
          if (status == 'QUEUED' || status == 'PROCESSING') {
             debugPrint('[Diet] Poll #$pollCount - $status...');
          }
        },
      );
    });
  }

  Future<void> _persistPlan(plan_entity.MonthlyDietPlanEntity monthly,
      {required bool isAI}) async {
    await _storage.savePlan(monthly);
    await _storage.saveIsAIGenerated(isAI);
    _ref.read(generatedDietPlanProvider.notifier).state = monthly;
    _ref.read(dietPlanIsAIGeneratedProvider.notifier).state = isAI;
    _ref.invalidate(savedDietPlanProvider);
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final dietRemoteDataSourceProvider = Provider<DietRemoteDataSource>((ref) {
  return DietRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final dietRepositoryProvider = Provider<DietRepository>((ref) {
  return DietRepositoryImpl(
      remoteDataSource: ref.watch(dietRemoteDataSourceProvider));
});

final getDailyMacrosUseCaseProvider = Provider<GetDailyMacrosUseCase>((ref) {
  return GetDailyMacrosUseCase(ref.watch(dietRepositoryProvider));
});

final generateAIDietPlanUseCaseProvider =
    Provider<GenerateAIDietPlanUseCase>((ref) {
  return GenerateAIDietPlanUseCase(ref.watch(dietRepositoryProvider));
});

final getActiveDietPlanUseCaseProvider =
    Provider<GetActiveDietPlanUseCase>((ref) {
  return GetActiveDietPlanUseCase(ref.watch(dietRepositoryProvider));
});

final getDietJobStatusUseCaseProvider =
    Provider<GetDietJobStatusUseCase>((ref) {
  return GetDietJobStatusUseCase(ref.watch(dietRepositoryProvider));
});

final dietNotifierProvider =
    StateNotifierProvider<DietNotifier, DietState>((ref) {
  // ref.read — the notifier only needs userId at creation time.
  // ref.watch would recreate the notifier (and cancel any active poll timer)
  // on every auth state change such as token refresh.
  final auth = ref.read(authNotifierProvider);
  final userId = auth is AuthAuthenticated ? auth.user.id : null;

  return DietNotifier(
    ref.watch(getDailyMacrosUseCaseProvider),
    ref.watch(generateAIDietPlanUseCaseProvider),
    ref.watch(getActiveDietPlanUseCaseProvider),
    ref.watch(getDietJobStatusUseCaseProvider),
    ref.watch(dietPlanStorageProvider),
    userId,
    ref,
  );
});

/// In-memory reference to the active monthly diet plan.
final generatedDietPlanProvider =
    StateProvider<plan_entity.MonthlyDietPlanEntity?>((ref) => null);

/// Whether the current saved diet plan is AI-generated (true) or trainer-assigned (false).
final dietPlanIsAIGeneratedProvider = StateProvider<bool>((ref) => false);
