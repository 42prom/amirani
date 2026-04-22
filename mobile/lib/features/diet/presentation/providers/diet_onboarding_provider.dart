import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/diet_preferences_entity.dart';
import '../../domain/entities/monthly_plan_entity.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../../../../core/services/diet_plan_storage_service.dart';
import '../../../../core/utils/food_emoji_registry.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/ai_orchestration_service.dart';
import '../../../../core/services/diet_macro_cycling_engine.dart';
import '../../../../core/providers/tier_limits_provider.dart';
import '../../../../core/services/meal_variety_service.dart';
import '../../../../core/models/user_body_metrics.dart';
import '../../../../core/providers/unit_system_provider.dart';
import '../../domain/utils/diet_shopping_utils.dart';
import 'package:amirani_app/core/localization/l10n_provider.dart';

/// Onboarding step enum
enum DietOnboardingStep {
  healthCheck, // Step 1: Check allergies from profile
  goalSelection, // Step 2: Select diet goal
  dietaryStyle, // Step 3: Dietary restrictions
  foodPreferences, // Step 4: Like/dislike foods
  mealSettings, // Step 5: Meals per day, times, reminders
  generating, // AI generating plan
  complete, // Plan ready
}

/// Activity level for TDEE calculation
enum ActivityLevel {
  sedentary, // Little or no exercise (desk job)
  light, // Light exercise 1-3 days/week
  moderate, // Moderate exercise 3-5 days/week
  active, // Heavy exercise 6-7 days/week
  veryActive, // Very heavy exercise, physical job
}

/// Weight loss intensity
enum WeightLossIntensity {
  mild, // -0.25 kg/week (250 cal deficit)
  optimal, // -0.5 kg/week (500 cal deficit) - recommended
  aggressive, // -0.75 kg/week (750 cal deficit)
  extreme, // -1.0 kg/week (1000 cal deficit) - not recommended long-term
}

/// TDEE Calculator - Mifflin-St Jeor Equation (most accurate)
class TDEECalculator {
  /// Calculate BMR (Basal Metabolic Rate)
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
  }) {
    if (isMale) {
      // Men: BMR = 10 × weight(kg) + 6.25 × height(cm) − 5 × age(y) + 5
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      // Women: BMR = 10 × weight(kg) + 6.25 × height(cm) − 5 × age(y) − 161
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }
  }

  /// Get activity multiplier
  static double getActivityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }

  /// Calculate TDEE (Total Daily Energy Expenditure)
  static double calculateTDEE({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
    required ActivityLevel activityLevel,
  }) {
    final bmr = calculateBMR(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      isMale: isMale,
    );
    return bmr * getActivityMultiplier(activityLevel);
  }

  /// Calculate target calories based on goal
  static int calculateTargetCalories({
    required double tdee,
    required DietGoal goal,
    WeightLossIntensity? lossIntensity,
    double? muscleGainRate, // kg per week
  }) {
    switch (goal) {
      case DietGoal.weightLoss:
        // Calorie deficit based on intensity
        final intensity = lossIntensity ?? WeightLossIntensity.optimal;
        final deficit = _getCalorieDeficit(intensity);
        final target = tdee - deficit;
        // Never go below BMR safety threshold (minimum 1200 women, 1500 men)
        return target.round().clamp(1200, tdee.round());

      case DietGoal.muscleGain:
        // Surplus for muscle gain (200-500 cal)
        final rate = muscleGainRate ?? 0.25;
        final surplus = (rate * 7700 / 7).round(); // 7700 cal = 1kg
        return (tdee + surplus.clamp(200, 500)).round();

      case DietGoal.maintenance:
        return tdee.round();

      case DietGoal.performance:
        // Slight surplus for athletic performance
        return (tdee + 300).round();

      case DietGoal.cleanEating:
        // Slight deficit for clean eating
        return (tdee - 200).round();

      case DietGoal.medicalDiet:
        // Conservative deficit
        return (tdee - 300).round();

      case DietGoal.generalHealth:
        // Balanced approach
        return tdee.round();
    }
  }

  /// Get calorie deficit for weight loss intensity
  static int _getCalorieDeficit(WeightLossIntensity intensity) {
    switch (intensity) {
      case WeightLossIntensity.mild:
        return 250; // ~0.25 kg/week
      case WeightLossIntensity.optimal:
        return 500; // ~0.5 kg/week (recommended)
      case WeightLossIntensity.aggressive:
        return 750; // ~0.75 kg/week
      case WeightLossIntensity.extreme:
        return 1000; // ~1 kg/week (not recommended)
    }
  }

  /// Calculate macro targets based on goal
  static Map<String, int> calculateMacros({
    required int targetCalories,
    required DietGoal goal,
    required double weightKg,
  }) {
    double proteinRatio, carbRatio, fatRatio;

    switch (goal) {
      case DietGoal.weightLoss:
        // High protein to preserve muscle during deficit
        // 2.0-2.2g protein per kg body weight
        final proteinGrams = (weightKg * 2.0).round();
        final proteinCal = proteinGrams * 4;
        final remainingCal = targetCalories - proteinCal;
        // 30% fat, rest carbs
        final fatCal = (remainingCal * 0.35).round();
        final carbCal = remainingCal - fatCal;
        return {
          'protein': proteinGrams,
          'carbs': (carbCal / 4).round(),
          'fats': (fatCal / 9).round(),
        };

      case DietGoal.muscleGain:
        // High protein, moderate carbs for muscle building
        // 1.8-2.0g protein per kg
        final proteinGrams = (weightKg * 1.8).round();
        proteinRatio = (proteinGrams * 4) / targetCalories;
        fatRatio = 0.25;
        carbRatio = 1 - proteinRatio - fatRatio;
        break;

      case DietGoal.performance:
        // Higher carbs for athletic performance
        proteinRatio = 0.25;
        carbRatio = 0.50;
        fatRatio = 0.25;
        break;

      case DietGoal.cleanEating:
      case DietGoal.maintenance:
      case DietGoal.medicalDiet:
      case DietGoal.generalHealth:
        // Balanced macros
        proteinRatio = 0.30;
        carbRatio = 0.40;
        fatRatio = 0.30;
        break;
    }

    return {
      'protein': ((targetCalories * proteinRatio) / 4).round(),
      'carbs': ((targetCalories * carbRatio) / 4).round(),
      'fats': ((targetCalories * fatRatio) / 9).round(),
    };
  }

  /// Estimate weight loss timeline
  static Map<String, dynamic> estimateProgress({
    required double currentWeightKg,
    required double targetWeightKg,
    required int dailyDeficit,
  }) {
    final weightToLose = currentWeightKg - targetWeightKg;
    if (weightToLose <= 0) {
      return {'weeks': 0, 'months': 0, 'message': 'Already at target!'};
    }

    // 7700 cal deficit = 1 kg loss
    final weeksToGoal = (weightToLose * 7700) / (dailyDeficit * 7);
    final monthsToGoal = weeksToGoal / 4.33;

    return {
      'weeks': weeksToGoal.round(),
      'months': monthsToGoal.round(),
      'weeklyLoss': (dailyDeficit * 7 / 7700),
      'message': '~${monthsToGoal.round()} months to reach goal',
    };
  }
}

/// State for diet onboarding
class DietOnboardingState {
  final DietOnboardingStep currentStep;
  final bool isLoading;
  final String? error;

  // Health check data (from profile)
  final bool hasHealthDataInProfile;
  final bool noMedicalConditions;
  final String? medicalConditionsText;
  final List<UserAllergyEntity> allergies;

  // User metrics (from profile) - SMART SYNC
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final bool isMale;
  final ActivityLevel activityLevel;
  final bool hasUserMetrics;

  // Calculated values
  final double? bmr;
  final double? tdee;
  final int? targetCalories;
  final int? targetProtein;
  final int? targetCarbs;
  final int? targetFats;

  // Weight loss specific
  final WeightLossIntensity weightLossIntensity;
  final double? targetWeightKg;
  final Map<String, dynamic>? progressEstimate;

  // User selections
  final DietGoal? selectedGoal;
  final double targetWeightChangePerWeek;
  final DietaryStyle dietaryStyle;
  final List<String> likedFoods;
  final List<String> dislikedFoods;
  final int mealsPerDay;
  final CookingSkill cookingSkill;
  final int maxPrepTimeMinutes;
  final BudgetPreference budget;

  // Meal reminder settings
  final bool mealRemindersEnabled;
  final String breakfastTime;
  final String lunchTime;
  final String dinnerTime;
  final String morningSnackTime;
  final String afternoonSnackTime;

  // Generated plan
  final MonthlyDietPlanEntity? generatedPlan;
  final double generationProgress;

  const DietOnboardingState({
    this.currentStep = DietOnboardingStep.healthCheck,
    this.isLoading = false,
    this.error,
    this.hasHealthDataInProfile = false,
    this.noMedicalConditions = false,
    this.medicalConditionsText,
    this.allergies = const [],
    // User metrics
    this.weightKg,
    this.heightCm,
    this.age,
    this.isMale = true,
    this.activityLevel = ActivityLevel.moderate,
    this.hasUserMetrics = false,
    // Calculated values
    this.bmr,
    this.tdee,
    this.targetCalories,
    this.targetProtein,
    this.targetCarbs,
    this.targetFats,
    // Weight loss
    this.weightLossIntensity = WeightLossIntensity.optimal,
    this.targetWeightKg,
    this.progressEstimate,
    // Selections
    this.selectedGoal,
    this.targetWeightChangePerWeek = -0.5,
    this.dietaryStyle = DietaryStyle.noRestrictions,
    this.likedFoods = const [],
    this.dislikedFoods = const [],
    this.mealsPerDay = 3,
    this.cookingSkill = CookingSkill.moderate,
    this.maxPrepTimeMinutes = 30,
    this.budget = BudgetPreference.standard,
    this.mealRemindersEnabled = true,
    this.breakfastTime = '08:00',
    this.lunchTime = '12:30',
    this.dinnerTime = '19:00',
    this.morningSnackTime = '10:30',
    this.afternoonSnackTime = '16:30',
    this.generatedPlan,
    this.generationProgress = 0.0,
  });

