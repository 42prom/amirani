import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/workout_preferences_entity.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../../../../core/services/workout_plan_storage_service.dart';
import '../../../../core/services/ai_orchestration_service.dart';
import '../../../../core/services/gym_equipment_service.dart';
import '../../../../core/services/workout_progression_engine.dart';
import '../../../../core/providers/tier_limits_provider.dart';
import '../../../../core/models/user_body_metrics.dart';
import '../../../../core/providers/unit_system_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'workout_provider.dart';
import '../../../../core/localization/l10n_provider.dart';

/// Onboarding step enum
enum WorkoutOnboardingStep {
  fitnessCheck, // Step 1: Check injuries from profile
  goalSelection, // Step 2: Select workout goal
  muscleFocus, // NEW: Select target muscle groups
  trainingStyle, // Step 3: Location + equipment + split
  exercisePreferences, // Step 4: Like/dislike exercises
  scheduleSettings, // Step 5: Days, duration, reminders
  generating, // AI generating plan
  complete, // Plan ready
}

/// State for workout onboarding
class WorkoutOnboardingState {
  final WorkoutOnboardingStep currentStep;
  final bool isLoading;
  final String? error;

  // Fitness profile (from profile sync)
  final bool hasInjuriesInProfile;
  final bool noInjuries;
  final String? injuriesText;
  final List<UserInjuryEntity> injuries;

  // User metrics
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final bool isMale;
  final double? targetWeightKg;
  final FitnessLevel fitnessLevel;
  final int experienceYears;
  final bool hasUserMetrics;

  // Goal selection
  final WorkoutGoal? selectedGoal;

  // Training style
  final TrainingLocation location;
  final List<Equipment> availableEquipment;
  final TrainingSplit trainingSplit;
  final Set<MuscleGroup> selectedMuscles;

  // Exercise preferences
  final List<String> likedExercises;
  final List<String> dislikedExercises;

  // Schedule
  final int daysPerWeek;
  final List<int> preferredDays; // 0=Monday, 6=Sunday
  final int sessionDurationMinutes;
  final PreferredWorkoutTime preferredTime;

  // Reminders
  final bool workoutRemindersEnabled;
  final String reminderTime;

  // Generated plan
  final MonthlyWorkoutPlanEntity? generatedPlan;

  const WorkoutOnboardingState({
    this.currentStep = WorkoutOnboardingStep.fitnessCheck,
    this.isLoading = false,
    this.error,
    // Fitness profile
    this.hasInjuriesInProfile = false,
    this.noInjuries = false,
    this.injuriesText,
    this.injuries = const [],
    // User metrics
    this.weightKg,
    this.heightCm,
    this.age,
    this.isMale = true,
    this.targetWeightKg,
    this.fitnessLevel = FitnessLevel.beginner,
    this.experienceYears = 0,
    this.hasUserMetrics = false,
    // Goal
    this.selectedGoal,
    // Training style
    this.location = TrainingLocation.home,
    this.availableEquipment = const [Equipment.bodyweightOnly],
    this.trainingSplit = TrainingSplit.fullBody,
    this.selectedMuscles = const {},
    // Exercise prefs
    this.likedExercises = const [],
    this.dislikedExercises = const [],
    // Schedule
    this.daysPerWeek = 3,
    this.preferredDays = const [0, 2, 4], // Mon, Wed, Fri
    this.sessionDurationMinutes = 45,
    this.preferredTime = PreferredWorkoutTime.morning,
    // Reminders
    this.workoutRemindersEnabled = true,
    this.reminderTime = '08:00',
    // Generated plan
    this.generatedPlan,
  });

