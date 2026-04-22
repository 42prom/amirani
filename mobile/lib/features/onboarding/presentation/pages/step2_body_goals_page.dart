import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/ruler_picker.dart';
import '../widgets/unit_toggle.dart';
import '../widgets/health_chips.dart';
import '../widgets/step_indicator.dart';

class Step2BodyGoalsPage extends ConsumerWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step2BodyGoalsPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final isImperial = state.unitSystem == UnitSystem.imperial;

    final double minW = isImperial ? 88.0 : 40.0;
    final double maxW = isImperial ? 440.0 : 200.0;
    final double displayWeight =
        isImperial ? state.weightLbs : state.weightKg;
    final double displayTarget =
        isImperial ? state.targetWeightLbs : state.targetWeightKg;
    final String unit = isImperial ? 'lbs' : 'kg';

    final bool canNext =
        state.noHealthConditions || state.healthConditions.isNotEmpty;

    final bmi = state.bmi;
    final category = state.bmiCategory;
    final Color bmiColor = category == 'Underweight'
        ? const Color(0xFF60A5FA)
        : category == 'Normal'
            ? const Color(0xFF22C55E)
            : category == 'Overweight'
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.textPrimary, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceDark,
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const Spacer(),
                  StepIndicator(totalSteps: 2, currentStep: 2),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // ── Compact header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: AppTheme.primaryBrand.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppTheme.primaryBrand.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      '02  BODY & GOALS',
                      style: TextStyle(
                        color: AppTheme.primaryBrand,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Unit toggle lives here (controls both rulers)
                  UnitToggle(
                    options: const ['kg', 'lbs'],
                    selectedIndex: isImperial ? 1 : 0,
                    onChanged: (i) => notifier.setUnitSystem(
                        i == 0 ? UnitSystem.metric : UnitSystem.imperial),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 50.ms, duration: 300.ms),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),

                    // ─ Current weight ─────────────────────────────────
                    _CompactWeightSection(
                      label: 'Current weight',
                      value: displayWeight,
                      unit: unit,
                      minValue: minW,
                      maxValue: maxW,
                      step: isImperial ? 1.0 : 0.5,
                      decimalPlaces: isImperial ? 0 : 1,
                      onChanged: (v) {
                        final kg = isImperial ? v / 2.20462 : v;
                        notifier.setWeight(kg);
                      },
                    ).animate().fadeIn(delay: 80.ms, duration: 300.ms),

                    const SizedBox(height: 8),

                    // BMI inline badge
                    _BmiInline(
                      bmi: bmi,
                      category: state.bmiCategory,
                      color: bmiColor,
                    ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                    const SizedBox(height: 16),

                    // ─ Target weight ──────────────────────────────────
                    _CompactWeightSection(
                      label: 'Target weight',
                      value: displayTarget,
                      unit: unit,
                      minValue: minW,
                      maxValue: maxW,
                      step: isImperial ? 1.0 : 0.5,
                      decimalPlaces: isImperial ? 0 : 1,
                      suffix: isImperial
                          ? '← ${state.weightLbs.toStringAsFixed(0)} lbs'
                          : '← ${state.weightKg.toStringAsFixed(1)} kg',
                      onChanged: (v) {
                        final kg = isImperial ? v / 2.20462 : v;
                        notifier.setTargetWeight(kg);
                      },
                    ).animate().fadeIn(delay: 120.ms, duration: 300.ms),

                    // Weight diff (compact, only when meaningful)
                    if (state.weightDiffKg.abs() > 0.4)
                      _WeightDiffBadge(
                        diffKg: state.weightDiffKg,
                        diffLbs: state.weightDiffKg * 2.20462,
                        isImperial: isImperial,
                      ).animate().fadeIn(delay: 150.ms, duration: 250.ms),

                    const SizedBox(height: 16),

                    // ─ Health conditions ──────────────────────────────
                    Row(
                      children: [
                        const Text(
                          'Health conditions',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Select all that apply',
                          style: TextStyle(
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 160.ms, duration: 300.ms),

                    const SizedBox(height: 10),

                    HealthChips(
                      selected: state.healthConditions,
                      noneSelected: state.noHealthConditions,
                      onToggle: notifier.toggleHealthCondition,
                      onNoneToggle: notifier.setNoHealthConditions,
                    ).animate().fadeIn(delay: 180.ms, duration: 300.ms),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── GET MY PLAN button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: canNext ? 1.0 : 0.4,
                  child: ElevatedButton(
                    onPressed: canNext ? onNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBrand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'GET MY PLAN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact weight section (label + value + ruler) ───────────────────────────

class _CompactWeightSection extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double minValue;
  final double maxValue;
  final double step;
  final int decimalPlaces;
  final String? suffix;
  final ValueChanged<double> onChanged;

  const _CompactWeightSection({
    required this.label,
    required this.value,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.step,
    required this.decimalPlaces,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: label on left, value on right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    suffix!,
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            // Value display (compact, right-aligned)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value.toStringAsFixed(decimalPlaces),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RulerPicker(
          value: value.clamp(minValue, maxValue),
          minValue: minValue,
          maxValue: maxValue,
          step: step,
          decimalPlaces: decimalPlaces,
          unit: unit,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Inline BMI badge ─────────────────────────────────────────────────────────

class _BmiInline extends StatelessWidget {
  final double bmi;
  final String category;
  final Color color;

  const _BmiInline({
    required this.bmi,
    required this.category,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            'BMI ${bmi.toStringAsFixed(1)}',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '• $category',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compact weight diff badge ─────────────────────────────────────────────────

class _WeightDiffBadge extends StatelessWidget {
  final double diffKg;
  final double diffLbs;
  final bool isImperial;

  const _WeightDiffBadge({
    required this.diffKg,
    required this.diffLbs,
    required this.isImperial,
  });

  @override
  Widget build(BuildContext context) {
    final isLoss = diffKg > 0;
    final color =
        isLoss ? const Color(0xFF22C55E) : const Color(0xFF3B82F6);
    final diffDisplay = isImperial
        ? '${diffLbs.abs().toStringAsFixed(0)} lbs'
        : '${diffKg.abs().toStringAsFixed(1)} kg';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(isLoss ? '🎯' : '💪', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            '${isLoss ? 'Lose' : 'Gain'} $diffDisplay',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '— goal set',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
