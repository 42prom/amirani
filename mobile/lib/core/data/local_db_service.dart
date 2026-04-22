import 'package:hive_flutter/hive_flutter.dart';
import '../../features/workout/domain/entities/monthly_workout_plan_entity.dart';
import '../../features/workout/domain/entities/workout_preferences_entity.dart';
import '../../features/auth/data/models/user_model.dart';

class LocalDBService {
  static const String workoutBoxName = 'workout_plans';
  static const String preferencesBoxName = 'user_preferences';
  static const String profileBoxName = 'user_profile';
  static const String dietBoxName = 'diet_plans';
  // Generic KV store for non-typed data (pending sync queues, job IDs, flags).
  static const String kvBoxName = 'kv_store';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Workout Entity Adapters
    _registerWorkoutAdapters();

    // Register Preferences Entity Adapters
    _registerPreferencesAdapters();

    // Open boxes
    await Hive.openBox<MonthlyWorkoutPlanEntity>(workoutBoxName);
    await Hive.openBox<WorkoutPreferencesEntity>(preferencesBoxName);
    await Hive.openBox<UserModel>(profileBoxName);
    await Hive.openBox<String>(dietBoxName);
    await Hive.openBox<String>(kvBoxName);
  }

  static void _registerWorkoutAdapters() {
    Hive.registerAdapter(UserModelAdapter()); // ID 40
    Hive.registerAdapter(MuscleGroupAdapter()); // ID 20
    Hive.registerAdapter(ExerciseDifficultyAdapter()); // ID 21
    Hive.registerAdapter(ExerciseSetEntityAdapter()); // ID 22
    Hive.registerAdapter(PlannedExerciseEntityAdapter()); // ID 23
    Hive.registerAdapter(DailyWorkoutPlanEntityAdapter()); // ID 24
    Hive.registerAdapter(WeeklyWorkoutPlanEntityAdapter()); // ID 25
    Hive.registerAdapter(DailyWorkoutTargetEntityAdapter()); // ID 26
    Hive.registerAdapter(MonthlyWorkoutPlanEntityAdapter()); // ID 27
  }

  static void _registerPreferencesAdapters() {
    Hive.registerAdapter(WorkoutGoalAdapter()); // ID 28
    Hive.registerAdapter(TrainingLocationAdapter()); // ID 29
    Hive.registerAdapter(EquipmentAdapter()); // ID 30
    Hive.registerAdapter(TrainingSplitAdapter()); // ID 31
    Hive.registerAdapter(FitnessLevelAdapter()); // ID 32
    Hive.registerAdapter(PreferredWorkoutTimeAdapter()); // ID 33
    Hive.registerAdapter(InjuryTypeAdapter()); // ID 34
    Hive.registerAdapter(InjurySeverityAdapter()); // ID 35
    Hive.registerAdapter(UserInjuryEntityAdapter()); // ID 36
    Hive.registerAdapter(WorkoutPreferencesEntityAdapter()); // ID 37
  }

  static Box<MonthlyWorkoutPlanEntity> get workoutBox =>
      Hive.box<MonthlyWorkoutPlanEntity>(workoutBoxName);

  static Box<WorkoutPreferencesEntity> get preferencesBox =>
      Hive.box<WorkoutPreferencesEntity>(preferencesBoxName);

  static Box<UserModel> get profileBox =>
      Hive.box<UserModel>(profileBoxName);

  static Box<String> get dietBox =>
      Hive.box<String>(dietBoxName);

  static Box<String> get kvBox =>
      Hive.box<String>(kvBoxName);
}
