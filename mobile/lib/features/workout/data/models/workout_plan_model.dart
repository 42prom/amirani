import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/workout_plan_entity.dart';
import 'routine_model.dart';

part 'workout_plan_model.freezed.dart';
part 'workout_plan_model.g.dart';

@freezed
class WorkoutPlanModel with _$WorkoutPlanModel {
  const factory WorkoutPlanModel({
    required String id,
    required String name,
    String? description,
    required String difficulty,
    required bool isAIGenerated,
    required bool isActive,
    @Default([]) List<RoutineModel> routines,
    required DateTime createdAt,
  }) = _WorkoutPlanModel;

  factory WorkoutPlanModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutPlanModelFromJson(json);
}

extension WorkoutPlanModelX on WorkoutPlanModel {
  WorkoutPlanEntity toEntity() {
    return WorkoutPlanEntity(
      id: id,
      name: name,
      description: description,
      difficulty: difficulty,
      isAIGenerated: isAIGenerated,
      isActive: isActive,
      routines: routines.map((r) => r.toEntity()).toList(),
      createdAt: createdAt,
    );
  }
}