  DietOnboardingState copyWith({
    DietOnboardingStep? currentStep,
    bool? isLoading,
    String? error,
    bool? hasHealthDataInProfile,
    bool? noMedicalConditions,
    String? medicalConditionsText,
    List<UserAllergyEntity>? allergies,
    // User metrics
    double? weightKg,
    double? heightCm,
    int? age,
    bool? isMale,
    ActivityLevel? activityLevel,
    bool? hasUserMetrics,
    // Calculated
    double? bmr,
    double? tdee,
    int? targetCalories,
    int? targetProtein,
    int? targetCarbs,
    int? targetFats,
    // Weight loss
    WeightLossIntensity? weightLossIntensity,
    double? targetWeightKg,
    Map<String, dynamic>? progressEstimate,
    // Selections
    DietGoal? selectedGoal,
    double? targetWeightChangePerWeek,
    DietaryStyle? dietaryStyle,
    List<String>? likedFoods,
    List<String>? dislikedFoods,
    int? mealsPerDay,
    CookingSkill? cookingSkill,
    int? maxPrepTimeMinutes,
    BudgetPreference? budget,
    bool? mealRemindersEnabled,
    String? breakfastTime,
    String? lunchTime,
    String? dinnerTime,
    String? morningSnackTime,
    String? afternoonSnackTime,
    MonthlyDietPlanEntity? generatedPlan,
    double? generationProgress,
  }) {
    return DietOnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasHealthDataInProfile:
          hasHealthDataInProfile ?? this.hasHealthDataInProfile,
      noMedicalConditions: noMedicalConditions ?? this.noMedicalConditions,
      medicalConditionsText:
          medicalConditionsText ?? this.medicalConditionsText,
      allergies: allergies ?? this.allergies,
      // User metrics
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      isMale: isMale ?? this.isMale,
      activityLevel: activityLevel ?? this.activityLevel,
      hasUserMetrics: hasUserMetrics ?? this.hasUserMetrics,
      // Calculated
      bmr: bmr ?? this.bmr,
      tdee: tdee ?? this.tdee,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFats: targetFats ?? this.targetFats,
      // Weight loss
      weightLossIntensity: weightLossIntensity ?? this.weightLossIntensity,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      progressEstimate: progressEstimate ?? this.progressEstimate,
      // Selections
      selectedGoal: selectedGoal ?? this.selectedGoal,
      targetWeightChangePerWeek:
          targetWeightChangePerWeek ?? this.targetWeightChangePerWeek,
      dietaryStyle: dietaryStyle ?? this.dietaryStyle,
      likedFoods: likedFoods ?? this.likedFoods,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      cookingSkill: cookingSkill ?? this.cookingSkill,
      maxPrepTimeMinutes: maxPrepTimeMinutes ?? this.maxPrepTimeMinutes,
      budget: budget ?? this.budget,
      mealRemindersEnabled: mealRemindersEnabled ?? this.mealRemindersEnabled,
      breakfastTime: breakfastTime ?? this.breakfastTime,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      morningSnackTime: morningSnackTime ?? this.morningSnackTime,
      afternoonSnackTime: afternoonSnackTime ?? this.afternoonSnackTime,
      generatedPlan: generatedPlan ?? this.generatedPlan,
      generationProgress: generationProgress ?? this.generationProgress,
    );
  }

  /// Check if we can skip health check step
  bool get canSkipHealthCheck =>
      noMedicalConditions ||
      medicalConditionsText != null && medicalConditionsText!.isNotEmpty;

  /// Get the first step based on profile data
  DietOnboardingStep get initialStep {
    if (noMedicalConditions) {
      // User marked "no health issues" - skip directly to goals
      return DietOnboardingStep.goalSelection;
    } else if (medicalConditionsText != null &&
        medicalConditionsText!.isNotEmpty) {
      // User has health data - show confirmation then goals
      return DietOnboardingStep.healthCheck;
    } else {
      // No data - ask user
      return DietOnboardingStep.healthCheck;
    }
  }
}

/// Diet onboarding notifier
class DietOnboardingNotifier extends StateNotifier<DietOnboardingState> {
  final Ref _ref;

  DietOnboardingNotifier(this._ref) : super(const DietOnboardingState()) {
    _initializeFromProfile();
  }

  /// Initialize state from user profile
  void _initializeFromProfile() {
    final profileSync = _ref.read(profileSyncProvider);

    final hasHealthData = profileSync.medicalConditions.isNotEmpty;
    final noMedical = profileSync.noMedicalConditions;

    // Parse user metrics from profile
    final weightKg = _parseDouble(profileSync.weight);
    final heightCm = _parseDouble(profileSync.height);
    final age = _calculateAge(profileSync.dob);
    final isMale = profileSync.gender.toLowerCase() != 'female';
    final hasMetrics = weightKg != null && heightCm != null && age != null;

    // Calculate BMR and TDEE if we have metrics
    double? bmr;
    double? tdee;
    if (weightKg != null && heightCm != null && age != null) {
      bmr = TDEECalculator.calculateBMR(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        isMale: isMale,
      );
      tdee = TDEECalculator.calculateTDEE(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        isMale: isMale,
        activityLevel: ActivityLevel.moderate, // Default, user can change
      );
    }

    state = state.copyWith(
      hasHealthDataInProfile: hasHealthData || noMedical,
      noMedicalConditions: noMedical,
      medicalConditionsText:
          hasHealthData ? profileSync.medicalConditions : null,
      // User metrics from profile
      targetWeightKg: profileSync.targetWeightKg,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      isMale: isMale,
      hasUserMetrics: hasMetrics,
      bmr: bmr,
      tdee: tdee,
      // Set initial step based on profile data
      currentStep: noMedical
          ? DietOnboardingStep.goalSelection
          : DietOnboardingStep.healthCheck,
    );
  }

  /// Parse double from string (weight, height)
  double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  /// Calculate age from date of birth string
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

  /// Move to next step
  void nextStep() {
    final nextIndex = state.currentStep.index + 1;
    if (nextIndex < DietOnboardingStep.values.length) {
      state = state.copyWith(
        currentStep: DietOnboardingStep.values[nextIndex],
        error: null,
      );
    }
  }

  /// Move to previous step
  void previousStep() {
    final prevIndex = state.currentStep.index - 1;
    if (prevIndex >= 0) {
      state = state.copyWith(
        currentStep: DietOnboardingStep.values[prevIndex],
        error: null,
      );
    }
  }

  /// Go to specific step
  void goToStep(DietOnboardingStep step) {
    state = state.copyWith(currentStep: step, error: null);
  }

  /// Confirm health data and continue
  void confirmHealthData() {
    state = state.copyWith(currentStep: DietOnboardingStep.goalSelection);
  }

  /// User confirms they have no health issues
  void confirmNoHealthIssues() {
    state = state.copyWith(
      noMedicalConditions: true,
      allergies: [],
      currentStep: DietOnboardingStep.goalSelection,
    );
    // Update profile
    _ref.read(profileSyncProvider.notifier).updateNoMedicalConditions(true);
  }

  /// Add allergy from user input
  void addAllergy(UserAllergyEntity allergy) {
    final updated = [...state.allergies, allergy];
    state = state.copyWith(allergies: updated);
  }

  /// Remove allergy
  void removeAllergy(int index) {
    final updated = [...state.allergies];
    updated.removeAt(index);
    state = state.copyWith(allergies: updated);
  }

  /// Save health conditions to profile
  void saveHealthConditions(String conditions) {
    state = state.copyWith(
      medicalConditionsText: conditions,
      noMedicalConditions: false,
    );
    // Update profile
    _ref.read(profileSyncProvider.notifier).updateMedicalConditions(conditions);
  }

  /// Select diet goal and calculate optimal calories
  void selectGoal(DietGoal goal, {double? weeklyChange}) {
    double change = weeklyChange ?? state.targetWeightChangePerWeek;

    // Set default weight change based on goal
    if (weeklyChange == null) {
      switch (goal) {
        case DietGoal.weightLoss:
          change = -0.5;
          break;
        case DietGoal.muscleGain:
          change = 0.3;
          break;
        case DietGoal.maintenance:
        case DietGoal.cleanEating:
        case DietGoal.medicalDiet:
        case DietGoal.performance:
        case DietGoal.generalHealth:
          change = 0.0;
          break;
      }
    }

    // Calculate target calories if we have TDEE
    int? targetCal;
    int? targetPro;
    int? targetCarb;
    int? targetFats;

    if (state.tdee != null && state.weightKg != null) {
      targetCal = TDEECalculator.calculateTargetCalories(
        tdee: state.tdee!,
        goal: goal,
        lossIntensity: state.weightLossIntensity,
      );

      final macros = TDEECalculator.calculateMacros(
        targetCalories: targetCal,
        goal: goal,
        weightKg: state.weightKg!,
      );

      targetPro = macros['protein'];
      targetCarb = macros['carbs'];
      targetFats = macros['fats'];
    }

    state = state.copyWith(
      selectedGoal: goal,
      targetWeightChangePerWeek: change,
      targetCalories: targetCal,
      targetProtein: targetPro,
      targetCarbs: targetCarb,
      targetFats: targetFats,
    );
  }

  /// Set activity level and recalculate TDEE
  void setActivityLevel(ActivityLevel level) {
    if (state.weightKg == null || state.heightCm == null || state.age == null) {
      state = state.copyWith(activityLevel: level);
      return;
    }

    // Recalculate TDEE with new activity level
    final newTdee = TDEECalculator.calculateTDEE(
      weightKg: state.weightKg!,
      heightCm: state.heightCm!,
      age: state.age!,
      isMale: state.isMale,
      activityLevel: level,
    );

    state = state.copyWith(
      activityLevel: level,
      tdee: newTdee,
    );

    // Recalculate calories if goal is set
    if (state.selectedGoal != null) {
      selectGoal(state.selectedGoal!);
    }
  }

