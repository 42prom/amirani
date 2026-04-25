import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class NotificationPrefsState {
  final bool pushEnabled;
  final bool workoutReminders;
  final bool mealReminders;
  final bool motivationalMessages;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool isLoading;
  final bool isSaving;

  const NotificationPrefsState({
    this.pushEnabled = true,
    this.workoutReminders = true,
    this.mealReminders = true,
    this.motivationalMessages = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.isLoading = false,
    this.isSaving = false,
  });

  NotificationPrefsState copyWith({
    bool? pushEnabled,
    bool? workoutReminders,
    bool? mealReminders,
    bool? motivationalMessages,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? isLoading,
    bool? isSaving,
  }) =>
      NotificationPrefsState(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        workoutReminders: workoutReminders ?? this.workoutReminders,
        mealReminders: mealReminders ?? this.mealReminders,
        motivationalMessages: motivationalMessages ?? this.motivationalMessages,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietHoursStart: quietHoursStart ?? this.quietHoursStart,
        quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
      );

  factory NotificationPrefsState.fromJson(Map<String, dynamic> j) =>
      NotificationPrefsState(
        pushEnabled: j['pushEnabled'] as bool? ?? true,
        workoutReminders: j['workoutReminders'] as bool? ?? true,
        mealReminders: j['mealReminders'] as bool? ?? true,
        motivationalMessages: j['motivationalMessages'] as bool? ?? true,
        quietHoursEnabled: j['quietHoursEnabled'] as bool? ?? false,
        quietHoursStart: j['quietHoursStart'] as String? ?? '22:00',
        quietHoursEnd: j['quietHoursEnd'] as String? ?? '07:00',
      );
}

class NotificationPrefsNotifier
    extends StateNotifier<NotificationPrefsState> {
  final Dio _dio;

  NotificationPrefsNotifier(this._dio) : super(const NotificationPrefsState()) {
    load();
  }

  Future<void> load() async {
    if (mounted) state = state.copyWith(isLoading: true);
    try {
      final res = await _dio.get('/notifications/preferences');
      final data = res.data['data'] as Map<String, dynamic>;
      if (mounted) {
        state = NotificationPrefsState.fromJson(data).copyWith(isLoading: false);
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    if (mounted) state = state.copyWith(isSaving: true);
    try {
      await _dio.patch('/notifications/preferences', data: patch);
    } catch (_) {}
    if (mounted) state = state.copyWith(isSaving: false);
  }

  void setPushEnabled(bool v) {
    state = state.copyWith(pushEnabled: v);
    _patch({'pushEnabled': v});
  }

  void setWorkoutReminders(bool v) {
    state = state.copyWith(workoutReminders: v);
    _patch({'workoutReminders': v});
  }

  void setMealReminders(bool v) {
    state = state.copyWith(mealReminders: v);
    _patch({'mealReminders': v});
  }

  void setMotivationalMessages(bool v) {
    state = state.copyWith(motivationalMessages: v);
    _patch({'motivationalMessages': v});
  }

  void setQuietHoursEnabled(bool v) {
    state = state.copyWith(quietHoursEnabled: v);
    _patch({'quietHoursEnabled': v});
  }

  void setQuietHours(String start, String end) {
    state = state.copyWith(quietHoursStart: start, quietHoursEnd: end);
    _patch({'quietHoursStart': start, 'quietHoursEnd': end});
  }
}

final notificationPrefsProvider = StateNotifierProvider<
    NotificationPrefsNotifier, NotificationPrefsState>((ref) {
  return NotificationPrefsNotifier(ref.watch(dioProvider));
});
