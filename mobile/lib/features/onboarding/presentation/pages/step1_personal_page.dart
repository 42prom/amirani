import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/theme/app_theme.dart';
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
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SizedBox(
              height: 320,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel',
                              style:
                                  TextStyle(color: AppTheme.textSecondary)),
                        ),
                        const Text(
                          'Date of Birth',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            notifier.setDateOfBirth(tempDate);
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            'Done',
                            style: TextStyle(
                              color: AppTheme.primaryBrand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: tempDate,
                      minimumDate: DateTime(1930),
                      maximumDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 10)),
                      onDateTimeChanged: (d) => setModal(() => tempDate = d),
                      backgroundColor: AppTheme.surfaceDark,
                    ),
                  ),
                ],
              ),
            );
          },
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

    final double displayHeight =
        isImperial ? state.heightCm / 2.54 : state.heightCm;
    final double minH = isImperial ? 48.0 : 120.0;
    final double maxH = isImperial ? 96.0 : 244.0;

    final dob = state.dateOfBirth;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dobLabel = '${dob.day} ${months[dob.month - 1]} ${dob.year}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.textPrimary, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceDark,
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const Spacer(),
                  StepIndicator(totalSteps: 2, currentStep: 1),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // ── Two-column body ──────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── LEFT: body + gender + DOB ─────────────────────
                  Expanded(
                    flex: 78,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge row + height value + unit toggle
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  color: AppTheme.primaryBrand
                                      .withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: AppTheme.primaryBrand
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  '01  PERSONAL',
                                  style: TextStyle(
                                    color: AppTheme.primaryBrand,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Current height value
                              isImperial
                                  ? RichText(
                                      text: TextSpan(children: [
                                        TextSpan(
                                          text: "${state.heightFeet}'",
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${state.heightInches}"',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ]),
                                    )
                                  : RichText(
                                      text: TextSpan(children: [
                                        TextSpan(
                                          text: '${state.heightCm.round()}',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' cm',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ]),
                                    ),
                              const SizedBox(width: 8),
                              UnitToggle(
                                options: const ['cm', 'ft'],
                                selectedIndex: isImperial ? 1 : 0,
                                compact: true,
                                onChanged: (i) => notifier.setUnitSystem(i == 0
                                    ? UnitSystem.metric
                                    : UnitSystem.imperial),
                              ),
                            ],
                          ).animate().fadeIn(delay: 50.ms, duration: 300.ms),

                          const SizedBox(height: 8),

                          // Title
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              "Let's know you better",
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ).animate().fadeIn(delay: 80.ms, duration: 350.ms),

                          const SizedBox(height: 10),

                          // Body silhouette — AnimatedSwitcher gives smooth
                          // fade+scale when user changes gender
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.93, end: 1.0)
                                        .animate(CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOut)),
                                    child: child,
                                  ),
                                );
                              },
                              child: _BodySilhouette(
                                key: ValueKey(state.gender),
                                isMale: state.gender != OnboardingGender.female,
                              ),
                            ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
                          ),

                          const SizedBox(height: 8),

                          // Gender tiles — Male / Female only
                          _GenderTiles(
                            selected: state.gender,
                            onChanged: notifier.setGender,
                          ).animate().fadeIn(delay: 150.ms, duration: 300.ms),

                          const SizedBox(height: 8),

                          // DOB tap row
                          GestureDetector(
                            onTap: () => _pickDob(context, state),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppTheme.surfaceDark,
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cake_outlined,
                                      color: AppTheme.primaryBrand, size: 15),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Date of Birth',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        Text(
                                          dobLabel,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(50),
                                      color: AppTheme.primaryBrand
                                          .withValues(alpha: 0.12),
                                    ),
                                    child: Text(
                                      'Age ${state.ageYears}',
                                      style: TextStyle(
                                        color: AppTheme.primaryBrand
                                            .withValues(alpha: 0.9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 180.ms, duration: 300.ms),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ── RIGHT: Height ruler (pure ruler strip) ────────
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
              label: 'NEXT',
              enabled: canNext,
              onTap: canNext ? widget.onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body silhouette (image) ───────────────────────────────────────────────────

class _BodySilhouette extends StatelessWidget {
  final bool isMale;

  const _BodySilhouette({super.key, required this.isMale});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.surfaceDark,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Radial glow behind body
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.1),
                  radius: 0.75,
                  colors: [
                    AppTheme.primaryBrand.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Body image
          Positioned.fill(
            child: Image.asset(
              isMale
                  ? 'assets/images/Mensfrontbody.png'
                  : 'assets/images/woomansfrontbody.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gender tiles (Male / Female only) ────────────────────────────────────────

class _GenderTiles extends StatelessWidget {
  final OnboardingGender? selected;
  final ValueChanged<OnboardingGender> onChanged;

  const _GenderTiles({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile('Male', OnboardingGender.male, Icons.male_rounded),
        const SizedBox(width: 8),
        _tile('Female', OnboardingGender.female, Icons.female_rounded),
      ],
    );
  }

  Widget _tile(String label, OnboardingGender value, IconData icon) {
    final isSelected = selected == value;
    final activeColor = value == OnboardingGender.male
        ? AppTheme.maleBlue
        : AppTheme.femalePink;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? activeColor.withValues(alpha: 0.15)
                : AppTheme.surfaceDark,
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: enabled ? 1.0 : 0.4,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBrand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              elevation: 0,
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
