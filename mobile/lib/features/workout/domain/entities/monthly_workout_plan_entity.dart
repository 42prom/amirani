import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'workout_preferences_entity.dart';

part 'monthly_workout_plan_entity.freezed.dart';
part 'monthly_workout_plan_entity.g.dart';

/// Muscle group targeted
@HiveType(typeId: 20)
enum MuscleGroup {
  @HiveField(0) chest,
  @HiveField(1) back,
  @HiveField(2) shoulders,
  @HiveField(3) biceps,
  @HiveField(4) triceps,
  @HiveField(5) forearms,
  @HiveField(6) abs,
  @HiveField(7) obliques,
  @HiveField(8) quads,
  @HiveField(9) hamstrings,
  @HiveField(10) glutes,
  @HiveField(11) calves,
  @HiveField(12) traps,
  @HiveField(13) neck,
  @HiveField(14) adductors,
  @HiveField(15) fullBody,
  @HiveField(16) cardio,
}

/// Exercise difficulty
@HiveType(typeId: 21)
enum ExerciseDifficulty {
  @HiveField(0) beginner,
  @HiveField(1) intermediate,
  @HiveField(2) advanced,
}

/// A single set within an exercise
@freezed
@HiveType(typeId: 22)
class ExerciseSetEntity with _$ExerciseSetEntity {
  const factory ExerciseSetEntity({
    @HiveField(0) required int setNumber,
    @HiveField(1) required int targetReps,
    @HiveField(13) int? targetRepsMax, // P2-E: upper rep bound for progressive overload
    @HiveField(2) int? targetSeconds, // For timed exercises like plank
    @HiveField(3) double? targetWeight, // kg, null for bodyweight
    @HiveField(4) @Default(60) int restSeconds,
    @HiveField(5) @Default(false) bool isCompleted,
    @HiveField(6) int? actualReps,
    @HiveField(7) double? actualWeight,
    @HiveField(8) DateTime? completedAt,
    @HiveField(9) double? rpe,
    @HiveField(10) int? tempoEccentric,
    @HiveField(11) int? tempoPause,
    @HiveField(12) int? tempoConcentric,
  }) = _ExerciseSetEntity;
}

/// A single planned exercise
@freezed
@HiveType(typeId: 23)
class PlannedExerciseEntity with _$PlannedExerciseEntity {
  const factory PlannedExerciseEntity({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) required String description,
    @HiveField(3) required List<MuscleGroup> targetMuscles,
    @HiveField(4) required ExerciseDifficulty difficulty,
    @HiveField(5) required List<ExerciseSetEntity> sets,
    @HiveField(6) required List<Equipment> requiredEquipment,
    @HiveField(7) String? imageUrl,
    @HiveField(8) String? videoUrl,
    @HiveField(9) String? instructions,
    @HiveField(10) @Default(false) bool isCompleted,
    @HiveField(11) @Default(false) bool isSwapped,
    @HiveField(12) @Default(false) bool isSkipped,
    @HiveField(13) DateTime? completedAt,
    @HiveField(14) String? progressionNote,
    @HiveField(15) double? rpe,
    @HiveField(16) double? targetWeight,
    @HiveField(17) int? tempoEccentric,
    @HiveField(18) int? tempoPause,
    @HiveField(19) int? tempoConcentric,
  }) = _PlannedExerciseEntity;

  const PlannedExerciseEntity._();

  int get completedSets => sets.where((s) => s.isCompleted).length;
  int get totalSets => sets.length;
  double get setProgress => totalSets == 0 ? 0 : completedSets / totalSets;

  String get setsDisplay => '${sets.length} Sets';
  String get repsDisplay {
    if (sets.isEmpty) return '';
    final firstSet = sets.first;
    if (firstSet.targetSeconds != null) {
      return '${firstSet.targetSeconds} Sec';
    }
    return '${firstSet.targetReps} Reps';
  }
}

