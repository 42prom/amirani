import 'dart:async' show unawaited;
import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../features/diet/domain/entities/monthly_plan_entity.dart';
import '../../features/diet/domain/entities/meal_reminder_entity.dart';

/// Service for managing smart meal reminders
class MealReminderService {
  final FlutterLocalNotificationsPlugin _notifications;
  bool _isInitialized = false;

  MealReminderService() : _notifications = FlutterLocalNotificationsPlugin();

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - navigate to diet page
    // This would typically use a navigation service or callback
  }

  /// Request notification permissions (iOS)
  Future<bool> requestPermissions() async {
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    final iosPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Schedule a meal reminder
  Future<void> scheduleMealReminder({
    required int id,
    required String mealName,
    required MealType mealType,
    required DateTime scheduledTime,
    required int calories,
    int minutesBefore = 15,
  }) async {
    if (!_isInitialized) await initialize();

    final reminderTime = scheduledTime.subtract(Duration(minutes: minutesBefore));

    // Don't schedule if time has passed
    if (reminderTime.isBefore(DateTime.now())) return;

    final androidDetails = AndroidNotificationDetails(
      'meal_reminders',
      'Meal Reminders',
      channelDescription: 'Reminders for your scheduled meals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFF1C40F), // Amirani gold
      enableLights: true,
      ledColor: const Color(0xFFF1C40F),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(
        'Your ${_getMealTypeName(mealType)} "$mealName" is scheduled in $minutesBefore minutes. $calories kcal',
        contentTitle: '${_getMealTypeEmoji(mealType)} Time for ${_getMealTypeName(mealType)}!',
        summaryText: 'Tap to view details',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      '${_getMealTypeEmoji(mealType)} Time for ${_getMealTypeName(mealType)}!',
      '$mealName - $calories kcal',
      tz.TZDateTime.from(reminderTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule all meal reminders for a day
  Future<void> scheduleDailyReminders({
    required DailyPlanEntity dayPlan,
    required MealReminderSettingsEntity settings,
  }) async {
    if (!settings.enabled) return;
    if (!_isInitialized) await initialize();

    // Cancel existing reminders for this day
    await cancelDailyReminders(dayPlan.date);

    int notificationId = _generateNotificationId(dayPlan.date);

    for (final meal in dayPlan.meals) {
      if (!settings.isEnabledForMeal(meal.type)) continue;
      if (meal.isCompleted || meal.isSkipped) continue;

      final mealTime = settings.getTimeForMeal(meal.type);
      if (mealTime == null) continue;

      final scheduledDateTime = _parseTimeForDate(dayPlan.date, mealTime);

      await scheduleMealReminder(
        id: notificationId++,
        mealName: meal.name,
        mealType: meal.type,
        scheduledTime: scheduledDateTime,
        calories: meal.nutrition.calories,
        minutesBefore: settings.minutesBefore,
      );
    }
  }

  /// Cancel all reminders for a specific day
  Future<void> cancelDailyReminders(DateTime date) async {
    // Cancel a range of IDs for the day
    final baseId = _generateNotificationId(date);
    for (int i = 0; i < 10; i++) {
      await _notifications.cancel(baseId + i);
    }
  }

  /// Cancel all meal reminders
  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  /// Show immediate notification (for testing)
  Future<void> showTestNotification() async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'meal_reminders',
      'Meal Reminders',
      channelDescription: 'Reminders for your scheduled meals',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      '🍳 Time for Breakfast!',
      'Scrambled Eggs with Spinach - 450 kcal',
      details,
    );
  }

  /// Generate a unique notification ID based on date
  int _generateNotificationId(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  /// Parse time string ("HH:MM") to DateTime for a specific date
  DateTime _parseTimeForDate(DateTime date, String time) {
    final parts = time.split(':');
    if (parts.length < 2) return date;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Get meal type name
  String _getMealTypeName(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
      case MealType.morningSnack:
        return 'Morning Snack';
      case MealType.afternoonSnack:
        return 'Afternoon Snack';
    }
  }

  /// Get meal type emoji
  String _getMealTypeEmoji(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return '🍳';
      case MealType.lunch:
        return '🥗';
      case MealType.dinner:
        return '🍽️';
      case MealType.snack:
        return '🍎';
      case MealType.morningSnack:
        return '🍏';
      case MealType.afternoonSnack:
        return '☕';
    }
  }
}

/// Provider for meal reminder service
final mealReminderServiceProvider = Provider<MealReminderService>((ref) {
  final service = MealReminderService();
  unawaited(service.initialize());
  return service;
});

/// Provider for managing reminder settings state
class MealReminderSettingsNotifier extends StateNotifier<MealReminderSettingsEntity> {
  final MealReminderService _service;

  MealReminderSettingsNotifier(this._service)
      : super(const MealReminderSettingsEntity(
          enabled: true,
          minutesBefore: 15,
          breakfastReminder: true,
          lunchReminder: true,
          dinnerReminder: true,
          morningSnackReminder: false,
          afternoonSnackReminder: false,
          breakfastTime: '08:00',
          lunchTime: '12:30',
          dinnerTime: '19:00',
          morningSnackTime: '10:30',
          afternoonSnackTime: '16:30',
        ));

  /// Toggle reminders on/off
  void toggleEnabled(bool enabled) {
    state = MealReminderSettingsEntity(
      enabled: enabled,
      minutesBefore: state.minutesBefore,
      breakfastReminder: state.breakfastReminder,
      lunchReminder: state.lunchReminder,
      dinnerReminder: state.dinnerReminder,
      morningSnackReminder: state.morningSnackReminder,
      afternoonSnackReminder: state.afternoonSnackReminder,
      breakfastTime: state.breakfastTime,
      lunchTime: state.lunchTime,
      dinnerTime: state.dinnerTime,
      morningSnackTime: state.morningSnackTime,
      afternoonSnackTime: state.afternoonSnackTime,
    );

    if (!enabled) {
      _service.cancelAllReminders();
    }
  }

  /// Update minutes before reminder
  void setMinutesBefore(int minutes) {
    state = MealReminderSettingsEntity(
      enabled: state.enabled,
      minutesBefore: minutes,
      breakfastReminder: state.breakfastReminder,
      lunchReminder: state.lunchReminder,
      dinnerReminder: state.dinnerReminder,
      morningSnackReminder: state.morningSnackReminder,
      afternoonSnackReminder: state.afternoonSnackReminder,
      breakfastTime: state.breakfastTime,
      lunchTime: state.lunchTime,
      dinnerTime: state.dinnerTime,
      morningSnackTime: state.morningSnackTime,
      afternoonSnackTime: state.afternoonSnackTime,
    );
  }

  /// Toggle specific meal reminder
  void toggleMealReminder(MealType type, bool enabled) {
    switch (type) {
      case MealType.breakfast:
        state = state.copyWith(breakfastReminder: enabled);
        break;
      case MealType.lunch:
        state = state.copyWith(lunchReminder: enabled);
        break;
      case MealType.dinner:
        state = state.copyWith(dinnerReminder: enabled);
        break;
      case MealType.morningSnack:
        state = state.copyWith(morningSnackReminder: enabled);
        break;
      case MealType.afternoonSnack:
        state = state.copyWith(afternoonSnackReminder: enabled);
        break;
      case MealType.snack:
        state = state.copyWith(
          morningSnackReminder: enabled,
          afternoonSnackReminder: enabled,
        );
        break;
    }
  }

  /// Update meal time
  void setMealTime(MealType type, String time) {
    switch (type) {
      case MealType.breakfast:
        state = state.copyWith(breakfastTime: time);
        break;
      case MealType.lunch:
        state = state.copyWith(lunchTime: time);
        break;
      case MealType.dinner:
        state = state.copyWith(dinnerTime: time);
        break;
      case MealType.morningSnack:
        state = state.copyWith(morningSnackTime: time);
        break;
      case MealType.afternoonSnack:
        state = state.copyWith(afternoonSnackTime: time);
        break;
      case MealType.snack:
        state = state.copyWith(
          morningSnackTime: time,
          afternoonSnackTime: time,
        );
        break;
    }
  }
}

final mealReminderSettingsProvider =
    StateNotifierProvider<MealReminderSettingsNotifier, MealReminderSettingsEntity>(
        (ref) {
  final service = ref.watch(mealReminderServiceProvider);
  return MealReminderSettingsNotifier(service);
});