  /// Set weight loss intensity (for weight loss goal)
  void setWeightLossIntensity(WeightLossIntensity intensity) {
    state = state.copyWith(weightLossIntensity: intensity);

    // Recalculate if goal is weight loss
    if (state.selectedGoal == DietGoal.weightLoss) {
      selectGoal(DietGoal.weightLoss);
    }
  }

  /// Set target weight (for progress estimation)
  void setTargetWeight(double targetKg) {
    if (state.weightKg == null || state.tdee == null) {
      state = state.copyWith(targetWeightKg: targetKg);
      return;
    }

    // Calculate deficit based on intensity
    final deficitPerDay = switch (state.weightLossIntensity) {
      WeightLossIntensity.mild => 250,
      WeightLossIntensity.optimal => 500,
      WeightLossIntensity.aggressive => 750,
      WeightLossIntensity.extreme => 1000,
    };

    final progress = TDEECalculator.estimateProgress(
      currentWeightKg: state.weightKg!,
      targetWeightKg: targetKg,
      dailyDeficit: deficitPerDay,
    );

    state = state.copyWith(
      targetWeightKg: targetKg,
      progressEstimate: progress,
    );
  }

  /// Update user metrics manually (if not from profile)
  void updateUserMetrics({
    double? weightKg,
    double? heightCm,
    int? age,
    bool? isMale,
    double? targetWeightKg,
  }) {
    final newWeight = weightKg ?? state.weightKg;
    final newHeight = heightCm ?? state.heightCm;
    final newAge = age ?? state.age;
    final newIsMale = isMale ?? state.isMale;

    if (newWeight == null || newHeight == null || newAge == null) {
      state = state.copyWith(
        weightKg: newWeight,
        heightCm: newHeight,
        age: newAge,
        isMale: newIsMale,
      );
      return;
    }

    // Calculate BMR and TDEE
    final bmr = TDEECalculator.calculateBMR(
      weightKg: newWeight,
      heightCm: newHeight,
      age: newAge,
      isMale: newIsMale,
    );

    final tdee = TDEECalculator.calculateTDEE(
      weightKg: newWeight,
      heightCm: newHeight,
      age: newAge,
      isMale: newIsMale,
      activityLevel: state.activityLevel,
    );

    state = state.copyWith(
      weightKg: newWeight,
      heightCm: newHeight,
      age: newAge,
      isMale: newIsMale,
      hasUserMetrics: true,
      bmr: bmr,
      tdee: tdee,
    );

    // Recalculate calories if goal is set
    if (state.selectedGoal != null) {
      selectGoal(state.selectedGoal!);
    }

    // Apply target weight if provided
    if (targetWeightKg != null && targetWeightKg != state.targetWeightKg) {
      setTargetWeight(targetWeightKg);
    }
  }

  /// Set dietary style
  void setDietaryStyle(DietaryStyle style) {
    state = state.copyWith(dietaryStyle: style);
  }

  /// Add liked food
  void addLikedFood(String food) {
    if (!state.likedFoods.contains(food)) {
      state = state.copyWith(likedFoods: [...state.likedFoods, food]);
    }
    // Remove from disliked if present
    if (state.dislikedFoods.contains(food)) {
      final updated = state.dislikedFoods.where((f) => f != food).toList();
      state = state.copyWith(dislikedFoods: updated);
    }
  }

  /// Add disliked food
  void addDislikedFood(String food) {
    if (!state.dislikedFoods.contains(food)) {
      state = state.copyWith(dislikedFoods: [...state.dislikedFoods, food]);
    }
    // Remove from liked if present
    if (state.likedFoods.contains(food)) {
      final updated = state.likedFoods.where((f) => f != food).toList();
      state = state.copyWith(likedFoods: updated);
    }
  }

