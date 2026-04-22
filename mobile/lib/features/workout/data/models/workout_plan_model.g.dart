// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_plan_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkoutPlanModelImpl _$$WorkoutPlanModelImplFromJson(
        Map<String, dynamic> json) =>
    _$WorkoutPlanModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      difficulty: json['difficulty'] as String,
      isAIGenerated: json['isAIGenerated'] as bool,
      isActive: json['isActive'] as bool,
      routines: (json['routines'] as List<dynamic>?)
              ?.map((e) => RoutineModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$WorkoutPlanModelImplToJson(
        _$WorkoutPlanModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'difficulty': instance.difficulty,
      'isAIGenerated': instance.isAIGenerated,
      'isActive': instance.isActive,
      'routines': instance.routines,
      'createdAt': instance.createdAt.toIso8601String(),
    };
