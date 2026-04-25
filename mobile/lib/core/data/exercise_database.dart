import 'package:flutter/material.dart';
import '../../features/workout/domain/entities/monthly_workout_plan_entity.dart';
import '../../features/workout/domain/entities/workout_preferences_entity.dart';

/// Represents an exercise in the database
class ExerciseData {
  final String id;
  final String name;
  final String description;
  final List<String> instructions;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final List<Equipment> requiredEquipment;
  final ExerciseDifficulty difficulty;
  final int defaultSets;
  final int defaultReps;
  final int? defaultSeconds; // For timed exercises
  final int restSeconds;
  final double caloriesPerRep;
  final String? videoUrl;
  final String? imageUrl;
  final List<String> tips;
  final bool isCompound;
  final bool isCardio;
  final bool isStretching;

  const ExerciseData({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    this.requiredEquipment = const [Equipment.bodyweightOnly],
    this.difficulty = ExerciseDifficulty.intermediate,
    this.defaultSets = 3,
    this.defaultReps = 12,
    this.defaultSeconds,
    this.restSeconds = 60,
    this.caloriesPerRep = 0.5,
    this.videoUrl,
    this.imageUrl,
    this.tips = const [],
    this.isCompound = false,
    this.isCardio = false,
    this.isStretching = false,
  });

  /// Check if this exercise can be performed with given equipment
  bool canPerformWith(List<Equipment> availableEquipment) {
    if (requiredEquipment.contains(Equipment.bodyweightOnly)) {
      return true;
    }
    return requiredEquipment.any((e) => availableEquipment.contains(e));
  }

  /// Get display name for equipment requirements
  String get equipmentDisplay {
    if (requiredEquipment.contains(Equipment.bodyweightOnly) &&
        requiredEquipment.length == 1) {
      return 'No equipment';
    }
    return requiredEquipment.map((e) => _equipmentName(e)).join(', ');
  }

  String _equipmentName(Equipment e) {
    switch (e) {
      case Equipment.bodyweightOnly:
        return 'Bodyweight';
      case Equipment.dumbbells:
        return 'Dumbbells';
      case Equipment.barbell:
        return 'Barbell';
      case Equipment.machines:
        return 'Machine';
      case Equipment.resistanceBands:
        return 'Bands';
      case Equipment.pullUpBar:
        return 'Pull-up Bar';
      case Equipment.kettlebell:
        return 'Kettlebell';
      case Equipment.cables:
        return 'Cables';
      case Equipment.bench:
        return 'Bench';
      case Equipment.jumpRope:
        return 'Jump Rope';
      case Equipment.medicineBall:
        return 'Medicine Ball';
      case Equipment.foamRoller:
        return 'Foam Roller';
      case Equipment.yogaMat:
        return 'Yoga Mat';
      case Equipment.stabilityBall:
        return 'Stability Ball';
      case Equipment.trxStraps:
        return 'TRX';
      case Equipment.parallelBars:
        return 'Parallel Bars';
      case Equipment.weightedVest:
        return 'Weighted Vest';
      case Equipment.ankleWeights:
        return 'Ankle Weights';
      case Equipment.abWheel:
        return 'Ab Wheel';
      case Equipment.battleRopes:
        return 'Battle Ropes';
    }
  }
}

/// Central exercise database with all exercises mapped to muscles
class ExerciseDatabase {
  ExerciseDatabase._();

  static final ExerciseDatabase instance = ExerciseDatabase._();

  /// Get all exercises
  List<ExerciseData> get allExercises => _exercises;

  /// Get exercises by muscle group
  List<ExerciseData> getExercisesForMuscle(MuscleGroup muscle) {
    return _exercises
        .where((e) =>
            e.primaryMuscles.contains(muscle) ||
            e.secondaryMuscles.contains(muscle))
        .toList();
  }

  /// Get primary exercises for a muscle (targets it directly)
  List<ExerciseData> getPrimaryExercisesForMuscle(MuscleGroup muscle) {
    return _exercises.where((e) => e.primaryMuscles.contains(muscle)).toList();
  }

  /// Get exercises filtered by available equipment
  List<ExerciseData> getExercisesWithEquipment(
    List<MuscleGroup> muscles,
    List<Equipment> equipment,
  ) {
    return _exercises.where((e) {
      final targetsMuscle = muscles.any((m) =>
          e.primaryMuscles.contains(m) || e.secondaryMuscles.contains(m));
      final canPerform = e.canPerformWith(equipment);
      return targetsMuscle && canPerform;
    }).toList();
  }

  /// Get exercises by difficulty
  List<ExerciseData> getExercisesByDifficulty(ExerciseDifficulty difficulty) {
    return _exercises.where((e) => e.difficulty == difficulty).toList();
  }

  /// Get bodyweight-only exercises
  List<ExerciseData> get bodyweightExercises {
    return _exercises
        .where((e) =>
            e.requiredEquipment.length == 1 &&
            e.requiredEquipment.first == Equipment.bodyweightOnly)
        .toList();
  }

