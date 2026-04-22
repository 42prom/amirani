import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'workout_preferences_entity.freezed.dart';
part 'workout_preferences_entity.g.dart';

/// Workout goal types
@HiveType(typeId: 28)
enum WorkoutGoal {
  @HiveField(0) weightLoss,
  @HiveField(1) muscleGain,
  @HiveField(2) strength,
  @HiveField(3) endurance,
  @HiveField(4) flexibility,
  @HiveField(5) generalFitness,
}

/// Training location
@HiveType(typeId: 29)
enum TrainingLocation {
  @HiveField(0) home,
  @HiveField(1) gym,
}

/// Equipment types available
@HiveType(typeId: 30)
enum Equipment {
  @HiveField(0) bodyweightOnly,
  @HiveField(1) dumbbells,
  @HiveField(2) barbell,
  @HiveField(3) machines,
  @HiveField(4) resistanceBands,
  @HiveField(5) pullUpBar,
  @HiveField(6) kettlebell,
  @HiveField(7) cables,
  @HiveField(8) bench,
  @HiveField(9) jumpRope,
  @HiveField(10) medicineBall,
  @HiveField(11) foamRoller,
  @HiveField(12) yogaMat,
  @HiveField(13) stabilityBall,
  @HiveField(14) trxStraps,
  @HiveField(15) parallelBars,
  @HiveField(16) weightedVest,
  @HiveField(17) ankleWeights,
  @HiveField(18) abWheel,
  @HiveField(19) battleRopes,
}

/// Training split types
@HiveType(typeId: 31)
enum TrainingSplit {
  @HiveField(0) fullBody,
  @HiveField(1) upperLower,
  @HiveField(2) pushPullLegs,
  @HiveField(3) broSplit,
  @HiveField(4) custom,
}

/// Fitness level
@HiveType(typeId: 32)
enum FitnessLevel {
  @HiveField(0) beginner,
  @HiveField(1) intermediate,
  @HiveField(2) advanced,
  @HiveField(3) athlete,
}

/// Preferred workout time
@HiveType(typeId: 33)
enum PreferredWorkoutTime {
  @HiveField(0) earlyMorning, // 5-7 AM
  @HiveField(1) morning, // 7-10 AM
  @HiveField(2) midday, // 10 AM - 2 PM
  @HiveField(3) afternoon, // 2-5 PM
  @HiveField(4) evening, // 5-8 PM
  @HiveField(5) night, // 8-11 PM
}

/// Common injury types
@HiveType(typeId: 34)
enum InjuryType {
  @HiveField(0) shoulder,
  @HiveField(1) back,
  @HiveField(2) knee,
  @HiveField(3) wrist,
  @HiveField(4) ankle,
  @HiveField(5) hip,
  @HiveField(6) neck,
  @HiveField(7) elbow,
  @HiveField(8) other,
}

/// Injury severity
@HiveType(typeId: 35)
enum InjurySeverity {
  @HiveField(0) minor, // Can work around it
  @HiveField(1) moderate, // Need to avoid certain exercises
  @HiveField(2) severe, // Significant limitations
}

@freezed
@HiveType(typeId: 36)
class UserInjuryEntity with _$UserInjuryEntity {
  const factory UserInjuryEntity({
    @HiveField(0) required InjuryType type,
    @HiveField(1) required InjurySeverity severity,
    @HiveField(2) String? customName, // For "other" type
    @HiveField(3) String? notes,
  }) = _UserInjuryEntity;
}

@freezed
@HiveType(typeId: 37)
class WorkoutPreferencesEntity with _$WorkoutPreferencesEntity {
  const factory WorkoutPreferencesEntity({
    @HiveField(0) required String odUserId,
    @HiveField(1) required WorkoutGoal goal,

    // Training setup
    @HiveField(2) @Default(TrainingLocation.home) TrainingLocation location,
    @HiveField(3) @Default([Equipment.bodyweightOnly]) List<Equipment> availableEquipment,
    @HiveField(4) @Default([]) List<String> outOfOrderMachines,
    @HiveField(5) @Default(TrainingSplit.fullBody) TrainingSplit trainingSplit,

    // Fitness profile
    @HiveField(6) @Default(FitnessLevel.beginner) FitnessLevel fitnessLevel,
    @HiveField(7) @Default(0) int experienceYears,
    @HiveField(8) @Default([]) List<UserInjuryEntity> injuries,

    // Exercise preferences
    @HiveField(9) @Default([]) List<String> likedExercises,
    @HiveField(10) @Default([]) List<String> dislikedExercises,

    // Schedule
    @HiveField(11) @Default(3) int daysPerWeek,
    @HiveField(12) @Default([]) List<int> preferredDays, // 0=Monday, 6=Sunday
    @HiveField(13) @Default(45) int sessionDurationMinutes,
    @HiveField(14) @Default(PreferredWorkoutTime.morning) PreferredWorkoutTime preferredTime,

    // Reminders
    @HiveField(15) @Default(true) bool workoutRemindersEnabled,
    @HiveField(16) String? reminderTime, // "08:00"

    // Targets
    @HiveField(17) double? targetWeightKg,
    @HiveField(18) int? targetCaloriesBurnedPerSession,

    @HiveField(21) @Default([]) List<String> targetMuscles,
    @HiveField(19) DateTime? createdAt,
    @HiveField(20) DateTime? updatedAt,
  }) = _WorkoutPreferencesEntity;
}
