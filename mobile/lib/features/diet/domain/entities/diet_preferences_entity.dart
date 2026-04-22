import 'package:freezed_annotation/freezed_annotation.dart';

part 'diet_preferences_entity.freezed.dart';

/// Diet goal types
enum DietGoal {
  weightLoss,
  muscleGain,
  maintenance,
  medicalDiet,
  cleanEating,
  performance,
  generalHealth,
}

/// Dietary style/restrictions
enum DietaryStyle {
  noRestrictions,
  vegetarian,
  vegan,
  pescatarian,
  keto,
  mediterranean,
  halal,
  kosher,
}

/// Cooking skill level
enum CookingSkill {
  quickAndEasy,
  moderate,
  lovesCooking,
}

/// Budget preference
enum BudgetPreference {
  economy,
  standard,
  premium,
}

/// Allergy severity levels
enum AllergySeverity {
  mild,
  moderate,
  severe,
}

/// Common allergy types for structured selection
enum AllergyType {
  lactose,
  gluten,
  peanuts,
  treeNuts,
  shellfish,
  fish,
  eggs,
  soy,
  wheat,
  sesame,
  other,
}

@freezed
class UserAllergyEntity with _$UserAllergyEntity {
  const factory UserAllergyEntity({
    required AllergyType type,
    required AllergySeverity severity,
    String? customName, // For "other" type
    String? notes,
  }) = _UserAllergyEntity;
}

@freezed
class DietPreferencesEntity with _$DietPreferencesEntity {
  const factory DietPreferencesEntity({
    required String odUserId,
    required DietGoal goal,
    double? targetWeightChangePerWeek, // kg per week (negative for loss)
    @Default(DietaryStyle.noRestrictions) DietaryStyle dietaryStyle,
    @Default([]) List<UserAllergyEntity> allergies,
    @Default([]) List<String> likedFoods,
    @Default([]) List<String> dislikedFoods,
    @Default(3) int mealsPerDay,
    @Default(CookingSkill.moderate) CookingSkill cookingSkill,
    @Default(30) int maxPrepTimeMinutes,
    @Default(BudgetPreference.standard) BudgetPreference budget,
    @Default(true) bool mealRemindersEnabled,
    String? breakfastTime, // "08:00"
    String? lunchTime, // "12:30"
    String? dinnerTime, // "19:00"
    String? morningSnackTime, // "10:30"
    String? afternoonSnackTime, // "16:30"
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _DietPreferencesEntity;
}
