import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_providers.dart';

/// App-wide unit system, persisted to SharedPreferences.
/// Canonical internal storage is always metric (kg, cm).
/// This controls how values are *displayed* throughout the app.
enum UnitSystem { metric, imperial }

class UnitSystemNotifier extends StateNotifier<UnitSystem> {
  final SharedPreferences _prefs;

  UnitSystemNotifier(this._prefs) : super(UnitSystem.metric) {
    _load();
  }

  void _load() {
    final stored = _prefs.getString('unit_system') ?? 'metric';
    state = stored == 'imperial' ? UnitSystem.imperial : UnitSystem.metric;
  }

  Future<void> set(UnitSystem system) async {
    state = system;
    await _prefs.setString('unit_system', system.name);
  }
}

final unitSystemProvider =
    StateNotifierProvider<UnitSystemNotifier, UnitSystem>(
  (ref) => UnitSystemNotifier(ref.watch(sharedPreferencesProvider)),
);

// ─── Conversion helpers ───────────────────────────────────────────────────────

class UnitConverter {
  // Weight
  static double kgToLbs(double kg) => kg * 2.20462;
  static double lbsToKg(double lbs) => lbs / 2.20462;

  // Height
  static double cmToInches(double cm) => cm / 2.54;
  static double inchesToCm(double inches) => inches * 2.54;
  static int cmToFeet(double cm) => (cm / 30.48).floor();
  static int cmToRemainderInches(double cm) => ((cm / 2.54) % 12).round();

  // Display string helpers
  static String weightDisplay(double kg, UnitSystem system,
      {int decimals = 1}) {
    if (system == UnitSystem.imperial) {
      return '${kgToLbs(kg).toStringAsFixed(0)} lbs';
    }
    return '${kg.toStringAsFixed(decimals)} kg';
  }

  static String heightDisplay(double cm, UnitSystem system) {
    if (system == UnitSystem.imperial) {
      final ft = cmToFeet(cm);
      final inches = cmToRemainderInches(cm);
      return '$ft ft $inches in';
    }
    return '${cm.round()} cm';
  }

  /// Returns both units side-by-side, e.g. "70 kg (154 lbs)"
  static String weightBoth(double kg) =>
      '${kg.toStringAsFixed(1)} kg (${kgToLbs(kg).toStringAsFixed(0)} lbs)';

  /// Returns both units side-by-side, e.g. "170 cm (5 ft 7 in)"
  static String heightBoth(double cm) {
    final ft = cmToFeet(cm);
    final inches = cmToRemainderInches(cm);
    return '${cm.round()} cm ($ft ft $inches in)';
  }
}
