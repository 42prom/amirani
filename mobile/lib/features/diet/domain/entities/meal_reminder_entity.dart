import 'package:freezed_annotation/freezed_annotation.dart';
import 'monthly_plan_entity.dart';

part 'meal_reminder_entity.freezed.dart';

/// Status of a meal reminder
enum ReminderStatus {
  scheduled,
  shown,
  dismissed,
  completed,
}

/// A scheduled meal reminder
@freezed
class MealReminderEntity with _$MealReminderEntity {
  const factory MealReminderEntity({
    required String id,
    required String odUserId,
    required MealType mealType,
    required String mealName,
    required DateTime scheduledTime,
    required int calories,
    @Default(ReminderStatus.scheduled) ReminderStatus status,
    int? notificationId, // For canceling
    String? mealId, // Link to PlannedMealEntity
  }) = _MealReminderEntity;
}

/// User's reminder settings
@freezed
class MealReminderSettingsEntity with _$MealReminderSettingsEntity {
  const factory MealReminderSettingsEntity({
    @Default(true) bool enabled,
    @Default(15) int minutesBefore, // Remind X minutes before meal time
    @Default(true) bool breakfastReminder,
    @Default(true) bool lunchReminder,
    @Default(true) bool dinnerReminder,
    @Default(false) bool morningSnackReminder,
    @Default(false) bool afternoonSnackReminder,
    String? breakfastTime, // "08:00"
    String? lunchTime, // "12:30"
    String? dinnerTime, // "19:00"
    String? morningSnackTime, // "10:30"
    String? afternoonSnackTime, // "16:30"
  }) = _MealReminderSettingsEntity;

  const MealReminderSettingsEntity._();

  /// Get scheduled time for a meal type
  String? getTimeForMeal(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return breakfastTime;
      case MealType.lunch:
        return lunchTime;
      case MealType.dinner:
        return dinnerTime;
      case MealType.morningSnack:
        return morningSnackTime;
      case MealType.afternoonSnack:
        return afternoonSnackTime;
      case MealType.snack:
        return afternoonSnackTime ?? morningSnackTime;
    }
  }

  /// Check if reminder is enabled for a meal type
  bool isEnabledForMeal(MealType type) {
    if (!enabled) return false;
    switch (type) {
      case MealType.breakfast:
        return breakfastReminder;
      case MealType.lunch:
        return lunchReminder;
      case MealType.dinner:
        return dinnerReminder;
      case MealType.morningSnack:
        return morningSnackReminder;
      case MealType.afternoonSnack:
        return afternoonSnackReminder;
      case MealType.snack:
        return afternoonSnackReminder || morningSnackReminder;
    }
  }
}
