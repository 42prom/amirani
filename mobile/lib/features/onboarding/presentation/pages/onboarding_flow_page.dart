import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_provider.dart';
import '../../../../core/providers/unit_system_provider.dart';
import '../../../../core/providers/storage_providers.dart';
import 'onboarding_welcome_page.dart';
import 'step1_personal_page.dart';
import 'step2_body_goals_page.dart';

class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  final PageController _pageController = PageController();

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finish() async {
    final state = ref.read(onboardingProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    // Mark onboarding done
    await prefs.setBool('onboarding_complete', true);

    // Persist unit system globally
    await ref.read(unitSystemProvider.notifier).set(state.unitSystem);

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Page 0: Welcome
        OnboardingWelcomePage(
          onReady: () {
            ref.read(onboardingProvider.notifier).nextStep();
            _goTo(1);
          },
        ),
        // Page 1: Personal (gender, height, DOB)
        Step1PersonalPage(
          onNext: () {
            ref.read(onboardingProvider.notifier).nextStep();
            _goTo(2);
          },
          onBack: () {
            ref.read(onboardingProvider.notifier).prevStep();
            _goTo(0);
          },
        ),
        // Page 2: Body & Goals (weight, target, health)
        Step2BodyGoalsPage(
          onNext: _finish,
          onBack: () {
            ref.read(onboardingProvider.notifier).prevStep();
            _goTo(1);
          },
        ),
      ],
    );
  }
}
