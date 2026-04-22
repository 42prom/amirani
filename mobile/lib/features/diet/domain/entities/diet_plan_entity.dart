import 'package:freezed_annotation/freezed_annotation.dart';
import 'meal_entity.dart';
import 'monthly_plan_entity.dart' as monthly;
import 'diet_preferences_entity.dart';
import '../utils/diet_plan_mapper.dart';

part 'diet_plan_entity.freezed.dart';

@freezed
class DietPlanEntity with _$DietPlanEntity {
  const factory DietPlanEntity({
    required String id,
    required String name,
    required bool isAIGenerated,
    required bool isActive,
    required int targetCalories,
    required int targetProtein,
    required int targetCarbs,
    required int targetFats,
    required double targetWater,
    required int numWeeks,
    DateTime? startDate,
    required List<MealEntity> meals,
    required DateTime createdAt,
    /// Typed goal from the backend. Null when backend hasn't sent it yet —
    /// [toMonthlyEntity] falls back to name-based inference only in that case.
    DietGoal? goal,
  }) = _DietPlanEntity;

  const DietPlanEntity._();

  /// Converts a trainer-assigned flat plan into a rich MonthlyDietPlanEntity.
  /// Delegates to [DietPlanMapper] — business logic lives in the mapper, not the entity.
  monthly.MonthlyDietPlanEntity toMonthlyEntity(String userId) =>
      const DietPlanMapper().toMonthlyEntity(this, userId);
}
