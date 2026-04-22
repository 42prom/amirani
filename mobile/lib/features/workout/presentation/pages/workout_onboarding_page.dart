import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../providers/workout_onboarding_provider.dart';
import '../../domain/entities/workout_preferences_entity.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../widgets/interactive_muscle_selector.dart';

class WorkoutOnboardingPage extends ConsumerStatefulWidget {
  const WorkoutOnboardingPage({super.key});

  @override
  ConsumerState<WorkoutOnboardingPage> createState() =>
      _WorkoutOnboardingPageState();
}

class _WorkoutOnboardingPageState extends ConsumerState<WorkoutOnboardingPage> {
  int _currentExerciseIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutOnboardingProvider);
    final profileSync = ref.watch(profileSyncProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85 + bottomInset,
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.7),
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

  Widget _buildStickyFooter(WorkoutOnboardingState state) {
    String label = 'Continue';
    IconData? icon;
    VoidCallback? onTap;
    bool enabled = true;

    switch (state.currentStep) {
      case WorkoutOnboardingStep.fitnessCheck:
        if (state.injuriesText != null && state.injuriesText!.isNotEmpty) {
          label = 'This is correct';
          onTap = () =>
              ref.read(workoutOnboardingProvider.notifier).confirmFitnessData();
        } else {
          return const SizedBox.shrink();
        }
        break;
      case WorkoutOnboardingStep.goalSelection:
        label = 'Continue';
        onTap = () => ref.read(workoutOnboardingProvider.notifier).nextStep();
        enabled = state.selectedGoal != null;
        break;
      case WorkoutOnboardingStep.muscleFocus:
        label = state.selectedMuscles.isEmpty ? 'Skip for now' : 'Continue';
        onTap = () => ref.read(workoutOnboardingProvider.notifier).nextStep();
        break;
      case WorkoutOnboardingStep.trainingStyle:
        label = 'Continue';
        onTap = () => ref.read(workoutOnboardingProvider.notifier).nextStep();
        break;
      case WorkoutOnboardingStep.exercisePreferences:
        label = 'Continue';
        onTap = () => ref.read(workoutOnboardingProvider.notifier).nextStep();
        break;
      case WorkoutOnboardingStep.scheduleSettings:
        label = 'Generate My Plan';
        icon = Icons.auto_awesome;
        onTap = () =>
            ref.read(workoutOnboardingProvider.notifier).generatePlan();
        break;
      case WorkoutOnboardingStep.generating:
        return const SizedBox.shrink();
      case WorkoutOnboardingStep.complete:
        label = 'Start Training';
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
        color: AppTheme.backgroundDark,
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

  Widget _buildHeader(
      WorkoutOnboardingState state, ProfileSyncState profileSync) {
    final stepIndex = state.currentStep.index;
    const totalSteps = 5; // Fitness, Goal, Style, Exercises, Schedule
    final bool showBack = stepIndex > 0 &&
        state.currentStep != WorkoutOnboardingStep.generating &&
        state.currentStep != WorkoutOnboardingStep.complete;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: showBack
                ? () =>
                    ref.read(workoutOnboardingProvider.notifier).previousStep()
                : null,
            child: SizedBox(
              height: 48,
              width: 48,
              child: showBack
                  ? const Center(
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: state.currentStep == WorkoutOnboardingStep.generating ||
                    state.currentStep == WorkoutOnboardingStep.complete
                ? const SizedBox.shrink()
                : _buildProgressIndicator(stepIndex, totalSteps),
          ),
          const SizedBox(width: 16),
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
                  ? AppTheme.primaryBrand
                  : Colors.white.withValues(alpha: 0.1),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryBrand.withValues(alpha: 0.5),
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

  Widget _buildStepContent(WorkoutOnboardingState state) {
    switch (state.currentStep) {
      case WorkoutOnboardingStep.fitnessCheck:
        return _buildFitnessCheckStep(state);
      case WorkoutOnboardingStep.goalSelection:
        return _buildGoalSelectionStep(state);
      case WorkoutOnboardingStep.muscleFocus:
        return _buildMuscleFocusStep(state);
      case WorkoutOnboardingStep.trainingStyle:
        return _buildTrainingStyleStep(state);
      case WorkoutOnboardingStep.exercisePreferences:
        return _buildExercisePreferencesStep(state);
      case WorkoutOnboardingStep.scheduleSettings:
        return _buildScheduleSettingsStep(state);
      case WorkoutOnboardingStep.generating:
        return _buildGeneratingStep(state);
      case WorkoutOnboardingStep.complete:
        return _buildCompleteStep(state);
    }
  }

  // ============================================================
  // STEP 1: FITNESS CHECK
  // ============================================================
  Widget _buildFitnessCheckStep(WorkoutOnboardingState state) {
    final hasData =
        state.injuriesText != null && state.injuriesText!.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fitness Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll make sure your workout plan is safe for you',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          if (hasData) ...[
            _buildInfoCard(
              icon: Icons.fitness_center,
              iconColor: AppTheme.primaryBrand,
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
                      state.injuriesText!,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'We\'ll adjust exercises accordingly',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSecondaryButton(
              label: 'Edit Fitness Info',
              onTap: () => _showInjuryInputDialog(),
            ),
          ] else ...[
            _buildInfoCard(
              icon: Icons.help_outline,
              iconColor: Colors.white54,
              title: 'Do you have any injuries or limitations?',
              child: const Column(
                children: [
                  SizedBox(height: 16),
                  Text(
                    'This helps us create a safe workout plan for you',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionCard(
              icon: Icons.check_circle_outline,
              title: 'I\'m injury-free',
              subtitle: 'No limitations, ready to train',
              isSelected: false,
              onTap: () {
                ref.read(workoutOnboardingProvider.notifier).confirmNoInjuries();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              icon: Icons.healing_outlined,
              title: 'I have limitations',
              subtitle: 'Injuries, pain, or restrictions',
              isSelected: false,
              onTap: () => _showInjuryInputDialog(),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showInjuryInputDialog() {
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
            color: AppTheme.surfaceDark,
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
                'Injuries & Limitations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us about any injuries, pain, or physical limitations',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      'e.g., Bad knees, lower back pain, shoulder injury...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryBrand),
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
                          .read(workoutOnboardingProvider.notifier)
                          .saveInjuries(controller.text);
                      Navigator.pop(context);
                      ref.read(workoutOnboardingProvider.notifier).nextStep();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBrand,
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
  Widget _buildGoalSelectionStep(WorkoutOnboardingState state) {
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
            'This helps us design your perfect workout plan',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.local_fire_department,
                  title: 'Lose Weight',
                  subtitle: 'Burn fat & calories',
                  goal: WorkoutGoal.weightLoss,
                  isSelected: state.selectedGoal == WorkoutGoal.weightLoss,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.fitness_center,
                  title: 'Build Muscle',
                  subtitle: 'Hypertrophy focus',
                  goal: WorkoutGoal.muscleGain,
                  isSelected: state.selectedGoal == WorkoutGoal.muscleGain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.bolt,
                  title: 'Get Stronger',
                  subtitle: 'Strength training',
                  goal: WorkoutGoal.strength,
                  isSelected: state.selectedGoal == WorkoutGoal.strength,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.directions_run,
                  title: 'Endurance',
                  subtitle: 'Cardio & stamina',
                  goal: WorkoutGoal.endurance,
                  isSelected: state.selectedGoal == WorkoutGoal.endurance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.self_improvement,
                  title: 'Flexibility',
                  subtitle: 'Mobility & stretch',
                  goal: WorkoutGoal.flexibility,
                  isSelected: state.selectedGoal == WorkoutGoal.flexibility,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.balance,
                  title: 'General Fit',
                  subtitle: 'Overall health',
                  goal: WorkoutGoal.generalFitness,
                  isSelected: state.selectedGoal == WorkoutGoal.generalFitness,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3: MUSCLE FOCUS
  // ============================================================
  Widget _buildMuscleFocusStep(WorkoutOnboardingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Muscle Focus',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap the muscles you want to prioritize',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: InteractiveMuscleSelector(
            initialSelection: state.selectedMuscles,
            isMale: state.isMale,
            onSelectionChanged: (muscles) {
              ref
                  .read(workoutOnboardingProvider.notifier)
                  .setTargetMuscles(muscles);
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            state.selectedMuscles.isEmpty
                ? 'Select any muscle to focus'
                : '${state.selectedMuscles.length} Muscle Groups Selected',
            style: TextStyle(
              color: state.selectedMuscles.isEmpty
                  ? Colors.white38
                  : AppTheme.primaryBrand,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGoalCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required WorkoutGoal goal,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(workoutOnboardingProvider.notifier).selectGoal(goal);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBrand
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.2),
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
                    ? AppTheme.primaryBrand.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.primaryBrand : Colors.white54,
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
  // STEP 3: TRAINING STYLE
  // ============================================================
  Widget _buildTrainingStyleStep(WorkoutOnboardingState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Training Setup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Where and how will you train?',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Location
          const Text(
            'LOCATION',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLocationCard(
                  icon: Icons.home,
                  title: 'Home',
                  isSelected: state.location == TrainingLocation.home,
                  onTap: () => ref
                      .read(workoutOnboardingProvider.notifier)
                      .setLocation(TrainingLocation.home),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationCard(
                  icon: Icons.fitness_center,
                  title: 'Gym',
                  isSelected: state.location == TrainingLocation.gym,
                  onTap: () => ref
                      .read(workoutOnboardingProvider.notifier)
                      .setLocation(TrainingLocation.gym),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Equipment
          const Text(
            'AVAILABLE EQUIPMENT',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getEquipmentForLocation(state.location).map((equipment) {
              final isSelected = state.availableEquipment.contains(equipment);
              return GestureDetector(
                onTap: () => ref
                    .read(workoutOnboardingProvider.notifier)
                    .toggleEquipment(equipment),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryBrand.withValues(alpha: 0.15)
                        : AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBrand
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    _getEquipmentName(equipment),
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryBrand : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Training Split
          const Text(
            'TRAINING SPLIT',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          _buildSplitOption(
            title: 'Full Body',
            subtitle: 'Train all muscles each session',
            split: TrainingSplit.fullBody,
            isSelected: state.trainingSplit == TrainingSplit.fullBody,
          ),
          _buildSplitOption(
            title: 'Upper/Lower',
            subtitle: 'Alternate upper and lower body',
            split: TrainingSplit.upperLower,
            isSelected: state.trainingSplit == TrainingSplit.upperLower,
          ),
          _buildSplitOption(
            title: 'Push/Pull/Legs',
            subtitle: '3-day muscle group rotation',
            split: TrainingSplit.pushPullLegs,
            isSelected: state.trainingSplit == TrainingSplit.pushPullLegs,
          ),
          _buildSplitOption(
            title: 'Bro Split',
            subtitle: 'One muscle group per day',
            split: TrainingSplit.broSplit,
            isSelected: state.trainingSplit == TrainingSplit.broSplit,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Equipment> _getEquipmentForLocation(TrainingLocation location) {
    if (location == TrainingLocation.home) {
      return [
        Equipment.bodyweightOnly,
        Equipment.dumbbells,
        Equipment.resistanceBands,
        Equipment.pullUpBar,
        Equipment.kettlebell,
      ];
    } else {
      return [
        Equipment.dumbbells,
        Equipment.barbell,
        Equipment.machines,
        Equipment.cables,
        Equipment.bench,
        Equipment.pullUpBar,
      ];
    }
  }

  String _getEquipmentName(Equipment equipment) {
    switch (equipment) {
      case Equipment.bodyweightOnly:
        return 'Bodyweight';
      case Equipment.dumbbells:
        return 'Dumbbells';
      case Equipment.barbell:
        return 'Barbell';
      case Equipment.machines:
        return 'Machines';
      case Equipment.resistanceBands:
        return 'Bands';
      case Equipment.pullUpBar:
        return 'Pull-up Bar';
      case Equipment.kettlebell:
        return 'Kettlebell';
      case Equipment.cables:
        return 'Cables';
      case Equipment.bench:
        return 'Bench';
      case Equipment.jumpRope:
        return 'Jump Rope';
      case Equipment.medicineBall:
        return 'Medicine Ball';
      case Equipment.foamRoller:
        return 'Foam Roller';
      case Equipment.yogaMat:
        return 'Yoga Mat';
      case Equipment.stabilityBall:
        return 'Stability Ball';
      case Equipment.trxStraps:
        return 'TRX Straps';
      case Equipment.parallelBars:
        return 'Parallel Bars';
      case Equipment.weightedVest:
        return 'Weighted Vest';
      case Equipment.ankleWeights:
        return 'Ankle Weights';
      case Equipment.abWheel:
        return 'Ab Wheel';
      case Equipment.battleRopes:
        return 'Battle Ropes';
    }
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBrand
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBrand : Colors.white54,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitOption({
    required String title,
    required String subtitle,
    required TrainingSplit split,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(workoutOnboardingProvider.notifier).setTrainingSplit(split);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBrand
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
                color: isSelected ? AppTheme.primaryBrand : Colors.transparent,
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
  // STEP 4: EXERCISE PREFERENCES
  // ============================================================
  Widget _buildExercisePreferencesStep(WorkoutOnboardingState state) {
    final exercises = getFilteredExercises(state.location);
    final currentExercise = _currentExerciseIndex < exercises.length
        ? exercises[_currentExerciseIndex]
        : null;

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
                  'Exercise Preferences',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Like, dislike, or skip exercises',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (currentExercise != null)
            Column(
              children: [
                // Exercise card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        exerciseEmojis[currentExercise] ?? '💪',
                        style: const TextStyle(fontSize: 80),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentExercise,
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
                      _buildExerciseActionButton(
                        icon: Icons.close,
                        label: 'Skip',
                        color: Colors.white38,
                        onTap: () {
                          ref
                              .read(workoutOnboardingProvider.notifier)
                              .skipExercise(currentExercise);
                          _nextExercise();
                        },
                      ),
                      _buildExerciseActionButton(
                        icon: Icons.thumb_down_outlined,
                        label: 'Dislike',
                        color: Colors.redAccent,
                        onTap: () {
                          ref
                              .read(workoutOnboardingProvider.notifier)
                              .addDislikedExercise(currentExercise);
                          _nextExercise();
                        },
                      ),
                      _buildExerciseActionButton(
                        icon: Icons.favorite,
                        label: 'Love',
                        color: AppTheme.primaryBrand,
                        onTap: () {
                          ref
                              .read(workoutOnboardingProvider.notifier)
                              .addLikedExercise(currentExercise);
                          _nextExercise();
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
                        value: _currentExerciseIndex / exercises.length,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryBrand),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_currentExerciseIndex + 1} of ${exercises.length}',
                        style:
                            const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Liked exercises chips
                if (state.likedExercises.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.likedExercises.map((exercise) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                exerciseEmojis[exercise] ?? '💪',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                exercise,
                                style: const TextStyle(
                                  color: AppTheme.primaryBrand,
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
                    color: AppTheme.primaryBrand, size: 64),
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
                  'You liked ${state.likedExercises.length} exercises',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 32),
              ],
            ),
        ],
      ),
    );
  }

  void _nextExercise() {
    setState(() {
      _currentExerciseIndex++;
    });
  }

  Widget _buildExerciseActionButton({
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
  // STEP 5: SCHEDULE SETTINGS
  // ============================================================
  Widget _buildScheduleSettingsStep(WorkoutOnboardingState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Schedule',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set your workout schedule',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Days per week
          _buildSettingCard(
            title: 'Days per week',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [2, 3, 4, 5, 6].map((count) {
                    final isSelected = state.daysPerWeek == count;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(workoutOnboardingProvider.notifier)
                              .setDaysPerWeek(count);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryBrand
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
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Preferred days
          _buildSettingCard(
            title: 'Preferred days',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final isSelected = state.preferredDays.contains(index);
                final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return GestureDetector(
                  onTap: () {
                    ref
                        .read(workoutOnboardingProvider.notifier)
                        .togglePreferredDay(index);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTheme.primaryBrand
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                    child: Center(
                      child: Text(
                        days[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Session duration
          _buildSettingCard(
            title: 'Session duration',
            child: Column(
              children: [
                Slider(
                  value: state.sessionDurationMinutes.toDouble(),
                  min: 15,
                  max: 90,
                  divisions: 15,
                  activeColor: AppTheme.primaryBrand,
                  inactiveColor: Colors.white.withValues(alpha: 0.1),
                  onChanged: (value) {
                    ref
                        .read(workoutOnboardingProvider.notifier)
                        .setSessionDuration(value.round());
                  },
                ),
                Text(
                  '${state.sessionDurationMinutes} minutes',
                  style: const TextStyle(
                    color: AppTheme.primaryBrand,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reminders
          _buildSettingCard(
            title: 'Workout Reminders',
            trailing: Switch(
              value: state.workoutRemindersEnabled,
              onChanged: (value) {
                ref
                    .read(workoutOnboardingProvider.notifier)
                    .toggleReminders(value);
              },
              activeTrackColor: AppTheme.primaryBrand.withValues(alpha: 0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primaryBrand;
                }
                return Colors.white54;
              }),
            ),
            child: const Text(
              'Get notified before workouts',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          if (state.workoutRemindersEnabled) ...[
            const SizedBox(height: 16),
            _buildReminderTimeCard(state),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildReminderTimeCard(WorkoutOnboardingState state) {
    return GestureDetector(
      onTap: () => _showTimePicker(state.reminderTime),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.alarm, color: AppTheme.primaryBrand, size: 20),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Reminder Time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              state.reminderTime,
              style: const TextStyle(
                color: AppTheme.primaryBrand,
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

  void _showTimePicker(String currentTime) async {
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
              primary: AppTheme.primaryBrand,
              surface: AppTheme.surfaceDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ref.read(workoutOnboardingProvider.notifier).setReminderTime(timeString);
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
        color: AppTheme.surfaceDark,
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
  Widget _buildGeneratingStep(WorkoutOnboardingState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.primaryBrand,
                size: 48,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Creating your plan...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              backgroundColor: AppTheme.surfaceDark,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBrand),
              minHeight: 6,
            ),
            const SizedBox(height: 24),
            const Text(
              'Analyzing your preferences and\nbuilding personalized workouts...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMPLETE STEP
  // ============================================================
  Widget _buildCompleteStep(WorkoutOnboardingState state) {
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
              color: AppTheme.surfaceDark,
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
                          'Weekly Target',
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
                        Icons.fitness_center,
                        color: AppTheme.primaryBrand,
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
                      '${plan.dailyTarget.durationMinutes}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        'min/session',
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
                    _buildStatSummary(
                      'Workouts',
                      '${plan.totalWorkouts}',
                      AppTheme.primaryBrand,
                    ),
                    _buildStatSummary(
                      'Exercises',
                      '${plan.dailyTarget.exercisesPerSession}',
                      Colors.blueAccent,
                    ),
                    _buildStatSummary(
                      'Calories',
                      '~${plan.dailyTarget.caloriesBurned}',
                      Colors.greenAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '4 Weeks of Training',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${plan.weeks.length} weeks planned with progressive overload',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildSecondaryButton(
            label: 'Regenerate Plan',
            onTap: () {
              ref.read(workoutOnboardingProvider.notifier).generatePlan();
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatSummary(String label, String value, Color color) {
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
        color: AppTheme.surfaceDark,
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
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBrand
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
              ? AppTheme.primaryBrand
              : Colors.white.withValues(alpha: 0.1),
          foregroundColor: enabled ? Colors.black : Colors.white38,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
}