  WorkoutOnboardingState copyWith({
    WorkoutOnboardingStep? currentStep,
    bool? isLoading,
    String? error,
    bool? hasInjuriesInProfile,
    bool? noInjuries,
    String? injuriesText,
    List<UserInjuryEntity>? injuries,
    double? weightKg,
    double? heightCm,
    int? age,
    bool? isMale,
    double? targetWeightKg,
    FitnessLevel? fitnessLevel,
    int? experienceYears,
    bool? hasUserMetrics,
    WorkoutGoal? selectedGoal,
    TrainingLocation? location,
    List<Equipment>? availableEquipment,
    TrainingSplit? trainingSplit,
    List<String>? likedExercises,
    List<String>? dislikedExercises,
    int? daysPerWeek,
    List<int>? preferredDays,
    int? sessionDurationMinutes,
    PreferredWorkoutTime? preferredTime,
    bool? workoutRemindersEnabled,
    String? reminderTime,
    Set<MuscleGroup>? selectedMuscles,
    MonthlyWorkoutPlanEntity? generatedPlan,
  }) {
    return WorkoutOnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      hasInjuriesInProfile: hasInjuriesInProfile ?? this.hasInjuriesInProfile,
      noInjuries: noInjuries ?? this.noInjuries,
      injuriesText: injuriesText ?? this.injuriesText,
      injuries: injuries ?? this.injuries,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      isMale: isMale ?? this.isMale,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      experienceYears: experienceYears ?? this.experienceYears,
      hasUserMetrics: hasUserMetrics ?? this.hasUserMetrics,
      selectedGoal: selectedGoal ?? this.selectedGoal,
      location: location ?? this.location,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      trainingSplit: trainingSplit ?? this.trainingSplit,
      selectedMuscles: selectedMuscles ?? this.selectedMuscles,
      likedExercises: likedExercises ?? this.likedExercises,
      dislikedExercises: dislikedExercises ?? this.dislikedExercises,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      preferredDays: preferredDays ?? this.preferredDays,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      preferredTime: preferredTime ?? this.preferredTime,
      workoutRemindersEnabled:
          workoutRemindersEnabled ?? this.workoutRemindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      generatedPlan: generatedPlan ?? this.generatedPlan,
    );
  }
}

/// Workout onboarding notifier
class WorkoutOnboardingNotifier extends StateNotifier<WorkoutOnboardingState> {
  final Ref _ref;

  WorkoutOnboardingNotifier(this._ref) : super(const WorkoutOnboardingState()) {
    _initializeFromProfile();
  }

  /// Initialize state from user profile
  void _initializeFromProfile() {
    final profileSync = _ref.read(profileSyncProvider);

    // Parse injuries from profile (stored in medicalConditions)
    // We look for injury-related keywords in the medical conditions
    final medicalText = profileSync.medicalConditions;
    final hasInjuryData = medicalText.isNotEmpty &&
        _containsInjuryKeywords(medicalText);
    final noInjury = profileSync.noMedicalConditions;

    // Parse user metrics
    final weightKg = _parseDouble(profileSync.weight);
    final heightCm = _parseDouble(profileSync.height);
    final age = _calculateAge(profileSync.dob);
    final isMale = profileSync.gender.toLowerCase() != 'female';
    final hasMetrics = weightKg != null && heightCm != null && age != null;

    state = state.copyWith(
      hasInjuriesInProfile: hasInjuryData || noInjury,
      noInjuries: noInjury,
      injuriesText: hasInjuryData ? medicalText : null,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      isMale: isMale,
      targetWeightKg: profileSync.targetWeightKg,
      hasUserMetrics: hasMetrics,
      currentStep: noInjury
          ? WorkoutOnboardingStep.goalSelection
          : WorkoutOnboardingStep.fitnessCheck,
    );
  }

  /// Check if medical conditions text contains injury-related keywords
  bool _containsInjuryKeywords(String text) {
    final lowerText = text.toLowerCase();
    const injuryKeywords = [
      'injury', 'pain', 'shoulder', 'knee', 'back', 'wrist',
      'ankle', 'hip', 'neck', 'elbow', 'sprain', 'strain',
      'surgery', 'operation', 'fracture', 'torn', 'disc'
    ];
    return injuryKeywords.any((keyword) => lowerText.contains(keyword));
  }

  double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  int? _calculateAge(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    try {
      final birthDate = DateTime.parse(dob);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age > 0 ? age : null;
    } catch (e) {
      return null;
    }
  }

  /// Reset to initial state
  void reset() {
    state = const WorkoutOnboardingState();
    _initializeFromProfile();
  }

  /// Move to next step
  void nextStep() {
    final nextIndex = state.currentStep.index + 1;
    if (nextIndex < WorkoutOnboardingStep.values.length) {
      state = state.copyWith(
        currentStep: WorkoutOnboardingStep.values[nextIndex],
        error: null,
      );
    }
  }

  /// Move to previous step
  void previousStep() {
    final prevIndex = state.currentStep.index - 1;
    if (prevIndex >= 0) {
      state = state.copyWith(
        currentStep: WorkoutOnboardingStep.values[prevIndex],
        error: null,
      );
    }
  }

  /// Confirm fitness data and continue
  void confirmFitnessData() {
    state = state.copyWith(currentStep: WorkoutOnboardingStep.goalSelection);
  }

  /// User confirms they have no injuries
  void confirmNoInjuries() {
    state = state.copyWith(
      noInjuries: true,
      injuries: [],
      currentStep: WorkoutOnboardingStep.goalSelection,
    );
    _ref.read(profileSyncProvider.notifier).updateNoMedicalConditions(true);
  }

