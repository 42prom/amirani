import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/meal_history_service.dart';
import '../../features/diet/domain/entities/monthly_plan_entity.dart' as diet_entity;
import '../../features/workout/domain/entities/monthly_workout_plan_entity.dart' as workout_entity;
import '../../features/diet/presentation/providers/shopping_basket_provider.dart';
import '../../features/diet/presentation/providers/diet_provider.dart';
import '../services/diet_plan_storage_service.dart';
import '../services/mobile_sync_service.dart';
import '../services/workout_plan_storage_service.dart';
import 'package:amirani_app/features/workout/presentation/providers/active_workout_session_provider.dart';
import 'package:amirani_app/features/workout/data/datasources/workout_history_remote_data_source.dart';
import 'package:amirani_app/core/providers/points_provider.dart';
import '../services/daily_snapshot_service.dart';
import '../../features/gym/presentation/providers/gym_access_provider.dart';

/// Tracks daily progress for workouts and meals in the current session.
/// This is local state that syncs to backend in background.

// ─── Exercise Progress ─────────────────────────────────────────────────────

enum SetStatus { notStarted, stage1, stage2, stage3, completed }
enum IntensityStatus { normal, hard, peak }

extension SetStatusColor on SetStatus {
  Color get color {
    switch (this) {
      case SetStatus.notStarted:
        return Colors.white.withValues(alpha: 0.2);
      case SetStatus.stage1:
        return const Color(0xFFF1C40E); // Gold
      case SetStatus.stage2:
        return const Color(0xFF1877F2); // Blue
      case SetStatus.stage3:
        return const Color(0xFF6366F1); // Purple
      case SetStatus.completed:
        return const Color(0xFF2ECC71); // Green
    }
  }

  IconData get icon {
    switch (this) {
      case SetStatus.notStarted:
        return Icons.radio_button_unchecked;
      case SetStatus.stage1:
        return Icons.circle;
      case SetStatus.stage2:
        return Icons.fiber_smart_record;
      case SetStatus.stage3:
        return Icons.auto_awesome_motion;
      case SetStatus.completed:
        return Icons.check;
    }
  }
}

class ExerciseProgress {
  final String exerciseId;
  final String exerciseName;
  final int targetSets;
  final int targetReps;
  final int completedSets;
  final List<workout_entity.ExerciseSetEntity> sets;
  final String? videoUrl;
  final String? imageUrl;
  final String? instructions;
  final double? targetWeight;
  final double? rpe;
  final int? tempoEccentric;
  final int? tempoPause;
  final int? tempoConcentric;
  final String? progressionNote;
  final List<workout_entity.MuscleGroup> targetMuscles;

  ExerciseProgress({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.sets = const [],
    this.completedSets = 0,
    this.videoUrl,
    this.imageUrl,
    this.instructions,
    this.targetWeight,
    this.rpe,
    this.tempoEccentric,
    this.tempoPause,
    this.tempoConcentric,
    this.progressionNote,
    this.targetMuscles = const [],
  });

  SetStatus get status {
    if (completedSets == 0) return SetStatus.notStarted;
    if (completedSets >= targetSets) return SetStatus.completed;

    final progress = completedSets / targetSets;
    if (progress < 0.4) return SetStatus.stage1;
    if (progress < 0.8) return SetStatus.stage2;
    return SetStatus.stage3;
  }

  IntensityStatus get intensityStatus {
    if (rpe == null) return IntensityStatus.normal;
    if (rpe! >= 9) return IntensityStatus.peak;
    if (rpe! >= 7) return IntensityStatus.hard;
    return IntensityStatus.normal;
  }

  Color get intensityColor {
    switch (intensityStatus) {
      case IntensityStatus.peak:
        return const Color(0xFFF43F5E); // Rose 500
      case IntensityStatus.hard:
        return const Color(0xFFF59E0B); // Amber 500
      default:
        return Colors.white.withValues(alpha: 0.05);
    }
  }

