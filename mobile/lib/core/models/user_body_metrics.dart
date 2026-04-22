import '../providers/unit_system_provider.dart';

/// Canonical body metrics passed to AI plan generators.
/// All values stored in metric internally; display strings respect [unitSystem].
class UserBodyMetrics {
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final bool isMale;
  final double? targetWeightKg;
  final int? targetCalories;
  final int? tdee;
  final int? targetProteinG;
  final UnitSystem unitSystem;
  final String? medicalConditions;

  const UserBodyMetrics({
    this.weightKg,
    this.heightCm,
    this.age,
    this.isMale = true,
    this.targetWeightKg,
    this.targetCalories,
    this.tdee,
    this.targetProteinG,
    this.unitSystem = UnitSystem.metric,
    this.medicalConditions,
  });

  bool get hasMetrics => weightKg != null && heightCm != null && age != null;

  /// Formatted for AI prompt — always includes both metric and imperial
  /// so the AI can reference either system correctly.
  String toPromptString() {
    if (!hasMetrics) return '';
    final w = weightKg!;
    final h = heightCm!;
    final wLbs = w * 2.20462;
    final hFt = (h / 30.48).floor();
    final hIn = ((h / 2.54) % 12).round();

    final buffer = StringBuffer();
    buffer.writeln('- Age: $age');
    buffer.writeln('- Gender: ${isMale ? 'Male' : 'Female'}');
    buffer.writeln(
        '- Weight: ${w.toStringAsFixed(1)} kg / ${wLbs.toStringAsFixed(0)} lbs');
    buffer.writeln(
        '- Height: ${h.round()} cm / $hFt ft $hIn in');

    if (targetWeightKg != null) {
      final tLbs = targetWeightKg! * 2.20462;
      buffer.writeln(
          '- Target Weight: ${targetWeightKg!.toStringAsFixed(1)} kg / ${tLbs.toStringAsFixed(0)} lbs');
    }
    if (tdee != null) {
      buffer.writeln('- TDEE (maintenance calories): $tdee kcal/day');
    }
    if (targetCalories != null) {
      buffer.writeln('- Daily Calorie Target: $targetCalories kcal');
    }
    if (targetProteinG != null) {
      buffer.writeln('- Protein Target: ${targetProteinG}g/day');
    }
    if (medicalConditions != null && medicalConditions!.isNotEmpty) {
      buffer.writeln('- Health Conditions: $medicalConditions');
    }
    return buffer.toString().trimRight();
  }
}
