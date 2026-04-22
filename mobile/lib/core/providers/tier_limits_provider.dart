import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_provider.dart';

class TierLimits {
  final String tier;
  final int aiRequestsPerDay;
  final int workoutPlansPerMonth;
  final int dietPlansPerMonth;
  final bool canAccessAICoach;
  final bool canAccessDietPlanner;

  // Usage counters
  final int dailyRequestsUsed;
  final int dailyRequestsLimit;
  final bool canMakeRequest;
  final bool monthlyLimitReached;
  final bool dailyLimitReached;

  final bool isOfflineFallback;

  const TierLimits({
    required this.tier,
    required this.aiRequestsPerDay,
    required this.workoutPlansPerMonth,
    required this.dietPlansPerMonth,
    required this.canAccessAICoach,
    required this.canAccessDietPlanner,
    required this.dailyRequestsUsed,
    required this.dailyRequestsLimit,
    required this.canMakeRequest,
    this.monthlyLimitReached = false,
    this.dailyLimitReached = false,
    this.isOfflineFallback = false,
  });

  /// Fallback when the tier-limits endpoint is unreachable.
  /// Blocks all generation — cannot grant access without a server-verified response.
  const TierLimits.offline()
      : tier = 'FREE',
        aiRequestsPerDay = 0,
        workoutPlansPerMonth = 0,
        dietPlansPerMonth = 0,
        canAccessAICoach = false,
        canAccessDietPlanner = false,
        dailyRequestsUsed = 0,
        dailyRequestsLimit = 0,
        canMakeRequest = false,
        monthlyLimitReached = false,
        dailyLimitReached = true,
        isOfflineFallback = true;

  factory TierLimits.fromJson(Map<String, dynamic> json) {
    final limits = (json['limits'] as Map<String, dynamic>?) ?? {};
    final usage = (json['usage'] as Map<String, dynamic>?) ?? {};
    return TierLimits(
      tier: json['tier'] as String? ?? 'FREE',
      aiRequestsPerDay: (limits['aiRequestsPerDay'] as num?)?.toInt() ?? 999,
      workoutPlansPerMonth: (limits['workoutPlansPerMonth'] as num?)?.toInt() ?? 999,
      dietPlansPerMonth: (limits['dietPlansPerMonth'] as num?)?.toInt() ?? 999,
      // Default to true — backend rejects over-limit requests server-side anyway.
      // Only block on the frontend when the backend explicitly disables access.
      canAccessAICoach: limits['canAccessAICoach'] as bool? ?? true,
      canAccessDietPlanner: limits['canAccessDietPlanner'] as bool? ?? true,
      dailyRequestsUsed: (usage['dailyRequestsUsed'] as num?)?.toInt() ?? 0,
      dailyRequestsLimit: (usage['dailyRequestsLimit'] as num?)?.toInt() ?? 999,
      canMakeRequest: usage['canMakeRequest'] as bool? ?? true,
      monthlyLimitReached: usage['monthlyLimitReached'] as bool? ?? false,
      dailyLimitReached: usage['dailyLimitReached'] as bool? ?? false,
    );
  }

  /// Human-readable label for upgrade prompts.
  String get tierLabel {
    switch (tier) {
      case 'HOME_PREMIUM':
        return 'Premium';
      case 'GYM_MEMBER':
        return 'Gym Member';
      default:
        return 'Free';
    }
  }

  String get remainingLabel {
    if (monthlyLimitReached) return 'Monthly AI tokens exhausted';
    if (dailyLimitReached) return 'Daily AI limit reached';
    // canMakeRequest=false without a specific limit flag means the backend
    // blocked the request for another reason (e.g. access tier).
    if (!canMakeRequest) return 'AI generation unavailable for your plan';
    return '${dailyRequestsLimit - dailyRequestsUsed} / $dailyRequestsLimit AI requests left today';
  }

  bool get shouldShowLimitBanner => !canMakeRequest;
}

/// Fetches tier limits once per app session; call [refresh] after plan generation
/// or after a gym membership change.
class TierLimitsNotifier extends AsyncNotifier<TierLimits> {
  @override
  Future<TierLimits> build() => _fetch();

  Future<TierLimits> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/sync/tier-limits');
      if (response.statusCode == 200 && response.data['data'] != null) {
        return TierLimits.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    // Endpoint unreachable — fall back to FREE so generation is blocked,
    // never silently granted.
    return const TierLimits.offline();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final tierLimitsProvider =
    AsyncNotifierProvider<TierLimitsNotifier, TierLimits>(() {
  return TierLimitsNotifier();
});