  /// Start a premium, non-linear progress simulation
  void startProgressSimulation() {
    // Reset to initial jump
    state = state.copyWith(generationProgress: 0.15);

    // Create a series of ticks that slow down as they approach 95%
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || state.currentStep != DietOnboardingStep.generating) {
        return;
      }
      state = state.copyWith(generationProgress: 0.35);
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted || state.currentStep != DietOnboardingStep.generating) {
        return;
      }
      state = state.copyWith(generationProgress: 0.55);
    });

    Future.delayed(const Duration(milliseconds: 5000), () {
      if (!mounted || state.currentStep != DietOnboardingStep.generating) {
        return;
      }
      state = state.copyWith(generationProgress: 0.75);
    });

    // Slow crawl from 75% to 95%
    void crawl(double current) {
      if (!mounted ||
          state.currentStep != DietOnboardingStep.generating ||
          current >= 0.95) {
        return;
      }

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted || state.currentStep != DietOnboardingStep.generating) {
          return;
        }
        final next = current + 0.02;
        if (next < 0.96) {
          state = state.copyWith(generationProgress: next);
          crawl(next);
        }
      });
    }

    Future.delayed(const Duration(milliseconds: 8000), () => crawl(0.75));
  }

  /// Skip food (neither like nor dislike)
  void skipFood(String food) {
    // Remove from both lists if present
    final updatedLiked = state.likedFoods.where((f) => f != food).toList();
    final updatedDisliked =
        state.dislikedFoods.where((f) => f != food).toList();
    state = state.copyWith(
      likedFoods: updatedLiked,
      dislikedFoods: updatedDisliked,
    );
  }

  /// Set meals per day (min 2, max 5)
  void setMealsPerDay(int count) {
    state = state.copyWith(mealsPerDay: count.clamp(2, 5));
  }

  /// Update weight and save to profile
  void updateWeight(double weightKg) {
    updateUserMetrics(weightKg: weightKg);
    _ref.read(profileSyncProvider.notifier).saveProfile(
          weight: weightKg.toStringAsFixed(1),
        );
  }

  /// Update height and save to profile
  void updateHeight(double heightCm) {
    updateUserMetrics(heightCm: heightCm);
    _ref.read(profileSyncProvider.notifier).saveProfile(
          height: heightCm.toStringAsFixed(0),
        );
  }

  /// Set cooking skill
  void setCookingSkill(CookingSkill skill) {
    state = state.copyWith(cookingSkill: skill);
  }

  /// Set max prep time
  void setMaxPrepTime(int minutes) {
    state = state.copyWith(maxPrepTimeMinutes: minutes);
  }

  /// Set budget preference
  void setBudget(BudgetPreference budget) {
    state = state.copyWith(budget: budget);
  }

  /// Toggle meal reminders
  void toggleMealReminders(bool enabled) {
    state = state.copyWith(mealRemindersEnabled: enabled);
  }

  /// Set meal time
  void setMealTime(MealType type, String time) {
    switch (type) {
      case MealType.breakfast:
        state = state.copyWith(breakfastTime: time);
        break;
      case MealType.lunch:
        state = state.copyWith(lunchTime: time);
        break;
      case MealType.dinner:
        state = state.copyWith(dinnerTime: time);
        break;
      case MealType.morningSnack:
        state = state.copyWith(morningSnackTime: time);
        break;
      case MealType.afternoonSnack:
        state = state.copyWith(afternoonSnackTime: time);
        break;
      case MealType.snack:
        state = state.copyWith(
          morningSnackTime: time,
          afternoonSnackTime: time,
        );
        break;
    }
  }

  /// Generate the diet plan using AI
  Future<void> generatePlan() async {
    if (state.selectedGoal == null) {
      state = state.copyWith(error: 'Please select a goal first');
      return;
    }

    state = state.copyWith(
      currentStep: DietOnboardingStep.generating,
      isLoading: true,
      error: null,
      generationProgress: 0.1, // Start with a jump
    );

    // Start progress simulation
    startProgressSimulation();

    try {
      // Get real user ID from auth state
      final authState = _ref.read(authNotifierProvider);
      final userId = authState is AuthAuthenticated ? authState.user.id : 'unknown_user';

      // Build preferences entity
      final preferences = DietPreferencesEntity(
        odUserId: userId,
        goal: state.selectedGoal!,
        targetWeightChangePerWeek: state.targetWeightChangePerWeek,
        dietaryStyle: state.dietaryStyle,
        allergies: state.allergies,
        likedFoods: state.likedFoods,
        dislikedFoods: state.dislikedFoods,
        mealsPerDay: state.mealsPerDay,
        cookingSkill: state.cookingSkill,
        maxPrepTimeMinutes: state.maxPrepTimeMinutes,
        budget: state.budget,
        mealRemindersEnabled: state.mealRemindersEnabled,
        breakfastTime: state.breakfastTime,
        lunchTime: state.lunchTime,
        dinnerTime: state.dinnerTime,
        morningSnackTime: state.morningSnackTime,
        afternoonSnackTime: state.afternoonSnackTime,
        createdAt: DateTime.now(),
      );

      // Build body metrics so AI can personalise calories/macros correctly
      final userMetrics = UserBodyMetrics(
        weightKg: state.weightKg,
        heightCm: state.heightCm,
        age: state.age,
        isMale: state.isMale,
        targetWeightKg: state.targetWeightKg,
        targetCalories: state.targetCalories,
        tdee: state.tdee?.round(),
        targetProteinG: state.targetProtein,
        unitSystem: _ref.read(unitSystemProvider),
        medicalConditions: state.medicalConditionsText?.isNotEmpty == true
            ? state.medicalConditionsText
            : null,
      );

      // Call AI service to generate plan
      MonthlyDietPlanEntity plan;
      try {
        final l10n = _ref.read(l10nProvider);
        plan = await _ref.read(aiOrchestrationProvider).generateDietPlan(
          preferences: preferences,
          odUserId: userId,
          userMetrics: userMetrics,
          languageCode: l10n.altLangCode ?? 'en',
        );
      } catch (aiError) {
        // Fallback to offline mock generation if strategy is offline or DeepSeek fails
        await Future.delayed(const Duration(seconds: 2));
        plan = _generateMockPlan(preferences);
      }

      // Expand AI week-1 blueprint into a 4-week macro-cycling plan,
      // then rotate meal names for weeks 2-4 — pure client-side, no AI calls.
      const cyclingEngine = DietMacroCyclingEngine();
      MonthlyDietPlanEntity expandedPlan = cyclingEngine.expandToFourWeeks(plan);

      final varietyService = MealVarietyService();
      await varietyService.init();
      expandedPlan = varietyService.applyVariety(expandedPlan);

      // Auto-save plan to local storage for persistence
      final storage = _ref.read(dietPlanStorageProvider);
      await storage.savePlan(expandedPlan);
      await storage.saveIsAIGenerated(true);
      await storage.savePreferences(preferences);
      // Refresh AI limits so dailyRequestsUsed counter is current after generation.
      unawaited(_ref.read(tierLimitsProvider.notifier).refresh());

      state = state.copyWith(
        isLoading: false,
        generatedPlan: expandedPlan,
        currentStep: DietOnboardingStep.complete,
        generationProgress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentStep: DietOnboardingStep.mealSettings,
      );
    }
  }

  /// Generate mock plan for testing
  MonthlyDietPlanEntity _generateMockPlan(DietPreferencesEntity preferences) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(const Duration(days: 30));

    // Get macro ratios based on dietary style
    final macroRatios = _getMacroRatiosForStyle(preferences.dietaryStyle);

    // Use SMART calculated calories from state, or fallback to defaults
    int targetCalories;
    int targetProtein;
    int targetCarbs;
    int targetFats;

    if (state.targetCalories != null) {
      // Use TDEE-based calculated values with dietary-style-specific ratios
      targetCalories = state.targetCalories!;
      targetProtein = (targetCalories * macroRatios['protein']! / 4).round();
      targetCarbs = (targetCalories * macroRatios['carbs']! / 4).round();
      targetFats = (targetCalories * macroRatios['fats']! / 9).round();
    } else {
      // Fallback to generic defaults (no user metrics available)
      switch (preferences.goal) {
        case DietGoal.weightLoss:
          targetCalories = 1800;
          break;
        case DietGoal.muscleGain:
          targetCalories = 2500;
          break;
        case DietGoal.performance:
          targetCalories = 2800;
          break;
        case DietGoal.maintenance:
        case DietGoal.cleanEating:
        case DietGoal.medicalDiet:
        case DietGoal.generalHealth:
          targetCalories = 2000;
          break;
      }
      targetProtein = (targetCalories * macroRatios['protein']! / 4).round();
      targetCarbs = (targetCalories * macroRatios['carbs']! / 4).round();
      targetFats = (targetCalories * macroRatios['fats']! / 9).round();
    }

    final macroTarget = DailyMacroTargetEntity(
      calories: targetCalories,
      protein: targetProtein,
      carbs: targetCarbs,
      fats: targetFats,
    );

    // Generate 4 weeks
    final weeks = <WeeklyPlanEntity>[];
    for (int w = 0; w < 4; w++) {
      final weekStart = startDate.add(Duration(days: w * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final days = <DailyPlanEntity>[];

      for (int d = 0; d < 7; d++) {
        final date = weekStart.add(Duration(days: d));
        days.add(_generateDayPlan(date, preferences, macroTarget));
      }

      weeks.add(WeeklyPlanEntity(
        weekNumber: w + 1,
        startDate: weekStart,
        endDate: weekEnd,
        days: days,
      ));
    }

    return MonthlyDietPlanEntity(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      odUserId: preferences.odUserId,
      startDate: startDate,
      endDate: endDate,
      goal: preferences.goal,
      macroTarget: macroTarget,
      weeks: weeks,
      shoppingLists: buildShoppingLists(weeks),
      createdAt: DateTime.now(),
    );
  }

  DailyPlanEntity _generateDayPlan(
    DateTime date,
    DietPreferencesEntity preferences,
    DailyMacroTargetEntity macroTarget,
  ) {
    final meals = <PlannedMealEntity>[];
    final mealsCount = preferences.mealsPerDay;
    final caloriesPerMeal = macroTarget.calories ~/ mealsCount;

    // Get meal types based on meals per day count
    final mealTypes = _getMealTypesForCount(mealsCount);

    for (int i = 0; i < mealTypes.length; i++) {
      final mealType = mealTypes[i];
      final mealData = _getMealForDietaryStyle(
        mealType,
        preferences.dietaryStyle,
        caloriesPerMeal,
        date,
        i, // day variation index
      );

      // Calculate macros based on dietary style
      final macroRatios = _getMacroRatiosForStyle(preferences.dietaryStyle);

      meals.add(PlannedMealEntity(
        id: 'meal_${date.millisecondsSinceEpoch}_${mealType.name}',
        type: mealType,
        name: mealData['name'] as String,
        description: mealData['description'] as String,
        ingredients: mealData['ingredients'] as List<IngredientEntity>,
        instructions: mealData['instructions'] as String,
        prepTimeMinutes: mealData['prepTime'] as int,
        nutrition: NutritionInfoEntity(
          calories: caloriesPerMeal,
          protein: (caloriesPerMeal * macroRatios['protein']! / 4).round(),
          carbs: (caloriesPerMeal * macroRatios['carbs']! / 4).round(),
          fats: (caloriesPerMeal * macroRatios['fats']! / 9).round(),
        ),
        imageUrl: mealData['imageUrl'] as String,
        scheduledTime: _getMealTime(mealType, preferences),
      ));
    }

    return DailyPlanEntity(
      id: 'day_${date.millisecondsSinceEpoch}',
      date: date,
      meals: meals,
      targetCalories: macroTarget.calories,
      targetProtein: macroTarget.protein,
      targetCarbs: macroTarget.carbs,
      targetFats: macroTarget.fats,
    );
  }

  /// Get meal types based on meals per day count
  List<MealType> _getMealTypesForCount(int count) {
    switch (count) {
      case 2:
        // Fasting style - lunch and dinner only
        return [MealType.lunch, MealType.dinner];
      case 3:
        return [MealType.breakfast, MealType.lunch, MealType.dinner];
      case 4:
        return [
          MealType.breakfast,
          MealType.lunch,
          MealType.snack,
          MealType.dinner
        ];
      case 5:
        // Two snacks
        return [
          MealType.breakfast,
          MealType.snack,
          MealType.lunch,
          MealType.snack,
          MealType.dinner
        ];
      default:
        return [MealType.breakfast, MealType.lunch, MealType.dinner];
    }
  }

  /// Get meal time based on type
  /// Get macro ratios based on dietary style (protein, carbs, fat as percentages)
  Map<String, double> _getMacroRatiosForStyle(DietaryStyle style) {
    switch (style) {
      case DietaryStyle.vegan:
        // Plant-based: higher carbs, moderate protein, lower fat
        return {'protein': 0.20, 'carbs': 0.60, 'fats': 0.20};
      case DietaryStyle.vegetarian:
        // Balanced with dairy/eggs for protein
        return {'protein': 0.25, 'carbs': 0.50, 'fats': 0.25};
      case DietaryStyle.keto:
        // Very low carb, high fat
        return {'protein': 0.25, 'carbs': 0.05, 'fats': 0.70};
      case DietaryStyle.mediterranean:
        // Balanced with healthy fats
        return {'protein': 0.25, 'carbs': 0.45, 'fats': 0.30};
      case DietaryStyle.pescatarian:
      case DietaryStyle.halal:
      case DietaryStyle.kosher:
      case DietaryStyle.noRestrictions:
        // Standard balanced macros
        // If goal is general health, ensure a very balanced 30/40/30 split
        if (state.selectedGoal == DietGoal.generalHealth) {
          return {'protein': 0.30, 'carbs': 0.40, 'fats': 0.30};
        }
        return {'protein': 0.30, 'carbs': 0.45, 'fats': 0.25};
    }
  }

  String _getMealTime(MealType type, DietPreferencesEntity preferences) {
    switch (type) {
      case MealType.breakfast:
        return preferences.breakfastTime ?? '08:00';
      case MealType.lunch:
        return preferences.lunchTime ?? '12:30';
      case MealType.dinner:
        return preferences.dinnerTime ?? '19:00';
      case MealType.morningSnack:
        return preferences.morningSnackTime ?? '10:30';
      case MealType.afternoonSnack:
        return preferences.afternoonSnackTime ?? '16:30';
      case MealType.snack:
        return preferences.afternoonSnackTime ?? preferences.morningSnackTime ?? '16:30';
    }
  }

  /// Generate appropriate meal based on dietary style
  Map<String, dynamic> _getMealForDietaryStyle(
    MealType type,
    DietaryStyle style,
    int targetCalories,
    DateTime date,
    int variation,
  ) {
    // Rotate through variations based on day
    final dayIndex = date.day % 7;

    switch (style) {
      case DietaryStyle.vegan:
        return _getVeganMeal(type, dayIndex);
      case DietaryStyle.vegetarian:
        return _getVegetarianMeal(type, dayIndex);
      case DietaryStyle.pescatarian:
        return _getPescatarianMeal(type, dayIndex);
      case DietaryStyle.keto:
        return _getKetoMeal(type, dayIndex);
      case DietaryStyle.mediterranean:
        return _getMediterraneanMeal(type, dayIndex);
      case DietaryStyle.halal:
      case DietaryStyle.kosher:
      case DietaryStyle.noRestrictions:
        return _getStandardMeal(type, dayIndex);
    }
  }

  Map<String, dynamic> _getVeganMeal(MealType type, int variation) {
    final meals = {
      MealType.breakfast: [
        {
          'name': 'Oatmeal with Banana',
          'description': 'Warm oatmeal topped with banana and maple syrup',
          'ingredients': [
            const IngredientEntity(
                name: 'Oatmeal',
                amount: '80',
                unit: 'g',
                calories: 300,
                carbs: 54,
                protein: 10,
                fats: 5),
            const IngredientEntity(
                name: 'Banana',
                amount: '1',
                unit: 'medium',
                calories: 105,
                carbs: 27,
                protein: 1,
                fats: 0),
            const IngredientEntity(
                name: 'Maple Syrup',
                amount: '1',
                unit: 'tbsp',
                calories: 52,
                carbs: 13,
                protein: 0,
                fats: 0),
            const IngredientEntity(
                name: 'Almond Milk',
                amount: '200',
                unit: 'ml',
                calories: 30,
                carbs: 1,
                protein: 1,
                fats: 2),
          ],
          'instructions':
              '1. Cook oatmeal with almond milk\n2. Slice banana\n3. Top with maple syrup',
          'prepTime': 10,
          'imageUrl':
              'https://images.unsplash.com/photo-1517673400267-0251440c45dc?w=400',
        },
        {
          'name': 'Smoothie Bowl',
          'description': 'Frozen fruit blend with granola',
          'ingredients': [
            const IngredientEntity(
                name: 'Frozen Berries',
                amount: '200',
                unit: 'g',
                calories: 100,
                carbs: 24,
                protein: 2,
                fats: 0),
            const IngredientEntity(
                name: 'Banana',
                amount: '1',
                unit: 'medium',
                calories: 105,
                carbs: 27,
                protein: 1,
                fats: 0),
            const IngredientEntity(
                name: 'Granola',
                amount: '40',
                unit: 'g',
                calories: 180,
                carbs: 30,
                protein: 4,
                fats: 6),
            const IngredientEntity(
                name: 'Oat Milk',
                amount: '100',
                unit: 'ml',
                calories: 50,
                carbs: 8,
                protein: 1,
                fats: 1),
          ],
          'instructions':
              '1. Blend frozen fruits with milk\n2. Pour into bowl\n3. Top with granola',
          'prepTime': 8,
          'imageUrl':
              'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=400',
        },
        {
          'name': 'Toast with Jam',
          'description': 'Whole grain toast with fruit jam',
          'ingredients': [
            const IngredientEntity(
                name: 'Whole Grain Bread',
                amount: '2',
                unit: 'slices',
                calories: 160,
                carbs: 28,
                protein: 6,
                fats: 2),
            const IngredientEntity(
                name: 'Fruit Jam',
                amount: '2',
                unit: 'tbsp',
                calories: 100,
                carbs: 26,
                protein: 0,
                fats: 0),
            const IngredientEntity(
                name: 'Orange Juice',
                amount: '200',
                unit: 'ml',
                calories: 90,
                carbs: 21,
                protein: 2,
                fats: 0),
          ],
          'instructions': '1. Toast bread\n2. Spread jam\n3. Serve with juice',
          'prepTime': 5,
          'imageUrl':
              'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400',
        },
      ],
      MealType.lunch: [
        {
          'name': 'Buddha Bowl',
          'description': 'Quinoa bowl with roasted vegetables',
          'ingredients': [
            const IngredientEntity(
                name: 'Quinoa',
                amount: '150',
                unit: 'g',
                calories: 180,
                carbs: 32,
                protein: 7,
                fats: 3),
            const IngredientEntity(
                name: 'Chickpeas',
                amount: '100',
                unit: 'g',
                calories: 164,
                carbs: 27,
                protein: 9,
                fats: 3),
            const IngredientEntity(
                name: 'Sweet Potato',
                amount: '100',
                unit: 'g',
                calories: 86,
                carbs: 20,
                protein: 2,
                fats: 0),
            const IngredientEntity(
                name: 'Kale',
                amount: '50',
                unit: 'g',
                calories: 25,
                carbs: 5,
                protein: 2,
                fats: 0),
          ],
          'instructions':
              '1. Cook quinoa\n2. Roast vegetables\n3. Combine in bowl',
          'prepTime': 25,
          'imageUrl':
              'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
        },
        {
          'name': 'Lentil Soup',
          'description': 'Hearty lentil soup with vegetables',
          'ingredients': [
            const IngredientEntity(
                name: 'Red Lentils',
                amount: '100',
                unit: 'g',
                calories: 116,
                carbs: 20,
                protein: 9,
                fats: 0),
            const IngredientEntity(
                name: 'Carrots',
                amount: '100',
                unit: 'g',
                calories: 41,
                carbs: 10,
                protein: 1,
                fats: 0),
            const IngredientEntity(
                name: 'Crusty Bread',
                amount: '60',
                unit: 'g',
                calories: 160,
                carbs: 30,
                protein: 5,
                fats: 2),
            const IngredientEntity(
                name: 'Vegetable Broth',
                amount: '300',
                unit: 'ml',
                calories: 15,
                carbs: 3,
                protein: 1,
                fats: 0),
          ],
          'instructions':
              '1. Simmer lentils with vegetables\n2. Season to taste\n3. Serve with bread',
          'prepTime': 30,
          'imageUrl':
              'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=400',
        },
        {
          'name': 'Pasta Primavera',
          'description': 'Pasta with fresh vegetables in tomato sauce',
          'ingredients': [
            const IngredientEntity(
                name: 'Whole Wheat Pasta',
                amount: '100',
                unit: 'g',
                calories: 174,
                carbs: 37,
                protein: 7,
                fats: 1),
            const IngredientEntity(
                name: 'Tomato Sauce',
                amount: '100',
                unit: 'g',
                calories: 30,
                carbs: 7,
                protein: 1,
                fats: 0),
            const IngredientEntity(
                name: 'Zucchini',
                amount: '100',
                unit: 'g',
                calories: 17,
                carbs: 3,
                protein: 1,
                fats: 0),
            const IngredientEntity(
                name: 'Bell Peppers',
                amount: '100',
                unit: 'g',
                calories: 31,
                carbs: 6,
                protein: 1,
                fats: 0),
          ],
          'instructions':
              '1. Cook pasta\n2. Sauté vegetables\n3. Combine with sauce',
          'prepTime': 20,
          'imageUrl':
              'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=400',
        },
      ],
      MealType.dinner: [
        {
          'name': 'Tofu Stir Fry',
          'description': 'Crispy tofu with vegetables and rice',
          'ingredients': [
            const IngredientEntity(
                name: 'Tofu',
                amount: '150',
                unit: 'g',
                calories: 130,
                carbs: 3,
                protein: 14,
                fats: 8),
            const IngredientEntity(
                name: 'Mixed Vegetables',
                amount: '150',
                unit: 'g',
                calories: 50,
                carbs: 10,
                protein: 2,
                fats: 0),
            const IngredientEntity(
                name: 'Brown Rice',
                amount: '150',
                unit: 'g',
                calories: 165,
                carbs: 35,
                protein: 4,
                fats: 1),
            const IngredientEntity(
                name: 'Soy Sauce',
                amount: '2',
                unit: 'tbsp',
                calories: 20,
                carbs: 2,
                protein: 2,
                fats: 0),
          ],
          'instructions':
              '1. Press and cube tofu\n2. Stir fry until crispy\n3. Add vegetables\n4. Serve with rice',
          'prepTime': 30,
          'imageUrl':
              'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
        },
        {
          'name': 'Bean Burrito Bowl',
          'description': 'Mexican-style bowl with black beans',
          'ingredients': [
            const IngredientEntity(
                name: 'Black Beans',
                amount: '150',
                unit: 'g',
                calories: 132,
                carbs: 24,
                protein: 9,
                fats: 0),
            const IngredientEntity(
                name: 'Brown Rice',
                amount: '150',
                unit: 'g',
                calories: 165,
                carbs: 35,
                protein: 4,
                fats: 1),
            const IngredientEntity(
                name: 'Corn',
                amount: '80',
                unit: 'g',
                calories: 77,
                carbs: 17,
                protein: 3,
                fats: 1),
            const IngredientEntity(
                name: 'Salsa',
                amount: '60',
                unit: 'g',
                calories: 20,
                carbs: 4,
                protein: 1,
                fats: 0),
          ],
          'instructions':
              '1. Warm beans and rice\n2. Add corn\n3. Top with salsa',
          'prepTime': 15,
          'imageUrl':
              'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?w=400',
        },
        {
          'name': 'Vegetable Curry',
          'description': 'Coconut curry with mixed vegetables',
          'ingredients': [
            const IngredientEntity(
                name: 'Chickpeas',
                amount: '100',
                unit: 'g',
                calories: 164,
                carbs: 27,
                protein: 9,
                fats: 3),
            const IngredientEntity(
                name: 'Cauliflower',
                amount: '100',
                unit: 'g',
                calories: 25,
                carbs: 5,
                protein: 2,
                fats: 0),
            const IngredientEntity(
                name: 'Basmati Rice',
                amount: '150',
                unit: 'g',
                calories: 195,
                carbs: 45,
                protein: 4,
                fats: 0),
            const IngredientEntity(
                name: 'Light Coconut Milk',
                amount: '100',
                unit: 'ml',
                calories: 50,
                carbs: 2,
                protein: 0,
                fats: 5),
          ],
          'instructions':
              '1. Sauté vegetables\n2. Add coconut milk and spices\n3. Serve with rice',
          'prepTime': 35,
          'imageUrl':
              'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=400',
        },
      ],
      MealType.snack: [
        {
          'name': 'Fresh Fruit Bowl',
          'description': 'Mixed fresh seasonal fruits',
          'ingredients': [
            const IngredientEntity(
                name: 'Apple',
                amount: '1',
                unit: 'medium',
                calories: 95,
                carbs: 25,
                protein: 0,
                fats: 0),
            const IngredientEntity(
                name: 'Orange',
                amount: '1',
                unit: 'medium',
                calories: 62,
                carbs: 15,
                protein: 1,
                fats: 0),
            const IngredientEntity(
                name: 'Grapes',
                amount: '100',
                unit: 'g',
                calories: 69,
                carbs: 18,
                protein: 1,
                fats: 0),
          ],
          'instructions': 'Wash and slice fruits, serve fresh',
          'prepTime': 5,
          'imageUrl':
              'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400',
        },
        {
          'name': 'Rice Cakes with Banana',
          'description': 'Light rice cakes topped with banana',
          'ingredients': [
            const IngredientEntity(
                name: 'Rice Cakes',
                amount: '3',
                unit: 'pieces',
                calories: 105,
                carbs: 23,
                protein: 2,
                fats: 0),
            const IngredientEntity(
                name: 'Banana',
                amount: '1',
                unit: 'medium',
                calories: 105,
                carbs: 27,
                protein: 1,
                fats: 0),
          ],
          'instructions': 'Slice banana and place on rice cakes',
          'prepTime': 2,
          'imageUrl':
              'https://images.unsplash.com/photo-1571748982800-fa51082c2224?w=400',
        },
        {
          'name': 'Edamame',
          'description': 'Steamed edamame with sea salt',
          'ingredients': [
            const IngredientEntity(
                name: 'Edamame',
                amount: '150',
                unit: 'g',
                calories: 180,
                carbs: 14,
                protein: 16,
                fats: 8),
          ],
          'instructions': 'Steam edamame and sprinkle with salt',
          'prepTime': 5,
          'imageUrl':
              'https://images.unsplash.com/photo-1564894809611-1742fc40ed80?w=400',
        },
      ],
    };

    final mealList = meals[type] ?? meals[MealType.breakfast]!;
    return mealList[variation % mealList.length];
  }

  Map<String, dynamic> _getVegetarianMeal(MealType type, int variation) {
    final meals = {
      MealType.breakfast: [
        {
          'name': 'Greek Yogurt Parfait',
          'description': 'Creamy yogurt with granola and berries',
          'ingredients': [
            const IngredientEntity(
                name: 'Greek Yogurt', amount: '200', unit: 'g', calories: 146),
            const IngredientEntity(
                name: 'Granola', amount: '50', unit: 'g', calories: 225),
            const IngredientEntity(
                name: 'Mixed Berries', amount: '100', unit: 'g', calories: 57),
          ],
          'instructions':
              '1. Layer yogurt\n2. Add granola\n3. Top with berries',
          'prepTime': 5,
          'imageUrl':
              'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400',
        },
      ],
      MealType.lunch: [
        {
          'name': 'Caprese Salad',
          'description': 'Fresh mozzarella with tomatoes and basil',
          'ingredients': [
            const IngredientEntity(
                name: 'Mozzarella', amount: '150', unit: 'g', calories: 450),
            const IngredientEntity(
                name: 'Tomatoes', amount: '200', unit: 'g', calories: 36),
            const IngredientEntity(
                name: 'Olive Oil', amount: '2', unit: 'tbsp', calories: 240),
          ],
          'instructions':
              '1. Slice mozzarella and tomatoes\n2. Arrange on plate\n3. Drizzle with oil\n4. Add basil',
          'prepTime': 10,
          'imageUrl':
              'https://images.unsplash.com/photo-1592417817098-8fd3d9eb14a5?w=400',
        },
      ],
      MealType.dinner: [
        {
          'name': 'Vegetable Lasagna',
          'description': 'Layers of pasta with vegetables and cheese',
          'ingredients': [
            const IngredientEntity(
                name: 'Lasagna Sheets',
                amount: '200',
                unit: 'g',
                calories: 262),
            const IngredientEntity(
                name: 'Ricotta', amount: '200', unit: 'g', calories: 348),
            const IngredientEntity(
                name: 'Spinach', amount: '150', unit: 'g', calories: 35),
          ],
          'instructions':
              '1. Layer pasta, ricotta, spinach\n2. Bake at 180°C for 40 min',
          'prepTime': 50,
          'imageUrl':
              'https://images.unsplash.com/photo-1574894709920-11b28e7367e3?w=400',
        },
      ],
      MealType.snack: [
        {
          'name': 'Cheese & Crackers',
          'description': 'Assorted cheese with whole grain crackers',
          'ingredients': [
            const IngredientEntity(
                name: 'Cheese', amount: '50', unit: 'g', calories: 200),
            const IngredientEntity(
                name: 'Crackers', amount: '30', unit: 'g', calories: 120),
          ],
          'instructions': 'Serve cheese with crackers',
          'prepTime': 2,
          'imageUrl':
              'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400',
        },
      ],
    };

    final mealList = meals[type] ?? meals[MealType.breakfast]!;
    return mealList[variation % mealList.length];
  }

  Map<String, dynamic> _getPescatarianMeal(MealType type, int variation) {
    final meals = {
      MealType.breakfast: [
        {
          'name': 'Smoked Salmon Toast',
          'description': 'Cream cheese and salmon on toast',
          'ingredients': [
            const IngredientEntity(
                name: 'Whole Grain Bread',
                amount: '2',
                unit: 'slices',
                calories: 160),
            const IngredientEntity(
                name: 'Smoked Salmon', amount: '60', unit: 'g', calories: 99),
            const IngredientEntity(
                name: 'Cream Cheese', amount: '30', unit: 'g', calories: 99),
          ],
          'instructions':
              '1. Toast bread\n2. Spread cream cheese\n3. Top with salmon',
          'prepTime': 8,
          'imageUrl':
              'https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=400',
        },
      ],
      MealType.lunch: [
        {
          'name': 'Tuna Poke Bowl',
          'description': 'Fresh tuna with rice and vegetables',
          'ingredients': [
            const IngredientEntity(
                name: 'Sushi-grade Tuna',
                amount: '150',
                unit: 'g',
                calories: 184),
            const IngredientEntity(
                name: 'Sushi Rice', amount: '150', unit: 'g', calories: 195),
            const IngredientEntity(
                name: 'Edamame', amount: '50', unit: 'g', calories: 60),
          ],
          'instructions':
              '1. Cube tuna\n2. Prepare rice\n3. Arrange in bowl\n4. Add toppings',
          'prepTime': 20,
          'imageUrl':
              'https://images.unsplash.com/photo-1546069901-d5bfd2cbfb1f?w=400',
        },
      ],
      MealType.dinner: [
        {
          'name': 'Grilled Sea Bass',
          'description': 'Mediterranean style grilled fish',
          'ingredients': [
            const IngredientEntity(
                name: 'Sea Bass', amount: '200', unit: 'g', calories: 206),
            const IngredientEntity(
                name: 'Lemon', amount: '1', unit: 'whole', calories: 17),
            const IngredientEntity(
                name: 'Asparagus', amount: '150', unit: 'g', calories: 30),
          ],
          'instructions':
              '1. Season fish\n2. Grill 4 min per side\n3. Serve with asparagus',
          'prepTime': 25,
          'imageUrl':
              'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400',
        },
      ],
      MealType.snack: [
        {
          'name': 'Shrimp Cocktail',
          'description': 'Chilled shrimp with cocktail sauce',
          'ingredients': [
            const IngredientEntity(
                name: 'Cooked Shrimp', amount: '100', unit: 'g', calories: 99),
            const IngredientEntity(
                name: 'Cocktail Sauce', amount: '30', unit: 'g', calories: 30),
          ],
          'instructions': 'Serve chilled shrimp with sauce',
          'prepTime': 5,
          'imageUrl':
              'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?w=400',
        },
      ],
    };

    final mealList = meals[type] ?? meals[MealType.breakfast]!;
    return mealList[variation % mealList.length];
  }

  Map<String, dynamic> _getKetoMeal(MealType type, int variation) {
    final meals = {
      MealType.breakfast: [
        {
          'name': 'Bacon & Eggs',
          'description': 'Classic keto breakfast',
          'ingredients': [
            const IngredientEntity(
                name: 'Bacon', amount: '4', unit: 'strips', calories: 172),
            const IngredientEntity(
                name: 'Eggs', amount: '3', unit: 'large', calories: 210),
            const IngredientEntity(
                name: 'Avocado', amount: '0.5', unit: 'medium', calories: 117),
          ],
          'instructions':
              '1. Fry bacon\n2. Cook eggs in bacon fat\n3. Serve with avocado',
          'prepTime': 15,
          'imageUrl':
              'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400',
        },
      ],
      MealType.lunch: [
        {
          'name': 'Bunless Burger',
          'description': 'Lettuce-wrapped beef burger',
          'ingredients': [
            const IngredientEntity(
                name: 'Ground Beef', amount: '150', unit: 'g', calories: 382),
            const IngredientEntity(
                name: 'Lettuce', amount: '50', unit: 'g', calories: 8),
            const IngredientEntity(
                name: 'Cheese', amount: '30', unit: 'g', calories: 120),
          ],
          'instructions':
              '1. Form patty\n2. Grill to preference\n3. Wrap in lettuce',
          'prepTime': 20,
          'imageUrl':
              'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
        },
      ],
      MealType.dinner: [
        {
          'name': 'Ribeye with Butter',
          'description': 'Pan-seared steak with herb butter',
          'ingredients': [
            const IngredientEntity(
                name: 'Ribeye Steak', amount: '250', unit: 'g', calories: 625),
            const IngredientEntity(
                name: 'Butter', amount: '30', unit: 'g', calories: 215),
            const IngredientEntity(
                name: 'Asparagus', amount: '100', unit: 'g', calories: 20),
          ],
          'instructions':
              '1. Season steak\n2. Sear in hot pan\n3. Top with butter\n4. Serve with asparagus',
          'prepTime': 25,
          'imageUrl':
              'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=400',
        },
      ],
      MealType.snack: [
        {
          'name': 'Cheese Crisps',
          'description': 'Baked cheese crackers',
          'ingredients': [
            const IngredientEntity(
                name: 'Cheddar Cheese', amount: '60', unit: 'g', calories: 240),
          ],
          'instructions': '1. Place cheese on parchment\n2. Bake until crispy',
          'prepTime': 10,
          'imageUrl':
              'https://images.unsplash.com/photo-1631209121750-a9f656d26a15?w=400',
        },
      ],
    };

    final mealList = meals[type] ?? meals[MealType.breakfast]!;
    return mealList[variation % mealList.length];
  }

  Map<String, dynamic> _getMediterraneanMeal(MealType type, int variation) {
    final meals = {
      MealType.breakfast: [
        {
          'name': 'Mediterranean Breakfast',
          'description': 'Eggs with olives and feta',
          'ingredients': [
            const IngredientEntity(
                name: 'Eggs', amount: '2', unit: 'large', calories: 140),
            const IngredientEntity(
                name: 'Feta Cheese', amount: '30', unit: 'g', calories: 75),
            const IngredientEntity(
                name: 'Olives', amount: '30', unit: 'g', calories: 39),
          ],
          'instructions': '1. Scramble eggs\n2. Top with feta and olives',
          'prepTime': 10,
          'imageUrl':
              'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400',
        },
      ],
      MealType.lunch: [
        {
          'name': 'Greek Salad',
          'description': 'Fresh vegetables with feta and olive oil',
          'ingredients': [
            const IngredientEntity(
                name: 'Cucumber', amount: '150', unit: 'g', calories: 24),
            const IngredientEntity(
                name: 'Tomatoes', amount: '150', unit: 'g', calories: 27),
            const IngredientEntity(
                name: 'Feta', amount: '100', unit: 'g', calories: 250),
          ],
          'instructions':
              '1. Chop vegetables\n2. Add feta\n3. Dress with olive oil',
          'prepTime': 15,
          'imageUrl':
              'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400',
        },
      ],
      MealType.dinner: [
        {
          'name': 'Grilled Lamb Chops',
          'description': 'Herb-crusted lamb with vegetables',
          'ingredients': [
            const IngredientEntity(
                name: 'Lamb Chops', amount: '200', unit: 'g', calories: 494),
            const IngredientEntity(
                name: 'Zucchini', amount: '100', unit: 'g', calories: 17),
            const IngredientEntity(
                name: 'Olive Oil', amount: '2', unit: 'tbsp', calories: 240),
          ],
          'instructions':
              '1. Season lamb\n2. Grill to preference\n3. Serve with grilled vegetables',
          'prepTime': 30,
          'imageUrl':
              'https://images.unsplash.com/photo-1544025162-d76694265947?w=400',
        },
      ],
      MealType.snack: [
        {
          'name': 'Mezze Plate',
          'description': 'Hummus, olives, and pita',
          'ingredients': [
            const IngredientEntity(
                name: 'Hummus', amount: '50', unit: 'g', calories: 83),
            const IngredientEntity(
                name: 'Pita Bread', amount: '30', unit: 'g', calories: 83),
            const IngredientEntity(
                name: 'Olives', amount: '20', unit: 'g', calories: 26),
          ],
          'instructions': 'Arrange on plate and serve',
          'prepTime': 5,
          'imageUrl':
              'https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=400',
        },
      ],
    };

    final mealList = meals[type] ?? meals[MealType.breakfast]!;
    return mealList[variation % mealList.length];
  }

  Map<String, dynamic> _getStandardMeal(MealType type, int variation) {
    final meals = {
      MealType.breakfast: [
        {
          'name': 'Scrambled Eggs with Spinach',
          'description': 'High protein breakfast with fresh vegetables',
          'ingredients': [
            const IngredientEntity(
                name: 'Eggs', amount: '3', unit: 'large', calories: 210),
            const IngredientEntity(
                name: 'Spinach', amount: '100', unit: 'g', calories: 23),
            const IngredientEntity(
                name: 'Olive Oil', amount: '1', unit: 'tbsp', calories: 120),
          ],
          'instructions':
              '1. Heat oil in pan\n2. Add spinach\n3. Add beaten eggs\n4. Scramble until cooked',
          'prepTime': 10,
          'imageUrl':
              'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400',
        },
        {
          'name': 'Oatmeal with Berries',
          'description': 'Warm oatmeal topped with fresh berries',
          'ingredients': [
            const IngredientEntity(
                name: 'Oatmeal', amount: '80', unit: 'g', calories: 303),
            const IngredientEntity(
                name: 'Mixed Berries', amount: '100', unit: 'g', calories: 57),
            const IngredientEntity(
                name: 'Honey', amount: '1', unit: 'tbsp', calories: 64),
          ],
          'instructions':
              '1. Cook oatmeal\n2. Top with berries\n3. Drizzle honey',
          'prepTime': 10,
          'imageUrl':
              'https://images.unsplash.com/photo-1517673400267-0251440c45dc?w=400',
        },
      ],
      MealType.lunch: [
        {
          'name': 'Grilled Chicken Salad',
          'description': 'Fresh salad with grilled chicken breast',
          'ingredients': [
            const IngredientEntity(
                name: 'Chicken Breast',
                amount: '150',
                unit: 'g',
                calories: 248),
            const IngredientEntity(
                name: 'Mixed Greens', amount: '100', unit: 'g', calories: 20),
            const IngredientEntity(
                name: 'Cherry Tomatoes', amount: '50', unit: 'g', calories: 9),
          ],
          'instructions':
              '1. Grill chicken\n2. Chop vegetables\n3. Combine and dress',
          'prepTime': 20,
          'imageUrl':
              'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
        },
      ],
      MealType.dinner: [
        {
          'name': 'Salmon with Vegetables',
          'description': 'Baked salmon with roasted vegetables',
          'ingredients': [
            const IngredientEntity(
                name: 'Salmon Fillet', amount: '180', unit: 'g', calories: 367),
            const IngredientEntity(
                name: 'Broccoli', amount: '100', unit: 'g', calories: 34),
            const IngredientEntity(
                name: 'Brown Rice', amount: '100', unit: 'g', calories: 111),
          ],
          'instructions':
              '1. Season salmon\n2. Bake at 200°C for 15 min\n3. Steam vegetables\n4. Serve with rice',
          'prepTime': 25,
          'imageUrl':
              'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400',
        },
      ],
      MealType.snack: [
        {
          'name': 'Apple & Almonds',
          'description': 'Healthy afternoon snack',
          'ingredients': [
            const IngredientEntity(
                name: 'Apple', amount: '1', unit: 'medium', calories: 95),
            const IngredientEntity(
                name: 'Almonds', amount: '30', unit: 'g', calories: 173),
          ],
          'instructions': 'Slice apple and enjoy with almonds',
          'prepTime': 2,
          'imageUrl':
              'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=400',
        },
      ],
    };

    final mealList = meals[type] ?? meals[MealType.breakfast]!;
    return mealList[variation % mealList.length];
  }

  /// Reset onboarding state
  void reset() {
    state = const DietOnboardingState();
    _initializeFromProfile();
  }
}