  ExerciseProgress copyWith({int? completedSets}) {
    return ExerciseProgress(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      targetSets: targetSets,
      targetReps: targetReps,
      completedSets: completedSets ?? this.completedSets,
      sets: sets,
      videoUrl: videoUrl,
      imageUrl: imageUrl,
      instructions: instructions,
      targetWeight: targetWeight,
      rpe: rpe,
      tempoEccentric: tempoEccentric,
      tempoPause: tempoPause,
      tempoConcentric: tempoConcentric,
      progressionNote: progressionNote,
      targetMuscles: targetMuscles,
    );
  }
}

// ─── Meal Progress ─────────────────────────────────────────────────────────

// ─── Hydration Progress ────────────────────────────────────────────────────

class HydrationProgress {
  final int targetCups;
  final int completedCups;

  HydrationProgress({
    this.targetCups = 8,
    this.completedCups = 0,
  });

  double get progress => targetCups > 0 ? completedCups / targetCups : 0;
  bool get isComplete => completedCups >= targetCups;

  HydrationProgress copyWith({int? completedCups}) {
    return HydrationProgress(
      targetCups: targetCups,
      completedCups: completedCups ?? this.completedCups,
    );
  }
}

// ─── Meal Progress ─────────────────────────────────────────────────────────

enum MealType { breakfast, lunch, dinner, snack, morningSnack, afternoonSnack }

const Map<MealType, String> categoryMealImages = {
  MealType.breakfast: 'https://images.unsplash.com/photo-1484723091739-30a097e8f929?auto=format&fit=crop&q=80&w=600',
  MealType.lunch: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=600',
  MealType.dinner: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80&w=600',
  MealType.morningSnack: 'https://images.unsplash.com/photo-1543362906-acfc16c670a3?auto=format&fit=crop&q=80&w=600',
  MealType.afternoonSnack: 'https://images.unsplash.com/photo-1594913785162-e678ac05d697?auto=format&fit=crop&q=80&w=600',
  MealType.snack: 'https://images.unsplash.com/photo-1671981200629-014c03829abb?auto=format&fit=crop&q=80&w=600',
};

extension MealTypeLabel on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snacks';
      case MealType.morningSnack:
        return 'Morning Snack';
      case MealType.afternoonSnack:
        return 'Afternoon Snack';
    }
  }
}

class MealIngredient {
  final String ingredientId;
  final String name;
  final String portion;
  final String? emoji;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;

