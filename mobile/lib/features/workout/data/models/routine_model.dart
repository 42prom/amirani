import '../../domain/entities/routine_entity.dart';
import 'exercise_model.dart';

/// Plain class implementation of RoutineModel to bypass Freezed version collisions.
class RoutineModel {
  final String id;
  final String name;
  final int orderIndex;
  final int estimatedMinutes;
  final int? estimatedCaloriesBurned;
  final DateTime? scheduledDate;
  final List<ExerciseModel> exercises;
  final List<String> targetMuscleGroups;

  const RoutineModel({
    required this.id,
    required this.name,
    required this.orderIndex,
    required this.estimatedMinutes,
    this.estimatedCaloriesBurned,
    this.scheduledDate,
    this.exercises = const [],
    this.targetMuscleGroups = const [],
  });

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
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
    return RoutineModel(
      id: json['id'] as String? ?? 'routine_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? '',
      orderIndex: toInt(json['orderIndex']),
      estimatedMinutes: toInt(json['estimatedMinutes']),
      estimatedCaloriesBurned: toIntOpt(json['estimatedCaloriesBurned']),
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'].toString())
          : null,
      exercises: (json['exercises'] as List? ?? [])
          .map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      targetMuscleGroups: (json['targetMuscleGroups'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'orderIndex': orderIndex,
        'estimatedMinutes': estimatedMinutes,
        'estimatedCaloriesBurned': estimatedCaloriesBurned,
        'scheduledDate': scheduledDate?.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'targetMuscleGroups': targetMuscleGroups,
      };

  RoutineEntity toEntity() {
    return RoutineEntity(
      id: id,
      name: name,
      orderIndex: orderIndex,
      estimatedMinutes: estimatedMinutes,
      estimatedCaloriesBurned: estimatedCaloriesBurned,
      scheduledDate: scheduledDate,
      exercises: exercises.map((e) => e.toEntity()).toList(),
      targetMuscleGroups: targetMuscleGroups,
    );
  }
}