/// Provider for diet onboarding
final dietOnboardingProvider =
    StateNotifierProvider<DietOnboardingNotifier, DietOnboardingState>((ref) {
  return DietOnboardingNotifier(ref);
});

/// Common foods for preference selection (45 most popular diet foods)
const commonFoods = [
  // Proteins - Animal (8)
  'Chicken',
  'Beef',
  'Fish',
  'Salmon',
  'Eggs',
  'Turkey',
  'Shrimp',
  'Tuna',
  // Proteins - Plant (5)
  'Tofu',
  'Lentils',
  'Chickpeas',
  'Beans',
  'Quinoa',
  // Grains & Carbs (6)
  'Rice',
  'Pasta',
  'Bread',
  'Oatmeal',
  'Potatoes',
  'Sweet Potato',
  // Vegetables (10)
  'Broccoli',
  'Spinach',
  'Tomatoes',
  'Carrots',
  'Cucumber',
  'Peppers',
  'Onions',
  'Mushrooms',
  'Lettuce',
  'Cabbage',
  // Fruits (8)
  'Banana',
  'Apple',
  'Orange',
  'Berries',
  'Avocado',
  'Grapes',
  'Mango',
  'Watermelon',
  // Dairy (4)
  'Yogurt',
  'Cheese',
  'Milk',
  'Butter',
  // Nuts (4)
  'Almonds',
  'Peanuts',
  'Walnuts',
  'Cashews',
];

