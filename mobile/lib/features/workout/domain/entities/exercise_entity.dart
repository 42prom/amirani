import 'package:freezed_annotation/freezed_annotation.dart';
import 'monthly_workout_plan_entity.dart';

part 'exercise_entity.freezed.dart';

@freezed
class ExerciseEntity with _$ExerciseEntity {
  const factory ExerciseEntity({
    required String id,
    required String exerciseName,
    required int orderIndex,
    required int targetSets,
    int? targetReps,
    int? targetRepsMax,   // P2-E: upper rep bound for progressive overload display
    int? targetSeconds,   // P2-A: timed holds (Plank, wall-sit) — from targetDuration
    @Default(false) bool isWarmup, // P2-C: warmup flag (orderIndex >= 1000)
    required int restSeconds,
    String? videoUrl,
    String? imageUrl,
    String? instructions,
    double? targetWeight,
    double? rpe,
    int? tempoEccentric,
    int? tempoPause,
    int? tempoConcentric,
    String? progressionNote,
    @Default([]) List<MuscleGroup> targetMuscles,
  }) = _ExerciseEntity;
}
