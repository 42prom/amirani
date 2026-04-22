import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/presentation/providers/profile_sync_provider.dart';
import '../../features/workout/presentation/providers/workout_onboarding_provider.dart';

/// Tracks profile changes that affect workout plan personalisation and
/// immediately propagates updated body metrics to [workoutOnboardingProvider].
class WorkoutProfileSyncState {
  final double? lastSyncedWeight;
  final double? lastSyncedHeight;
  final int? lastSyncedAge;
  final bool? lastSyncedIsMale;
  final double? lastSyncedTargetWeightKg;
  final bool needsRecalculation;
  final String? changeReason;
  final DateTime? lastChecked;

  const WorkoutProfileSyncState({
    this.lastSyncedWeight,
    this.lastSyncedHeight,
    this.lastSyncedAge,
    this.lastSyncedIsMale,
    this.lastSyncedTargetWeightKg,
    this.needsRecalculation = false,
    this.changeReason,
    this.lastChecked,
  });

  WorkoutProfileSyncState copyWith({
    double? lastSyncedWeight,
    double? lastSyncedHeight,
    int? lastSyncedAge,
    bool? lastSyncedIsMale,
    double? lastSyncedTargetWeightKg,
    bool? needsRecalculation,
    String? changeReason,
    DateTime? lastChecked,
  }) {
    return WorkoutProfileSyncState(
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
}

class WorkoutProfileSyncNotifier
    extends StateNotifier<WorkoutProfileSyncState> {
  final Ref _ref;

  WorkoutProfileSyncNotifier(this._ref)
      : super(const WorkoutProfileSyncState()) {
    _ref.listen(profileSyncProvider, _onProfileChange);
    _initializeFromCurrentProfile();
  }

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

    // Recalculate age from DOB
    final newAge = _calculateAge(current.dob);

    final changes = <String>[];

    // Weight change > 1 kg
    final oldWeight = state.lastSyncedWeight;
    if (newWeight != null && oldWeight != null) {
      final diff = (newWeight - oldWeight).abs();
      if (diff >= 1.0) changes.add('weight ${diff.toStringAsFixed(1)} kg');
    }

    // Height change > 1 cm
    final oldHeight = state.lastSyncedHeight;
    if (newHeight != null && oldHeight != null) {
      if ((newHeight - oldHeight).abs() >= 1.0) changes.add('height updated');
    }

    // Gender change
    if (state.lastSyncedIsMale != null && newIsMale != state.lastSyncedIsMale) {
      changes.add('gender updated');
    }

    // Target weight change > 0.5 kg
    final oldTarget = state.lastSyncedTargetWeightKg;
    if (newTarget != null && oldTarget != null) {
      if ((newTarget - oldTarget).abs() >= 0.5) {
        changes.add('target weight updated');
      }
    }

    if (changes.isNotEmpty) {
      // ── Immediately apply to workout provider so AI prompt stays fresh ──
      _ref.read(workoutOnboardingProvider.notifier).updateUserMetrics(
        weightKg: newWeight,
        heightCm: newHeight,
        isMale: newIsMale,
        age: newAge,
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
    final newAge = _calculateAge(profile.dob);

    _ref.read(workoutOnboardingProvider.notifier).updateUserMetrics(
      weightKg: newWeight,
      heightCm: newHeight,
      isMale: newIsMale,
      age: newAge,
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

  double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  int? _calculateAge(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    try {
      final birth = DateTime.parse(dob);
      final today = DateTime.now();
      int age = today.year - birth.year;
      if (today.month < birth.month ||
          (today.month == birth.month && today.day < birth.day)) {
        age--;
      }
      return age > 0 ? age : null;
    } catch (_) {
      return null;
    }
  }
}

final workoutProfileSyncProvider = StateNotifierProvider<
    WorkoutProfileSyncNotifier, WorkoutProfileSyncState>((ref) {
  return WorkoutProfileSyncNotifier(ref);
});
