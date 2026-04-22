import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/providers/tier_limits_provider.dart';
import '../../../../core/utils/error_messages.dart';
import 'package:amirani_app/core/localization/l10n_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class GymLanguageConfig {
  final String code;        // e.g. 'ka', 'ru'
  final int version;        // integer — no downgrades without forceRefresh
  final String displayName; // native script e.g. 'ქართული'
  final bool forceRefresh;  // backend sets true to bust cached pack

  const GymLanguageConfig({
    required this.code,
    required this.version,
    required this.displayName,
    this.forceRefresh = false,
  });

  factory GymLanguageConfig.fromJson(Map<String, dynamic> json) {
    return GymLanguageConfig(
      code:         json['code'] as String? ?? 'en',
      version:      (json['version'] as num?)?.toInt() ?? 1,
      displayName:  json['displayName'] as String? ?? '',
      forceRefresh: json['forceRefresh'] as bool? ?? false,
    );
  }
}

class GymMembershipInfo {
  final String id;
  final String gymId;
  final String gymName;
  final String? gymLogoUrl;
  final String status; // ACTIVE | FROZEN | CANCELLED | EXPIRED
  final String endDate;
  final String? trainerId;
  final String? trainerName;
  final String? trainerAvatarUrl;
  final String? trainerSpecialization;
  final GymLanguageConfig? language; // null = gym has no alternative language

  const GymMembershipInfo({
    required this.id,
    required this.gymId,
    required this.gymName,
    this.gymLogoUrl,
    required this.status,
    required this.endDate,
    this.trainerId,
    this.trainerName,
    this.trainerAvatarUrl,
    this.trainerSpecialization,
    this.language,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isPending => status == 'PENDING';
  bool get isAwaitingApproval => status == 'PENDING';
  bool get hasTrainer => trainerId != null;
  bool get hasLanguageConfig => language != null;

  factory GymMembershipInfo.fromJson(Map<String, dynamic> json) {
    final trainerMap  = json['trainer'] as Map<String, dynamic>?;
    final languageMap = json['language'] as Map<String, dynamic>?;
    return GymMembershipInfo(
      id:                    json['id']?.toString() ?? '',
      gymId:                 json['gymId']?.toString() ?? '',
      gymName:               (json['gym'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      gymLogoUrl:            (json['gym'] as Map<String, dynamic>?)?['logoUrl'] as String?,
      status:                json['status'] as String? ?? 'ACTIVE',
      endDate:               json['endDate'] as String? ?? '',
      trainerId:             json['trainerId'] as String?,
      trainerName:           trainerMap?['fullName'] as String?,
      trainerAvatarUrl:      trainerMap?['avatarUrl'] as String?,
      trainerSpecialization: trainerMap?['specialization'] as String?,
      language:              languageMap != null ? GymLanguageConfig.fromJson(languageMap) : null,
    );
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

abstract class MembershipState {}

class MembershipInitial   extends MembershipState {}
class MembershipLoading   extends MembershipState {}
class MembershipLoaded    extends MembershipState {
  final List<GymMembershipInfo> memberships;
  MembershipLoaded(this.memberships);
  bool get hasActiveMembership => memberships.any((m) => m.isActive);
}
class MembershipError extends MembershipState {
  final String message;
  MembershipError(this.message);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MembershipNotifier extends StateNotifier<MembershipState> {
  final Ref _ref;

  MembershipNotifier(this._ref) : super(MembershipInitial()) {
    fetch();
  }

  Future<void> fetch() async {
    state = MembershipLoading();
    try {
      final response = await _ref.read(dioProvider).get('/memberships/my');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      final memberships = data
          .map((j) => GymMembershipInfo.fromJson(j as Map<String, dynamic>))
          .toList();

      state = MembershipLoaded(memberships);

      // Membership tier may have changed (join/leave/expire) — refresh AI limits
      // so the new tier (GYM_MEMBER, HOME_PREMIUM, FREE) is reflected immediately.
      _ref.read(tierLimitsProvider.notifier).refresh();

      // Background language pack sync — silent, no UI blocked.
      // Finds the first active membership that carries a language config.
      final langConfig = memberships
          .where((m) => m.isActive && m.hasLanguageConfig)
          .map((m) => m.language!)
          .firstOrNull;

      if (langConfig != null) {
        _ref.read(l10nProvider.notifier).ensureLanguage(
          lang:         langConfig.code,
          version:      langConfig.version,
          displayName:  langConfig.displayName,
          forceRefresh: langConfig.forceRefresh,
        );
      }
    } catch (e) {
      state = MembershipError(ErrorMessages.from(e, fallback: 'Failed to load memberships'));
    }
  }

  /// Cancel active membership for a gym (DELETE /memberships/leave/:gymId).
  /// Returns an error message string on failure, null on success.
  Future<String?> leaveMembership(String gymId) async {
    try {
      await _ref.read(dioProvider).delete('/memberships/leave/$gymId');
      // Wipe the language pack for this gym — the user no longer belongs to it.
      await _ref.read(l10nProvider.notifier).clearCache();
      await fetch(); // refresh list + tier limits (fetch() calls tierLimits.refresh())
      return null;
    } catch (e) {
      return ErrorMessages.from(e, fallback: 'Failed to leave gym');
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final membershipProvider =
    StateNotifierProvider<MembershipNotifier, MembershipState>((ref) {
  return MembershipNotifier(ref);
});
