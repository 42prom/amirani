import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_entity.freezed.dart';

enum TaskType { workoutSession, meal, custom }

@freezed
class TaskEntity with _$TaskEntity {
  const factory TaskEntity({
    required String id,
    required String title,
    String? description,
    required TaskType type,
    required int points,
    required bool isCompleted,
    DateTime? completedAt,
    String? planId,
  }) = _TaskEntity;
}
