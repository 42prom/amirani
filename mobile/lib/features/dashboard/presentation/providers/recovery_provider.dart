import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/utils/error_messages.dart';

class RecoveryEntry {
  final int sleepHours;
  final int energyLevel; // 1–5
  final int sorenessLevel; // 1–5
  final int recoveryScore; // 0–100
  final String? notes;
  final DateTime loggedAt;

  const RecoveryEntry({
    required this.sleepHours,
    required this.energyLevel,
    required this.sorenessLevel,
    required this.recoveryScore,
    this.notes,
    required this.loggedAt,
  });

  factory RecoveryEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['rawData'] as Map<String, dynamic>? ?? {};
    return RecoveryEntry(
      sleepHours: (json['sleepHours'] as num?)?.toInt() ?? 0,
      energyLevel: (raw['energyLevel'] as num?)?.toInt() ?? 3,
      sorenessLevel: (raw['sorenessLevel'] as num?)?.toInt() ?? 3,
      recoveryScore: (json['recoveryScore'] as num?)?.toInt() ?? 0,
      notes: raw['notes'] as String?,
      loggedAt: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class RecoveryState {
  final RecoveryEntry? todayEntry;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  const RecoveryState({
    this.todayEntry,
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  RecoveryState copyWith({
    RecoveryEntry? todayEntry,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearEntry = false,
  }) {
    return RecoveryState(
      todayEntry: clearEntry ? null : (todayEntry ?? this.todayEntry),
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

class RecoveryNotifier extends StateNotifier<RecoveryState> {
  final Ref _ref;

  RecoveryNotifier(this._ref) : super(const RecoveryState());

  Future<void> fetchToday() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _ref.read(dioProvider).get('/sync/recovery/today');
      if (response.statusCode == 200 && response.data['data'] != null) {
        state = state.copyWith(
          isLoading: false,
          todayEntry: RecoveryEntry.fromJson(
              response.data['data'] as Map<String, dynamic>),
        );
      } else {
        state = state.copyWith(isLoading: false, clearEntry: true);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false, clearEntry: true);
    }
  }

  Future<bool> logRecovery({
    required int sleepHours,
    required int energyLevel,
    required int sorenessLevel,
    String? notes,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final response = await _ref.read(dioProvider).post('/sync/recovery', data: {
        'sleepHours': sleepHours,
        'energyLevel': energyLevel,
        'sorenessLevel': sorenessLevel,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          state = state.copyWith(
            isSubmitting: false,
            todayEntry: RecoveryEntry.fromJson(data),
          );
        } else {
          state = state.copyWith(isSubmitting: false);
        }
        return true;
      }
      state = state.copyWith(isSubmitting: false, error: 'Failed to save');
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: ErrorMessages.from(e, fallback: 'Failed to save recovery log'),
      );
      return false;
    }
  }
}

final recoveryProvider =
    StateNotifierProvider<RecoveryNotifier, RecoveryState>((ref) {
  return RecoveryNotifier(ref);
});