/// A single day's workout plan
@freezed
@HiveType(typeId: 24)
class DailyWorkoutPlanEntity with _$DailyWorkoutPlanEntity {
  const factory DailyWorkoutPlanEntity({
    @HiveField(0) required String id,
    @HiveField(1) required DateTime date,
    @HiveField(2) required String workoutName, // "Push Day", "Full Body A", etc.
    @HiveField(3) required List<PlannedExerciseEntity> exercises,
    @HiveField(4) required int estimatedDurationMinutes,
    @HiveField(5) required int estimatedCaloriesBurned,
    @HiveField(6) required List<MuscleGroup> targetMuscleGroups,
    @HiveField(7) String? scheduledTime, // "08:00" for reminders
    @HiveField(8) @Default(false) bool isRestDay,
    @HiveField(9) @Default(false) bool isCompleted,
    @HiveField(10) DateTime? startedAt,
    @HiveField(11) DateTime? completedAt,
  }) = _DailyWorkoutPlanEntity;

  const DailyWorkoutPlanEntity._();

  int get completedExercises =>
      exercises.where((e) => e.isCompleted).length;

  double get completionProgress =>
      exercises.isEmpty ? 0 : completedExercises / exercises.length;

  String get progressDisplay => '$completedExercises/${exercises.length} Done';
}

/// A week's workout plan
@freezed
@HiveType(typeId: 25)
class WeeklyWorkoutPlanEntity with _$WeeklyWorkoutPlanEntity {
  const factory WeeklyWorkoutPlanEntity({
    @HiveField(0) required int weekNumber,
    @HiveField(1) required DateTime startDate,
    @HiveField(2) required DateTime endDate,
    @HiveField(3) required List<DailyWorkoutPlanEntity> days,
  }) = _WeeklyWorkoutPlanEntity;

  const WeeklyWorkoutPlanEntity._();

  int get workoutDays => days.where((d) => !d.isRestDay).length;
  int get completedDays => days.where((d) => d.isCompleted).length;

  double get completionProgress {
    final nonRestDays = days.where((d) => !d.isRestDay).toList();
    if (nonRestDays.isEmpty) return 0;
    return nonRestDays.fold(0.0, (sum, d) => sum + d.completionProgress) /
        nonRestDays.length;
  }
}

/// Daily workout targets
@freezed
@HiveType(typeId: 26)
class DailyWorkoutTargetEntity with _$DailyWorkoutTargetEntity {
  const factory DailyWorkoutTargetEntity({
    @HiveField(0) required int exercisesPerSession,
    @HiveField(1) required int durationMinutes,
    @HiveField(2) required int caloriesBurned,
    @HiveField(3) required int setsPerMuscleGroup,
  }) = _DailyWorkoutTargetEntity;
}

/// The complete monthly workout plan (4 weeks)
@freezed
@HiveType(typeId: 27)
class MonthlyWorkoutPlanEntity with _$MonthlyWorkoutPlanEntity {
  const factory MonthlyWorkoutPlanEntity({
    @HiveField(0) required String id,
    @HiveField(1) required String odUserId,
    @HiveField(2) required DateTime startDate,
    @HiveField(3) required DateTime endDate,
    @HiveField(4) required WorkoutGoal goal,
    @HiveField(5) required TrainingLocation location,
    @HiveField(6) required TrainingSplit split,
    @HiveField(7) required DailyWorkoutTargetEntity dailyTarget,
    @HiveField(8) required List<WeeklyWorkoutPlanEntity> weeks,
    @HiveField(9) DateTime? createdAt,
    @HiveField(10) DateTime? updatedAt,
  }) = _MonthlyWorkoutPlanEntity;

  const MonthlyWorkoutPlanEntity._();

  /// Get the plan for a specific date
  DailyWorkoutPlanEntity? getDayPlan(DateTime date) {
    for (final week in weeks) {
      for (final day in week.days) {
        if (day.date.year == date.year &&
            day.date.month == date.month &&
            day.date.day == date.day) {
          return day;
        }
      }
    }
    return null;
  }

  /// Get current week number (1-4)
  int getCurrentWeek(DateTime now) {
    final daysSinceStart = now.difference(startDate).inDays;
    return (daysSinceStart ~/ 7) + 1;
  }

  /// Total workouts in plan
  int get totalWorkouts =>
      weeks.fold(0, (sum, w) => sum + w.workoutDays);

  /// Completed workouts
  int get completedWorkouts =>
      weeks.fold(0, (sum, w) => sum + w.completedDays);

  /// Overall completion progress
  double get overallProgress {
    if (weeks.isEmpty) return 0;
    return weeks.fold(0.0, (sum, w) => sum + w.completionProgress) /
        weeks.length;
  }
}
