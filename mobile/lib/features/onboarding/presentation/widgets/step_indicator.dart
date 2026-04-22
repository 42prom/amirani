import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';

class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep; // 1-based

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final active = i < currentStep;
        final current = i == currentStep - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 4,
          width: current ? 28 : 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? AppTheme.primaryBrand
                : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }
}
