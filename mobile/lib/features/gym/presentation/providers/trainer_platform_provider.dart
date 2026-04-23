import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/trainer_repository.dart';
import '../../data/repositories/trainer_repository_impl.dart';

// ─── States ───────────────────────────────────────────────────────────────────

class TrainerPlatformState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? dashboardStats;
  final List<dynamic> members;
  final Map<String, Map<String, dynamic>> memberStatsCache;

  TrainerPlatformState({
    this.isLoading = false,
    this.error,
    this.dashboardStats,
    this.members = const [],
    this.memberStatsCache = const {},
  });

  TrainerPlatformState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? dashboardStats,
    List<dynamic>? members,
    Map<String, Map<String, dynamic>>? memberStatsCache,
  }) {
    return TrainerPlatformState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      members: members ?? this.members,
      memberStatsCache: memberStatsCache ?? this.memberStatsCache,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TrainerPlatformNotifier extends StateNotifier<TrainerPlatformState> {
  final TrainerRepository _repository;

  TrainerPlatformNotifier(this._repository) : super(TrainerPlatformState());

  /// Load all dashboard data and assigned members
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    
    final results = await Future.wait([
      _repository.getDashboardStats(),
      _repository.getAssignedMembers(),
    ]);

    final statsRes = results[0] as Either<Failure, Map<String, dynamic>>;
    final membersRes = results[1] as Either<Failure, List<dynamic>>;

    state = state.copyWith(
      isLoading: false,
      dashboardStats: statsRes.isRight() ? statsRes.getOrElse(() => {}) : null,
      members: membersRes.getOrElse(() => []),
      error: statsRes.fold((l) => l.message, (r) => null),
    );
  }

  /// Fetch detailed stats for a specific member
  Future<void> fetchMemberStats(String memberId) async {
    // If already in cache, we could skip or refresh. For now, let's refresh.
    final res = await _repository.getMemberStats(memberId);
    
    res.fold(
      (l) => state = state.copyWith(error: l.message),
      (r) {
        final newCache = Map<String, Map<String, dynamic>>.from(state.memberStatsCache);
        newCache[memberId] = r;
        state = state.copyWith(memberStatsCache: newCache);
      },
    );
  }

  /// Manually refresh dashboard
  Future<void> refresh() => loadAll();
}

// ─── Provider ──────────────────────────────────────────────────────────────────

final trainerPlatformProvider = StateNotifierProvider<TrainerPlatformNotifier, TrainerPlatformState>((ref) {
  return TrainerPlatformNotifier(ref.watch(trainerRepositoryProvider));
});
