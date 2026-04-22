import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';

/// Legacy gender selector widget — not used in the current onboarding flow.
/// Step1 uses the inline _GenderTiles widget instead.
class GenderSelector extends StatelessWidget {
  final OnboardingGender? selected;
  final ValueChanged<OnboardingGender> onChanged;

  const GenderSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderCard(
            label: 'Male',
            icon: '♂',
            emoji: '🏋️',
            color: const Color(0xFF3B82F6),
            selected: selected == OnboardingGender.male,
            onTap: () => onChanged(OnboardingGender.male),
            delay: 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderCard(
            label: 'Female',
            icon: '♀',
            emoji: '🤸',
            color: const Color(0xFFEC4899),
            selected: selected == OnboardingGender.female,
            onTap: () => onChanged(OnboardingGender.female),
            delay: 80,
          ),
        ),
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final String icon;
  final String emoji;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final int delay;

  const _GenderCard({
    required this.label,
    required this.icon,
    required this.emoji,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.08),
                  ]
                : [AppTheme.surfaceDark, AppTheme.surfaceDark],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 4),
                Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ],
          ),
        ),
      )
          .animate(delay: Duration(milliseconds: delay))
          .fadeIn(duration: 300.ms)
          .slideY(
              begin: 0.15,
              end: 0,
              duration: 350.ms,
              curve: Curves.easeOutCubic),
    );
  }
}
