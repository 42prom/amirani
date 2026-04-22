import 'package:amirani_app/features/workout/domain/entities/monthly_workout_plan_entity.dart';
import 'package:amirani_app/features/workout/domain/entities/workout_preferences_entity.dart';

/// Pure-Dart, zero-network engine that takes a single AI-generated week (week 1)
/// and expands it into a full 4-week progressive overload plan.
///
/// Progression logic per goal:
///   muscleGain / strength → +5% weight, +1 rep per set each week (deload week 4)
///   weightLoss / endurance → +1 rep per set, shorter rest each week
///   generalFitness / flexibility → +1 rep per set, +1 set on compound lifts week 3
///
/// The engine is completely independent of the diet system and the AI service.
class WorkoutProgressionEngine {
  const WorkoutProgressionEngine();

  /// Expands [week1] into a 4-week progressive plan starting from [planStartDate].
  /// Returns a list of exactly 4 [WeeklyWorkoutPlanEntity] objects.
  List<WeeklyWorkoutPlanEntity> expandToFourWeeks({
    required WeeklyWorkoutPlanEntity week1,
    required WorkoutGoal goal,
    required DateTime planStartDate,
  }) {
    return [
      _buildWeek(week1, weekNumber: 1, weekOffset: 0, goal: goal, planStartDate: planStartDate),
      _buildWeek(week1, weekNumber: 2, weekOffset: 1, goal: goal, planStartDate: planStartDate),
      _buildWeek(week1, weekNumber: 3, weekOffset: 2, goal: goal, planStartDate: planStartDate),
      _buildWeek(week1, weekNumber: 4, weekOffset: 3, goal: goal, planStartDate: planStartDate),
    ];
  }

  WeeklyWorkoutPlanEntity _buildWeek(
    WeeklyWorkoutPlanEntity template, {
    required int weekNumber,
    required int weekOffset,
    required WorkoutGoal goal,
    required DateTime planStartDate,
  }) {
    final weekStart = planStartDate.add(Duration(days: weekOffset * 7));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

    final progressedDays = template.days.map((day) {
      final newDate = day.date.add(Duration(days: weekOffset * 7));
      if (day.isRestDay) {
        return day.copyWith(
          id: 'day_${newDate.millisecondsSinceEpoch}',
          date: newDate,
          isCompleted: false,
          startedAt: null,
          completedAt: null,
        );
      }
      return day.copyWith(
        id: 'day_${newDate.millisecondsSinceEpoch}',
        date: newDate,
        isCompleted: false,
        startedAt: null,
        completedAt: null,
        exercises: day.exercises
            .map((ex) => _progressExercise(ex, weekNumber: weekNumber, goal: goal))
            .toList(),
      );
    }).toList();

    return WeeklyWorkoutPlanEntity(
      weekNumber: weekNumber,
      startDate: weekStart,
      endDate: weekEnd,
      days: progressedDays,
    );
  }

  PlannedExerciseEntity _progressExercise(
    PlannedExerciseEntity exercise, {
    required int weekNumber,
    required WorkoutGoal goal,
  }) {
    // Week 1 is the AI baseline — no modifications.
    if (weekNumber == 1) return exercise;

    final progressedSets = exercise.sets.map((set) {
      return _progressSet(set, weekNumber: weekNumber, goal: goal);
    }).toList();

    final note = _progressionNote(weekNumber: weekNumber, goal: goal);

    return exercise.copyWith(
      sets: progressedSets,
      progressionNote: note,
      isCompleted: false,
      completedAt: null,
    );
  }

  ExerciseSetEntity _progressSet(
    ExerciseSetEntity set, {
    required int weekNumber,
    required WorkoutGoal goal,
  }) {
    // Week 4 deload for strength/muscle — back to week 1 volume at 90% weight.
    final isDeload = weekNumber == 4 &&
        (goal == WorkoutGoal.muscleGain || goal == WorkoutGoal.strength);

    if (isDeload) {
      final deloadWeight = set.targetWeight != null
          ? _roundWeight(set.targetWeight! * 0.90)
          : null;
      return set.copyWith(
        targetWeight: deloadWeight,
        isCompleted: false,
        actualReps: null,
        actualWeight: null,
        completedAt: null,
      );
    }

    final progression = weekNumber - 1; // 1 for week2, 2 for week3, 3 for week4

    switch (goal) {
      case WorkoutGoal.muscleGain:
      case WorkoutGoal.strength:
        // +5% weight per week, +1 rep per set
        final newWeight = set.targetWeight != null
            ? _roundWeight(set.targetWeight! * (1 + 0.05 * progression))
            : null;
        return set.copyWith(
          targetWeight: newWeight,
          targetReps: set.targetReps + progression,
          isCompleted: false,
          actualReps: null,
          actualWeight: null,
          completedAt: null,
        );

      case WorkoutGoal.weightLoss:
      case WorkoutGoal.endurance:
        // +1 rep per set per week, shorter rest (−10s per week, min 30s)
        final newRest = (set.restSeconds - 10 * progression).clamp(30, 180);
        return set.copyWith(
          targetReps: set.targetReps + progression,
          restSeconds: newRest,
          isCompleted: false,
          actualReps: null,
          actualWeight: null,
          completedAt: null,
        );

      case WorkoutGoal.generalFitness:
      case WorkoutGoal.flexibility:
        // +1 rep per set per week
        return set.copyWith(
          targetReps: set.targetReps + progression,
          isCompleted: false,
          actualReps: null,
          actualWeight: null,
          completedAt: null,
        );
    }
  }

  String _progressionNote({required int weekNumber, required WorkoutGoal goal}) {
    final isDeload = weekNumber == 4 &&
        (goal == WorkoutGoal.muscleGain || goal == WorkoutGoal.strength);
    if (isDeload) return 'Deload week — reduce load by 10%, focus on form';
    switch (weekNumber) {
      case 2:
        return 'Week 2 — add progressive overload';
      case 3:
        return 'Week 3 — push intensity';
      default:
        return '';
    }
  }

  /// Rounds weight to nearest 2.5 kg increment (standard plate math).
  double _roundWeight(double weight) {
    return (weight / 2.5).round() * 2.5;
  }
}
