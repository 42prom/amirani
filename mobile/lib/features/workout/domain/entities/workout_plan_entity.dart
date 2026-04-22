import 'package:freezed_annotation/freezed_annotation.dart';
import 'routine_entity.dart';
import 'monthly_workout_plan_entity.dart';
import 'workout_preferences_entity.dart';

part 'workout_plan_entity.freezed.dart';

@freezed
class WorkoutPlanEntity with _$WorkoutPlanEntity {
  const factory WorkoutPlanEntity({
    required String id,
    required String name,
    String? description,
    required String difficulty,
    required bool isAIGenerated,
    required bool isActive,
    required List<RoutineEntity> routines,
    required DateTime createdAt,
  }) = _WorkoutPlanEntity;
}

/// Converts a trainer-created WorkoutPlanEntity into a MonthlyWorkoutPlanEntity
/// so it can be saved to Hive and displayed with the same rich experience as
/// AI-generated plans (set-level completion, day selector, offline support).
extension WorkoutPlanEntityToMonthly on WorkoutPlanEntity {
  MonthlyWorkoutPlanEntity toMonthlyEntity(String userId) {
    final scheduledRoutines = routines
        .where((r) => r.scheduledDate != null)
        .toList()
      ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));

    final rawStart = scheduledRoutines.isNotEmpty
        ? scheduledRoutines.first.scheduledDate!
        : createdAt;
    // Normalize to the Monday of the starting week to ensure consistent 
    // day-mapping in the UI day selector.
    final localStart = rawStart.toLocal();
    final offset = localStart.weekday - 1;
    final startDate = DateTime(localStart.year, localStart.month, localStart.day)
        .subtract(Duration(days: offset));

    // Compute number of weeks from the span of scheduled routines (max 4).
    // Use toLocal() so the span is calculated in the user's timezone.
    int numWeeks = 1;
    if (scheduledRoutines.isNotEmpty) {
      final maxLocal = scheduledRoutines.last.scheduledDate!.toLocal();
      final maxDate = DateTime(maxLocal.year, maxLocal.month, maxLocal.day);
      final span = maxDate.difference(startDate).inDays + 1;
      numWeeks = ((span / 7).ceil()).clamp(1, 4);
    }

    final List<WeeklyWorkoutPlanEntity> weeks = [];
    for (int w = 0; w < numWeeks; w++) {
      final weekStart = DateTime(
        startDate.year, startDate.month, startDate.day + w * 7,
      );
      final weekEnd = DateTime(
        weekStart.year, weekStart.month, weekStart.day + 6,
      );

      final List<DailyWorkoutPlanEntity> days = [];
      for (int d = 0; d < 7; d++) {
        final dayDate = DateTime(
          weekStart.year, weekStart.month, weekStart.day + d,
        );

        // Find a routine whose scheduledDate matches this calendar day.
        // scheduledDate arrives as UTC from the backend — convert to local
        // before comparing so UTC-x users don't see routines shift one day back.
        final routine = scheduledRoutines.where((r) {
          final sd = r.scheduledDate!.toLocal();
          return sd.year == dayDate.year &&
              sd.month == dayDate.month &&
              sd.day == dayDate.day;
        }).firstOrNull;

        // P4-C: routine != null means trainer scheduled a workout here even if
        // exercises list is empty (e.g. plan still being filled out).
        // Only fall through to rest-day when no routine is scheduled at all.
        if (routine != null) {
          // Separate warmup (orderIndex >= 1000) from main work for display
          final mainExercises = routine.exercises
              .where((e) => !e.isWarmup)
              .toList();
          final warmupExercises = routine.exercises
              .where((e) => e.isWarmup)
              .toList();
          // Show warmup first, then main work
          final orderedExercises = [...warmupExercises, ...mainExercises];

          final exercises = orderedExercises.map((ex) {
            final sets = List.generate(
              ex.targetSets,
              (i) => ExerciseSetEntity(
                setNumber: i + 1,
                // Timed hold: targetReps=1 is a sentinel — use targetSeconds instead
                targetReps: ex.targetSeconds != null ? 1 : (ex.targetReps ?? 10),
                targetRepsMax: ex.targetRepsMax,  // P2-E: upper bound for overload display
                targetSeconds: ex.targetSeconds,
                restSeconds: ex.restSeconds,
                targetWeight: ex.targetWeight,
                rpe: ex.rpe,
                tempoEccentric: ex.tempoEccentric,
                tempoPause: ex.tempoPause,
                tempoConcentric: ex.tempoConcentric,
              ),
            );
            return PlannedExerciseEntity(
              id: ex.id,
              name: ex.exerciseName,
              description: ex.instructions ?? '',
              targetMuscles: ex.targetMuscles,
              difficulty: _mapDifficulty(difficulty),
              sets: sets,
              requiredEquipment: const [],
              videoUrl: ex.videoUrl,
              imageUrl: ex.imageUrl,
              instructions: ex.instructions,
              progressionNote: ex.progressionNote,
            );
          }).toList();

          days.add(DailyWorkoutPlanEntity(
            id: routine.id,
            date: dayDate,
            workoutName: routine.name,
            exercises: exercises,
            estimatedDurationMinutes: routine.estimatedMinutes,
            estimatedCaloriesBurned: routine.estimatedCaloriesBurned ?? 0,
            targetMuscleGroups: routine.exercises
                .expand((e) => e.targetMuscles)
                .toSet()
                .toList(),
            isRestDay: false,
          ));
        } else {
          days.add(DailyWorkoutPlanEntity(
            id: '${id}_rest_w${w + 1}_d${d + 1}',
            date: dayDate,
            workoutName: 'Rest Day',
            exercises: const [],
            estimatedDurationMinutes: 0,
            estimatedCaloriesBurned: 0,
            targetMuscleGroups: const [],
            isRestDay: true,
          ));
        }
      }

      weeks.add(WeeklyWorkoutPlanEntity(
        weekNumber: w + 1,
        startDate: weekStart,
        endDate: weekEnd,
        days: days,
      ));
    }

    return MonthlyWorkoutPlanEntity(
      id: id,
      odUserId: userId,
      startDate: startDate,
      endDate: DateTime(
        startDate.year, startDate.month, startDate.day + (numWeeks * 7) - 1,
      ),
      goal: _mapWorkoutGoal(name),
      location: TrainingLocation.gym,
      split: TrainingSplit.custom,
      dailyTarget: DailyWorkoutTargetEntity(
        exercisesPerSession: (routines.fold(0, (s, r) => s + r.exercises.length) / 
            (routines.isNotEmpty ? routines.length : 1)).round(),
        durationMinutes: (routines.fold(0, (s, r) => s + r.estimatedMinutes) / 
            (routines.isNotEmpty ? routines.length : 1)).round(),
        caloriesBurned: (routines.fold(0, (s, r) => s + r.exercises.fold(0, (ss, e) => ss + e.targetSets * 15)) / 
            (routines.isNotEmpty ? routines.length : 1)).round(),
        setsPerMuscleGroup: 10, // Default heuristic
      ),
      weeks: weeks,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  WorkoutGoal _mapWorkoutGoal(String planName) {
    final name = planName.toLowerCase();
    if (name.contains('strength') || name.contains('power')) return WorkoutGoal.strength;
    if (name.contains('weight') || name.contains('loss') || name.contains('cut')) return WorkoutGoal.weightLoss;
    if (name.contains('muscle') || name.contains('gain') || name.contains('bulk')) return WorkoutGoal.muscleGain;
    return WorkoutGoal.generalFitness;
  }

  ExerciseDifficulty _mapDifficulty(String diff) {
    switch (diff.toLowerCase()) {
      case 'beginner': return ExerciseDifficulty.beginner;
      case 'advanced': return ExerciseDifficulty.advanced;
      default: return ExerciseDifficulty.intermediate;
    }
  }
}