  /// Save injuries to profile
  void saveInjuries(String injuriesText) {
    state = state.copyWith(
      injuriesText: injuriesText,
      noInjuries: false,
    );
    // Store injuries in medical conditions field
    _ref.read(profileSyncProvider.notifier).updateMedicalConditions(injuriesText);
  }

  /// Select workout goal
  void selectGoal(WorkoutGoal goal) {
    state = state.copyWith(selectedGoal: goal);
  }

  /// Set training location
  void setLocation(TrainingLocation location) {
    // Reset equipment based on location
    final defaultEquipment = location == TrainingLocation.home
        ? [Equipment.bodyweightOnly]
        : [Equipment.dumbbells, Equipment.barbell, Equipment.machines];

    state = state.copyWith(
      location: location,
      availableEquipment: defaultEquipment,
    );
  }

  /// Toggle equipment
  void toggleEquipment(Equipment equipment) {
    final current = List<Equipment>.from(state.availableEquipment);
    if (current.contains(equipment)) {
      current.remove(equipment);
      // Ensure at least bodyweight
      if (current.isEmpty) {
        current.add(Equipment.bodyweightOnly);
      }
    } else {
      current.add(equipment);
    }
    state = state.copyWith(availableEquipment: current);
  }

  /// Set training split
  void setTrainingSplit(TrainingSplit split) {
    state = state.copyWith(trainingSplit: split);
  }
  
  /// Set target muscles
  void setTargetMuscles(Set<MuscleGroup> muscles) {
    state = state.copyWith(selectedMuscles: muscles);
  }

  /// Set fitness level
  void setFitnessLevel(FitnessLevel level) {
    state = state.copyWith(fitnessLevel: level);
  }

  /// Add liked exercise
  void addLikedExercise(String exercise) {
    final updated = [...state.likedExercises, exercise];
    // Remove from disliked if present
    final disliked = state.dislikedExercises.where((e) => e != exercise).toList();
    state = state.copyWith(likedExercises: updated, dislikedExercises: disliked);
  }

  /// Add disliked exercise
  void addDislikedExercise(String exercise) {
    final updated = [...state.dislikedExercises, exercise];
    // Remove from liked if present
    final liked = state.likedExercises.where((e) => e != exercise).toList();
    state = state.copyWith(dislikedExercises: updated, likedExercises: liked);
  }

  /// Skip exercise (neutral)
  void skipExercise(String exercise) {
    // Just remove from both lists if present
    final liked = state.likedExercises.where((e) => e != exercise).toList();
    final disliked = state.dislikedExercises.where((e) => e != exercise).toList();
    state = state.copyWith(likedExercises: liked, dislikedExercises: disliked);
  }

  /// Set days per week
  void setDaysPerWeek(int days) {
    // Auto-suggest preferred days based on count
    List<int> suggestedDays;
    switch (days) {
      case 2:
        suggestedDays = [1, 4]; // Tue, Fri
        break;
      case 3:
        suggestedDays = [0, 2, 4]; // Mon, Wed, Fri
        break;
      case 4:
        suggestedDays = [0, 1, 3, 4]; // Mon, Tue, Thu, Fri
        break;
      case 5:
        suggestedDays = [0, 1, 2, 3, 4]; // Mon-Fri
        break;
      case 6:
        suggestedDays = [0, 1, 2, 3, 4, 5]; // Mon-Sat
        break;
      default:
        suggestedDays = [0, 2, 4];
    }
    state = state.copyWith(daysPerWeek: days, preferredDays: suggestedDays);
  }

  /// Toggle preferred day
  void togglePreferredDay(int day) {
    final current = List<int>.from(state.preferredDays);
    if (current.contains(day)) {
      current.remove(day);
    } else {
      current.add(day);
      current.sort();
    }
    state = state.copyWith(
      preferredDays: current,
      daysPerWeek: current.length,
    );
  }

  /// Set session duration
  void setSessionDuration(int minutes) {
    state = state.copyWith(sessionDurationMinutes: minutes);
  }

  /// Set preferred time
  void setPreferredTime(PreferredWorkoutTime time) {
    state = state.copyWith(preferredTime: time);
  }

  /// Toggle reminders
  void toggleReminders(bool enabled) {
    state = state.copyWith(workoutRemindersEnabled: enabled);
  }

  /// Set reminder time
  void setReminderTime(String time) {
    state = state.copyWith(reminderTime: time);
  }

