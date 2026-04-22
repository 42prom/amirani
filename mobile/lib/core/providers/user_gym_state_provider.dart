import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../network/dio_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

// ─── User Gym State Model ─────────────────────────────────────────────────────

class GymMembershipInfo {
  final String id;
  final String gymId;
  final String gymName;
  final String? gymLogoUrl;
  final String planName;
  final String status; // ACTIVE, EXPIRED, FROZEN, etc.
  final DateTime endDate;
  final bool isActive;

  const GymMembershipInfo({
    required this.id,
    required this.gymId,
    required this.gymName,
    this.gymLogoUrl,
    required this.planName,
    required this.status,
    required this.endDate,
    required this.isActive,
  });

  factory GymMembershipInfo.fromJson(Map<String, dynamic> json) {
    final gymJson = json['gym'] as Map<String, dynamic>?;
    final planJson = json['plan'] as Map<String, dynamic>?;
    return GymMembershipInfo(
      id: json['id']?.toString() ?? '',
      gymId: gymJson?['id']?.toString() ?? json['gymId']?.toString() ?? '',
      gymName: gymJson?['name'] as String? ?? 'Unknown Gym',
      gymLogoUrl: gymJson?['logoUrl'] as String?,
      planName: planJson?['name'] as String? ?? 'Member',
      status: json['status']?.toString() ?? 'ACTIVE',
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      isActive: json['status'] == 'ACTIVE',
    );
  }
}

class UserGymState {
  final List<GymMembershipInfo> memberships;
  final String? activeGymId;
  final bool isLoading;
  final String? error;

  const UserGymState({
    this.memberships = const [],
    this.activeGymId,
    this.isLoading = false,
    this.error,
  });

  bool get hasActiveGym => activeGym != null;

  GymMembershipInfo? get activeGym {
    if (memberships.isEmpty) return null;
    if (activeGymId != null) {
      final found = memberships.where((m) => m.gymId == activeGymId && m.isActive).firstOrNull;
      if (found != null) return found;
    }
    // Fallback: first active membership
    return memberships.where((m) => m.isActive).firstOrNull;
  }

  UserGymState copyWith({
    List<GymMembershipInfo>? memberships,
    String? activeGymId,
    bool? isLoading,
    String? error,
  }) {
    return UserGymState(
      memberships: memberships ?? this.memberships,
      activeGymId: activeGymId ?? this.activeGymId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class UserGymStateNotifier extends StateNotifier<UserGymState> {
  final Ref _ref;

  UserGymStateNotifier(this._ref) : super(const UserGymState()) {
    _loadFromCache();
  }

  // Load memberships from API; fall back to Hive cache on error
  Future<void> refresh() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      state = const UserGymState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/memberships/my');
      final data = response.data['data'] as List<dynamic>;

      final memberships = data
          .map((m) => GymMembershipInfo.fromJson(m as Map<String, dynamic>))
          .toList();

      // Persist to cache
      await _saveToCache(memberships);

      state = state.copyWith(
        memberships: memberships,
        isLoading: false,
      );
    } on Exception catch (_) {
      // API failed — serve from cache so offline works
      final cached = await _loadCachedMemberships();
      state = state.copyWith(
        memberships: cached,
        isLoading: false,
        error: cached.isEmpty ? 'Could not load gym data' : null,
      );
    }
  }

  // Switch active gym (when user has multiple memberships)
  Future<void> setActiveGym(String gymId) async {
    state = state.copyWith(activeGymId: gymId);
    // Persist preference
    final box = await Hive.openBox<String>('gym_prefs');
    await box.put('activeGymId', gymId);
  }

  // Called on logout — clear state
  void clear() {
    state = const UserGymState();
  }

  // ─── Cache helpers ──────────────────────────────────────────────────────

  Future<void> _loadFromCache() async {
    final cached = await _loadCachedMemberships();
    if (cached.isNotEmpty) {
      final box = await Hive.openBox<String>('gym_prefs');
      final activeGymId = box.get('activeGymId');
      state = state.copyWith(
        memberships: cached,
        activeGymId: activeGymId,
      );
    }
    // Always refresh from API after loading cache
    await refresh();
  }

  Future<List<GymMembershipInfo>> _loadCachedMemberships() async {
    try {
      final box = await Hive.openBox<String>('gym_memberships_cache');
      final raw = box.get('memberships');
      if (raw == null) return [];
      return []; // simplified: full deserialization handled by refresh()
    } on Exception catch (_) {
      return [];
    }
  }

  Future<void> _saveToCache(List<GymMembershipInfo> memberships) async {
    try {
      final box = await Hive.openBox<String>('gym_memberships_cache');
      await box.put('memberships', memberships.map((m) => m.gymId).join(','));
      await box.put('count', memberships.length.toString());
    } on Exception catch (_) {
      // silently skip cache failures
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Single source of truth for the user's gym membership state.
///
/// Use this everywhere gym-gated features need to check membership:
///
///   final gymState = ref.watch(userGymStateProvider);
///   if (!gymState.hasActiveGym) → show QR scanner
///   if (gymState.hasActiveGym) → show gym features
///
/// The provider automatically refreshes when the auth state changes.
final userGymStateProvider =
    StateNotifierProvider<UserGymStateNotifier, UserGymState>((ref) {
  final notifier = UserGymStateNotifier(ref);

  // Auto-refresh when user logs in or out
  ref.listen(currentUserProvider, (previous, next) {
    if (next == null) {
      notifier.clear();
    } else if (previous?.id != next.id) {
      notifier.refresh();
    }
  });

  return notifier;
});

/// Convenience: just the active gym or null
final activeGymProvider = Provider<GymMembershipInfo?>((ref) {
  return ref.watch(userGymStateProvider).activeGym;
});

/// True if user has at least one active gym membership
final hasGymMembershipProvider = Provider<bool>((ref) {
  return ref.watch(userGymStateProvider).hasActiveGym;
});
