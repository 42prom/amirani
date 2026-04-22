import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/unit_system_provider.dart';
import '../../../../core/providers/storage_providers.dart';

export '../../../../core/providers/unit_system_provider.dart' show UnitSystem;

enum OnboardingGender { male, female }

class OnboardingState {
  final int currentStep; // 0=welcome, 1=personal, 2=body&goals
  final OnboardingGender? gender;
  final double heightCm;
  final DateTime dateOfBirth; // never null — defaults to 1990-06-15
  final UnitSystem unitSystem;
  final double weightKg;
  final double targetWeightKg;
  final List<String> healthConditions;
  final bool noHealthConditions;

  OnboardingState({
    this.currentStep = 0,
    this.gender,
    this.heightCm = 170.0,
    DateTime? dateOfBirth,
    this.unitSystem = UnitSystem.metric,
    this.weightKg = 70.0,
    this.targetWeightKg = 65.0,
    this.healthConditions = const [],
    this.noHealthConditions = false,
  }) : dateOfBirth = dateOfBirth ?? DateTime(1990, 6, 15);

  OnboardingState copyWith({
    int? currentStep,
    OnboardingGender? gender,
    double? heightCm,
    DateTime? dateOfBirth,
    UnitSystem? unitSystem,
    double? weightKg,
    double? targetWeightKg,
    List<String>? healthConditions,
    bool? noHealthConditions,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      unitSystem: unitSystem ?? this.unitSystem,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      healthConditions: healthConditions ?? this.healthConditions,
      noHealthConditions: noHealthConditions ?? this.noHealthConditions,
    );
  }

  // --- Computed: BMI ---
  double get bmi {
    final h = heightCm / 100;
    return weightKg / (h * h);
  }

  String get bmiCategory {
    final b = bmi;
    final isMale = gender == OnboardingGender.male;

    if (isMale) {
      if (b < 18.5) return 'Underweight';
      if (b < 25.0) return 'Normal';
      if (b < 30.0) return 'Overweight';
      return 'Obese';
    } else {
      // Slightly lower thresholds often used for female physiological differences in "Normal" range
      if (b < 18.0) return 'Underweight';
      if (b < 24.0) return 'Normal';
      if (b < 29.0) return 'Overweight';
      return 'Obese';
    }
  }

  // --- Computed: Age ---
  int get ageYears {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  // --- Height helpers ---
  int get heightFeet => (heightCm / 30.48).floor();
  int get heightInches => ((heightCm / 2.54) % 12).round();

  // --- Weight helpers ---
  double get weightLbs => weightKg * 2.20462;
  double get targetWeightLbs => targetWeightKg * 2.20462;

  double get weightDiffKg => weightKg - targetWeightKg;
  double get weightDiffPct =>
      weightKg > 0 ? ((weightKg - targetWeightKg) / weightKg * 100) : 0;
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final SharedPreferences _prefs;

  OnboardingNotifier(this._prefs) : super(OnboardingState()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final genderStr = _prefs.getString('ob_gender');
    final height = _prefs.getDouble('ob_height_cm');
    final dobStr = _prefs.getString('ob_dob');
    final weight = _prefs.getDouble('ob_weight_kg');
    final targetWeight = _prefs.getDouble('ob_target_weight_kg');
    final conditionsStr = _prefs.getString('ob_health_conditions');
    final noConditions = _prefs.getBool('ob_no_health_conditions');

    state = state.copyWith(
      gender: genderStr != null && genderStr.isNotEmpty
          ? OnboardingGender.values.firstWhere(
              (e) => e.name == genderStr,
              orElse: () => OnboardingGender.male,
            )
          : null,
      heightCm: height ?? state.heightCm,
      dateOfBirth: dobStr != null ? DateTime.tryParse(dobStr) : state.dateOfBirth,
      weightKg: weight ?? state.weightKg,
      targetWeightKg: targetWeight ?? state.targetWeightKg,
      healthConditions: conditionsStr != null && conditionsStr.isNotEmpty
          ? conditionsStr.split(',')
          : state.healthConditions,
      noHealthConditions: noConditions ?? state.noHealthConditions,
    );
  }

  void _persist() {
    _prefs.setString('ob_gender', state.gender?.name ?? '');
    _prefs.setDouble('ob_height_cm', state.heightCm);
    _prefs.setString('ob_dob', state.dateOfBirth.toIso8601String());
    _prefs.setDouble('ob_weight_kg', state.weightKg);
    _prefs.setDouble('ob_target_weight_kg', state.targetWeightKg);
    _prefs.setString('ob_health_conditions', state.healthConditions.join(','));
    _prefs.setBool('ob_no_health_conditions', state.noHealthConditions);
  }

  void nextStep() =>
      state = state.copyWith(currentStep: state.currentStep + 1);
  void prevStep() =>
      state = state.copyWith(currentStep: (state.currentStep - 1).clamp(0, 99));

  void setGender(OnboardingGender g) {
    state = state.copyWith(gender: g);
    _persist();
  }

  void setHeight(double cm) {
    state = state.copyWith(heightCm: cm);
    _persist();
  }

  void setDateOfBirth(DateTime dob) {
    state = state.copyWith(dateOfBirth: dob);
    _persist();
  }

  void setWeight(double kg) {
    state = state.copyWith(weightKg: kg);
    _persist();
  }

  void setTargetWeight(double kg) {
    state = state.copyWith(targetWeightKg: kg);
    _persist();
  }

  void setUnitSystem(UnitSystem s) {
    state = state.copyWith(unitSystem: s);
    // Unit system is generally handled by its own provider, but we could persist here too if needed
  }

  void toggleHealthCondition(String condition) {
    final list = List<String>.from(state.healthConditions);
    list.contains(condition) ? list.remove(condition) : list.add(condition);
    state = state.copyWith(healthConditions: list, noHealthConditions: false);
    _persist();
  }

  void setNoHealthConditions(bool value) {
    state = state.copyWith(
      noHealthConditions: value,
      healthConditions: value ? [] : state.healthConditions,
    );
    _persist();
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(ref.watch(sharedPreferencesProvider)),
);
