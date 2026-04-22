import '../../domain/entities/diet_plan_entity.dart';
import '../../domain/entities/diet_preferences_entity.dart';
import 'meal_model.dart';

/// Manual DTO for Diet Plans to avoid generator collisions.
class DietPlanModel {
  final String id;
  final String name;
  final bool isAIGenerated;
  final bool isActive;
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFats;
  final double targetWater;
  final int numWeeks;
  final DateTime? startDate;
  final List<MealModel> meals;
  final DateTime createdAt;
  /// Typed goal sent by the backend. Null means the backend hasn't been updated
  /// yet — callers fall back to name-based inference in that case.
  final DietGoal? goal;

  const DietPlanModel({
    required this.id,
    required this.name,
    required this.isAIGenerated,
    required this.isActive,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFats,
    required this.targetWater,
    required this.numWeeks,
    this.startDate,
    this.meals = const [],
    required this.createdAt,
    this.goal,
  });

  factory DietPlanModel.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    // Parse typed goal from backend. Backend sends snake_case enum name
    // (e.g. "weight_loss" or "weightLoss"). Try both formats.
    DietGoal? parsedGoal;
    final rawGoal = json['goal'] as String?;
    if (rawGoal != null) {
      final normalised = rawGoal.replaceAll('_', '').toLowerCase();
      parsedGoal = DietGoal.values.firstWhere(
        (g) => g.name.toLowerCase() == normalised,
        orElse: () => DietGoal.generalHealth,
      );
    }

    return DietPlanModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isAIGenerated: json['isAIGenerated'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      targetCalories: toInt(json['targetCalories']),
      targetProtein: toInt(json['targetProtein']),
      targetCarbs: toInt(json['targetCarbs']),
      targetFats: toInt(json['targetFats']),
      targetWater: toDouble(json['targetWater']),
      numWeeks: toInt(json['numWeeks']),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => MealModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      goal: parsedGoal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isAIGenerated': isAIGenerated,
        'isActive': isActive,
        'targetCalories': targetCalories,
        'targetProtein': targetProtein,
        'targetCarbs': targetCarbs,
        'targetFats': targetFats,
        'targetWater': targetWater,
        'numWeeks': numWeeks,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        'meals': meals.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        if (goal != null) 'goal': goal!.name,
      };

  DietPlanEntity toEntity() {
    return DietPlanEntity(
      id: id,
      name: name,
      isAIGenerated: isAIGenerated,
      isActive: isActive,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFats: targetFats,
      targetWater: targetWater,
      numWeeks: numWeeks,
      startDate: startDate,
      meals: meals.map((m) => m.toEntity()).toList(),
      createdAt: createdAt,
      goal: goal,
    );
  }
}
