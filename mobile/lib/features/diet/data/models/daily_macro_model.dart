import '../../domain/entities/daily_macro_entity.dart';

/// Maps the backend GET /sync/diet/macros response.
/// Backend returns a flat object — no 'id', 'date', or 'meals'.
/// Fat fields are singular ("targetFat"/"currentFat") on the backend.
class DailyMacroModel {
  final int targetCalories;
  final int currentCalories;
  final int targetProtein;
  final int currentProtein;
  final int targetCarbs;
  final int currentCarbs;
  final int targetFats;
  final int currentFats;

  const DailyMacroModel({
    required this.targetCalories,
    required this.currentCalories,
    required this.targetProtein,
    required this.currentProtein,
    required this.targetCarbs,
    required this.currentCarbs,
    required this.targetFats,
    required this.currentFats,
  });

  factory DailyMacroModel.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }
    return DailyMacroModel(
      targetCalories: toInt(json['targetCalories']),
      currentCalories: toInt(json['currentCalories']),
      targetProtein: toInt(json['targetProtein']),
      currentProtein: toInt(json['currentProtein']),
      targetCarbs: toInt(json['targetCarbs']),
      currentCarbs: toInt(json['currentCarbs']),
      // Backend uses singular "targetFat" / "currentFat"
      targetFats: toInt(json['targetFats']),
      currentFats: toInt(json['currentFats']),
    );
  }

  DailyMacroEntity toEntity(DateTime date) {
    return DailyMacroEntity(
      id: 'macros_${date.toIso8601String().split('T').first}',
      date: date,
      targetCalories: targetCalories,
      currentCalories: currentCalories,
      targetProtein: targetProtein,
      currentProtein: currentProtein,
      targetCarbs: targetCarbs,
      currentCarbs: currentCarbs,
      targetFats: targetFats,
      currentFats: currentFats,
      meals: const [],
    );
  }
}
