import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../data/datasources/workout_history_remote_data_source.dart';
import '../../../../core/providers/points_provider.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class LoggedSet {
  final int setIndex;
  final double weightKg;
  final int reps;
  final int? rpe; // Rate of Perceived Exertion (1–10)
  final DateTime completedAt;

  const LoggedSet({
    required this.setIndex,
    required this.weightKg,
    required this.reps,
    this.rpe,
    required this.completedAt,
  });
}

class ActiveExercise {
  final ExerciseEntity entity;
  final List<LoggedSet> loggedSets;

  const ActiveExercise({
    required this.entity,
    this.loggedSets = const [],
  });

  bool get isComplete => loggedSets.length >= entity.targetSets;

  ActiveExercise copyWith({List<LoggedSet>? loggedSets}) {
    return ActiveExercise(
      entity: entity,
      loggedSets: loggedSets ?? this.loggedSets,
    );
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

enum WorkoutPhase { active, resting, completed }

class ActiveWorkoutSessionState {
  final String routineId;
  final String routineName;
  final List<ActiveExercise> exercises;
  final int currentExerciseIndex;
  final WorkoutPhase phase;
  final int restSecondsLeft;
  final int restSecondsTotal;
  final DateTime startedAt;
  final DateTime? completedAt;

  const ActiveWorkoutSessionState({
    required this.routineId,
    required this.routineName,
    required this.exercises,
    this.currentExerciseIndex = 0,
    this.phase = WorkoutPhase.active,
    this.restSecondsLeft = 0,
    this.restSecondsTotal = 60,
    required this.startedAt,
    this.completedAt,
  });

  ActiveExercise? get currentExercise =>
      exercises.isNotEmpty && currentExerciseIndex < exercises.length
          ? exercises[currentExerciseIndex]
          : null;

  int get completedExerciseCount =>
      exercises.where((e) => e.isComplete).length;

  int get elapsedSeconds =>
      DateTime.now().difference(startedAt).inSeconds;

  bool get isLastExercise =>
      currentExerciseIndex >= exercises.length - 1;

  ActiveWorkoutSessionState copyWith({
    List<ActiveExercise>? exercises,
    int? currentExerciseIndex,
    WorkoutPhase? phase,
    int? restSecondsLeft,
    int? restSecondsTotal,
    DateTime? completedAt,
  }) {
    return ActiveWorkoutSessionState(
      routineId: routineId,
      routineName: routineName,
      exercises: exercises ?? this.exercises,
      currentExerciseIndex:
          currentExerciseIndex ?? this.currentExerciseIndex,
      phase: phase ?? this.phase,
      restSecondsLeft: restSecondsLeft ?? this.restSecondsLeft,
      restSecondsTotal: restSecondsTotal ?? this.restSecondsTotal,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ActiveWorkoutSessionNotifier
    extends StateNotifier<ActiveWorkoutSessionState?> {
  final Ref _ref;
  Timer? _restTimer;

  ActiveWorkoutSessionNotifier(this._ref) : super(null);

  // ── Start a workout session ──────────────────────────────────────────────

  void startSession(String routineId, String routineName,
      List<ExerciseEntity> exercises) {
    state = ActiveWorkoutSessionState(
      routineId: routineId,
      routineName: routineName,
      exercises: exercises
          .map((e) => ActiveExercise(entity: e))
          .toList(),
      startedAt: DateTime.now(),
    );
  }

  // ── Log a completed set ──────────────────────────────────────────────────

  void logSet({
    required double weightKg,
    required int reps,
    int? rpe,
  }) {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.active) return;

    final idx = s.currentExerciseIndex;
    final exercise = s.exercises[idx];
    final setIndex = exercise.loggedSets.length;

    final newSet = LoggedSet(
      setIndex: setIndex,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      completedAt: DateTime.now(),
    );

    final updated = exercise.copyWith(
      loggedSets: [...exercise.loggedSets, newSet],
    );

    final newExercises = [...s.exercises];
    newExercises[idx] = updated;

    state = s.copyWith(exercises: newExercises);

    // Auto-start rest timer if not on last set
    final setsRemaining = updated.entity.targetSets - updated.loggedSets.length;
    if (setsRemaining > 0) {
      _startRestTimer(updated.entity.restSeconds);
    }
  }

  // ── Skip rest timer ──────────────────────────────────────────────────────

  void skipRest() {
    _restTimer?.cancel();
    state = state?.copyWith(
      phase: WorkoutPhase.active,
      restSecondsLeft: 0,
    );
  }

  // ── Move to next exercise ────────────────────────────────────────────────

  void nextExercise() {
    final s = state;
    if (s == null) return;

    _restTimer?.cancel();

    if (s.isLastExercise) {
      final completed = s.copyWith(
        phase: WorkoutPhase.completed,
        completedAt: DateTime.now(),
      );
      state = completed;
      _syncSession(completed);
      return;
    }

    state = s.copyWith(
      currentExerciseIndex: s.currentExerciseIndex + 1,
      phase: WorkoutPhase.active,
      restSecondsLeft: 0,
    );
  }

  // ── Skip current exercise ────────────────────────────────────────────────

  void skipExercise() => nextExercise();

  // ── Finish workout early ─────────────────────────────────────────────────

  void finishWorkout() {
    _restTimer?.cancel();
    final completed = state?.copyWith(
      phase: WorkoutPhase.completed,
      completedAt: DateTime.now(),
    );
    state = completed;
    if (completed != null) _syncSession(completed);
  }

  // ── Reset session ────────────────────────────────────────────────────────

  void reset() {
    _restTimer?.cancel();
    state = null;
  }

  /// Discard the session without saving (user chose to quit mid-workout).
  void abandonWorkout() => reset();

  // ── Rest timer internal ──────────────────────────────────────────────────

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();

    state = state?.copyWith(
      phase: WorkoutPhase.resting,
      restSecondsLeft: seconds,
      restSecondsTotal: seconds,
    );

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final s = state;
      if (s == null || s.phase != WorkoutPhase.resting) {
        timer.cancel();
        return;
      }

      final newLeft = s.restSecondsLeft - 1;
      if (newLeft <= 0) {
        timer.cancel();
        state = s.copyWith(
          phase: WorkoutPhase.active,
          restSecondsLeft: 0,
        );
      } else {
        state = s.copyWith(restSecondsLeft: newLeft);
      }
    });
  }

  // ── Sync completed session to backend ────────────────────────────────────

  Future<void> _syncSession(ActiveWorkoutSessionState session) async {
    final ds = _ref.read(workoutHistoryDataSourceProvider);
    try {
      await ds.saveSession(session);
    } catch (_) {
      ds.queueSession(session);
    }
    _ref.read(pointsProvider.notifier).syncFromBackend();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final activeWorkoutSessionProvider = StateNotifierProvider<
    ActiveWorkoutSessionNotifier, ActiveWorkoutSessionState?>(
  (ref) => ActiveWorkoutSessionNotifier(ref),
);
