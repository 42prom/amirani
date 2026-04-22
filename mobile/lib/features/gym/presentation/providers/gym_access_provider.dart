import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/qr_check_in_entity.dart';
import '../../domain/usecases/gym_usecases.dart';
import 'gym_provider.dart';
import '../../../../core/services/daily_snapshot_service.dart';

// ─── States ───────────────────────────────────────────────────────────────────

abstract class GymAccessState {}

/// Not yet scanned — default state on app launch
class GymAccessIdle extends GymAccessState {}

/// Camera open and scanning
class GymAccessScanning extends GymAccessState {}

/// QR decoded, awaiting server response
class GymAccessValidating extends GymAccessState {}

/// Successfully admitted
class GymAccessAdmitted extends GymAccessState {
  final QrCheckInEntity checkIn;
  GymAccessAdmitted(this.checkIn);
}

/// Scan failed or membership invalid
class GymAccessDenied extends GymAccessState {
  final String reason;
  GymAccessDenied(this.reason);
}

/// Previous session has expired
class GymAccessExpired extends GymAccessState {}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class GymAccessNotifier extends StateNotifier<GymAccessState> {
  final QrCheckInUseCase _qrCheckInUseCase;
  final FlutterSecureStorage _storage;
  final DailySnapshotService _snapshotService;

  static const _keyCheckInId = 'qr_check_in_id';
  static const _keyGymId = 'qr_check_in_gym_id';
  static const _keyGymName = 'qr_check_in_gym_name';
  static const _keyAdmittedAt = 'qr_check_in_admitted_at';
  static const _keyExpiresAt = 'qr_check_in_expires_at';
  static const _keyPlanName = 'qr_check_in_plan_name';
  static const _keyDaysRemaining = 'qr_check_in_days_remaining';

  GymAccessNotifier(this._qrCheckInUseCase, this._storage, this._snapshotService)
      : super(GymAccessIdle()) {
    _restoreSession();
  }

  /// Attempt QR check-in with decoded payload from scanner
  Future<void> performQrCheckIn(String gymId, String token) async {
    state = GymAccessValidating();

    final result = await _qrCheckInUseCase(QrCheckInParams(gymId, token));

    result.fold(
      (failure) => state = GymAccessDenied(failure.message),
      (checkIn) async {
        await _persistSession(checkIn);
        state = GymAccessAdmitted(checkIn);
      },
    );
  }

  /// Clear admission (e.g. on logout or manual exit)
  Future<void> clearAccess() async {
    if (state is GymAccessAdmitted) {
      final admitted = state as GymAccessAdmitted;
      final minutes = DateTime.now().difference(admitted.checkIn.admittedAt).inMinutes;
      _snapshotService.recordGymMinutes(DateTime.now(), minutes);
    }
    await _clearPersistedSession();
    state = GymAccessIdle();
  }

  /// Check if stored session is still valid on app resume
  Future<void> checkIfExpired() async {
    if (state is! GymAccessAdmitted) return;
    final admitted = state as GymAccessAdmitted;
    if (!admitted.checkIn.isActive) {
      final minutes = admitted.checkIn.expiresAt
          .difference(admitted.checkIn.admittedAt)
          .inMinutes
          .clamp(0, 480);
      _snapshotService.recordGymMinutes(admitted.checkIn.expiresAt, minutes);
      await _clearPersistedSession();
      state = GymAccessExpired();
    }
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    final checkInId = await _storage.read(key: _keyCheckInId);
    final gymId = await _storage.read(key: _keyGymId);
    final gymName = await _storage.read(key: _keyGymName);
    final admittedAtStr = await _storage.read(key: _keyAdmittedAt);
    final expiresAtStr = await _storage.read(key: _keyExpiresAt);
    final planName = await _storage.read(key: _keyPlanName);
    final daysRemainingStr = await _storage.read(key: _keyDaysRemaining);

    if (checkInId == null ||
        gymId == null ||
        gymName == null ||
        admittedAtStr == null ||
        expiresAtStr == null) {
      return;
    }

    final DateTime expiresAt;
    final DateTime admittedAt;
    try {
      expiresAt = DateTime.parse(expiresAtStr);
      admittedAt = DateTime.parse(admittedAtStr);
    } catch (_) {
      await _clearPersistedSession();
      return;
    }

    if (DateTime.now().isAfter(expiresAt)) {
      final minutes = expiresAt.difference(admittedAt).inMinutes.clamp(0, 480);
      _snapshotService.recordGymMinutes(expiresAt, minutes);
      await _clearPersistedSession();
      state = GymAccessExpired();
      return;
    }

    state = GymAccessAdmitted(QrCheckInEntity(
      checkInId: checkInId,
      gymId: gymId,
      gymName: gymName,
      admittedAt: admittedAt,
      expiresAt: expiresAt,
      planName: planName,
      daysRemaining: daysRemainingStr != null ? int.tryParse(daysRemainingStr) : null,
    ));
  }

  Future<void> _persistSession(QrCheckInEntity checkIn) async {
    await _storage.write(key: _keyCheckInId, value: checkIn.checkInId);
    await _storage.write(key: _keyGymId, value: checkIn.gymId);
    await _storage.write(key: _keyGymName, value: checkIn.gymName);
    await _storage.write(
        key: _keyAdmittedAt, value: checkIn.admittedAt.toIso8601String());
    await _storage.write(
        key: _keyExpiresAt, value: checkIn.expiresAt.toIso8601String());
    await _storage.write(key: _keyPlanName, value: checkIn.planName);
    await _storage.write(
        key: _keyDaysRemaining, value: checkIn.daysRemaining?.toString());
  }

  Future<void> _clearPersistedSession() async {
    await _storage.delete(key: _keyCheckInId);
    await _storage.delete(key: _keyGymId);
    await _storage.delete(key: _keyGymName);
    await _storage.delete(key: _keyAdmittedAt);
    await _storage.delete(key: _keyExpiresAt);
    await _storage.delete(key: _keyPlanName);
    await _storage.delete(key: _keyDaysRemaining);
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final qrCheckInUseCaseProvider = Provider<QrCheckInUseCase>((ref) {
  return QrCheckInUseCase(ref.watch(gymRepositoryProvider));
});

final getGymQrTokenUseCaseProvider = Provider<GetGymQrTokenUseCase>((ref) {
  return GetGymQrTokenUseCase(ref.watch(gymRepositoryProvider));
});

final gymAccessProvider =
    StateNotifierProvider<GymAccessNotifier, GymAccessState>((ref) {
  return GymAccessNotifier(
    ref.watch(qrCheckInUseCaseProvider),
    const FlutterSecureStorage(),
    ref.read(dailySnapshotServiceProvider),
  );
});

/// Async provider that fetches the branch QR token for branch managers
final gymQrTokenProvider =
    FutureProvider.family<String, String>((ref, gymId) async {
  final useCase = ref.watch(getGymQrTokenUseCaseProvider);
  final result = await useCase(GetGymQrTokenParams(gymId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (token) => token,
  );
});
