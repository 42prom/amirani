import '../../domain/entities/exercise_entity.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart' show MuscleGroup;

/// Plain DTO that maps the backend exercise JSON to ExerciseEntity.
class ExerciseModel {
  final String id;
  final String exerciseName;
  final int orderIndex;
  final int targetSets;
  final int? targetReps;
  final int? targetRepsMax; // P2-E: upper rep bound for progressive overload display
  final int? targetSeconds; // P2-A: from targetDuration — timed holds (Plank, wall-sit)
  final bool isWarmup;      // P2-C: orderIndex >= 1000 sentinel
  final int restSeconds;
  final double? targetWeight;
  final double? rpe;
  final int? tempoEccentric;
  final int? tempoPause;
  final int? tempoConcentric;
  final String? progressionNote;
  final String? videoUrl;
  final String? imageUrl;
  final String? instructions;
  final List<String> targetMusclesRaw;

  const ExerciseModel({
    required this.id,
    required this.exerciseName,
    required this.orderIndex,
    required this.targetSets,
    this.targetReps,
    this.targetRepsMax,
    this.targetSeconds,
    this.isWarmup = false,
    required this.restSeconds,
    this.targetWeight,
    this.rpe,
    this.tempoEccentric,
    this.tempoPause,
    this.tempoConcentric,
    this.progressionNote,
    this.videoUrl,
    this.imageUrl,
    this.instructions,
    this.targetMusclesRaw = const [],
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }
    int? toIntOpt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }
    double? toDoubleOpt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final rawMuscles = json['targetMuscles'];
    final List<String> muscles = rawMuscles is List
        ? rawMuscles.map((e) => e.toString()).toList()
        : const [];

    // targetDuration is what the backend stores; targetSeconds is what mobile uses.
    // orderIndex >= 1000 is the warmup sentinel set by saveWorkoutPlan.
    final orderIdx = toInt(json['orderIndex']);
    return ExerciseModel(
      id: json['id'] as String? ?? '',
      exerciseName: json['exerciseName'] as String? ?? '',
      orderIndex: orderIdx,
      targetSets: toInt(json['targetSets']),
      targetReps: toIntOpt(json['targetReps']),
      targetRepsMax: toIntOpt(json['targetRepsMax']),
      targetSeconds: toIntOpt(json['targetDuration']),
      isWarmup: orderIdx >= 1000,
      restSeconds: toInt(json['restSeconds']),
      targetWeight: toDoubleOpt(json['targetWeight']),
      rpe: toDoubleOpt(json['rpe']),
      tempoEccentric: toIntOpt(json['tempoEccentric']),
      tempoPause: toIntOpt(json['tempoPause']),
      tempoConcentric: toIntOpt(json['tempoConcentric']),
      progressionNote: json['progressionNote'] as String?,
      videoUrl: json['videoUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      instructions: json['instructions'] as String?,
      targetMusclesRaw: muscles,
    );
  }

  ExerciseEntity toEntity() {
    return ExerciseEntity(
      id: id,
      exerciseName: exerciseName,
      orderIndex: orderIndex,
      targetSets: targetSets,
      targetReps: targetReps,
      targetRepsMax: targetRepsMax,
      targetSeconds: targetSeconds,
      isWarmup: isWarmup,
      restSeconds: restSeconds,
      targetWeight: targetWeight,
      rpe: rpe,
      tempoEccentric: tempoEccentric,
      tempoPause: tempoPause,
      tempoConcentric: tempoConcentric,
      progressionNote: progressionNote,
      videoUrl: videoUrl,
      imageUrl: imageUrl,
      instructions: instructions,
      targetMuscles: targetMusclesRaw
          .map((s) => _parseMuscleGroup(s))
          .whereType<MuscleGroup>()
          .toList(),
    );
  }

  // Aliases map common backend/library strings (snake_case, full words, synonyms)
  // to the MuscleGroup enum name so muscle badges are never silently dropped.
  static const _muscleAliases = <String, String>{
    'quadriceps': 'quads',
    'quad': 'quads',
    'pectorals': 'chest',
    'pecs': 'chest',
    'pec': 'chest',
    'deltoids': 'shoulders',
    'delts': 'shoulders',
    'delt': 'shoulders',
    'abdominals': 'abs',
    'abdominal': 'abs',
    'core': 'abs',
    'upperback': 'back',
    'lats': 'back',
    'lat': 'back',
    'rhomboids': 'back',
    'erectorspinae': 'back',
    'hamstring': 'hamstrings',
    'glute': 'glutes',
    'calf': 'calves',
    'trapezius': 'traps',
    'trap': 'traps',
    'fullbody': 'fullBody',
    'full body': 'fullBody',
    'cardio': 'cardio',
    'adductor': 'adductors',
  };

  static MuscleGroup? _parseMuscleGroup(String raw) {
    final key = raw.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    final resolved = _muscleAliases[key] ?? _muscleAliases[raw.toLowerCase()] ?? key;
    for (final mg in MuscleGroup.values) {
      if (mg.name.toLowerCase() == resolved.toLowerCase()) return mg;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseName': exerciseName,
        'orderIndex': orderIndex,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'targetRepsMax': targetRepsMax,
        'targetDuration': targetSeconds,
        'isWarmup': isWarmup,
        'restSeconds': restSeconds,
        'targetWeight': targetWeight,
        'rpe': rpe,
        'tempoEccentric': tempoEccentric,
        'tempoPause': tempoPause,
        'tempoConcentric': tempoConcentric,
        'progressionNote': progressionNote,
        'videoUrl': videoUrl,
        'imageUrl': imageUrl,
        'instructions': instructions,
        'targetMuscles': targetMusclesRaw,
      };
}