/// Food categories for balanced selection
/// Food categories with DISTINCT items (no duplicates/similar foods)
/// Each food should be meaningfully different from others in same category
const _foodCategories = {
  // Animal proteins - ONE representative from each protein type
  // (removed Salmon since Fish covers it, removed Tuna since we have Fish/Shrimp)
  'proteins_animal': [
    'Chicken',    // Poultry
    'Beef',       // Red meat
    'Fish',       // Seafood - general
    'Eggs',       // Eggs
    'Turkey',     // Alternative poultry
    'Shrimp',     // Shellfish
  ],
  // Plant proteins - distinct sources
  'proteins_plant': ['Tofu', 'Lentils', 'Chickpeas', 'Beans', 'Quinoa'],
  // Carbs - distinct types
  'carbs': ['Rice', 'Pasta', 'Bread', 'Oatmeal', 'Potatoes', 'Sweet Potato'],
  // Vegetables - diverse selection
  'vegetables': [
    'Broccoli',
    'Spinach',
    'Tomatoes',
    'Carrots',
    'Cucumber',
    'Peppers',
    'Onions',
    'Mushrooms',
    'Lettuce',
    'Cabbage'
  ],
  // Fruits - diverse selection
  'fruits': [
    'Banana',
    'Apple',
    'Orange',
    'Berries',
    'Avocado',
    'Grapes',
    'Mango',
    'Watermelon'
  ],
  // Dairy - distinct products
  'dairy': ['Yogurt', 'Cheese', 'Milk', 'Butter'],
  // Nuts - distinct types
  'nuts': ['Almonds', 'Peanuts', 'Walnuts', 'Cashews'],
};

