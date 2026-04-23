import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../../../design_system/tokens/app_tokens.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/components/glass_onboarding_background.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/vertical_ruler_picker.dart';
import '../widgets/unit_toggle.dart';
import '../widgets/step_indicator.dart';

class Step1PersonalPage extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step1PersonalPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<Step1PersonalPage> createState() => _Step1PersonalPageState();
}

class _Step1PersonalPageState extends ConsumerState<Step1PersonalPage> {
  void _pickDob(BuildContext context, OnboardingState state) {
    final notifier = ref.read(onboardingProvider.notifier);
    DateTime tempDate = state.dateOfBirth;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (_) {
        return GlassCard(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: SizedBox(
            height: 350,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel',
                            style: AppTokens.textLabelSm.copyWith(color: AppTokens.colorTextSecondary)),
                      ),
                      Text(
                        'Date of Birth',
                        style: AppTokens.textHeadingMd,
                      ),
                      TextButton(
                        onPressed: () {
                          notifier.setDateOfBirth(tempDate);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Done',
                          style: AppTokens.textLabelSm.copyWith(
                            color: AppTokens.colorBrand,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32, color: AppTokens.colorBorderSubtle),
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: tempDate,
                      minimumDate: DateTime(1930),
                      maximumDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                      onDateTimeChanged: (d) => setState(() => tempDate = d),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final isImperial = state.unitSystem == UnitSystem.imperial;
    final canNext = state.gender != null;

    final double displayHeight = isImperial ? state.heightCm / 2.54 : state.heightCm;
    final double minH = isImperial ? 48.0 : 120.0;
    final double maxH = isImperial ? 96.0 : 244.0;

    final dob = state.dateOfBirth;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dobLabel = '${dob.day} ${months[dob.month - 1]} ${dob.year}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassOnboardingBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTokens.colorTextPrimary, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const Spacer(),
                    StepIndicator(totalSteps: 2, currentStep: 1),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              // ── Two-column body ──────────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── LEFT: body + gender + DOB ─────────────────────
                    Expanded(
                      flex: 78,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge row + height value + unit toggle
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(50),
                                    color: AppTokens.colorBrand.withValues(alpha: 0.15),
                                    border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    '01  PERSONAL',
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
                                  options: const ['cm', 'ft'],
                                  selectedIndex: isImperial ? 1 : 0,
                                  compact: true,
                                  onChanged: (i) =>
                                      notifier.setUnitSystem(i == 0 ? UnitSystem.metric : UnitSystem.imperial),
                                ),
                              ],
                            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                            const SizedBox(height: 12),

                            // Title
                            Text(
                              "Your Profile",
                              style: AppTokens.textDisplayMd.copyWith(fontSize: 28),
                            ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: -0.1, end: 0),

                            const SizedBox(height: 16),

                            // Body silhouette
                            Expanded(
                              child: GlassCard(
                                padding: EdgeInsets.zero,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  child: _BodySilhouette(
                                    key: ValueKey(state.gender),
                                    isMale: state.gender != OnboardingGender.female,
                                  ),
                                ),
                              ).animate().fadeIn(delay: 300.ms, duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),
                            ),

                            const SizedBox(height: 12),

                            // Gender tiles
                            _GenderTiles(
                              selected: state.gender,
                              onChanged: notifier.setGender,
                            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                            const SizedBox(height: 12),

                            // DOB tap row
                            GestureDetector(
                              onTap: () => _pickDob(context, state),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                borderRadius: BorderRadius.circular(16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cake_rounded, color: AppTokens.colorBrand, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'DATE OF BIRTH',
                                            style: AppTokens.textLabelSm.copyWith(
                                              fontSize: 9,
                                              letterSpacing: 1.2,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dobLabel,
                                            style: AppTokens.textHeadingMd,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                                        color: Colors.white.withValues(alpha: 0.1),
                                      ),
                                      child: Text(
                                        'Age ${state.ageYears}',
                                        style: AppTokens.textLabelSm.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                          ],
                        ),
                      ),
                    ),

                    // ── RIGHT: Height ruler ────────
                    Expanded(
                      flex: 20,
                      child: VerticalRulerPicker(
                        value: displayHeight.clamp(minH, maxH),
                        minValue: minH,
                        maxValue: maxH,
                        step: 1.0,
                        decimalPlaces: 0,
                        tickSpacing: 10.0,
                        onChanged: (v) {
                          final cm = isImperial ? v * 2.54 : v;
                          notifier.setHeight(cm);
                        },
                        isImperial: isImperial,
                      ),
                    ),
                  ],
                ),
              ),

              // ── NEXT button ──────────────────────────────────────────
              _BottomButton(
                label: 'CONTINUE',
                enabled: canNext,
                onTap: canNext ? widget.onNext : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body silhouette ───────────────────────────────────────────────────

class _BodySilhouette extends StatelessWidget {
  final bool isMale;

  const _BodySilhouette({super.key, required this.isMale});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.1),
                radius: 0.8,
                colors: [
                  AppTokens.colorBrand.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Image.asset(
              isMale ? 'assets/images/Mensfrontbody.png' : 'assets/images/woomansfrontbody.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Gender tiles ────────────────────────────────────────

class _GenderTiles extends StatelessWidget {
  final OnboardingGender? selected;
  final ValueChanged<OnboardingGender> onChanged;

  const _GenderTiles({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile('MALE', OnboardingGender.male, Icons.male_rounded),
        const SizedBox(width: 12),
        _tile('FEMALE', OnboardingGender.female, Icons.female_rounded),
      ],
    );
  }

  Widget _tile(String label, OnboardingGender value, IconData icon) {
    final isSelected = selected == value;
    final activeColor = value == OnboardingGender.male ? AppTheme.maleBlue : AppTheme.femalePink;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: BorderRadius.circular(16),
          borderColor: isSelected ? activeColor : null,
          backgroundColor: isSelected ? activeColor.withValues(alpha: 0.1) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : AppTokens.colorTextSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTokens.textLabelSm.copyWith(
                  color: isSelected ? activeColor : AppTokens.colorTextSecondary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
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
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
