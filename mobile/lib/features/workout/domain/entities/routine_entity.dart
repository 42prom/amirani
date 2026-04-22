import 'package:freezed_annotation/freezed_annotation.dart';
import 'exercise_entity.dart';

part 'routine_entity.freezed.dart';

@freezed
class RoutineEntity with _$RoutineEntity {
  const factory RoutineEntity({
    required String id,
    required String name,
    required int orderIndex,
    required int estimatedMinutes,
    int? estimatedCaloriesBurned,
    DateTime? scheduledDate,
    required List<ExerciseEntity> exercises,
    @Default([]) List<String> targetMuscleGroups,
  }) = _RoutineEntity;
}