/// Priority order for each dietary style (most important categories first)
const _dietPriorityCategories = {
  'standard': [
    'proteins_animal',
    'vegetables',
    'carbs',
    'fruits',
    'dairy',
    'nuts',
    'proteins_plant'
  ],
  'vegan': ['proteins_plant', 'vegetables', 'carbs', 'fruits', 'nuts'],
  'vegetarian': [
    'proteins_plant',
    'dairy',
    'vegetables',
    'carbs',
    'fruits',
    'nuts'
  ],
  'pescatarian': [
    'proteins_animal',
    'proteins_plant',
    'vegetables',
    'carbs',
    'fruits',
    'dairy',
    'nuts'
  ],
  'keto': [
    'proteins_animal',
    'nuts',
    'dairy',
    'vegetables',
    'fruits',
    'proteins_plant'
  ],
  'mediterranean': [
    'proteins_animal',
    'vegetables',
    'fruits',
    'nuts',
    'carbs',
    'dairy',
    'proteins_plant'
  ],
};

/// Get filtered foods based on dietary style and allergies (max 20 per diet)
/// Shows most popular from each category in balanced order
///
/// CRITICAL: The allergies list may contain:
/// 1. Direct food names: 'broccoli', 'chicken', 'milk'
/// 2. Expanded allergy terms: 'yogurt', 'cheese', 'butter' (from lactose intolerance)
/// 3. Category terms: 'dairy', 'nuts', 'seafood'
List<String> getFilteredFoods(DietaryStyle style,
    {List<String> allergies = const []}) {
  // Normalize allergies to lowercase for comparison
  final normalizedAllergies = allergies.map((a) => a.toLowerCase()).toSet();

  // Foods excluded by dietary style
  const meatFoods = ['Chicken', 'Beef', 'Turkey'];
  const fishFoods = ['Fish', 'Shrimp'];
  const dairyFoods = ['Yogurt', 'Cheese', 'Milk', 'Butter'];
  const eggFoods = ['Eggs'];
  const animalProducts = [
    ...meatFoods,
    ...fishFoods,
    ...dairyFoods,
    ...eggFoods
  ];
  const highCarbFoods = [
    'Rice',
    'Pasta',
    'Bread',
    'Potatoes',
    'Sweet Potato',
    'Banana',
    'Oatmeal',
    'Mango',
    'Grapes'
  ];

  // Category-based allergy expansion (if user says 'dairy', exclude all dairy)
  Set<String> expandedExclusions = {};
  if (normalizedAllergies.contains('dairy')) {
    expandedExclusions.addAll(dairyFoods.map((f) => f.toLowerCase()));
  }
  if (normalizedAllergies.contains('nuts') || normalizedAllergies.contains('nut allergy')) {
    expandedExclusions.addAll(['almonds', 'peanuts', 'walnuts', 'cashews', 'pistachios']);
  }
  if (normalizedAllergies.contains('seafood') || normalizedAllergies.contains('shellfish')) {
    expandedExclusions.addAll(fishFoods.map((f) => f.toLowerCase()));
  }
  if (normalizedAllergies.contains('gluten')) {
    expandedExclusions.addAll(['bread', 'pasta', 'oatmeal']);
  }

  // Get priority order based on diet style
  String priorityKey;
  Set<String> excludedFoods = {};

  switch (style) {
    case DietaryStyle.vegan:
      priorityKey = 'vegan';
      excludedFoods = {...animalProducts};
      break;
    case DietaryStyle.vegetarian:
      priorityKey = 'vegetarian';
      excludedFoods = {...meatFoods};
      break;
    case DietaryStyle.pescatarian:
      priorityKey = 'pescatarian';
      excludedFoods = {...meatFoods};
      break;
    case DietaryStyle.keto:
      priorityKey = 'keto';
      excludedFoods = {...highCarbFoods};
      break;
    case DietaryStyle.mediterranean:
      priorityKey = 'mediterranean';
      break;
    case DietaryStyle.kosher:
      priorityKey = 'standard';
      excludedFoods = {'Shrimp'};
      break;
    default:
      priorityKey = 'standard';
  }

  // Get category priority for this diet
  final categoryOrder = _dietPriorityCategories[priorityKey] ??
      _dietPriorityCategories['standard']!;

  // Build filtered list with balanced category representation
  final result = <String>[];
  final maxPerCategory = (20 / categoryOrder.length).ceil();

  for (final category in categoryOrder) {
    final categoryFoods = _foodCategories[category] ?? [];
    int added = 0;

    for (final food in categoryFoods) {
      if (added >= maxPerCategory) break;
      if (excludedFoods.contains(food)) continue;
      if (result.contains(food)) continue;

      // Check allergies (case-insensitive)
      final foodLower = food.toLowerCase();

      // 1. Check direct allergy match (e.g., user typed 'broccoli')
      if (normalizedAllergies.contains(foodLower)) continue;

      // 2. Check expanded exclusions (e.g., 'dairy' → excludes all dairy foods)
      if (expandedExclusions.contains(foodLower)) continue;

      // 3. Check partial match (e.g., 'egg' matches 'Eggs')
      final hasAllergy = normalizedAllergies.any((allergy) =>
          foodLower.contains(allergy) || allergy.contains(foodLower));
      if (hasAllergy) continue;

      result.add(food);
      added++;
    }
  }

  // Fill remaining slots if needed (up to 20)
  if (result.length < 20) {
    for (final category in categoryOrder) {
      if (result.length >= 20) break;
      final categoryFoods = _foodCategories[category] ?? [];

      for (final food in categoryFoods) {
        if (result.length >= 20) break;
        if (excludedFoods.contains(food)) continue;
        if (result.contains(food)) continue;

        final foodLower = food.toLowerCase();

        // 1. Check direct allergy match
        if (normalizedAllergies.contains(foodLower)) continue;

        // 2. Check expanded exclusions
        if (expandedExclusions.contains(foodLower)) continue;

        // 3. Check partial match
        final hasAllergy = normalizedAllergies.any((allergy) =>
            foodLower.contains(allergy) || allergy.contains(foodLower));
        if (hasAllergy) continue;

        result.add(food);
      }
    }
  }

  return result;
}

