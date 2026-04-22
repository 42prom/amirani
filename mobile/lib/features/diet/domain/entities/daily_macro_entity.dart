import 'package:freezed_annotation/freezed_annotation.dart';
import 'meal_entity.dart';

part 'daily_macro_entity.freezed.dart';

@freezed
class DailyMacroEntity with _$DailyMacroEntity {
  const factory DailyMacroEntity({
    required String id,
    required DateTime date,
    required int targetCalories,
    required int currentCalories,
    required int targetProtein,
    required int currentProtein,
    required int targetCarbs,
    required int currentCarbs,
    required int targetFats,
    required int currentFats,
    required List<MealEntity> meals,
  }) = _DailyMacroEntity;
}