  /// Get compound exercises
  List<ExerciseData> get compoundExercises {
    return _exercises.where((e) => e.isCompound).toList();
  }

  /// Get cardio exercises
  List<ExerciseData> get cardioExercises {
    return _exercises.where((e) => e.isCardio).toList();
  }

  /// Search exercises by name
  List<ExerciseData> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _exercises
        .where((e) =>
            e.name.toLowerCase().contains(lowerQuery) ||
            e.description.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get exercise by ID
  ExerciseData? getById(String id) {
    try {
      return _exercises.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXERCISE DATABASE
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<ExerciseData> _exercises = [
    // ─────────────────────────────────────────────────────────────────────────
    // CHEST EXERCISES
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'pushup',
      name: 'Push-ups',
      description: 'Classic bodyweight chest exercise',
      instructions: [
        'Start in plank position with hands shoulder-width apart',
        'Lower chest toward floor, keeping core tight',
        'Push back up to starting position',
        'Keep body in straight line throughout',
      ],
      primaryMuscles: [MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 60,
      caloriesPerRep: 0.4,
      videoUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Push_Ups/0.webp',
      isCompound: true,
      tips: ['Keep elbows at 45-degree angle', 'Engage core throughout'],
    ),
    ExerciseData(
      id: 'incline_pushup',
      name: 'Incline Push-ups',
      description: 'Easier push-up variation with hands elevated',
      instructions: [
        'Place hands on elevated surface (bench, step)',
        'Keep body straight from head to heels',
        'Lower chest toward the surface',
        'Push back up with control',
      ],
      primaryMuscles: [MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'decline_pushup',
      name: 'Decline Push-ups',
      description: 'Advanced push-up with feet elevated',
      instructions: [
        'Place feet on elevated surface',
        'Hands on floor shoulder-width apart',
        'Lower chest toward floor',
        'Push back up maintaining straight body',
      ],
      primaryMuscles: [MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 75,
      isCompound: true,
    ),
    ExerciseData(
      id: 'diamond_pushup',
      name: 'Diamond Push-ups',
      description: 'Close-grip push-up targeting triceps and inner chest',
      instructions: [
        'Form diamond shape with hands under chest',
        'Keep elbows close to body',
        'Lower chest toward hands',
        'Push back up squeezing triceps',
      ],
      primaryMuscles: [MuscleGroup.triceps, MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.shoulders],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'wide_pushup',
      name: 'Wide Push-ups',
      description: 'Push-up variation targeting outer chest',
      instructions: [
        'Place hands wider than shoulder-width',
        'Lower chest to floor',
        'Push back up focusing on chest contraction',
        'Keep core engaged throughout',
      ],
      primaryMuscles: [MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.shoulders],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'dumbbell_bench_press',
      name: 'Dumbbell Bench Press',
      description: 'Classic chest builder with dumbbells',
      instructions: [
        'Lie on bench holding dumbbells at chest level',
        'Press weights up and slightly inward',
        'Lower with control to starting position',
        'Keep feet flat on floor',
      ],
      primaryMuscles: [MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.dumbbells, Equipment.bench],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 4,
      defaultReps: 10,
      restSeconds: 90,
      isCompound: true,
    ),
    ExerciseData(
      id: 'dumbbell_fly',
      name: 'Dumbbell Fly',
      description: 'Isolation exercise for chest stretch and contraction',
      instructions: [
        'Lie on bench with dumbbells above chest',
        'Lower weights in arc motion to sides',
        'Feel stretch in chest at bottom',
        'Bring weights back up squeezing chest',
      ],
      primaryMuscles: [MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.shoulders],
      requiredEquipment: [Equipment.dumbbells, Equipment.bench],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 60,
    ),
    ExerciseData(
      id: 'resistance_band_chest_press',
      name: 'Resistance Band Chest Press',
      description: 'Chest press using resistance bands',
      instructions: [
        'Anchor band behind you at chest height',
        'Hold handles at chest level',
        'Press forward extending arms',
        'Return with control',
      ],
      primaryMuscles: [MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.resistanceBands],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 60,
      isCompound: true,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // BACK EXERCISES
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'pullup',
      name: 'Pull-ups',
      description: 'The king of back exercises',
      instructions: [
        'Hang from bar with overhand grip',
        'Pull body up until chin clears bar',
        'Lower with control',
        'Keep core engaged throughout',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [MuscleGroup.biceps, MuscleGroup.forearms],
      requiredEquipment: [Equipment.pullUpBar],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 8,
      restSeconds: 90,
      isCompound: true,
      tips: ['Squeeze shoulder blades together', 'Avoid swinging'],
    ),
    ExerciseData(
      id: 'chinup',
      name: 'Chin-ups',
      description: 'Underhand grip pull-up emphasizing biceps',
      instructions: [
        'Hang from bar with underhand grip',
        'Pull body up until chin clears bar',
        'Lower with control',
        'Keep elbows close to body',
      ],
      primaryMuscles: [MuscleGroup.back, MuscleGroup.biceps],
      secondaryMuscles: [MuscleGroup.forearms],
      requiredEquipment: [Equipment.pullUpBar],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 8,
      restSeconds: 90,
      isCompound: true,
    ),
    ExerciseData(
      id: 'inverted_row',
      name: 'Inverted Rows',
      description: 'Bodyweight row using low bar or TRX',
      instructions: [
        'Hang underneath bar or TRX handles',
        'Keep body straight',
        'Pull chest to bar/handles',
        'Lower with control',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [MuscleGroup.biceps, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'superman',
      name: 'Superman Hold',
      description: 'Lower back and posterior chain exercise',
      instructions: [
        'Lie face down with arms extended',
        'Lift arms, chest, and legs off floor',
        'Hold position squeezing back',
        'Lower with control',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [MuscleGroup.glutes],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 10,
      defaultSeconds: 3,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'dumbbell_row',
      name: 'Dumbbell Row',
      description: 'Single-arm back exercise',
      instructions: [
        'Place one knee and hand on bench',
        'Hold dumbbell in free hand',
        'Pull weight to hip',
        'Lower with control',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [MuscleGroup.biceps, MuscleGroup.forearms],
      requiredEquipment: [Equipment.dumbbells, Equipment.bench],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'resistance_band_row',
      name: 'Resistance Band Row',
      description: 'Seated or standing row with bands',
      instructions: [
        'Sit with legs extended, band around feet',
        'Pull handles to torso',
        'Squeeze shoulder blades together',
        'Return with control',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [MuscleGroup.biceps],
      requiredEquipment: [Equipment.resistanceBands],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 60,
    ),
    ExerciseData(
      id: 'trx_row',
      name: 'TRX Row',
      description: 'Suspension trainer row',
      instructions: [
        'Hold TRX handles, lean back',
        'Keep body straight',
        'Pull chest to handles',
        'Lower with control',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [MuscleGroup.biceps, MuscleGroup.abs],
      requiredEquipment: [Equipment.trxStraps],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 60,
      isCompound: true,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // SHOULDER EXERCISES
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'pike_pushup',
      name: 'Pike Push-ups',
      description: 'Bodyweight shoulder press alternative',
      instructions: [
        'Start in downward dog position',
        'Lower head toward floor bending elbows',
        'Push back up',
        'Keep hips high throughout',
      ],
      primaryMuscles: [MuscleGroup.shoulders],
      secondaryMuscles: [MuscleGroup.triceps],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'dumbbell_shoulder_press',
      name: 'Dumbbell Shoulder Press',
      description: 'Seated or standing overhead press',
      instructions: [
        'Hold dumbbells at shoulder level',
        'Press weights overhead',
        'Lower with control to shoulders',
        'Keep core braced',
      ],
      primaryMuscles: [MuscleGroup.shoulders],
      secondaryMuscles: [MuscleGroup.triceps],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 75,
      isCompound: true,
    ),
    ExerciseData(
      id: 'lateral_raise',
      name: 'Lateral Raises',
      description: 'Isolation exercise for side delts',
      instructions: [
        'Hold dumbbells at sides',
        'Raise arms out to sides until parallel to floor',
        'Lower with control',
        'Slight bend in elbows',
      ],
      primaryMuscles: [MuscleGroup.shoulders],
      secondaryMuscles: [],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'front_raise',
      name: 'Front Raises',
      description: 'Targets front deltoids',
      instructions: [
        'Hold dumbbells in front of thighs',
        'Raise one or both arms to shoulder height',
        'Lower with control',
        'Alternate arms or do together',
      ],
      primaryMuscles: [MuscleGroup.shoulders],
      secondaryMuscles: [MuscleGroup.chest],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'resistance_band_shoulder_press',
      name: 'Band Shoulder Press',
      description: 'Overhead press using resistance bands',
      instructions: [
        'Stand on band, hold handles at shoulders',
        'Press handles overhead',
        'Lower with control',
        'Keep core engaged',
      ],
      primaryMuscles: [MuscleGroup.shoulders],
      secondaryMuscles: [MuscleGroup.triceps],
      requiredEquipment: [Equipment.resistanceBands],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'wall_handstand_hold',
      name: 'Wall Handstand Hold',
      description: 'Advanced shoulder stability exercise',
      instructions: [
        'Kick up into handstand against wall',
        'Keep body straight',
        'Hold position',
        'Come down safely',
      ],
      primaryMuscles: [MuscleGroup.shoulders],
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.abs],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.advanced,
      defaultSets: 3,
      defaultSeconds: 30,
      restSeconds: 90,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // ARM EXERCISES (BICEPS & TRICEPS)
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'bicep_curl',
      name: 'Dumbbell Bicep Curls',
      description: 'Classic arm builder',
      instructions: [
        'Hold dumbbells at sides, palms forward',
        'Curl weights toward shoulders',
        'Squeeze at top',
        'Lower with control',
      ],
      primaryMuscles: [MuscleGroup.biceps],
      secondaryMuscles: [MuscleGroup.forearms],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'hammer_curl',
      name: 'Hammer Curls',
      description: 'Neutral grip curl for biceps and forearms',
      instructions: [
        'Hold dumbbells with palms facing each other',
        'Curl weights toward shoulders',
        'Keep elbows stationary',
        'Lower with control',
      ],
      primaryMuscles: [MuscleGroup.biceps, MuscleGroup.forearms],
      secondaryMuscles: [],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'tricep_dip',
      name: 'Tricep Dips',
      description: 'Bodyweight tricep exercise using chair or bench',
      instructions: [
        'Place hands on bench behind you',
        'Extend legs forward',
        'Lower body by bending elbows',
        'Push back up',
      ],
      primaryMuscles: [MuscleGroup.triceps],
      secondaryMuscles: [MuscleGroup.shoulders, MuscleGroup.chest],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'parallel_bar_dip',
      name: 'Parallel Bar Dips',
      description: 'Advanced dip for chest and triceps',
      instructions: [
        'Support yourself on parallel bars',
        'Lower body by bending elbows',
        'Go until upper arms are parallel to floor',
        'Push back up',
      ],
      primaryMuscles: [MuscleGroup.triceps, MuscleGroup.chest],
      secondaryMuscles: [MuscleGroup.shoulders],
      requiredEquipment: [Equipment.parallelBars],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 90,
      isCompound: true,
    ),
    ExerciseData(
      id: 'tricep_extension',
      name: 'Overhead Tricep Extension',
      description: 'Dumbbell tricep isolation',
      instructions: [
        'Hold dumbbell overhead with both hands',
        'Lower weight behind head',
        'Extend arms back up',
        'Keep elbows close to head',
      ],
      primaryMuscles: [MuscleGroup.triceps],
      secondaryMuscles: [],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'resistance_band_curl',
      name: 'Resistance Band Curls',
      description: 'Bicep curls with bands',
      instructions: [
        'Stand on band, hold handles',
        'Curl handles toward shoulders',
        'Squeeze at top',
        'Lower with control',
      ],
      primaryMuscles: [MuscleGroup.biceps],
      secondaryMuscles: [MuscleGroup.forearms],
      requiredEquipment: [Equipment.resistanceBands],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 45,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // LEG EXERCISES
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'bodyweight_squat',
      name: 'Air Squats',
      description: 'Fundamental lower body exercise',
      instructions: [
        'Stand with feet shoulder-width apart',
        'Lower hips back and down',
        'Keep chest up, knees over toes',
        'Push through heels to stand',
      ],
      primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.hamstrings, MuscleGroup.calves],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 60,
      isCompound: true,
      tips: ['Keep weight on heels', 'Go as low as mobility allows'],
    ),
    ExerciseData(
      id: 'goblet_squat',
      name: 'Goblet Squat',
      description: 'Squat holding weight at chest',
      instructions: [
        'Hold dumbbell or kettlebell at chest',
        'Squat down keeping weight close',
        'Keep elbows inside knees at bottom',
        'Drive up through heels',
      ],
      primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.hamstrings, MuscleGroup.abs],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 75,
      isCompound: true,
    ),
    ExerciseData(
      id: 'kettlebell_swing',
      name: 'Kettlebell Swing',
      description: 'Explosive hip hinge movement',
      instructions: [
        'Stand with kettlebell between feet',
        'Hinge at hips, grab handle',
        'Swing weight forward with hip drive',
        'Let weight swing back between legs',
      ],
      primaryMuscles: [MuscleGroup.glutes, MuscleGroup.hamstrings],
      secondaryMuscles: [MuscleGroup.back, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.kettlebell],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 60,
      isCompound: true,
      isCardio: true,
    ),
    ExerciseData(
      id: 'lunges',
      name: 'Walking Lunges',
      description: 'Unilateral leg exercise',
      instructions: [
        'Step forward with one leg',
        'Lower until both knees at 90 degrees',
        'Push through front heel to step forward',
        'Alternate legs',
      ],
      primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.hamstrings],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 60,
      isCompound: true,
    ),
    ExerciseData(
      id: 'split_squat',
      name: 'Bulgarian Split Squat',
      description: 'Single leg squat with rear foot elevated',
      instructions: [
        'Place rear foot on bench behind you',
        'Lower into lunge position',
        'Front thigh parallel to floor',
        'Drive up through front heel',
      ],
      primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.hamstrings],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 75,
      isCompound: true,
    ),
    ExerciseData(
      id: 'glute_bridge',
      name: 'Glute Bridge',
      description: 'Hip extension exercise for glutes',
      instructions: [
        'Lie on back, knees bent, feet flat',
        'Push through heels, lift hips',
        'Squeeze glutes at top',
        'Lower with control',
      ],
      primaryMuscles: [MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.hamstrings],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'single_leg_deadlift',
      name: 'Single Leg Deadlift',
      description: 'Balance and hamstring exercise',
      instructions: [
        'Stand on one leg',
        'Hinge forward at hips',
        'Extend free leg behind you',
        'Return to standing',
      ],
      primaryMuscles: [MuscleGroup.hamstrings, MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.back],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
    ),
    ExerciseData(
      id: 'calf_raise',
      name: 'Standing Calf Raises',
      description: 'Calf building exercise',
      instructions: [
        'Stand on edge of step',
        'Rise up on toes',
        'Lower heels below step level',
        'Repeat with control',
      ],
      primaryMuscles: [MuscleGroup.calves],
      secondaryMuscles: [],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 20,
      restSeconds: 30,
    ),
    ExerciseData(
      id: 'jump_squat',
      name: 'Jump Squats',
      description: 'Explosive plyometric squat',
      instructions: [
        'Perform regular squat',
        'Explode up into jump',
        'Land softly and immediately squat',
        'Repeat with rhythm',
      ],
      primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.calves],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 75,
      isCompound: true,
      isCardio: true,
    ),
    ExerciseData(
      id: 'wall_sit',
      name: 'Wall Sit',
      description: 'Isometric quad exercise',
      instructions: [
        'Lean against wall, slide down',
        'Thighs parallel to floor',
        'Hold position',
        'Keep back flat against wall',
      ],
      primaryMuscles: [MuscleGroup.quads],
      secondaryMuscles: [MuscleGroup.glutes],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultSeconds: 45,
      restSeconds: 60,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // CORE/ABS EXERCISES
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'plank',
      name: 'Plank',
      description: 'Core stabilization exercise',
      instructions: [
        'Start in forearm position',
        'Keep body straight from head to heels',
        'Engage core and glutes',
        'Hold position breathing steadily',
      ],
      primaryMuscles: [MuscleGroup.abs],
      secondaryMuscles: [MuscleGroup.shoulders, MuscleGroup.back],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultSeconds: 45,
      restSeconds: 45,
      tips: ['Dont let hips sag or pike up'],
    ),
    ExerciseData(
      id: 'side_plank',
      name: 'Side Plank',
      description: 'Lateral core stability',
      instructions: [
        'Lie on side, prop up on forearm',
        'Lift hips off ground',
        'Keep body in straight line',
        'Hold then switch sides',
      ],
      primaryMuscles: [MuscleGroup.obliques],
      secondaryMuscles: [MuscleGroup.abs, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultSeconds: 30,
      restSeconds: 30,
    ),
    ExerciseData(
      id: 'mountain_climber',
      name: 'Mountain Climbers',
      description: 'Dynamic core and cardio exercise',
      instructions: [
        'Start in high plank position',
        'Drive one knee toward chest',
        'Quickly switch legs',
        'Keep hips level and core engaged',
      ],
      primaryMuscles: [MuscleGroup.abs],
      secondaryMuscles: [MuscleGroup.shoulders, MuscleGroup.quads],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 20,
      restSeconds: 45,
      isCardio: true,
    ),
    ExerciseData(
      id: 'bicycle_crunch',
      name: 'Bicycle Crunches',
      description: 'Rotational core exercise',
      instructions: [
        'Lie on back, hands behind head',
        'Bring knee to opposite elbow',
        'Extend other leg',
        'Alternate sides with control',
      ],
      primaryMuscles: [MuscleGroup.abs, MuscleGroup.obliques],
      secondaryMuscles: [],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 20,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'leg_raise',
      name: 'Lying Leg Raises',
      description: 'Lower ab exercise',
      instructions: [
        'Lie on back, legs extended',
        'Lift legs toward ceiling',
        'Lower with control',
        'Keep lower back pressed to floor',
      ],
      primaryMuscles: [MuscleGroup.abs],
      secondaryMuscles: [],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'hanging_leg_raise',
      name: 'Hanging Leg Raises',
      description: 'Advanced lower ab exercise',
      instructions: [
        'Hang from pull-up bar',
        'Raise legs to parallel or higher',
        'Lower with control',
        'Avoid swinging',
      ],
      primaryMuscles: [MuscleGroup.abs],
      secondaryMuscles: [MuscleGroup.forearms],
      requiredEquipment: [Equipment.pullUpBar],
      difficulty: ExerciseDifficulty.advanced,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
    ),
    ExerciseData(
      id: 'dead_bug',
      name: 'Dead Bug',
      description: 'Anti-extension core exercise',
      instructions: [
        'Lie on back, arms up, knees bent 90°',
        'Lower opposite arm and leg',
        'Keep lower back pressed to floor',
        'Return and alternate',
      ],
      primaryMuscles: [MuscleGroup.abs],
      secondaryMuscles: [],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 12,
      restSeconds: 45,
    ),
    ExerciseData(
      id: 'ab_wheel_rollout',
      name: 'Ab Wheel Rollout',
      description: 'Advanced core exercise',
      instructions: [
        'Kneel with hands on ab wheel',
        'Roll forward extending body',
        'Roll back using core',
        'Keep core braced throughout',
      ],
      primaryMuscles: [MuscleGroup.abs],
      secondaryMuscles: [MuscleGroup.shoulders, MuscleGroup.back],
      requiredEquipment: [Equipment.abWheel],
      difficulty: ExerciseDifficulty.advanced,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
    ),
    ExerciseData(
      id: 'russian_twist',
      name: 'Russian Twist',
      description: 'Rotational oblique exercise',
      instructions: [
        'Sit with knees bent, lean back slightly',
        'Hold weight or clasp hands',
        'Rotate torso side to side',
        'Keep core tight',
      ],
      primaryMuscles: [MuscleGroup.obliques],
      secondaryMuscles: [MuscleGroup.abs],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 20,
      restSeconds: 45,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // CARDIO EXERCISES
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'burpee',
      name: 'Burpees',
      description: 'Full body cardio exercise',
      instructions: [
        'Start standing, drop to squat',
        'Jump feet back to plank',
        'Perform a pushup (optional)',
        'Jump feet forward and explode up',
      ],
      primaryMuscles: [MuscleGroup.fullBody],
      secondaryMuscles: [MuscleGroup.chest, MuscleGroup.quads],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
      isCompound: true,
      isCardio: true,
      caloriesPerRep: 1.5,
    ),
    ExerciseData(
      id: 'jumping_jack',
      name: 'Jumping Jacks',
      description: 'Classic cardio warm-up',
      instructions: [
        'Stand with feet together, arms at sides',
        'Jump feet out while raising arms',
        'Jump back to start',
        'Repeat with rhythm',
      ],
      primaryMuscles: [MuscleGroup.cardio],
      secondaryMuscles: [MuscleGroup.shoulders, MuscleGroup.calves],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultReps: 30,
      restSeconds: 30,
      isCardio: true,
      caloriesPerRep: 0.2,
    ),
    ExerciseData(
      id: 'high_knees',
      name: 'High Knees',
      description: 'Running in place with high knees',
      instructions: [
        'Run in place',
        'Bring knees up to hip level',
        'Pump arms',
        'Maintain quick pace',
      ],
      primaryMuscles: [MuscleGroup.cardio],
      secondaryMuscles: [MuscleGroup.quads, MuscleGroup.abs],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultSeconds: 30,
      restSeconds: 30,
      isCardio: true,
    ),
    ExerciseData(
      id: 'jump_rope',
      name: 'Jump Rope',
      description: 'Cardio and coordination exercise',
      instructions: [
        'Hold rope handles at hip level',
        'Jump as rope passes under feet',
        'Land softly on balls of feet',
        'Maintain consistent rhythm',
      ],
      primaryMuscles: [MuscleGroup.cardio],
      secondaryMuscles: [MuscleGroup.calves, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.jumpRope],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 3,
      defaultSeconds: 60,
      restSeconds: 30,
      isCardio: true,
      caloriesPerRep: 0.1,
    ),
    ExerciseData(
      id: 'box_jump',
      name: 'Box Jumps',
      description: 'Plyometric lower body exercise',
      instructions: [
        'Stand facing box or platform',
        'Jump explosively onto box',
        'Land softly with bent knees',
        'Step down and repeat',
      ],
      primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.calves],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
      isCompound: true,
      isCardio: true,
    ),
    ExerciseData(
      id: 'battle_rope_wave',
      name: 'Battle Rope Waves',
      description: 'Upper body and cardio conditioning',
      instructions: [
        'Hold rope end in each hand',
        'Squat slightly for stability',
        'Create alternating waves',
        'Maintain for time',
      ],
      primaryMuscles: [MuscleGroup.shoulders],
      secondaryMuscles: [MuscleGroup.back, MuscleGroup.abs],
      requiredEquipment: [Equipment.battleRopes],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultSeconds: 30,
      restSeconds: 60,
      isCardio: true,
    ),
    ExerciseData(
      id: 'skater_jumps',
      name: 'Skater Jumps',
      description: 'Lateral plyometric exercise',
      instructions: [
        'Stand on one leg',
        'Jump laterally to opposite leg',
        'Land softly and immediately jump back',
        'Swing arms for momentum',
      ],
      primaryMuscles: [MuscleGroup.glutes, MuscleGroup.quads],
      secondaryMuscles: [MuscleGroup.calves],
      requiredEquipment: [Equipment.bodyweightOnly],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 20,
      restSeconds: 45,
      isCardio: true,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // FULL BODY / COMPOUND EXERCISES
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'deadlift_dumbbell',
      name: 'Dumbbell Deadlift',
      description: 'Fundamental hip hinge pattern',
      instructions: [
        'Stand with dumbbells in front of thighs',
        'Hinge at hips, lowering weights',
        'Keep back flat, weights close to legs',
        'Drive through heels to stand',
      ],
      primaryMuscles: [
        MuscleGroup.hamstrings,
        MuscleGroup.glutes,
        MuscleGroup.back
      ],
      secondaryMuscles: [MuscleGroup.forearms],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 90,
      isCompound: true,
    ),
    ExerciseData(
      id: 'thruster',
      name: 'Dumbbell Thrusters',
      description: 'Squat to press combination',
      instructions: [
        'Hold dumbbells at shoulders',
        'Perform front squat',
        'Drive up and press overhead',
        'Lower weights to shoulders and repeat',
      ],
      primaryMuscles: [MuscleGroup.quads, MuscleGroup.shoulders],
      secondaryMuscles: [MuscleGroup.glutes, MuscleGroup.triceps],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.intermediate,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 75,
      isCompound: true,
      isCardio: true,
    ),
    ExerciseData(
      id: 'renegade_row',
      name: 'Renegade Rows',
      description: 'Plank with alternating rows',
      instructions: [
        'Hold plank on dumbbells',
        'Row one weight to hip',
        'Lower and switch sides',
        'Keep hips stable',
      ],
      primaryMuscles: [MuscleGroup.back, MuscleGroup.abs],
      secondaryMuscles: [MuscleGroup.biceps, MuscleGroup.shoulders],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.advanced,
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 75,
      isCompound: true,
    ),
    ExerciseData(
      id: 'manmaker',
      name: 'Man Makers',
      description: 'Ultimate full body complex',
      instructions: [
        'Start standing with dumbbells',
        'Burpee down to plank',
        'Perform pushup and two rows',
        'Jump up and press overhead',
      ],
      primaryMuscles: [MuscleGroup.fullBody],
      secondaryMuscles: [
        MuscleGroup.chest,
        MuscleGroup.back,
        MuscleGroup.shoulders
      ],
      requiredEquipment: [Equipment.dumbbells],
      difficulty: ExerciseDifficulty.advanced,
      defaultSets: 3,
      defaultReps: 6,
      restSeconds: 90,
      isCompound: true,
      isCardio: true,
      caloriesPerRep: 3.0,
    ),
    ExerciseData(
      id: 'turkish_getup',
      name: 'Turkish Get-up',
      description: 'Complex mobility and strength movement',
      instructions: [
        'Lie down holding weight overhead',
        'Progress through get-up sequence',
        'Stand up keeping weight overhead',
        'Reverse movement to lie back down',
      ],
      primaryMuscles: [MuscleGroup.fullBody],
      secondaryMuscles: [
        MuscleGroup.shoulders,
        MuscleGroup.abs,
        MuscleGroup.glutes
      ],
      requiredEquipment: [Equipment.kettlebell],
      difficulty: ExerciseDifficulty.advanced,
      defaultSets: 2,
      defaultReps: 3,
      restSeconds: 90,
      isCompound: true,
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // STRETCHING / MOBILITY
    // ─────────────────────────────────────────────────────────────────────────
    ExerciseData(
      id: 'cat_cow',
      name: 'Cat-Cow Stretch',
      description: 'Spinal mobility exercise',
      instructions: [
        'Start on hands and knees',
        'Arch back, lift head (cow)',
        'Round spine, tuck chin (cat)',
        'Flow between positions',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [MuscleGroup.abs],
      requiredEquipment: [Equipment.yogaMat],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 2,
      defaultReps: 10,
      restSeconds: 30,
      isStretching: true,
    ),
    ExerciseData(
      id: 'childs_pose',
      name: 'Child\'s Pose',
      description: 'Restorative stretch for back and hips',
      instructions: [
        'Kneel with big toes together',
        'Sit back on heels',
        'Extend arms forward on floor',
        'Relax and breathe deeply',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [MuscleGroup.glutes],
      requiredEquipment: [Equipment.yogaMat],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 2,
      defaultSeconds: 60,
      restSeconds: 15,
      isStretching: true,
    ),
    ExerciseData(
      id: 'pigeon_pose',
      name: 'Pigeon Pose',
      description: 'Deep hip flexor and glute stretch',
      instructions: [
        'Start in downward dog',
        'Bring one knee forward behind wrist',
        'Extend opposite leg back',
        'Hold and breathe, switch sides',
      ],
      primaryMuscles: [MuscleGroup.glutes],
      secondaryMuscles: [MuscleGroup.quads],
      requiredEquipment: [Equipment.yogaMat],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 2,
      defaultSeconds: 60,
      restSeconds: 15,
      isStretching: true,
    ),
    ExerciseData(
      id: 'foam_roll_back',
      name: 'Foam Roll Upper Back',
      description: 'Self-myofascial release for back',
      instructions: [
        'Lie on foam roller at upper back',
        'Support head with hands',
        'Roll from mid-back to shoulders',
        'Pause on tight spots',
      ],
      primaryMuscles: [MuscleGroup.back],
      secondaryMuscles: [],
      requiredEquipment: [Equipment.foamRoller],
      difficulty: ExerciseDifficulty.beginner,
      defaultSets: 1,
      defaultSeconds: 90,
      restSeconds: 30,
      isStretching: true,
    ),
  ];
}

/// Extension methods for muscle groups
extension MuscleGroupExtension on MuscleGroup {
  String get displayName {
    switch (this) {
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.biceps:
        return 'Biceps';
      case MuscleGroup.triceps:
        return 'Triceps';
      case MuscleGroup.forearms:
        return 'Forearms';
      case MuscleGroup.abs:
        return 'Abs';
      case MuscleGroup.obliques:
        return 'Obliques';
      case MuscleGroup.quads:
        return 'Quads';
      case MuscleGroup.hamstrings:
        return 'Hamstrings';
      case MuscleGroup.glutes:
        return 'Glutes';
      case MuscleGroup.calves:
        return 'Calves';
      case MuscleGroup.traps:
        return 'Traps';
      case MuscleGroup.neck:
        return 'Neck';
      case MuscleGroup.adductors:
        return 'Adductors';
      case MuscleGroup.fullBody:
        return 'Full Body';
      case MuscleGroup.cardio:
        return 'Cardio';
    }
  }

  Color get color {
    switch (this) {
      case MuscleGroup.shoulders:
        return const Color(0xFFFFD100);
      case MuscleGroup.chest:
        return const Color(0xFFD32F2F);
      case MuscleGroup.abs:
        return const Color(0xFFF4511E);
      case MuscleGroup.biceps:
        return const Color(0xFF7B1FA2);
      case MuscleGroup.triceps:
        return const Color(0xFFD81B60);
      case MuscleGroup.obliques:
        return const Color(0xFF43A047);
      case MuscleGroup.back:
        return const Color(0xFF1B5E20);
      case MuscleGroup.quads:
        return const Color(0xFF1E88E5);
      case MuscleGroup.hamstrings:
        return const Color(0xFFFF5722);
      case MuscleGroup.glutes:
        return const Color(0xFF673AB7);
      case MuscleGroup.calves:
        return const Color(0xFF00ACC1);
      case MuscleGroup.forearms:
        return const Color(0xFF8E24AA);
      case MuscleGroup.traps:
        return const Color(0xFFFF8F00); // Amber — neck/trap region
      case MuscleGroup.neck:
        return const Color(0xFFEF6C00); // Deep orange — neck
      default:
        return const Color(0xFF5ABF4D); // AppTokens.colorBrand fallback
    }
  }

  String get emoji {
    switch (this) {
      case MuscleGroup.chest:
        return '💪';
      case MuscleGroup.back:
        return '🔙';
      case MuscleGroup.shoulders:
        return '🎯';
      case MuscleGroup.biceps:
        return '💪';
      case MuscleGroup.triceps:
        return '🦾';
      case MuscleGroup.forearms:
        return '✊';
      case MuscleGroup.abs:
        return '🔥';
      case MuscleGroup.obliques:
        return '↔️';
      case MuscleGroup.quads:
        return '🦵';
      case MuscleGroup.hamstrings:
        return '🦿';
      case MuscleGroup.glutes:
        return '🍑';
      case MuscleGroup.calves:
        return '🦶';
      case MuscleGroup.traps:
        return '📐';
      case MuscleGroup.neck:
        return '🦒';
      case MuscleGroup.adductors:
        return '🦵';
      case MuscleGroup.fullBody:
        return '🏃';
      case MuscleGroup.cardio:
        return '❤️';
    }
  }

  /// Get related muscle groups (typically worked together)
  List<MuscleGroup> get relatedMuscles {
    switch (this) {
      case MuscleGroup.chest:
        return [MuscleGroup.triceps, MuscleGroup.shoulders];
      case MuscleGroup.back:
        return [MuscleGroup.biceps, MuscleGroup.forearms];
      case MuscleGroup.shoulders:
        return [MuscleGroup.triceps, MuscleGroup.chest];
      case MuscleGroup.biceps:
        return [MuscleGroup.back, MuscleGroup.forearms];
      case MuscleGroup.triceps:
        return [MuscleGroup.chest, MuscleGroup.shoulders];
      case MuscleGroup.forearms:
        return [MuscleGroup.biceps];
      case MuscleGroup.abs:
        return [MuscleGroup.obliques];
      case MuscleGroup.obliques:
        return [MuscleGroup.abs];
      case MuscleGroup.quads:
        return [MuscleGroup.glutes, MuscleGroup.hamstrings];
      case MuscleGroup.hamstrings:
        return [MuscleGroup.glutes, MuscleGroup.calves];
      case MuscleGroup.glutes:
        return [MuscleGroup.hamstrings, MuscleGroup.quads];
      case MuscleGroup.calves:
        return [MuscleGroup.hamstrings];
      case MuscleGroup.traps:
        return [MuscleGroup.shoulders, MuscleGroup.back];
      case MuscleGroup.neck:
        return [MuscleGroup.traps];
      case MuscleGroup.adductors:
        return [MuscleGroup.quads, MuscleGroup.hamstrings];
      case MuscleGroup.fullBody:
        return [];
      case MuscleGroup.cardio:
        return [];
    }
  }
}