/// Food emojis for display
/// Utility for mapping food names to emojis using keyword matching
class FoodEmojiUtility {
  static const Map<String, String> _foodEmojiMap = {
    // Proteins - Animal
    // Proteins - Animal
    'chicken': '🍗',
    'beef': '🥩',
    'steak': '🥩',
    'fish': '🐟',
    'salmon': '🐟',
    'egg': '🥚',
    'turkey': '🦃',
    'shrimp': '🦐',
    'tuna': '🍣',
    'pork': ' Bacon ',
    'bacon': '🥓',
    'lamb': '🍖',
    'meat': '🥩',
    'sea bass': '🐟',
    'sushi': '🍣',

    // Proteins - Plant
    'tofu': '🍱',
    'lentils': '🫘',
    'chickpeas': '🧆',
    'beans': '🫘',
    'quinoa': '🌾',
    'edamame': '🫛',
    'hummus': '🥣',
    'falafel': '🧆',

    // Grains & Carbs
    'rice': '🍚',
    'pasta': '🍝',
    'bread': '🍞',
    'toast': '🍞',
    'oatmeal': '🥣',
    'oats': '🌾',
    'potato': '🥔',
    'sweet potato': '🍠',
    'pancakes': '🥞',
    'granola': '🥣',
    'muesli': '🥣',
    'quesadilla': '🫓',
    'burrito': '🌯',
    'wrap': '🌯',
    'pita': '🫓',
    'lasagna': '🍝',
    'pizza': '🍕',
    'burger': '🍔',
    'bun': '🍞',

    // Vegetables
    'broccoli': '🥦',
    'spinach': '🥬',
    'tomato': '🍅',
    'carrot': '🥕',
    'cucumber': '🥒',
    'pepper': '🫑',
    'onion': '🧅',
    'mushroom': '🍄',
    'lettuce': '🥬',
    'salad': '🥗',
    'cabbage': '🥬',
    'zucchini': '🥒',
    'kale': '🥬',
    'cauliflower': '🥦',
    'asparagus': '🥬',
    'eggplant': '🍆',
    'olives': '🫒',
    'avocado': '🥑',

    // Fruits
    'banana': '🍌',
    'apple': '🍎',
    'orange': '🍊',
    'berries': '🫐',
    'strawberry': '🍓',
    'blueberry': '🫐',
    'raspberry': '🍓',
    'grapes': '🍇',
    'mango': '🥭',
    'watermelon': '🍉',
    'lemon': '🍋',
    'lime': '🍋',
    'fruit': '🍎🍌',

    // Dairy
    'yogurt': '🥣',
    'greek yogurt': '🍶',
    'cottage cheese': '🧀',
    'cheese': '🧀',
    'milk': '🥛',
    'butter': '🧈',
    'feta': '🧀',
    'mozzarella': '🍕',
    'ricotta': '🥣',

    // Nuts & Seeds
    'almonds': '🌰',
    'peanuts': '🥜',
    'walnuts': '🌰',
    'cashews': '🌰',
    'nuts': '🥜',
    'seeds': '🌱',

    // Others
    'soup': '🥣',
    'curry': '🍛',
    'stew': '🥣',
    'honey': '🍯',
    'syrup': '🍯',
    'jam': '🍓',
    'salsa': '🍅',
    'smoothie': '🥤',
    'tea': '☕',
    'coffee': '☕',
    'water': '💧',
    'juice': '🥤',
  };

  /// Legacy map for compatibility with existing UI components
  static Map<String, String> get foodEmojis =>
      _foodEmojiMap.map((key, value) => MapEntry(_capitalize(key), value));

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Find the best matching emoji for a given food name
  /// Now delegates to FoodEmojiRegistry for expanded unique emoji mappings
  static String? getEmojiForName(String name) {
    // Use the new comprehensive registry with unique emojis
    final emoji = FoodEmojiRegistry.getEmoji(name);
    // Return null only if generic fallback was used (for backwards compatibility)
    return emoji == '🍽️' ? null : emoji;
  }
}

/// Legacy constant for compatibility
@Deprecated('Use FoodEmojiUtility.foodEmojis instead')
Map<String, String> get foodEmojis => FoodEmojiUtility.foodEmojis;