  MealIngredient({
    required this.ingredientId,
    required this.name,
    required this.portion,
    this.emoji,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  MealIngredient copyWith({bool? isCompleted}) {
    return MealIngredient(
      ingredientId: ingredientId,
      name: name,
      portion: portion,
      emoji: emoji,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
  }
}

class MealProgress {
  final String mealId;
  final MealType mealType;
  final String name;
  final String description;
  final String? emoji;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final String imageUrl;
  final String? instructions;
  final String? scheduledTime;
  final String? heroIngredient;
  final String? ingredientSummary;
  final bool isCompleted;
  final List<MealIngredient> ingredients;

  MealProgress({
    required this.mealId,
    required this.mealType,
    required this.name,
    required this.description,
    this.emoji,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.imageUrl,
    this.instructions,
    this.scheduledTime,
    this.heroIngredient,
    this.ingredientSummary,
    this.isCompleted = false,
    this.ingredients = const [],
  });

  MealProgress copyWith({bool? isCompleted}) {
    return MealProgress(
      mealId: mealId,
      mealType: mealType,
      name: name,
      description: description,
      emoji: emoji,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      imageUrl: imageUrl,
      instructions: instructions,
      scheduledTime: scheduledTime,
      heroIngredient: heroIngredient,
      ingredientSummary: ingredientSummary,
      isCompleted: isCompleted ?? this.isCompleted,
      ingredients: ingredients,
    );
  }
}

// ─── Session State ─────────────────────────────────────────────────────────

class SessionProgressState {
  final DateTime date;
  final List<ExerciseProgress> exercises;
  final List<MealProgress> meals;
  final List<diet_entity.SmartBagEntryEntity> smartBagEntries;
  final HydrationProgress hydration;
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFats;
  final int activityMinutes;
  final bool isWorkoutPlanActive;
  final bool isDietPlanActive;
  final int estimatedCaloriesBurned;
  final int estimatedDurationMinutes;

  SessionProgressState({
    required this.date,
    this.exercises = const [],
    this.meals = const [],
    this.smartBagEntries = const [],
    HydrationProgress? hydration,
    this.targetCalories = 2000,
    this.targetProtein = 150,
    this.targetCarbs = 250,
    this.targetFats = 70,
    this.activityMinutes = 0,
    this.isWorkoutPlanActive = false,
    this.isDietPlanActive = false,
    this.estimatedCaloriesBurned = 0,
    this.estimatedDurationMinutes = 0,
  }) : hydration = hydration ?? HydrationProgress();

  // Calculated values
  int get completedExercises =>
      exercises.where((e) => e.status == SetStatus.completed).length;
  int get totalExercises => exercises.length;
  double get workoutProgress =>
      totalExercises > 0 
          ? completedExercises / totalExercises 
          : (isWorkoutPlanActive ? 1.0 : 0.0);

  int get completedMeals => meals.where((m) => m.isCompleted).length;
  int get totalMeals => meals.length;
  double get dietProgress => 
      totalMeals > 0 
          ? completedMeals / totalMeals 
          : (isDietPlanActive ? 1.0 : 0.0);

  int get consumedCalories =>
      meals.where((m) => m.isCompleted).fold(0, (sum, m) => sum + m.calories);
  int get consumedProtein =>
      meals.where((m) => m.isCompleted).fold(0, (sum, m) => sum + m.protein);
  int get consumedCarbs =>
      meals.where((m) => m.isCompleted).fold(0, (sum, m) => sum + m.carbs);
  int get consumedFats =>
      meals.where((m) => m.isCompleted).fold(0, (sum, m) => sum + m.fats);

  int get remainingCalories => targetCalories - consumedCalories;

  double get overallProgress {
    if (totalTasks == 0) {
      return (isWorkoutPlanActive || isDietPlanActive) ? 1.0 : 0.0;
    }
    return completedTasks / totalTasks;
  }

  int get totalTasks => totalExercises + totalMeals;
  int get completedTasks => completedExercises + completedMeals;

  /// Flagship Dynamic Score Calculation (0-100)
  /// Weights: Workout (50%), Diet (40%), Hydration (10%)
  /// If no workout is assigned (Rest Day), the weights of diet/hydration 
  /// scale to fill the 100% gap.
  int get dailyScore {
    int earned = 0;

    // 1. Workout Points (Weight: 50)
    // If no exercises assigned (Rest Day), treat as 100% contribution
    earned += (workoutProgress.clamp(0.0, 1.0) * 50).round();

    // 2. Diet Points (Weight: 40)
    // If no meals assigned, treat as 100% contribution
    earned += (dietProgress.clamp(0.0, 1.0) * 40).round();

    // 3. Hydration Points (Weight: 10)
    earned += (hydration.progress.clamp(0.0, 1.0) * 10).round();
    
    return earned.clamp(0, 100);
  }

  SessionProgressState copyWith({
    DateTime? date,
    List<ExerciseProgress>? exercises,
    List<MealProgress>? meals,
    List<diet_entity.SmartBagEntryEntity>? smartBagEntries,
    HydrationProgress? hydration,
    int? targetCalories,
    int? targetProtein,
    int? targetCarbs,
    int? targetFats,
    int? activityMinutes,
    bool? isWorkoutPlanActive,
    bool? isDietPlanActive,
    int? estimatedCaloriesBurned,
    int? estimatedDurationMinutes,
  }) {
    return SessionProgressState(
      date: date ?? this.date,
      exercises: exercises ?? this.exercises,
      meals: meals ?? this.meals,
      smartBagEntries: smartBagEntries ?? this.smartBagEntries,
      hydration: hydration ?? this.hydration,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFats: targetFats ?? this.targetFats,
      activityMinutes: activityMinutes ?? this.activityMinutes,
      isWorkoutPlanActive: isWorkoutPlanActive ?? this.isWorkoutPlanActive,
      isDietPlanActive: isDietPlanActive ?? this.isDietPlanActive,
      estimatedCaloriesBurned: estimatedCaloriesBurned ?? this.estimatedCaloriesBurned,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
    );
  }
}

// ─── Session Notifier ──────────────────────────────────────────────────────

class SessionProgressNotifier extends StateNotifier<SessionProgressState> {
  final Ref _ref;
  Timer? _syncTimer;

  SessionProgressNotifier(this._ref)
      : super(SessionProgressState(date: DateTime.now()));

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  /// Debounced Cloud Sync (Flagship Efficiency)
  /// Consolidates all progress (Exercise, Diet, Hydration) into a single
  /// Score Package and sends it to the cloud after activity settles.
  void triggerCloudSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      final syncService = _ref.read(mobileSyncServiceProvider);
      final pointsState = _ref.read(pointsProvider);

      final payload = {
        'date': state.date.toIso8601String(),
        'caloriesConsumed': state.consumedCalories,
        'proteinConsumed': state.consumedProtein,
        'carbsConsumed': state.consumedCarbs,
        'fatsConsumed': state.consumedFats,
        'waterConsumed': state.hydration.completedCups,
        'activeMinutes': state.activityMinutes,
        'tasksTotal': state.totalTasks,
        'tasksCompleted': state.completedTasks,
        'score': state.dailyScore,
      };

      debugPrint('[Sync] Triggering Cloud Sync: $payload');

      syncService.syncUp(
        dailyProgress: [payload],
        profileChanges: {
          'totalPoints': pointsState.totalPoints,
          'streakDays': pointsState.streakDays,
        },
      );

      _saveLocalSnapshot();
    });
  }

