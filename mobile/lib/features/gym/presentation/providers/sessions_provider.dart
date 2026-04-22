import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/utils/error_messages.dart';
import '../../data/models/session_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class SessionsState {
  final List<TrainingSessionModel> sessions;
  final Set<String> bookedSessionIds;
  final bool isLoading;
  final String? error;
  final String? actionError;

  const SessionsState({
    this.sessions = const [],
    this.bookedSessionIds = const {},
    this.isLoading = false,
    this.error,
    this.actionError,
  });

  SessionsState copyWith({
    List<TrainingSessionModel>? sessions,
    Set<String>? bookedSessionIds,
    bool? isLoading,
    String? error,
    String? actionError,
    bool clearActionError = false,
    bool clearError = false,
  }) =>
      SessionsState(
        sessions: sessions ?? this.sessions,
        bookedSessionIds: bookedSessionIds ?? this.bookedSessionIds,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        actionError: clearActionError ? null : (actionError ?? this.actionError),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SessionsNotifier extends StateNotifier<SessionsState> {
  final Ref _ref;
  String? _lastGymId;

  SessionsNotifier(this._ref) : super(const SessionsState());

  /// Refresh using the last known gymId (no-op if never fetched).
  Future<void> refresh() async {
    if (_lastGymId != null) await fetchSessions(_lastGymId!);
  }

  Future<void> fetchSessions(String gymId) async {
    _lastGymId = gymId;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dio = _ref.read(dioProvider);

      // Fetch sessions
      final sessionsRes = await dio.get(
        '/trainers/sessions',
        queryParameters: {'gymId': gymId},
      );
      final sessionsJson = sessionsRes.data['data'] as List? ?? [];
      final sessions = sessionsJson
          .map((j) => TrainingSessionModel.fromJson(j as Map<String, dynamic>))
          .toList();

      // Fetch my bookings (best-effort — don't fail if unavailable)
      final Set<String> bookedIds = {};
      try {
        final bookingsRes = await dio.get('/trainers/sessions/my-bookings');
        final bookingsJson = bookingsRes.data['data'] as List? ?? [];
        for (final b in bookingsJson) {
          final sessionId = (b as Map<String, dynamic>)['sessionId'] as String?;
          if (sessionId != null) bookedIds.add(sessionId);
        }
      } catch (_) {}

      // Annotate sessions with booking status
      for (final s in sessions) {
        s.isBooked = bookedIds.contains(s.id);
      }

      state = state.copyWith(
        sessions: sessions,
        bookedSessionIds: bookedIds,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ErrorMessages.from(e, fallback: 'Failed to load sessions'),
      );
    }
  }

  Future<bool> bookSession(String sessionId) async {
    state = state.copyWith(clearActionError: true);
    // Optimistic update — show booked immediately
    _updateBookingStatus(sessionId, booked: true);
    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/trainers/sessions/$sessionId/book');
      return true;
    } catch (e) {
      // Rollback on failure
      _updateBookingStatus(sessionId, booked: false);
      state = state.copyWith(actionError: ErrorMessages.from(e, fallback: 'Failed to book session'));
      return false;
    }
  }

  Future<bool> cancelBooking(String sessionId) async {
    state = state.copyWith(clearActionError: true);
    // Optimistic update — show cancelled immediately
    _updateBookingStatus(sessionId, booked: false);
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete('/trainers/sessions/$sessionId/book');
      return true;
    } catch (e) {
      // Rollback on failure
      _updateBookingStatus(sessionId, booked: true);
      state = state.copyWith(actionError: ErrorMessages.from(e, fallback: 'Failed to cancel booking'));
      return false;
    }
  }

  void _updateBookingStatus(String sessionId, {required bool booked}) {
    final updatedIds = Set<String>.from(state.bookedSessionIds);
    if (booked) {
      updatedIds.add(sessionId);
    } else {
      updatedIds.remove(sessionId);
    }

    final updatedSessions = state.sessions.map((s) {
      if (s.id != sessionId) return s;
      final delta = booked ? 1 : -1;
      return TrainingSessionModel(
        id: s.id,
        gymId: s.gymId,
        title: s.title,
        description: s.description,
        type: s.type,
        startTime: s.startTime,
        endTime: s.endTime,
        maxCapacity: s.maxCapacity,
        location: s.location,
        color: s.color,
        status: s.status,
        trainer: s.trainer,
        confirmedCount: (s.confirmedCount + delta).clamp(0, s.maxCapacity ?? 9999),
        isBooked: booked,
      );
    }).toList();

    state = state.copyWith(sessions: updatedSessions, bookedSessionIds: updatedIds);
  }

}

// ── Provider ──────────────────────────────────────────────────────────────────

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, SessionsState>(
  (ref) => SessionsNotifier(ref),
);
