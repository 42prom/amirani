import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/support_remote_data_source.dart';
import '../../../../core/utils/error_messages.dart';

// ─── States ───────────────────────────────────────────────────────────────────

abstract class SupportState {}

class SupportInitial extends SupportState {}

class SupportLoading extends SupportState {}

class SupportLoaded extends SupportState {
  final List<SupportTicketModel> tickets;
  SupportLoaded(this.tickets);
}

class SupportDetailLoaded extends SupportState {
  final List<SupportTicketModel> tickets;
  final SupportTicketModel detail;
  SupportDetailLoaded({required this.tickets, required this.detail});
}

class SupportError extends SupportState {
  final String message;
  SupportError(this.message);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SupportNotifier extends StateNotifier<SupportState> {
  final SupportRemoteDataSource _ds;

  SupportNotifier(this._ds) : super(SupportInitial());

  Future<void> loadTickets(String gymId) async {
    state = SupportLoading();
    try {
      final tickets = await _ds.getMyTickets(gymId);
      state = SupportLoaded(tickets);
    } catch (e) {
      state = SupportError(ErrorMessages.from(e, fallback: 'Something went wrong. Please try again.'));
    }
  }

  Future<void> loadDetail(String gymId, String ticketId) async {
    final current = state;
    final existingList = current is SupportLoaded
        ? current.tickets
        : current is SupportDetailLoaded
            ? current.tickets
            : <SupportTicketModel>[];
    try {
      final detail = await _ds.getTicket(gymId, ticketId);
      state = SupportDetailLoaded(tickets: existingList, detail: detail);
    } catch (e) {
      state = SupportError(ErrorMessages.from(e, fallback: 'Something went wrong. Please try again.'));
    }
  }

  Future<bool> createTicket({
    required String gymId,
    required String subject,
    required String body,
    required String priority,
  }) async {
    try {
      await _ds.createTicket(
        gymId: gymId,
        subject: subject,
        body: body,
        priority: priority,
      );
      await loadTickets(gymId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> reply({
    required String gymId,
    required String ticketId,
    required String body,
  }) async {
    try {
      await _ds.reply(gymId: gymId, ticketId: ticketId, body: body);
      await loadDetail(gymId, ticketId);
      return true;
    } catch (e) {
      return false;
    }
  }

  void backToList() {
    final current = state;
    if (current is SupportDetailLoaded) {
      state = SupportLoaded(current.tickets);
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final supportProvider =
    StateNotifierProvider<SupportNotifier, SupportState>((ref) {
  return SupportNotifier(ref.watch(supportDataSourceProvider));
});