  void _saveLocalSnapshot() {
    try {
      final gymState = _ref.read(gymAccessProvider);
      int? gymMinutes;
      if (gymState is GymAccessAdmitted && gymState.checkIn.isActive) {
        final minutes = DateTime.now().difference(gymState.checkIn.admittedAt).inMinutes;
        if (minutes > 0) gymMinutes = minutes;
      }

      final snapshot = DailySnapshot(
        date: DateTime.now(),
        overallScore: state.dailyScore,
        dietScore: state.isDietPlanActive && state.totalMeals > 0
            ? (state.dietProgress * 100).round().clamp(0, 100)
            : null,
        workoutScore: state.isWorkoutPlanActive && state.totalExercises > 0
            ? (state.workoutProgress * 100).round().clamp(0, 100)
            : null,
        gymMinutes: gymMinutes,
      );

      _ref.read(dailySnapshotServiceProvider).save(snapshot);
    } catch (_) {}
  }

  /// Load state for a specific day from the monthly plan
  void loadDay(DateTime date, diet_entity.MonthlyDietPlanEntity plan) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dayPlan = plan.getDayPlan(normalizedDate);

    if (dayPlan != null) {
      final sessionMeals = dayPlan.meals.asMap().entries.map((entry) {
        final index = entry.key;
        final meal = entry.value;
        final mappedType = _mapEntityMealType(meal.type);
        return MealProgress(
          mealId: "${meal.id}_$index",
          mealType: mappedType,
          name: meal.name,
          description: meal.description,
          calories: meal.nutrition.calories,
          protein: meal.nutrition.protein,
          carbs: meal.nutrition.carbs,
          fats: meal.nutrition.fats,
          imageUrl: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
              ? meal.imageUrl!
              : (categoryMealImages[mappedType] ?? ''),
          instructions: meal.instructions,
          scheduledTime: meal.scheduledTime,
          heroIngredient: meal.heroIngredient,
          ingredientSummary: meal.ingredientSummary,
          isCompleted: meal.isCompleted,
          ingredients: meal.ingredients.map((ing) => MealIngredient(
            ingredientId: "ing_${ing.name.hashCode}",
            name: ing.name,
            portion: "${ing.amount} ${ing.unit}",
            calories: ing.calories,
            protein: ing.protein,
            carbs: ing.carbs,
            fats: ing.fats,
          )).toList(),
        );
      }).toList();

      state = state.copyWith(
        date: normalizedDate,
        meals: sessionMeals,
        smartBagEntries: dayPlan.smartBagEntries,
        targetCalories: dayPlan.targetCalories,
        targetProtein: dayPlan.targetProtein,
        targetCarbs: dayPlan.targetCarbs,
        targetFats: dayPlan.targetFats,
        isDietPlanActive: true,
      );
    } else {
      // If no plan for this date, reset meals but keep date. 
      // Also check if a plan exists AT ALL to set the active flag.
      state = state.copyWith(
          date: normalizedDate, 
          meals: [],
          isDietPlanActive: true // Flag stays true because the monthly plan exists
      );
    }
    