  /// Update user metrics when profile changes (called by WorkoutProfileSyncNotifier)
  void updateUserMetrics({
    double? weightKg,
    double? heightCm,
    int? age,
    bool? isMale,
    double? targetWeightKg,
  }) {
    state = state.copyWith(
      weightKg: weightKg ?? state.weightKg,
      heightCm: heightCm ?? state.heightCm,
      age: age ?? state.age,
      isMale: isMale ?? state.isMale,
      targetWeightKg: targetWeightKg ?? state.targetWeightKg,
      hasUserMetrics: (weightKg ?? state.weightKg) != null &&
          (heightCm ?? state.heightCm) != null &&
          (age ?? state.age) != null,
    );
  }

  /// Generate the workout plan using AI Orchestration Service
  Future<void> generatePlan() async {
    state = state.copyWith(
      currentStep: WorkoutOnboardingStep.generating,
      isLoading: true,
      error: null,
    );

    try {
      // Get real user ID from auth state
      final authState = _ref.read(authNotifierProvider);
      final userId = authState is AuthAuthenticated ? authState.user.id : 'unknown_user';

      // Build preferences entity — targetMuscles carries the user's visual muscle selection
      final targetMuscleNames = state.selectedMuscles.map((m) => m.name).toList();

      // When the user has chosen specific muscles, treat this as a custom split.
      // This ensures the plan header shows "Custom Split" instead of "FULLBODY Split".
      final effectiveSplit = targetMuscleNames.isNotEmpty
          ? TrainingSplit.custom
          : state.trainingSplit;

      final preferences = WorkoutPreferencesEntity(
        odUserId: userId,
        goal: state.selectedGoal ?? WorkoutGoal.generalFitness,
        location: state.location,
        availableEquipment: state.availableEquipment,
        outOfOrderMachines: _ref.read(gymEquipmentProvider).outOfOrderMachines,
        trainingSplit: effectiveSplit,
        fitnessLevel: state.fitnessLevel,
        experienceYears: state.experienceYears,
        injuries: state.injuries,
        likedExercises: state.likedExercises,
        dislikedExercises: state.dislikedExercises,
        daysPerWeek: state.daysPerWeek,
        preferredDays: state.preferredDays,
        targetMuscles: targetMuscleNames,
        sessionDurationMinutes: state.sessionDurationMinutes,
        preferredTime: state.preferredTime,
        workoutRemindersEnabled: state.workoutRemindersEnabled,
        reminderTime: state.reminderTime,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Build body metrics so AI can personalise the plan
      final userMetrics = UserBodyMetrics(
        weightKg: state.weightKg,
        heightCm: state.heightCm,
        age: state.age,
        isMale: state.isMale,
        targetWeightKg: state.targetWeightKg,
        unitSystem: _ref.read(unitSystemProvider),
        medicalConditions: state.injuriesText?.isNotEmpty == true
            ? state.injuriesText
            : null,
      );

      // Generate plan using AI Orchestration Service
      // Supports: offline (enhanced mock), API, or direct AI
      // targetMuscleNames is passed explicitly so every strategy path receives it
      final aiService = _ref.read(aiOrchestrationProvider);
      final l10n = _ref.read(l10nProvider);
      final plan = await aiService.generateWorkoutPlan(
        preferences: preferences,
        odUserId: preferences.odUserId,
        userMetrics: userMetrics,
        targetMuscleNames: targetMuscleNames, // ← critical: passes user muscle selection
        languageCode: l10n.altLangCode ?? 'en',
      );

      // Expand the AI week-1 blueprint into a 4-week progressive plan
      // using pure client-side logic — no extra AI calls needed.
      MonthlyWorkoutPlanEntity expandedPlan = plan;
      if (plan.weeks.isNotEmpty) {
        const engine = WorkoutProgressionEngine();
        final progressedWeeks = engine.expandToFourWeeks(
          week1: plan.weeks.first,
          goal: plan.goal,
          planStartDate: plan.startDate,
        );
        expandedPlan = plan.copyWith(weeks: progressedWeeks);
      }

      // Save plan and preferences to storage
      final storage = _ref.read(workoutPlanStorageProvider);
      // Explicitly DELETE the old plan first — guarantees the stale cached plan
      // can never survive a regeneration, regardless of Hive caching behaviour.
      await storage.deletePlan();
      await storage.savePlan(expandedPlan);
      await storage.savePreferences(preferences);
      // Invalidate ALL plan-related providers so WorkoutPage rebuilds immediately with
      // the fresh plan — never shows the old Hive-cached plan.
      _ref.invalidate(savedWorkoutPlanProvider);
      _ref.invalidate(hasWorkoutPlanProvider);
      // Refresh AI limits so dailyRequestsUsed counter is current after generation.
      unawaited(_ref.read(tierLimitsProvider.notifier).refresh());
      // Sync with backend so Hive gets the authoritative UUID-based plan.
      // This prevents the plan from appearing to "revert" on the next refresh
      // (locally-saved plan has timestamp ID; backend plan has UUID — IDs always
      // differ, so without this sync fetchActivePlan() would overwrite on every refresh).
      unawaited(_ref.read(workoutNotifierProvider.notifier).fetchActivePlan());

      state = state.copyWith(
        currentStep: WorkoutOnboardingStep.complete,
        isLoading: false,
        generatedPlan: expandedPlan,
        error: null,
      );
    } catch (e) {
      // 409: backend requires a diet plan before a workout can be generated.
      if (e is DioException && e.response?.statusCode == 409) {
        final msg = (e.response?.data as Map<String, dynamic>?)?['error']?['message'] as String?
            ?? 'A diet plan is required before generating a workout plan. Please complete your nutrition setup first.';
        state = state.copyWith(
          currentStep: WorkoutOnboardingStep.scheduleSettings,
          isLoading: false,
          error: msg,
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate plan: $e',
      );
    }
  }

}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

final workoutOnboardingProvider =
    StateNotifierProvider<WorkoutOnboardingNotifier, WorkoutOnboardingState>(
        (ref) {
  return WorkoutOnboardingNotifier(ref);
});

// ════════════════════════════════════════════════════════════════════════════
// EXERCISE LIST FOR PREFERENCE SWIPER
// ════════════════════════════════════════════════════════════════════════════

/// Get filtered exercises for preference selection
List<String> getFilteredExercises(TrainingLocation location, {List<String>? injuries}) {
  final allExercises = location == TrainingLocation.home
      ? _homeExerciseList
      : _gymExerciseList;

  if (injuries == null || injuries.isEmpty) {
    return allExercises;
  }

  // Filter out exercises that might aggravate injuries
  return allExercises.where((exercise) {
    final lowerEx = exercise.toLowerCase();
    for (final injury in injuries) {
      final lowerInj = injury.toLowerCase();
      if (lowerInj.contains('shoulder') &&
          (lowerEx.contains('press') || lowerEx.contains('raise'))) {
        return false;
      }
      if (lowerInj.contains('knee') &&
          (lowerEx.contains('squat') || lowerEx.contains('lunge'))) {
        return false;
      }
      if (lowerInj.contains('back') &&
          (lowerEx.contains('deadlift') || lowerEx.contains('row'))) {
        return false;
      }
    }
    return true;
  }).toList();
}

const _homeExerciseList = [
  'Pushups',
  'Air Squats',
  'Plank',
  'Lunges',
  'Mountain Climbers',
  'Burpees',
  'Glute Bridges',
  'Superman',
  'Diamond Pushups',
  'Pike Pushups',
  'Dips',
  'Jump Squats',
  'Wall Sit',
  'Crunches',
  'Bicycle Crunches',
  'Leg Raises',
  'High Knees',
  'Jumping Jacks',
];

const _gymExerciseList = [
  'Bench Press',
  'Barbell Squat',
  'Deadlift',
  'Overhead Press',
  'Barbell Row',
  'Lat Pulldown',
  'Leg Press',
  'Bicep Curls',
  'Tricep Pushdown',
  'Lateral Raises',
  'Cable Flyes',
  'Leg Curl',
  'Calf Raises',
  'Pull-ups',
  'Dips',
  'Face Pulls',
  'Romanian Deadlift',
  'Hip Thrust',
];

/// Emoji mapping for exercises
const exerciseEmojis = {
  'Pushups': '💪',
  'Air Squats': '🦵',
  'Plank': '🧘',
  'Lunges': '🏃',
  'Mountain Climbers': '⛰️',
  'Burpees': '🔥',
  'Glute Bridges': '🍑',
  'Superman': '🦸',
  'Bench Press': '🏋️',
  'Barbell Squat': '🦵',
  'Deadlift': '💀',
  'Overhead Press': '🙌',
  'Barbell Row': '🚣',
  'Lat Pulldown': '⬇️',
  'Leg Press': '🦿',
  'Bicep Curls': '💪',
  'Tricep Pushdown': '💪',
  'Pull-ups': '🏋️',
  'Dips': '⬇️',
  'Crunches': '🔄',
  'Jump Squats': '🦘',
  'High Knees': '🦵',
};
