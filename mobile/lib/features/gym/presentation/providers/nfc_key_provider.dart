import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/nfc_hce_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'gym_access_provider.dart';

class NfcKeyState {
  final PhoneKeyStatus status;
  final bool isEnrolling;
  final String? error;

  NfcKeyState({
    required this.status,
    this.isEnrolling = false,
    this.error,
  });

  NfcKeyState copyWith({
    PhoneKeyStatus? status,
    bool? isEnrolling,
    String? error,
  }) {
    return NfcKeyState(
      status: status ?? this.status,
      isEnrolling: isEnrolling ?? this.isEnrolling,
      error: error,
    );
  }
}

class NfcKeyNotifier extends StateNotifier<NfcKeyState> {
  final GymAccessNotifier _accessNotifier;
  final String? _userId;

  NfcKeyNotifier(this._accessNotifier, this._userId) 
    : super(NfcKeyState(status: PhoneKeyStatus.notSupported)) {
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    final status = await NfcHceService.getStatus();
    state = state.copyWith(status: status);
  }

  Future<void> enroll(String gymId) async {
    if (_userId == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }
    state = state.copyWith(isEnrolling: true, error: null);
    try {
      final result = await NfcHceService.enroll(
        gymId: gymId,
        enrollCallback: (cred) => _accessNotifier.enrollNfcKey(gymId, _userId, cred),
      );

      if (result == HceEnrollResult.success) {
        await refreshStatus();
      } else {
        state = state.copyWith(error: 'Enrollment failed: ${result.name}');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isEnrolling: false);
    }
  }

  Future<void> unenroll(String gymId) async {
    if (_userId == null) return;
    state = state.copyWith(isEnrolling: true, error: null);
    try {
      final ok = await NfcHceService.unenroll(
        revokeCallback: (cred) => _accessNotifier.revokeNfcKey(gymId, _userId, cred),
      );
      if (ok) {
        await refreshStatus();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isEnrolling: false);
    }
  }

  Future<void> togglePower(bool enabled) async {
    if (enabled) {
      await NfcHceService.enable();
    } else {
      await NfcHceService.disable();
    }
    await refreshStatus();
  }
}

final nfcKeyProvider = StateNotifierProvider<NfcKeyNotifier, NfcKeyState>((ref) {
  final user = ref.watch(currentUserProvider);
  return NfcKeyNotifier(
    ref.watch(gymAccessProvider.notifier),
    user?.id,
  );
});
