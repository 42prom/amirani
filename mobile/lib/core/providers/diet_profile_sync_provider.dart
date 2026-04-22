import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/presentation/providers/profile_sync_provider.dart';
import '../../features/diet/presentation/providers/diet_onboarding_provider.dart';

/// State for tracking profile changes that affect diet calculations
class DietProfileSyncState {
  final double? lastSyncedWeight;
  final double? lastSyncedHeight;
  final int? lastSyncedAge;
  final bool? lastSyncedIsMale;
  final double? lastSyncedTargetWeightKg;
  final bool needsRecalculation;
  final String? changeReason;
  final DateTime? lastChecked;

  const DietProfileSyncState({
    this.lastSyncedWeight,
    this.lastSyncedHeight,
    this.lastSyncedAge,
    this.lastSyncedIsMale,
    this.lastSyncedTargetWeightKg,
    this.needsRecalculation = false,
    this.changeReason,
    this.lastChecked,
  });

  DietProfileSyncState copyWith({
    double? lastSyncedWeight,
    double? lastSyncedHeight,
    int? lastSyncedAge,
    bool? lastSyncedIsMale,
    double? lastSyncedTargetWeightKg,
    bool? needsRecalculation,
    String? changeReason,
    DateTime? lastChecked,
  }) {
    return DietProfileSyncState(
      lastSyncedWeight: lastSyncedWeight ?? this.lastSyncedWeight,
      lastSyncedHeight: lastSyncedHeight ?? this.lastSyncedHeight,
      lastSyncedAge: lastSyncedAge ?? this.lastSyncedAge,
      lastSyncedIsMale: lastSyncedIsMale ?? this.lastSyncedIsMale,
      lastSyncedTargetWeightKg:
          lastSyncedTargetWeightKg ?? this.lastSyncedTargetWeightKg,
      needsRecalculation: needsRecalculation ?? this.needsRecalculation,
      changeReason: changeReason,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  /// Calculate estimated calorie impact of changes
  int get estimatedCalorieImpact {
    // Gender change affects ~161 calories (Mifflin-St Jeor)
    // Weight change: ~10 calories per kg
    // Height change: ~6.25 calories per cm
    int impact = 0;

    // These are rough estimates for user awareness
    if (lastSyncedIsMale != null && changeReason?.contains('gender') == true) {
      impact += 161;
    }

    return impact;
  }
}

/// Notifier for tracking profile changes that affect diet calculations
class DietProfileSyncNotifier extends StateNotifier<DietProfileSyncState> {
  final Ref _ref;

  DietProfileSyncNotifier(this._ref) : super(const DietProfileSyncState()) {
    // Listen to profile changes
    _ref.listen(profileSyncProvider, _onProfileChange);
    // Initialize from current profile
    _initializeFromCurrentProfile();
  }

  /// Initialize state from current profile values
  void _initializeFromCurrentProfile() {
    final profile = _ref.read(profileSyncProvider);
    state = state.copyWith(
      lastSyncedWeight: _parseDouble(profile.weight),
      lastSyncedHeight: _parseDouble(profile.height),
      lastSyncedIsMale: profile.gender.toLowerCase() != 'female',
      lastSyncedTargetWeightKg: profile.targetWeightKg,
      lastChecked: DateTime.now(),
    );
  }

  /// Called when profile changes — immediately syncs metrics, flags AI regen
  void _onProfileChange(ProfileSyncState? previous, ProfileSyncState current) {
    if (previous == null) return;
    if (!mounted) return;

    final newWeight = _parseDouble(current.weight);
    final newHeight = _parseDouble(current.height);
    final newIsMale = current.gender.toLowerCase() != 'female';
    final newTarget = current.targetWeightKg;

    final changes = <String>[];

    // Weight change > 1 kg
    final oldWeight = state.lastSyncedWeight;
    if (newWeight != null && oldWeight != null) {
      final diff = (newWeight - oldWeight).abs();
      if (diff >= 1.0) {
        changes.add('Weight changed by ${diff.toStringAsFixed(1)} kg');
      }
    }

    // Height change > 1 cm
    final oldHeight = state.lastSyncedHeight;
    if (newHeight != null && oldHeight != null) {
      if ((newHeight - oldHeight).abs() >= 1.0) {
        changes.add('Height updated');
      }
    }

    // Gender change
    if (state.lastSyncedIsMale != null && newIsMale != state.lastSyncedIsMale) {
      changes.add('Gender updated');
    }

    // Target weight change > 0.5 kg
    final oldTarget = state.lastSyncedTargetWeightKg;
    if (newTarget != null && oldTarget != null) {
      if ((newTarget - oldTarget).abs() >= 0.5) {
        changes.add('Goal weight updated');
      }
    }

    if (changes.isNotEmpty) {
      // ── Immediately apply to diet provider so TDEE/macros stay fresh ──
      _ref.read(dietOnboardingProvider.notifier).updateUserMetrics(
        weightKg: newWeight,
        heightCm: newHeight,
        isMale: newIsMale,
        targetWeightKg: newTarget,
      );

      state = state.copyWith(
        needsRecalculation: true,
        changeReason: changes.join(', '),
        lastSyncedWeight: newWeight,
        lastSyncedHeight: newHeight,
        lastSyncedIsMale: newIsMale,
        lastSyncedTargetWeightKg: newTarget,
        lastChecked: DateTime.now(),
      );
    }
  }

  /// User confirms they want a full AI plan regeneration
  void triggerPlanRegeneration() {
    final profile = _ref.read(profileSyncProvider);
    final newWeight = _parseDouble(profile.weight);
    final newHeight = _parseDouble(profile.height);
    final newIsMale = profile.gender.toLowerCase() != 'female';
    final newTarget = profile.targetWeightKg;

    _ref.read(dietOnboardingProvider.notifier).updateUserMetrics(
      weightKg: newWeight,
      heightCm: newHeight,
      isMale: newIsMale,
      targetWeightKg: newTarget,
    );

    state = state.copyWith(
      needsRecalculation: false,
      changeReason: null,
      lastSyncedWeight: newWeight,
      lastSyncedHeight: newHeight,
      lastSyncedIsMale: newIsMale,
      lastSyncedTargetWeightKg: newTarget,
      lastChecked: DateTime.now(),
    );
  }

  /// Dismiss the full-regen prompt without generating a new plan
  void dismissRegenerationPrompt() {
    final profile = _ref.read(profileSyncProvider);
    state = state.copyWith(
      needsRecalculation: false,
      changeReason: null,
      lastSyncedWeight: _parseDouble(profile.weight),
      lastSyncedHeight: _parseDouble(profile.height),
      lastSyncedIsMale: profile.gender.toLowerCase() != 'female',
      lastSyncedTargetWeightKg: profile.targetWeightKg,
      lastChecked: DateTime.now(),
    );
  }

  /// Force a check for profile changes (can be called manually)
  void checkForChanges() {
    final profile = _ref.read(profileSyncProvider);
    _onProfileChange(null, profile);
  }

  /// Parse numeric value from string (handles various formats)
  double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    // Remove any non-numeric characters except decimal point
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }
}

/// Provider for diet profile sync
final dietProfileSyncProvider =
    StateNotifierProvider<DietProfileSyncNotifier, DietProfileSyncState>((ref) {
  return DietProfileSyncNotifier(ref);
});
