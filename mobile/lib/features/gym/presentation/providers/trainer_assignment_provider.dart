import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/trainer_assignment_data_source.dart';
import '../../../gym/data/datasources/support_remote_data_source.dart';
import '../../../../core/utils/error_messages.dart';

// ─── State ────────────────────────────────────────────────────────────────────

abstract class TrainerAssignmentState {}

class TrainerAssignmentInitial extends TrainerAssignmentState {}

class TrainerAssignmentLoading extends TrainerAssignmentState {}

class TrainerAssignmentLoaded extends TrainerAssignmentState {
  final AssignedTrainerModel? assignedTrainer;
  final PendingRequestModel? pendingRequest;

  TrainerAssignmentLoaded({this.assignedTrainer, this.pendingRequest});

  bool get hasTrainer => assignedTrainer != null;
  bool get hasPendingRequest => pendingRequest != null;
}

class TrainerAssignmentError extends TrainerAssignmentState {
  final String message;
  TrainerAssignmentError(this.message);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TrainerAssignmentNotifier extends StateNotifier<TrainerAssignmentState> {
  final TrainerAssignmentDataSource _ds;

  TrainerAssignmentNotifier(this._ds) : super(TrainerAssignmentInitial());

  Future<void> loadStatus(String gymId) async {
    state = TrainerAssignmentLoading();
    await _fetchStatus(gymId);
  }

  /// Refreshes without setting state to Loading (useful for background/silent updates)
  Future<void> refreshStatus(String gymId) async {
    await _fetchStatus(gymId);
  }

  Future<void> _fetchStatus(String gymId) async {
    try {
      final data = await _ds.getMyStatus(gymId);
      final trainerData = data['assignedTrainer'] as Map<String, dynamic>?;
      final requestData = data['pendingRequest'] as Map<String, dynamic>?;
      state = TrainerAssignmentLoaded(
        assignedTrainer: trainerData != null ? AssignedTrainerModel.fromJson(trainerData) : null,
        pendingRequest: requestData != null ? PendingRequestModel.fromJson(requestData) : null,
      );
    } catch (e) {
      state = TrainerAssignmentError(ErrorMessages.from(e));
    }
  }

  /// Returns null on success, error message on failure
  Future<String?> requestTrainer(String gymId, String trainerId, {String? message}) async {
    try {
      await _ds.requestTrainer(gymId, trainerId, message: message);
      await loadStatus(gymId);
      return null;
    } catch (e) {
      return ErrorMessages.from(e);
    }
  }

  /// Returns null on success, error message on failure
  Future<String?> removeAssignment(String gymId) async {
    try {
      await _ds.removeAssignment(gymId);
      await loadStatus(gymId);
      return null;
    } catch (e) {
      return ErrorMessages.from(e);
    }
  }

  Future<SupportTicketModel?> openChat(String gymId, String trainerId) async {
    try {
      return await _ds.openTrainerConversation(gymId, trainerId);
    } catch (e) {
      return null;
    }
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────────

final trainerAssignmentProvider =
    StateNotifierProvider<TrainerAssignmentNotifier, TrainerAssignmentState>((ref) {
  return TrainerAssignmentNotifier(ref.watch(trainerAssignmentDataSourceProvider));
});
