import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../design_system/tokens/app_tokens.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/components/glass_onboarding_background.dart';
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
    final double displayWeight = isImperial ? state.weightLbs : state.weightKg;
    final double displayTarget = isImperial ? state.targetWeightLbs : state.targetWeightKg;
    final String unit = isImperial ? 'lbs' : 'kg';

    final bool canNext = state.noHealthConditions || state.healthConditions.isNotEmpty;

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
      backgroundColor: Colors.transparent,
      body: GlassOnboardingBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTokens.colorTextPrimary, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const Spacer(),
                    StepIndicator(totalSteps: 2, currentStep: 2),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              // ── Compact header ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        color: AppTokens.colorBrand.withValues(alpha: 0.15),
                        border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        '02  BODY & GOALS',
                        style: TextStyle(
                          color: AppTokens.colorBrand,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    UnitToggle(
                      options: const ['kg', 'lbs'],
                      selectedIndex: isImperial ? 1 : 0,
                      onChanged: (i) => notifier.setUnitSystem(i == 0 ? UnitSystem.metric : UnitSystem.imperial),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              // ── Scrollable content ───────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      Text(
                        "Your Goals",
                        style: AppTokens.textDisplayMd.copyWith(fontSize: 28),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: -0.1, end: 0),

                      const SizedBox(height: 20),

                      // ─ Current weight ─────────────────────────────────
                      GlassCard(
                        child: _CompactWeightSection(
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
                        ),
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: 12),

                      // BMI inline badge
                      _BmiInline(
                        bmi: bmi,
                        category: state.bmiCategory,
                        color: bmiColor,
                      ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                      const SizedBox(height: 16),

                      // ─ Target weight ──────────────────────────────────
                      GlassCard(
                        child: _CompactWeightSection(
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
                        ),
                      ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                      // Weight diff
                      if (state.weightDiffKg.abs() > 0.4)
                        _WeightDiffBadge(
                          diffKg: state.weightDiffKg,
                          diffLbs: state.weightDiffKg * 2.20462,
                          isImperial: isImperial,
                        ).animate().fadeIn(delay: 600.ms, duration: 300.ms),

                      const SizedBox(height: 24),

                      // ─ Health conditions ──────────────────────────────
                      Row(
                        children: [
                          const Text(
                            'HEALTH CONDITIONS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Select all that apply',
                            style: AppTokens.textLabelSm.copyWith(fontSize: 10),
                          ),
                        ],
                      ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

                      const SizedBox(height: 12),

                      GlassCard(
                        padding: const EdgeInsets.all(AppTokens.space16),
                        child: HealthChips(
                          selected: state.healthConditions,
                          noneSelected: state.noHealthConditions,
                          onToggle: notifier.toggleHealthCondition,
                          onNoneToggle: notifier.setNoHealthConditions,
                        ),
                      ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── GET MY PLAN button ───────────────────────────────────────
              _BottomButton(
                label: 'GENERATE PLAN',
                enabled: canNext,
                onTap: canNext ? onNext : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact weight section ───────────────────────────

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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppTokens.colorTextSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    suffix!,
                    style: TextStyle(
                      color: AppTokens.colorBrand.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value.toStringAsFixed(decimalPlaces),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: AppTokens.colorTextSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'BMI ${bmi.toStringAsFixed(1)}',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '• $category',
            style: AppTokens.textLabelSm,
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
    final color = isLoss ? const Color(0xFF22C55E) : const Color(0xFF3B82F6);
    final diffDisplay = isImperial ? '${diffLbs.abs().toStringAsFixed(0)} lbs' : '${diffKg.abs().toStringAsFixed(1)} kg';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(isLoss ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '${isLoss ? 'LOSE' : 'GAIN'} $diffDisplay GOAL',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom button ─────────────────────────────────────────────────────────────

class _BottomButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _BottomButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTokens.colorBrand.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ]
              : null,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: enabled ? 1.0 : 0.4,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.colorBrand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius16),
              ),
              elevation: 0,
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
