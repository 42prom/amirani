import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../providers/diet_onboarding_provider.dart';
import '../../domain/entities/diet_preferences_entity.dart';
import '../../domain/entities/monthly_plan_entity.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';

class DietOnboardingPage extends ConsumerStatefulWidget {
  const DietOnboardingPage({super.key});

  @override
  ConsumerState<DietOnboardingPage> createState() => _DietOnboardingPageState();
}

class _DietOnboardingPageState extends ConsumerState<DietOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentFoodIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dietOnboardingProvider);
    final profileSync = ref.watch(profileSyncProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85 + bottomInset,
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: AppTokens.colorBgPrimary.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(state, profileSync),
              Expanded(
                child: _buildStepContent(state),
              ),
              _buildStickyFooter(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyFooter(DietOnboardingState state) {
    String label = 'Continue';
    IconData? icon;
    VoidCallback? onTap;
    bool enabled = true;

    switch (state.currentStep) {
      case DietOnboardingStep.healthCheck:
        if (state.medicalConditionsText != null &&
            state.medicalConditionsText!.isNotEmpty) {
          label = 'This is correct';
          onTap = () =>
              ref.read(dietOnboardingProvider.notifier).confirmHealthData();
        } else {
          return const SizedBox.shrink();
        }
        break;
      case DietOnboardingStep.goalSelection:
        label = 'Continue';
        onTap = () => ref.read(dietOnboardingProvider.notifier).nextStep();
        // Require both weight and goal to be selected
        enabled = state.selectedGoal != null && state.weightKg != null;
        break;
      case DietOnboardingStep.dietaryStyle:
        label = 'Continue';
        onTap = () => ref.read(dietOnboardingProvider.notifier).nextStep();
        break;
      case DietOnboardingStep.foodPreferences:
        label = 'Continue';
        onTap = () => ref.read(dietOnboardingProvider.notifier).nextStep();
        break;
      case DietOnboardingStep.mealSettings:
        label = 'Generate My Plan';
        icon = Icons.auto_awesome;
        onTap = () => ref.read(dietOnboardingProvider.notifier).generatePlan();
        break;
      case DietOnboardingStep.generating:
        // Return the premium progress button instead of empty space
        return Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: AppTokens.colorBgPrimary,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Container(color: AppTokens.colorBrand),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: MediaQuery.of(context).size.width * state.generationProgress,
                    height: double.infinity,
                    color: const Color(0xFF2ECC71),
                  ),
                  Center(
                    child: Text(
                      'Synchronizing...',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case DietOnboardingStep.complete:
        label = 'Start My Journey';
        icon = Icons.rocket_launch;
        onTap = () => Navigator.pop(context, state.generatedPlan);
        break;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppTokens.colorBgPrimary,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: _buildPrimaryButton(
        label: label,
        icon: icon,
        onTap: enabled ? onTap : () {},
        enabled: enabled,
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(DietOnboardingState state, ProfileSyncState profileSync) {
    final stepIndex = state.currentStep.index;
    const totalSteps = 5; // Health, Goal, Style, Foods, Settings
    final bool showBack = stepIndex > 0 &&
        state.currentStep != DietOnboardingStep.generating &&
        state.currentStep != DietOnboardingStep.complete;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Back Button / Profile Circle
          GestureDetector(
            onTap: showBack
                ? () => ref.read(dietOnboardingProvider.notifier).previousStep()
                : null,
            child: SizedBox(
              height: 48,
              width: 48,
              child: showBack
                  ? const Center(
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 16),
          // Progress Indicator
          Expanded(
            child: state.currentStep == DietOnboardingStep.generating ||
                    state.currentStep == DietOnboardingStep.complete
                ? const SizedBox.shrink()
                : _buildProgressIndicator(stepIndex, totalSteps),
          ),
          const SizedBox(width: 16),
          // Close Button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (index) {
        final isActive = index <= current;
        final isCurrent = index == current;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < total - 1 ? 8 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isActive
                  ? AppTokens.colorBrand
                  : Colors.white.withValues(alpha: 0.1),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppTokens.colorBrand.withValues(alpha: 0.5),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent(DietOnboardingState state) {
    switch (state.currentStep) {
      case DietOnboardingStep.healthCheck:
        return _buildHealthCheckStep(state);
      case DietOnboardingStep.goalSelection:
        return _buildGoalSelectionStep(state);
      case DietOnboardingStep.dietaryStyle:
        return _buildDietaryStyleStep(state);
      case DietOnboardingStep.foodPreferences:
        return _buildFoodPreferencesStep(state);
      case DietOnboardingStep.mealSettings:
        return _buildMealSettingsStep(state);
      case DietOnboardingStep.generating:
        return _buildGeneratingStep(state);
      case DietOnboardingStep.complete:
        return _buildCompleteStep(state);
    }
  }

  // ============================================================
  // STEP 1: HEALTH CHECK
  // ============================================================
  Widget _buildHealthCheckStep(DietOnboardingState state) {
    final hasData = state.medicalConditionsText != null &&
        state.medicalConditionsText!.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll make sure your diet plan is safe for you',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          if (hasData) ...[
            _buildInfoCard(
              icon: Icons.shield_outlined,
              iconColor: AppTokens.colorBrand,
              title: 'We found in your profile:',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.medicalConditionsText!,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Color(0xFF2ECC71), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'We\'ll avoid these in your plan',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSecondaryButton(
              label: 'Edit Health Info',
              onTap: () {
                _showHealthInputDialog();
              },
            ),
          ] else ...[
            _buildInfoCard(
              icon: Icons.help_outline,
              iconColor: Colors.white54,
              title: 'Do you have any allergies or health conditions?',
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'This helps us create a safe diet plan for you',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionCard(
              icon: Icons.check_circle_outline,
              title: 'I\'m healthy',
              subtitle: 'No allergies or medical conditions',
              isSelected: false,
              onTap: () {
                ref
                    .read(dietOnboardingProvider.notifier)
                    .confirmNoHealthIssues();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              icon: Icons.medical_information_outlined,
              title: 'I have health conditions',
              subtitle: 'Allergies, diabetes, dietary restrictions, etc.',
              isSelected: false,
              onTap: () {
                _showHealthInputDialog();
              },
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showHealthInputDialog() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTokens.colorBgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Health Conditions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter any allergies, medical conditions, or dietary restrictions',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      'e.g., Lactose intolerant, peanut allergy, diabetes...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTokens.colorBrand),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      ref
                          .read(dietOnboardingProvider.notifier)
                          .saveHealthConditions(controller.text);
                      Navigator.pop(context);
                      ref.read(dietOnboardingProvider.notifier).nextStep();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.colorBrand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save & Continue',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STEP 2: GOAL SELECTION
  // ============================================================
  Widget _buildGoalSelectionStep(DietOnboardingState state) {
    // Check if weight is missing
    final hasWeight = state.weightKg != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What\'s your goal?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This helps us calculate your daily calories',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          // Weight Metrics Card - shows calculation basis
          _buildWeightMetricsCard(state, hasWeight),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.local_fire_department,
                  title: 'Lose Weight',
                  subtitle: '-0.5 kg/week',
                  goal: DietGoal.weightLoss,
                  isSelected: state.selectedGoal == DietGoal.weightLoss,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.fitness_center,
                  title: 'Build Muscle',
                  subtitle: '+0.3 kg/week',
                  goal: DietGoal.muscleGain,
                  isSelected: state.selectedGoal == DietGoal.muscleGain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.balance,
                  title: 'Maintain',
                  subtitle: 'Stay balanced',
                  goal: DietGoal.maintenance,
                  isSelected: state.selectedGoal == DietGoal.maintenance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.eco,
                  title: 'Clean Eating',
                  subtitle: 'Whole foods',
                  goal: DietGoal.cleanEating,
                  isSelected: state.selectedGoal == DietGoal.cleanEating,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.medical_services_outlined,
                  title: 'Medical Diet',
                  subtitle: 'Health focused',
                  goal: DietGoal.medicalDiet,
                  isSelected: state.selectedGoal == DietGoal.medicalDiet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.speed,
                  title: 'Performance',
                  subtitle: 'Athletic goals',
                  goal: DietGoal.performance,
                  isSelected: state.selectedGoal == DietGoal.performance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Weight metrics card showing calculation basis
  Widget _buildWeightMetricsCard(DietOnboardingState state, bool hasWeight) {
    if (!hasWeight) {
      return _buildWeightInputCard();
    }

    // Labels and multipliers for each activity level — drives both UI and TDEE.
    // Order matches ActivityLevel enum declaration.
    const activityLabels = ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'];
    const activityValues = ActivityLevel.values;

    // What to display in the calorie row:
    //   • No goal selected yet → show maintenance TDEE ("your baseline")
    //   • Goal selected        → show the adjusted target ("your daily target")
    final bool goalPicked   = state.selectedGoal != null;
    final int? displayedCal = goalPicked ? state.targetCalories : state.tdee?.round();
    final String calLabel   = goalPicked ? 'Your Daily Target' : 'Maintenance (TDEE)';
    final String? bmrNote   = state.bmr != null
        ? 'BMR ${state.bmr!.round()} kcal · ${_activityLabel(state.activityLevel)}'
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.colorBrand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.colorBrand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate_outlined,
                    color: AppTokens.colorBrand, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Your calorie calculation',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Weight + Height row ──────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Weight tile
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showWeightEditDialog(state.weightKg),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monitor_weight_outlined,
                              color: AppTokens.colorBrand, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Weight',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10)),
                                Text(
                                  '${state.weightKg?.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_outlined,
                              color:
                                  AppTokens.colorBrand.withValues(alpha: 0.7),
                              size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Height tile
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showHeightEditDialog(state.heightCm),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.heightCm == null
                              ? AppTokens.colorBrand.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.height,
                              color: AppTokens.colorBrand, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Height',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10)),
                                Text(
                                  state.heightCm != null
                                      ? '${state.heightCm!.toStringAsFixed(0)} cm'
                                      : 'Tap to add',
                                  style: TextStyle(
                                    color: state.heightCm != null
                                        ? Colors.white
                                        : AppTokens.colorBrand,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_outlined,
                              color:
                                  AppTokens.colorBrand.withValues(alpha: 0.7),
                              size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Activity level selector ──────────────────────────────────
          // This is the input that most directly controls the calorie output.
          // Was previously hardcoded to moderate — now the member chooses it.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activity Level',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(activityValues.length, (i) {
                    final level  = activityValues[i];
                    final label  = activityLabels[i];
                    final active = state.activityLevel == level;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => ref
                            .read(dietOnboardingProvider.notifier)
                            .setActivityLevel(level),
                        child: Container(
                          margin: EdgeInsets.only(
                              right: i < activityValues.length - 1 ? 4 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: active
                                ? AppTokens.colorBrand
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            // Shorten to first word so it fits in the chip
                            label.split(' ').first,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: active ? Colors.black : Colors.white54,
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Calorie result row ───────────────────────────────────────
          // Shows maintenance TDEE before goal selection, then switches to
          // the actual adjusted target once a goal is picked.
          if (displayedCal != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: goalPicked
                    ? AppTokens.colorBrand.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: goalPicked
                    ? Border.all(
                        color: AppTokens.colorBrand.withValues(alpha: 0.4))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    goalPicked
                        ? Icons.flag_outlined
                        : Icons.local_fire_department,
                    color: AppTokens.colorBrand,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(calLabel,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                        Text(
                          '$displayedCal kcal/day',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (bmrNote != null)
                          Text(bmrNote,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _activityLabel(ActivityLevel level) {
    const labels = {
      ActivityLevel.sedentary:  'Sedentary ×1.2',
      ActivityLevel.light:      'Light ×1.375',
      ActivityLevel.moderate:   'Moderate ×1.55',
      ActivityLevel.active:     'Active ×1.725',
      ActivityLevel.veryActive: 'Very Active ×1.9',
    };
    return labels[level] ?? '';
  }

  /// Weight input card for first-time entry
  Widget _buildWeightInputCard() {
    final controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTokens.colorBrand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.colorBrand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppTokens.colorBrand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Enter your weight',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'We need your weight to calculate personalized calories',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: '70.0',
                    hintStyle: const TextStyle(color: Colors.white38),
                    suffixText: 'kg',
                    suffixStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTokens.colorBrand),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final weight = double.tryParse(controller.text);
                  if (weight != null && weight > 20 && weight < 300) {
                    ref
                        .read(dietOnboardingProvider.notifier)
                        .updateWeight(weight);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.colorBrand,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show height edit dialog
  void _showHeightEditDialog(double? currentHeight) {
    final controller = TextEditingController(
      text: currentHeight?.toStringAsFixed(0) ?? '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTokens.colorBgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Update Height',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your calories will be recalculated automatically',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 24),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '170',
                  hintStyle: const TextStyle(color: Colors.white38),
                  suffixText: 'cm',
                  suffixStyle:
                      const TextStyle(color: Colors.white54, fontSize: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                        color: AppTokens.colorBrand, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final height = double.tryParse(controller.text);
                    if (height != null && height >= 100 && height <= 250) {
                      ref
                          .read(dietOnboardingProvider.notifier)
                          .updateHeight(height);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.colorBrand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Update Height',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Show weight edit dialog
  void _showWeightEditDialog(double? currentWeight) {
    final controller = TextEditingController(
      text: currentWeight?.toStringAsFixed(1) ?? '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTokens.colorBgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Update Weight',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your calories will be recalculated automatically',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 24),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '70.0',
                  hintStyle: const TextStyle(color: Colors.white38),
                  suffixText: 'kg',
                  suffixStyle:
                      const TextStyle(color: Colors.white54, fontSize: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                        color: AppTokens.colorBrand, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final weight = double.tryParse(controller.text);
                    if (weight != null && weight > 20 && weight < 300) {
                      ref
                          .read(dietOnboardingProvider.notifier)
                          .updateWeight(weight);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.colorBrand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Update Weight',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required DietGoal goal,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(dietOnboardingProvider.notifier).selectGoal(goal);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTokens.colorBgSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? AppTokens.colorBrand
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTokens.colorBrand.withValues(alpha: 0.2),
                    blurRadius: 20,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTokens.colorBrand.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTokens.colorBrand : Colors.white54,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEP 3: DIETARY STYLE
  // ============================================================
  Widget _buildDietaryStyleStep(DietOnboardingState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dietary Style',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Do you follow any specific diet?',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          _buildStyleOption(
            title: 'No Restrictions',
            subtitle: 'I eat everything',
            style: DietaryStyle.noRestrictions,
            isSelected: state.dietaryStyle == DietaryStyle.noRestrictions,
          ),
          _buildStyleOption(
            title: 'Vegetarian',
            subtitle: 'No meat, fish okay',
            style: DietaryStyle.vegetarian,
            isSelected: state.dietaryStyle == DietaryStyle.vegetarian,
          ),
          _buildStyleOption(
            title: 'Vegan',
            subtitle: 'No animal products',
            style: DietaryStyle.vegan,
            isSelected: state.dietaryStyle == DietaryStyle.vegan,
          ),
          _buildStyleOption(
            title: 'Pescatarian',
            subtitle: 'Fish and seafood only',
            style: DietaryStyle.pescatarian,
            isSelected: state.dietaryStyle == DietaryStyle.pescatarian,
          ),
          _buildStyleOption(
            title: 'Keto / Low Carb',
            subtitle: 'High fat, minimal carbs',
            style: DietaryStyle.keto,
            isSelected: state.dietaryStyle == DietaryStyle.keto,
          ),
          _buildStyleOption(
            title: 'Mediterranean',
            subtitle: 'Heart-healthy eating',
            style: DietaryStyle.mediterranean,
            isSelected: state.dietaryStyle == DietaryStyle.mediterranean,
          ),
          _buildStyleOption(
            title: 'Halal',
            subtitle: 'Islamic dietary laws',
            style: DietaryStyle.halal,
            isSelected: state.dietaryStyle == DietaryStyle.halal,
          ),
          _buildStyleOption(
            title: 'Kosher',
            subtitle: 'Jewish dietary laws',
            style: DietaryStyle.kosher,
            isSelected: state.dietaryStyle == DietaryStyle.kosher,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStyleOption({
    required String title,
    required String subtitle,
    required DietaryStyle style,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(dietOnboardingProvider.notifier).setDietaryStyle(style);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.colorBgSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? AppTokens.colorBrand
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTokens.colorBrand : Colors.transparent,
                border: isSelected
                    ? null
                    : Border.all(color: Colors.white38, width: 2),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.black, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEP 4: FOOD PREFERENCES (SWIPE INTERFACE)
  // ============================================================
  Widget _buildFoodPreferencesStep(DietOnboardingState state) {
    // Extract allergies from medical conditions text
    final allergies =
        _extractAllergiesFromConditions(state.medicalConditionsText);

    // Use filtered foods based on dietary style and allergies
    final foods = getFilteredFoods(state.dietaryStyle, allergies: allergies);
    final currentFood =
        _currentFoodIndex < foods.length ? foods[_currentFoodIndex] : null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What do you like?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap foods you love, skip what you don\'t',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (currentFood != null)
            Column(
              children: [
                // Food card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTokens.colorBgSurface,
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        FoodEmojiUtility.getEmojiForName(currentFood) ?? '🍽️',
                        style: const TextStyle(fontSize: 80),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentFood,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFoodActionButton(
                        icon: Icons.close,
                        label: 'Skip',
                        color: Colors.white38,
                        onTap: () {
                          ref
                              .read(dietOnboardingProvider.notifier)
                              .skipFood(currentFood);
                          _nextFood();
                        },
                      ),
                      _buildFoodActionButton(
                        icon: Icons.thumb_down_outlined,
                        label: 'Dislike',
                        color: Colors.redAccent,
                        onTap: () {
                          ref
                              .read(dietOnboardingProvider.notifier)
                              .addDislikedFood(currentFood);
                          _nextFood();
                        },
                      ),
                      _buildFoodActionButton(
                        icon: Icons.favorite,
                        label: 'Love',
                        color: AppTokens.colorBrand,
                        onTap: () {
                          ref
                              .read(dietOnboardingProvider.notifier)
                              .addLikedFood(currentFood);
                          _nextFood();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _currentFoodIndex / foods.length,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTokens.colorBrand),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_currentFoodIndex + 1} of ${foods.length}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Liked foods chips
                if (state.likedFoods.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.likedFoods.map((food) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                AppTokens.colorBrand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                FoodEmojiUtility.getEmojiForName(food) ?? '🍽️',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                food,
                                style: const TextStyle(
                                  color: AppTokens.colorBrand,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            )
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    color: AppTokens.colorBrand, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'All done!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You liked ${state.likedFoods.length} foods',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 32),
              ],
            ),
        ],
      ),
    );
  }

  /// Extract food allergies from medical conditions text
  List<String> _extractAllergiesFromConditions(String? conditions) {
    if (conditions == null || conditions.isEmpty) return [];

    final allergies = <String>[];
    final text = conditions.toLowerCase();

    // ═══════════════════════════════════════════════════════════════════════════
    // CONDITION → FOODS MAPPING (Critical for proper filtering)
    // When user mentions a condition, we filter ALL related foods
    // ═══════════════════════════════════════════════════════════════════════════
    const conditionToFoods = {
      // Lactose intolerance → filter ALL dairy products
      'lactose': [
        'yogurt',
        'cheese',
        'milk',
        'butter',
        'cream',
        'dairy',
        'mozzarella',
        'cheddar',
        'parmesan',
        'feta',
        'cottage cheese',
        'sour cream',
        'ice cream',
        'whey'
      ],
      'lactose intolerant': [
        'yogurt',
        'cheese',
        'milk',
        'butter',
        'cream',
        'dairy',
        'mozzarella',
        'cheddar',
        'parmesan',
        'feta',
        'cottage cheese',
        'sour cream',
        'ice cream',
        'whey'
      ],

      // Gluten intolerance/celiac → filter ALL gluten foods
      'gluten': [
        'bread',
        'pasta',
        'wheat',
        'oatmeal',
        'barley',
        'rye',
        'crackers',
        'cereal',
        'flour',
        'couscous',
        'bulgur'
      ],
      'celiac': [
        'bread',
        'pasta',
        'wheat',
        'oatmeal',
        'barley',
        'rye',
        'crackers',
        'cereal',
        'flour',
        'couscous',
        'bulgur'
      ],

      // Nut allergies → filter ALL nuts
      'nut allergy': [
        'almonds',
        'peanuts',
        'walnuts',
        'cashews',
        'pistachios',
        'hazelnuts',
        'pecans',
        'macadamia',
        'nuts'
      ],
      'tree nuts': [
        'almonds',
        'walnuts',
        'cashews',
        'pistachios',
        'hazelnuts',
        'pecans',
        'macadamia'
      ],
      'peanut': ['peanuts', 'peanut butter'],

      // Seafood/shellfish allergies
      'shellfish': [
        'shrimp',
        'crab',
        'lobster',
        'clams',
        'mussels',
        'oysters',
        'scallops'
      ],
      'seafood': [
        'fish',
        'salmon',
        'tuna',
        'shrimp',
        'crab',
        'lobster',
        'shellfish'
      ],

      // Egg allergy
      'egg allergy': ['eggs', 'egg', 'mayonnaise'],

      // Soy allergy
      'soy': ['tofu', 'soy sauce', 'edamame', 'tempeh', 'soy milk'],

      // Dairy allergy (different from lactose - more severe)
      'dairy allergy': [
        'yogurt',
        'cheese',
        'milk',
        'butter',
        'cream',
        'dairy',
        'whey',
        'casein'
      ],
      'dairy': [
        'yogurt',
        'cheese',
        'milk',
        'butter',
        'cream',
        'mozzarella',
        'cheddar',
        'parmesan',
        'feta'
      ],
    };

    // Check for condition keywords and expand to all related foods
    for (final entry in conditionToFoods.entries) {
      if (text.contains(entry.key)) {
        allergies.addAll(entry.value);
      }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIRECT FOOD KEYWORDS (user mentions specific food)
    // ═══════════════════════════════════════════════════════════════════════════
    const directFoodKeywords = [
      // Vegetables
      'broccoli', 'spinach', 'tomatoes', 'tomato', 'carrots', 'carrot',
      'cucumber', 'peppers', 'pepper', 'onions', 'onion', 'mushrooms',
      'mushroom',
      'lettuce', 'cabbage', 'asparagus', 'celery', 'zucchini', 'eggplant',
      // Fruits
      'banana', 'apple', 'orange', 'berries', 'berry', 'avocado',
      'grapes', 'grape', 'mango', 'watermelon', 'strawberry', 'blueberry',
      'pineapple', 'kiwi', 'peach', 'plum', 'cherry',
      // Proteins
      'chicken', 'beef', 'fish', 'salmon', 'eggs', 'egg', 'turkey',
      'shrimp', 'tuna', 'pork', 'lamb', 'bacon',
      // Plant proteins
      'tofu', 'lentils', 'chickpeas', 'beans', 'quinoa',
      // Carbs
      'rice', 'pasta', 'bread', 'oatmeal', 'potatoes', 'potato',
      // Dairy (individual items)
      'yogurt', 'cheese', 'milk', 'butter',
      // Nuts (individual items)
      'almonds', 'peanuts', 'walnuts', 'cashews', 'pistachios',
    ];

    for (final keyword in directFoodKeywords) {
      if (text.contains(keyword) && !allergies.contains(keyword)) {
        allergies.add(keyword);
      }
    }

    // Remove duplicates
    return allergies.toSet().toList();
  }

  void _nextFood() {
    setState(() {
      _currentFoodIndex++;
    });
  }

  Widget _buildFoodActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 5: MEAL SETTINGS
  // ============================================================
  Widget _buildMealSettingsStep(DietOnboardingState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meal Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Customize your meal schedule',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          // Meals per day (min 2, max 5)
          _buildSettingCard(
            title: 'Meals per day',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [2, 3, 4, 5].map((count) {
                    final isSelected = state.mealsPerDay == count;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(dietOnboardingProvider.notifier)
                              .setMealsPerDay(count);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTokens.colorBrand
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  _getMealScheduleDescription(state.mealsPerDay),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Smart Reminders
          _buildSettingCard(
            title: 'Smart Meal Reminders',
            trailing: Switch(
              value: state.mealRemindersEnabled,
              onChanged: (value) {
                ref
                    .read(dietOnboardingProvider.notifier)
                    .toggleMealReminders(value);
              },
              activeThumbColor: AppTokens.colorBrand,
            ),
            child: const Text(
              'Get notified before each meal',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          if (state.mealRemindersEnabled) ...[
            const SizedBox(height: 16),
            // Meal times based on meals per day
            ..._buildMealTimeCards(state),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Get description for meal schedule based on count
  String _getMealScheduleDescription(int mealsPerDay) {
    switch (mealsPerDay) {
      case 2:
        return 'Fasting style: Lunch + Dinner (16-18 hour fast)';
      case 3:
        return 'Classic: Breakfast, Lunch, Dinner';
      case 4:
        return 'With snack: Breakfast, Lunch, Snack, Dinner';
      case 5:
        return 'Frequent: Breakfast, Snack, Lunch, Snack, Dinner';
      default:
        return '';
    }
  }

  /// Build meal time cards based on meals per day
  List<Widget> _buildMealTimeCards(DietOnboardingState state) {
    final cards = <Widget>[];

    switch (state.mealsPerDay) {
      case 2:
        // Fasting: Lunch + Dinner only
        cards.add(_buildMealTimeCard(
          mealType: MealType.lunch,
          icon: Icons.wb_cloudy_outlined,
          title: 'Lunch',
          time: state.lunchTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.dinner,
          icon: Icons.nights_stay_outlined,
          title: 'Dinner',
          time: state.dinnerTime,
        ));
        break;
      case 3:
        // Classic: Breakfast, Lunch, Dinner
        cards.add(_buildMealTimeCard(
          mealType: MealType.breakfast,
          icon: Icons.wb_sunny_outlined,
          title: 'Breakfast',
          time: state.breakfastTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.lunch,
          icon: Icons.wb_cloudy_outlined,
          title: 'Lunch',
          time: state.lunchTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.dinner,
          icon: Icons.nights_stay_outlined,
          title: 'Dinner',
          time: state.dinnerTime,
        ));
        break;
      case 4:
        // With snack: Breakfast, Lunch, Snack, Dinner
        cards.add(_buildMealTimeCard(
          mealType: MealType.breakfast,
          icon: Icons.wb_sunny_outlined,
          title: 'Breakfast',
          time: state.breakfastTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.lunch,
          icon: Icons.wb_cloudy_outlined,
          title: 'Lunch',
          time: state.lunchTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.snack,
          icon: Icons.cookie_outlined,
          title: 'Afternoon Snack',
          time: state.afternoonSnackTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.dinner,
          icon: Icons.nights_stay_outlined,
          title: 'Dinner',
          time: state.dinnerTime,
        ));
        break;
      case 5:
        // Frequent: Breakfast, Morning Snack, Lunch, Afternoon Snack, Dinner
        cards.add(_buildMealTimeCard(
          mealType: MealType.breakfast,
          icon: Icons.wb_sunny_outlined,
          title: 'Breakfast',
          time: state.breakfastTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.morningSnack,
          icon: Icons.cookie_outlined,
          title: 'Morning Snack',
          time: state.morningSnackTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.lunch,
          icon: Icons.wb_cloudy_outlined,
          title: 'Lunch',
          time: state.lunchTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.afternoonSnack,
          icon: Icons.cookie_outlined,
          title: 'Afternoon Snack',
          time: state.afternoonSnackTime,
        ));
        cards.add(_buildMealTimeCard(
          mealType: MealType.dinner,
          icon: Icons.nights_stay_outlined,
          title: 'Dinner',
          time: state.dinnerTime,
        ));
        break;
    }

    return cards;
  }

  Widget _buildMealTimeCard({
    required MealType mealType,
    required IconData icon,
    required String title,
    required String time,
  }) {
    return GestureDetector(
      onTap: () => _showTimePicker(mealType, time),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.colorBgSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTokens.colorBrand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTokens.colorBrand, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              time,
              style: const TextStyle(
                color: AppTokens.colorBrand,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showTimePicker(MealType mealType, String currentTime) async {
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTokens.colorBrand,
              surface: AppTokens.colorBgSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ref
          .read(dietOnboardingProvider.notifier)
          .setMealTime(mealType, timeString);
    }
  }

  Widget _buildSettingCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ============================================================
  // GENERATING STEP
  // ============================================================
  Widget _buildGeneratingStep(DietOnboardingState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sparkle Icon (Image 1 style)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppTokens.colorBrand,
              size: 48,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Creating your plan...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),
          // Progress bar synced with state
          LinearProgressIndicator(
            value: state.generationProgress,
            backgroundColor: AppTokens.colorBgSurface,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            '${(state.generationProgress * 100).toInt()}% complete',
            style: const TextStyle(
                color: AppTokens.colorBrand,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Detailed status text (Image 1 style)
          Text(
            _getDietGenerationFullStatus(state.generationProgress),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPLETE STEP
  // ============================================================
  Widget _buildCompleteStep(DietOnboardingState state) {
    final plan = state.generatedPlan;
    if (plan == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF2ECC71),
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Your Plan is Ready!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Plan summary card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTokens.colorBgSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Target',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: AppTokens.colorBrand,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plan.macroTarget.calories}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        'kcal',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMacroSummary('Protein',
                        '${plan.macroTarget.protein}g', AppTokens.colorBrand),
                    _buildMacroSummary('Carbs', '${plan.macroTarget.carbs}g',
                        Colors.blueAccent),
                    _buildMacroSummary(
                        'Fat', '${plan.macroTarget.fats}g', Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '30 Days of Meals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${plan.weeks.length} weeks • ${plan.weeks.fold(0, (sum, w) => sum + w.days.length)} days planned',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildSecondaryButton(
            label: 'Regenerate Plan',
            onTap: () {
              ref.read(dietOnboardingProvider.notifier).generatePlan();
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMacroSummary(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  // ============================================================
  // COMMON WIDGETS
  // ============================================================
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.colorBgSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? AppTokens.colorBrand
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white54, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? AppTokens.colorBrand
              : Colors.white.withValues(alpha: 0.1),
          foregroundColor: enabled ? Colors.black : Colors.white38,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }


  String _getDietGenerationFullStatus(double progress) {
    if (progress < 0.25) return 'Reviewing your allergies and health data\nto ensure total safety...';
    if (progress < 0.50) return 'Calculating your personalized TDEE\nand optimal macro ratios...';
    if (progress < 0.75) return 'Matching ingredients to your food likes\nand dietary preferences...';
    if (progress < 0.95) return 'Almost there! Finalizing your 30-day\ncomplete nutritional routine...';
    return 'Synchronizing with your unique profile...';
  }
}