    triggerCloudSync();
  }

  /// Sync from local storage (Hive) - used for fresh app starts or Challenge page updates.
  /// Ensures progress ring is accurate even before visiting other tabs.
  Future<void> refreshFromStorage() async {
    final now = DateTime.now();

    // 1. Sync Diet
    final dietStorage = _ref.read(dietPlanStorageProvider);
    final dietPlan = await dietStorage.loadPlan();
    if (dietPlan != null) {
      loadDay(now, dietPlan);
    } else {
        state = state.copyWith(isDietPlanActive: false);
    }

    // 2. Sync Workout
    final workoutStorage = _ref.read(workoutPlanStorageProvider);
    final workoutPlan = await workoutStorage.loadPlan();
    if (workoutPlan != null) {
      final todayWorkout = workoutPlan.getDayPlan(now);
      final List<ExerciseProgress> exercises = [];
      if (todayWorkout != null && !todayWorkout.isRestDay) {
        exercises.addAll(todayWorkout.exercises.map((ex) => ExerciseProgress(
          exerciseId: ex.id,
          exerciseName: ex.name,
          targetSets: ex.sets.length,
          targetReps: ex.sets.isNotEmpty ? ex.sets.first.targetReps : 10,
          sets: ex.sets,
          completedSets: ex.sets.where((s) => s.isCompleted).length,
          imageUrl: ex.imageUrl,
          instructions: ex.instructions,
          videoUrl: ex.videoUrl,
          targetMuscles: ex.targetMuscles,
          rpe: ex.rpe,
          targetWeight: ex.targetWeight,
          progressionNote: ex.progressionNote,
        )));
      }
      state = state.copyWith(
        exercises: exercises,
        isWorkoutPlanActive: true,
        estimatedCaloriesBurned: todayWorkout?.estimatedCaloriesBurned ?? 0,
        estimatedDurationMinutes: todayWorkout?.estimatedDurationMinutes ?? 0,
      );
    } else {
        state = state.copyWith(isWorkoutPlanActive: false);
    }
    
    // 3. Sync Hydration/Activity from cloud-cached local state
    // (Already fetched via syncDown() above)
  }

  MealType _mapEntityMealType(diet_entity.MealType type) {
    switch (type) {
      case diet_entity.MealType.breakfast: return MealType.breakfast;
      case diet_entity.MealType.lunch: return MealType.lunch;
      case diet_entity.MealType.dinner: return MealType.dinner;
      case diet_entity.MealType.snack: return MealType.snack;
      case diet_entity.MealType.morningSnack: return MealType.morningSnack;
      case diet_entity.MealType.afternoonSnack: return MealType.afternoonSnack;
    }
  }


  /// Complete one set of an exercise
  /// If already completed, reset to 0 (prevents mistakes)
  void completeExerciseSet(String exerciseId, {bool isTrainerPlan = false}) {
    // Flagship: We allow marking if the date matches the state date, 
    // even if state.date is slightly offset from strictly 'Now'.

    final exercises = state.exercises.map((e) {
      if (e.exerciseId == exerciseId) {
        int newCompleted;
        // If already completed, reset to 0
        if (e.completedSets >= e.targetSets) {
          newCompleted = 0;
        } else {
          // Otherwise increment
          newCompleted = e.completedSets + 1;
        }
        
        // PERSISTENCE SYNC (Trainer Sovereign Logic)
        // If it's a trainer plan or AI plan, trigger immediate sync to persistent storage
        _persistExerciseCompletionAsync(exerciseId, newCompleted);

        // AWARD POINTS
        _ref.read(pointsProvider.notifier).awardSetCompleted();

        return e.copyWith(completedSets: newCompleted);
      }
      return e;
    }).toList();

    state = state.copyWith(exercises: exercises);
    triggerCloudSync();
  }

  /// Mark entire exercise as complete (all sets)
  void markExerciseComplete(String exerciseId, {bool isTrainerPlan = false}) {
    // Allow mark-all-complete for the active session date

    final exercises = state.exercises.map((e) {
      if (e.exerciseId == exerciseId) {
        // Mark all sets as complete
        final newCompleted = e.targetSets;
        
        // PERSISTENCE SYNC (Trainer Sovereign Logic)
        _persistMarkAllCompleteAsync(exerciseId);

        return e.copyWith(completedSets: newCompleted);
      }
      return e;
    }).toList();

    state = state.copyWith(exercises: exercises);
    triggerCloudSync();
  }

  /// ASYNC PERSISTENCE for Mark All Complete
  Future<void> _persistMarkAllCompleteAsync(String exerciseId) async {
    final storage = _ref.read(workoutPlanStorageProvider);
    await storage.markAllSetsComplete(
      date: state.date,
      exerciseId: exerciseId,
    );
    _ref.invalidate(savedWorkoutPlanProvider);
  }

  /// ASYNC PERSISTENCE for Exercises
  Future<void> _persistExerciseCompletionAsync(String exerciseId, int completedSets) async {
    final storage = _ref.read(workoutPlanStorageProvider);
    await storage.incrementPlannedSetCompletion(
      date: state.date,
      exerciseId: exerciseId,
    );
    // Invalidation deferred to finishWorkout() — calling it per set is too expensive.
  }

  /// Toggle meal completion
  void toggleMealCompletion(String mealId) {
    // Allow toggle for the active session date

    final meal = state.meals.firstWhere(
      (m) => m.mealId == mealId,
      orElse: () => state.meals.first,
    );
    final newCompletedState = !meal.isCompleted;
    
    debugPrint('[Diet_Action] Toggling Meal: ${meal.name} (${meal.mealType}) | New Status: ${newCompletedState ? "COMPLETED" : "SKIPPED"}');

    final updatedMeals = state.meals.map((m) {
      if (m.mealId == mealId) {
        return m.copyWith(isCompleted: newCompletedState);
      }
      return m;
    }).toList();

    state = state.copyWith(meals: updatedMeals);
    triggerCloudSync();
 
    // AWARD POINTS
    if (newCompletedState) {
      _ref.read(pointsProvider.notifier).awardMealLogged();
    }
 
    // PERSISTENCE SYNC
    // Save to Monthly Plan in storage so it persists across app restarts and day switches
    // We await this to ensure the plan provider is updated BEFORE any navigation-triggered reloads
    _persistMealCompletionAsync(mealId, newCompletedState);
 
    // ZERO-INPUT CONSUMPTION SYNC
    // Automatically update pantry when a meal is eaten or unmarked
    try {
      final pantry = Map<String, double>.from(_ref.read(virtualPantryProvider));
      for (final ingredient in meal.ingredients) {
        final nameKey = ingredient.name.toLowerCase();
        // Parse portion (e.g., "150g" -> 150.0, "2" -> 2.0)
        final qtyMatch = RegExp(r"([0-9.]+)").firstMatch(ingredient.portion);
        if (qtyMatch != null) {
          final qty = double.tryParse(qtyMatch.group(1)!) ?? 0.0;
          if (newCompletedState) {
            // Eaten: Subtract from pantry (clamp to 0)
            pantry[nameKey] = (pantry[nameKey] ?? 0.0) - qty;
            if (pantry[nameKey]! < 0) pantry[nameKey] = 0;
          } else {
            // Unmarked: Put back into pantry
            pantry[nameKey] = (pantry[nameKey] ?? 0.0) + qty;
          }
        }
      }
      _ref.read(virtualPantryProvider.notifier).updatePantry(pantry);
    } catch (e) {
      debugPrint("Consumption Sync Error: $e");
    }

    // Record to meal history for learning
    final historyService = _ref.read(mealHistoryServiceProvider);
    historyService.recordMealEvent(
      mealId: mealId,
      mealName: meal.name,
      mealType: _sessionToEntityMealType(meal.mealType),
      eventType: newCompletedState ? MealEventType.completed : MealEventType.skipped,
      date: state.date,
      ingredients: meal.ingredients.map((i) => i.name).toList(),
    );

  }
 
  /// ASYNC PERSISTENCE: Wraps the awaitable persistence call
  Future<void> _persistMealCompletionAsync(String mealId, bool isCompleted) async {
    await _persistMealCompletion(mealId, isCompleted);
  }
 
  /// Finalize the workout session and sync all completed sets to the cloud
  Future<void> finishWorkout() async {
    if (state.exercises.isEmpty) return;

    final syncService = _ref.read(mobileSyncServiceProvider);

    // Sync daily activity progress (fire-and-forget)
    syncService.syncUp(
      dailyProgress: [
        {
          'date': state.date.toIso8601String(),
          'activeMinutes': state.activityMinutes,
          'tasksTotal': state.totalTasks,
          'tasksCompleted': state.completedTasks,
          'score': state.dailyScore,
        }
      ],
    );

    // AWARD COMPLETION BONUS
    _ref.read(pointsProvider.notifier).awardWorkoutCompleted(setsLogged: state.completedExercises);

    // Post detailed workout history using real logged sets from the active session
    final session = _ref.read(activeWorkoutSessionProvider);
    if (session == null || session.exercises.isEmpty) return;

    final ds = _ref.read(workoutHistoryDataSourceProvider);
    try {
      await ds.saveSession(session);
    } catch (_) {
      ds.queueSession(session);
    }

    // Invalidate once here so workout tab reflects completed sets when user returns.
    _ref.invalidate(savedWorkoutPlanProvider);
  }

  /// Saves the completion status back to the persistent monthly plan
  Future<void> _persistMealCompletion(String sessionMealId, bool isCompleted) async {
    final storage = _ref.read(dietPlanStorageProvider);
    final plan = await storage.loadPlan();
    if (plan == null) return;
 
    // The sessionMealId is in format "mealId_index"
    final parts = sessionMealId.split('_');
    final realMealId = parts[0];
    final mealIndex = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final normalizedDate = DateTime(state.date.year, state.date.month, state.date.day);
 
    bool found = false;
    final updatedWeeks = plan.weeks.map((week) {
      return week.copyWith(
        days: week.days.map((day) {
          final dDate = day.date;
          if (dDate.year == normalizedDate.year &&
              dDate.month == normalizedDate.month &&
              dDate.day == normalizedDate.day) {
            return day.copyWith(
              meals: day.meals.asMap().entries.map((entry) {
                final idx = entry.key;
                final meal = entry.value;
                
                // Match by both ID and index to ensure zero-collision updates
                // especially for duplicate meal types (e.g. 2 snacks)
                if (meal.id == realMealId && (mealIndex == null || idx == mealIndex)) {
                  found = true;
                  return meal.copyWith(
                    isCompleted: isCompleted,
                    completedAt: isCompleted ? DateTime.now() : null,
                  );
                }
                return meal;
              }).toList(),
            );
          }
          return day;
        }).toList(),
      );
    }).toList();

    if (found) {
      final updatedPlan = plan.copyWith(weeks: updatedWeeks);
      // Update the global plan provider so other UI components stay in sync immediately
      _ref.read(generatedDietPlanProvider.notifier).state = updatedPlan;
      
      await storage.savePlan(updatedPlan);
    }
  }

  /// Convert session MealType to entity MealType
  diet_entity.MealType _sessionToEntityMealType(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return diet_entity.MealType.breakfast;
      case MealType.lunch:
        return diet_entity.MealType.lunch;
      case MealType.dinner:
        return diet_entity.MealType.dinner;
      case MealType.snack:
        return diet_entity.MealType.snack;
      case MealType.morningSnack:
        return diet_entity.MealType.morningSnack;
      case MealType.afternoonSnack:
        return diet_entity.MealType.afternoonSnack;
    }
  }

  /// Toggle hydration cup at index
  void toggleHydrationCup(int index) {
    final current = state.hydration.completedCups;
    int newCups;

    if (index < current) {
      // Tapping a filled cup - remove cups from that point
      newCups = index;
    } else {
      // Tapping an empty cup - fill up to and including that cup
      newCups = index + 1;
    }

    state = state.copyWith(
      hydration: state.hydration.copyWith(completedCups: newCups),
    );
    triggerCloudSync();
  }

  /// Hydrate state from cloud sync data
  void updateFromSync(Map<String, dynamic> data) {
    if (data['date'] == null) return;
    final syncDate = DateTime.tryParse(data['date']?.toString() ?? '');
    if (syncDate == null) return;
    
    // Only update if the dates match (don't overwrite today with yesterday's sync)
    if (syncDate.year == state.date.year &&
        syncDate.month == state.date.month &&
        syncDate.day == state.date.day) {
      
      state = state.copyWith(
        hydration: state.hydration.copyWith(
          completedCups: _safeInt(data['waterConsumed'], state.hydration.completedCups),
        ),
        activityMinutes: _safeInt(data['activeMinutes'], state.activityMinutes),
      );
    }
  }

  int _safeInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Trigger full sync down and update local state
  Future<void> syncDown() async {
    try {
      final result = await _ref.read(mobileSyncServiceProvider).syncDown();
      
      // 1. Progress items
      for (final progress in result.dailyProgress) {
        try {
          updateFromSync(progress);
        } catch (e) {
          debugPrint("[Sync] Progress update error: $e");
        }
      }

      // 2. Points/XP status from Cloud
      if (result.userData != null) {
        final totalP = _safeInt(result.userData!['totalPoints'], 0);
        final streakD = _safeInt(result.userData!['streakDays'], 0);
        
        _ref.read(pointsProvider.notifier).updateFromSync(totalP, streakD);
      }
    } catch (e) {
      debugPrint("[Sync] Global syncDown error: $e");
    }
  }

  /// Set exercises from workout plan
  void setExercises(List<ExerciseProgress> exercises) {
    state = state.copyWith(
      exercises: exercises,
      isWorkoutPlanActive: true,
    );
    triggerCloudSync();
  }

  /// Set meals from diet plan
  void setMeals(List<MealProgress> meals) {
    state = state.copyWith(meals: meals);
  }

  /// Set macro targets
  void setMacroTargets({
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
  }) {
    state = state.copyWith(
      targetCalories: calories ?? state.targetCalories,
      targetProtein: protein ?? state.targetProtein,
      targetCarbs: carbs ?? state.targetCarbs,
      targetFats: fats ?? state.targetFats,
    );
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────

final sessionProgressProvider =
    StateNotifierProvider<SessionProgressNotifier, SessionProgressState>((ref) {
  return SessionProgressNotifier(ref);
});
