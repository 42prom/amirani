import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/ai_orchestration_service.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../../../../core/data/exercise_database.dart';
import '../../../../core/services/user_equipment_service.dart';
import '../../../../core/services/gym_equipment_service.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';
import '../../domain/entities/workout_preferences_entity.dart';
import '../widgets/interactive_muscle_selector.dart';
import '../../../../core/services/workout_plan_storage_service.dart';
import '../../../../core/providers/session_progress_provider.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import 'package:amirani_app/core/widgets/premium_state_card.dart';
import 'package:amirani_app/core/localization/l10n_provider.dart';

/// Workout plan type
enum WorkoutPlanType { home, gym }

/// Step in the workout plan builder
enum BuilderStep { equipment, muscles, schedule, summary }

/// State for workout plan builder
class WorkoutPlanBuilderState {
  final BuilderStep currentStep;
  final WorkoutPlanType? planType;
  final Set<Equipment> selectedEquipment;
  final Set<MuscleGroup> selectedMuscles;
  final Set<int> preferredDays;
  final int sessionDurationMinutes;
  final FitnessLevel fitnessLevel;
  final WorkoutGoal goal;
  final bool isGenerating;
  final double generationProgress;

  const WorkoutPlanBuilderState({
    this.currentStep = BuilderStep.equipment,
    this.planType,
    this.selectedEquipment = const {},
    this.selectedMuscles = const {},
    this.preferredDays = const {0, 2, 4}, // Default M, W, F
    this.sessionDurationMinutes = 45,
    this.fitnessLevel = FitnessLevel.intermediate,
    this.goal = WorkoutGoal.generalFitness,
    this.isGenerating = false,
    this.generationProgress = 0.0,
  });

  WorkoutPlanBuilderState copyWith({
    BuilderStep? currentStep,
    WorkoutPlanType? planType,
    Set<Equipment>? selectedEquipment,
    Set<MuscleGroup>? selectedMuscles,
    Set<int>? preferredDays,
    int? sessionDurationMinutes,
    FitnessLevel? fitnessLevel,
    WorkoutGoal? goal,
    bool? isGenerating,
    double? generationProgress,
  }) {
    return WorkoutPlanBuilderState(
      currentStep: currentStep ?? this.currentStep,
      planType: planType ?? this.planType,
      selectedEquipment: selectedEquipment ?? this.selectedEquipment,
      selectedMuscles: selectedMuscles ?? this.selectedMuscles,
      preferredDays: preferredDays ?? this.preferredDays,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      goal: goal ?? this.goal,
      isGenerating: isGenerating ?? this.isGenerating,
      generationProgress: generationProgress ?? this.generationProgress,
    );
  }

  double get progress {
    switch (currentStep) {
      case BuilderStep.equipment:
        return 0.25;
      case BuilderStep.muscles:
        return 0.5;
      case BuilderStep.schedule:
        return 0.75;
      case BuilderStep.summary:
        return 1.0;
    }
  }

  bool get canProceed {
    switch (currentStep) {
      case BuilderStep.equipment:
        return true; // Bodyweight is always available
      case BuilderStep.muscles:
        return selectedMuscles.isNotEmpty;
      case BuilderStep.schedule:
        return preferredDays.isNotEmpty;
      case BuilderStep.summary:
        return true;
    }
  }
}

/// Notifier for workout plan builder
class WorkoutPlanBuilderNotifier
    extends StateNotifier<WorkoutPlanBuilderState> {
  WorkoutPlanBuilderNotifier() : super(const WorkoutPlanBuilderState());

  void initWithPlanType(WorkoutPlanType type) {
    state = WorkoutPlanBuilderState(
      currentStep: BuilderStep.equipment,
      planType: type,
    );
  }

  void toggleEquipment(Equipment equipment) {
    final newSet = Set<Equipment>.from(state.selectedEquipment);
    if (newSet.contains(equipment)) {
      newSet.remove(equipment);
    } else {
      newSet.add(equipment);
    }
    state = state.copyWith(selectedEquipment: newSet);
  }

  void setMuscles(Set<MuscleGroup> muscles) {
    state = state.copyWith(selectedMuscles: muscles);
  }

  void togglePreferredDay(int day) {
    final newDays = Set<int>.from(state.preferredDays);
    if (newDays.contains(day)) {
      newDays.remove(day);
    } else {
      newDays.add(day);
    }
    state = state.copyWith(preferredDays: newDays);
  }

  void setSessionDuration(int minutes) {
    state = state.copyWith(sessionDurationMinutes: minutes);
  }

  void setFitnessLevel(FitnessLevel level) {
    state = state.copyWith(fitnessLevel: level);
  }

  void setGoal(WorkoutGoal goal) {
    state = state.copyWith(goal: goal);
  }

  void nextStep() {
    final steps = BuilderStep.values;
    final currentIndex = steps.indexOf(state.currentStep);
    if (currentIndex < steps.length - 1) {
      state = state.copyWith(currentStep: steps[currentIndex + 1]);
    }
  }

  void previousStep() {
    final steps = BuilderStep.values;
    final currentIndex = steps.indexOf(state.currentStep);
    if (currentIndex > 0) {
      state = state.copyWith(currentStep: steps[currentIndex - 1]);
    }
  }

  void goToStep(BuilderStep step) {
    state = state.copyWith(currentStep: step);
  }

  void setGenerating(bool isGenerating) {
    state = state.copyWith(
      isGenerating: isGenerating,
      generationProgress: isGenerating ? 0.0 : state.generationProgress,
    );
  }

  void setGenerationProgress(double progress) {
    state = state.copyWith(generationProgress: progress);
  }

  /// Simulator for premium filling button. 
  /// 0-20% fast, 20-95% slow crawl.
  Future<void> startProgressSimulation() async {
    if (!state.isGenerating) return;
    
    // Initial jump
    double current = 0.1;
    setGenerationProgress(current);
    await Future.delayed(const Duration(milliseconds: 300));
    
    current = 0.2;
    setGenerationProgress(current);
    
    // Slow crawl while waiting for actual AI response
    while (state.isGenerating && current < 0.95) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!state.isGenerating) break;
      
      // The closer it gets to 95%, the slower it moves
      double increment = (0.96 - current) * 0.1; 
      current += increment;
      setGenerationProgress(current);
    }
  }

  void reset(WorkoutPlanType planType) {
    state = WorkoutPlanBuilderState(planType: planType);
  }
}

/// Provider for workout plan builder
final workoutPlanBuilderProvider =
    StateNotifierProvider<WorkoutPlanBuilderNotifier, WorkoutPlanBuilderState>(
        (ref) {
  return WorkoutPlanBuilderNotifier();
});

/// Main workout plan builder page
class WorkoutPlanBuilderPage extends ConsumerStatefulWidget {
  final WorkoutPlanType initialPlanType;

  const WorkoutPlanBuilderPage({
    super.key,
    required this.initialPlanType,
  });

  static Future<void> show(
      BuildContext context, WorkoutPlanType initialPlanType) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) =>
          WorkoutPlanBuilderPage(initialPlanType: initialPlanType),
    );
  }

  @override
  ConsumerState<WorkoutPlanBuilderPage> createState() =>
      _WorkoutPlanBuilderPageState();
}

class _WorkoutPlanBuilderPageState
    extends ConsumerState<WorkoutPlanBuilderPage> {
  @override
  void initState() {
    super.initState();
    // Initialize builder state with the provided plan type
    Future.microtask(() {
      ref
          .read(workoutPlanBuilderProvider.notifier)
          .initWithPlanType(widget.initialPlanType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutPlanBuilderProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85 + bottomInset,
      decoration: BoxDecoration(
        color: AppTokens.colorBgPrimary.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.radius32)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.radius32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppTokens.blurStandard, sigmaY: AppTokens.blurStandard),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(state),
              if (!state.isGenerating) _buildProgressBar(state),
              Expanded(
                child: state.isGenerating
                    ? _buildGeneratingStep(state)
                    : _buildStepContent(state),
              ),
              _buildNavigationButtons(state),
            ],
          ),
        ),
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

  Widget _buildHeader(WorkoutPlanBuilderState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!state.isGenerating)
            IconButton(
              onPressed: () {
                if (state.currentStep == BuilderStep.equipment) {
                  Navigator.pop(context);
                } else {
                  ref.read(workoutPlanBuilderProvider.notifier).previousStep();
                }
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 40), // Balanced space for the close button on the right
          
          Expanded(
            child: state.isGenerating 
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Text(
                      _getStepTitle(state.currentStep),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Step ${state.currentStep.index + 1} of 4',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
          ),
          
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(WorkoutPlanBuilderState state) {
    const totalSteps = 4;
    final currentStepIndex = state.currentStep.index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isCompleted = index <= currentStepIndex;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                right: index == totalSteps - 1 ? 0 : 8,
              ),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTokens.colorBrand
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(WorkoutPlanBuilderState state) {
    switch (state.currentStep) {
      case BuilderStep.equipment:
        return _buildEquipmentStep(state);
      case BuilderStep.muscles:
        return _buildMusclesStep(state);
      case BuilderStep.schedule:
        return _buildScheduleStep(state);
      case BuilderStep.summary:
        return _buildSummaryStep(state);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: Equipment Selection
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEquipmentStep(WorkoutPlanBuilderState state) {
    final isHomePlan = state.planType == WorkoutPlanType.home;

    if (isHomePlan) {
      return _buildHomeEquipmentSelector(state);
    } else {
      return _buildGymEquipmentSelector(state);
    }
  }

  Widget _buildHomeEquipmentSelector(WorkoutPlanBuilderState state) {
    final equipmentList = EquipmentInfo.homeEquipment;

    return Column(
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTokens.colorBrand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTokens.colorBrand, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bodyweight exercises are always included. Add any equipment you own!',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Equipment grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: equipmentList.length,
            itemBuilder: (context, index) {
              final info = equipmentList[index];
              final isSelected =
                  state.selectedEquipment.contains(info.equipment);
              final isBodyweight = info.equipment == Equipment.bodyweightOnly;

              return GestureDetector(
                onTap: isBodyweight
                    ? null
                    : () => ref
                        .read(workoutPlanBuilderProvider.notifier)
                        .toggleEquipment(info.equipment),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected || isBodyweight
                        ? AppTokens.colorBrand.withValues(alpha: 0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected || isBodyweight
                          ? AppTokens.colorBrand.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(info.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(
                        info.displayName,
                        style: TextStyle(
                          color: isSelected || isBodyweight
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isBodyweight)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2ECC71).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Included',
                            style: TextStyle(
                                color: Color(0xFF2ECC71), fontSize: 8),
                          ),
                        ),
                      if (isSelected && !isBodyweight)
                        const Icon(Icons.check_circle,
                            color: AppTokens.colorBrand, size: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Selected count
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${state.selectedEquipment.length + 1} equipment types selected',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGymEquipmentSelector(WorkoutPlanBuilderState state) {
    final gymEquipmentState = ref.watch(gymEquipmentProvider);

    // Load gym equipment on first build if not loaded
    if (gymEquipmentState.joinedGyms.isEmpty && !gymEquipmentState.isLoading) {
      Future.microtask(() {
        ref.read(gymEquipmentProvider.notifier).loadUserGyms('current_user');
      });
    }

    return Column(
      children: [
        // Gym selector (if multiple gyms)
        if (gymEquipmentState.joinedGyms.length > 1)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.fitness_center,
                        color: Colors.blueAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Select Your Gym',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: gymEquipmentState.joinedGyms.map((gym) {
                      final isSelected =
                          gymEquipmentState.selectedGym?.gymId == gym.gymId;
                      return GestureDetector(
                        onTap: () => ref
                            .read(gymEquipmentProvider.notifier)
                            .selectGym(gym.gymId),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blueAccent.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white12,
                            ),
                          ),
                          child: Text(
                            gym.gymName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

        // Info banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  gymEquipmentState.selectedGym != null
                      ? 'Equipment available at ${gymEquipmentState.selectedGym!.gymName}'
                      : 'Loading gym equipment...',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Loading state
        if (gymEquipmentState.isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          )
        // Equipment grid from gym
        else if (gymEquipmentState.selectedGym != null)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: gymEquipmentState.selectedGym!.equipment.length,
              itemBuilder: (context, index) {
                final item = gymEquipmentState.selectedGym!.equipment[index];
                final info = EquipmentInfo.getInfo(item.type);
                final isAvailable = item.isAvailable;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.blueAccent.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAvailable
                          ? Colors.blueAccent.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        info?.emoji ?? '🏋️',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayName,
                              style: TextStyle(
                                color:
                                    isAvailable ? Colors.white : Colors.white38,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (item.location != null)
                              Text(
                                item.location!,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                              : Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAvailable ? Icons.check : Icons.close,
                              color: isAvailable
                                  ? const Color(0xFF2ECC71)
                                  : Colors.redAccent,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAvailable ? 'x${item.quantity}' : 'N/A',
                              style: TextStyle(
                                color: isAvailable
                                    ? const Color(0xFF2ECC71)
                                    : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        else
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: PremiumStateCard(
                  icon: Icons.location_off_rounded,
                  title: 'No Gym Selected',
                  subtitle: 'Please join a gym to access its professional equipment list.',
                ),
              ),
            ),
          ),

        // Summary
        if (gymEquipmentState.selectedGym != null)
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${gymEquipmentState.selectedGym!.equipment.where((e) => e.isAvailable).length} equipment types available',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: Muscle Selection
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMusclesStep(WorkoutPlanBuilderState state) {
    final gender = ref.watch(profileSyncProvider).gender;
    final isMale = gender.toLowerCase() != 'female';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InteractiveMuscleSelector(
        isMale: isMale,
        onSelectionChanged: (muscles) {
          ref.read(workoutPlanBuilderProvider.notifier).setMuscles(muscles);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4: Schedule Settings
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScheduleStep(WorkoutPlanBuilderState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preferred Days
          _buildSettingCard(
            title: 'Preferred Days',
            subtitle: 'Which days do you want to train?',
            icon: Icons.calendar_today,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final isSelected = state.preferredDays.contains(index);
                final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return GestureDetector(
                  onTap: () {
                    ref
                        .read(workoutPlanBuilderProvider.notifier)
                        .togglePreferredDay(index);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTokens.colorBrand
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
            title: 'Session Duration',
            subtitle: 'How long can you train?',
            icon: Icons.timer,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [30, 45, 60, 90].map((mins) {
                  final isSelected = state.sessionDurationMinutes == mins;
                  return GestureDetector(
                    onTap: () => ref
                        .read(workoutPlanBuilderProvider.notifier)
                        .setSessionDuration(mins),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTokens.colorBrand
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTokens.colorBrand
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        '$mins min',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Fitness level
          _buildSettingCard(
            title: 'Fitness Level',
            subtitle: 'Be honest for best results',
            icon: Icons.trending_up,
            child: Column(
              children: FitnessLevel.values.map((level) {
                final isSelected = state.fitnessLevel == level;
                return GestureDetector(
                  onTap: () => ref
                      .read(workoutPlanBuilderProvider.notifier)
                      .setFitnessLevel(level),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTokens.colorBrand.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTokens.colorBrand
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getLevelIcon(level),
                          color: isSelected
                              ? AppTokens.colorBrand
                              : Colors.white54,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getLevelName(level),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: AppTokens.colorBrand, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Goal
          _buildSettingCard(
            title: 'Primary Goal',
            subtitle: 'What do you want to achieve?',
            icon: Icons.flag,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WorkoutGoal.values.map((goal) {
                final isSelected = state.goal == goal;
                return GestureDetector(
                  onTap: () => ref
                      .read(workoutPlanBuilderProvider.notifier)
                      .setGoal(goal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTokens.colorBrand.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTokens.colorBrand
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      _getGoalName(goal),
                      style: TextStyle(
                        color:
                            isSelected ? AppTokens.colorBrand : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTokens.colorBrand, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 5: Summary
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryStep(WorkoutPlanBuilderState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Equipment
          _buildSummaryRow(
            icon: Icons.sports_gymnastics,
            title: 'Equipment',
            value: '${state.selectedEquipment.length + 1} types',
            color: Colors.greenAccent,
          ),

          // Target muscles
          _buildSummaryRow(
            icon: Icons.accessibility_new,
            title: 'Target Muscles',
            value: state.selectedMuscles.map((m) => m.displayName).join(', '),
            color: Colors.purpleAccent,
          ),

          // Schedule
          _buildSummaryRow(
            icon: Icons.calendar_today,
            title: 'Schedule',
            value:
                '${state.preferredDays.length} days/week • ${state.sessionDurationMinutes} min',
            color: Colors.cyanAccent,
          ),

          // Fitness level
          _buildSummaryRow(
            icon: Icons.trending_up,
            title: 'Fitness Level',
            value: _getLevelName(state.fitnessLevel),
            color: Colors.orangeAccent,
          ),

          // Goal
          _buildSummaryRow(
            icon: Icons.flag,
            title: 'Goal',
            value: _getGoalName(state.goal),
            color: Colors.redAccent,
          ),

          const SizedBox(height: 24),

          // Generate button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTokens.colorBrand.withValues(alpha: 0.15),
                  AppTokens.colorBrand.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTokens.colorBrand.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppTokens.colorBrand, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Ready to Generate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'AI will create your personalized 4-week workout plan',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // Navigate to appropriate step for editing
              switch (title) {
                case 'Equipment':
                  ref
                      .read(workoutPlanBuilderProvider.notifier)
                      .goToStep(BuilderStep.equipment);
                  break;
                case 'Target Muscles':
                  ref
                      .read(workoutPlanBuilderProvider.notifier)
                      .goToStep(BuilderStep.muscles);
                  break;
                default:
                  ref
                      .read(workoutPlanBuilderProvider.notifier)
                      .goToStep(BuilderStep.schedule);
              }
            },
            child: const Icon(Icons.edit, color: Colors.white38, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(WorkoutPlanBuilderState state) {
    final isLastStep = state.currentStep == BuilderStep.summary;

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
              color: (state.isGenerating ? const Color(0xFF2ECC71) : AppTokens.colorBrand)
                  .withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Background Base
              Container(color: AppTokens.colorBrand),
              
              // Progress Fill
              if (state.isGenerating)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: MediaQuery.of(context).size.width * state.generationProgress,
                  height: double.infinity,
                  color: const Color(0xFF2ECC71),
                ),
              
              // Button Overlay
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (!state.isGenerating && state.canProceed)
                      ? () {
                          if (isLastStep) {
                            _generatePlan(state);
                          } else {
                            ref
                                .read(workoutPlanBuilderProvider.notifier)
                                .nextStep();
                          }
                        }
                      : null,
                  child: Center(
                    child: Text(
                      state.isGenerating
                          ? 'Synchronizing...'
                          : (isLastStep ? 'Generate Plan' : 'Continue'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingStep(WorkoutPlanBuilderState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sparkle Icon
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
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            '${(state.generationProgress * 100).toInt()}% complete',
            style: const TextStyle(
              color: AppTokens.colorBrand,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Detailed status text
          Text(
            _getGenerationFullStatus(state.generationProgress),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getGenerationFullStatus(double progress) {
    if (progress < 0.20) {
      return 'Analyzing your goals and fitness level\nto ensure optimal volume...';
    }
    if (progress < 0.40) {
      return 'Selecting specialized exercises based\non your available equipment...';
    }
    if (progress < 0.60) {
      return 'Balancing muscle group frequency and\noptimal hypertrophy variables...';
    }
    if (progress < 0.80) {
      return 'Optimizing rest periods and sequencing\nfor maximum strength gains...';
    }
    if (progress < 0.95) {
      return 'Almost there! Finalizing your 30-day\nprogressive overload routine...';
    }
    return 'Synchronizing with your unique profile...';
  }

  Future<void> _generatePlan(WorkoutPlanBuilderState state) async {
    ref.read(workoutPlanBuilderProvider.notifier).setGenerating(true);
    
    // Start simulation in background
    ref.read(workoutPlanBuilderProvider.notifier).startProgressSimulation();

    try {
      final orchestrationService = ref.read(aiOrchestrationProvider);
      final authState = ref.read(authNotifierProvider);
      String userId = 'guest';

      if (authState is AuthAuthenticated) {
        userId = authState.user.id;
      }

      final targetMuscleNames =
          state.selectedMuscles.map((m) => m.name).toList();

      final preferences = WorkoutPreferencesEntity(
        odUserId: userId,
        goal: state.goal,
        fitnessLevel: state.fitnessLevel,
        daysPerWeek: state.preferredDays.length,
        preferredDays: state.preferredDays.toList(),
        sessionDurationMinutes: state.sessionDurationMinutes,
        availableEquipment: state.selectedEquipment.toList(),
        outOfOrderMachines: ref.read(gymEquipmentProvider).outOfOrderMachines,
        targetMuscles: targetMuscleNames,
        trainingSplit: targetMuscleNames.isNotEmpty
            ? TrainingSplit.custom
            : TrainingSplit.fullBody,
      );

      final l10n = ref.read(l10nProvider);
      final generatedPlan = await orchestrationService.generateWorkoutPlan(
        preferences: preferences,
        odUserId: userId,
        targetMuscleNames: targetMuscleNames,
        languageCode: l10n.altLangCode ?? 'en',
      );

      // Save to local storage for the WorkoutPage's preferred flow
      await ref.read(workoutPlanStorageProvider).savePlan(generatedPlan);
      
      // Invalidate the provider to trigger a rebuild in WorkoutPage
      ref.invalidate(savedWorkoutPlanProvider);

      // ── Seed today's session progress from the generated plan ──────────────
      // This ensures the 3-step exercise protocol (Gold→Blue→Purple→Green)
      // is immediately populated for today when the plan lands.
      final todayWorkout = generatedPlan.getDayPlan(DateTime.now());
      if (todayWorkout != null &&
          !todayWorkout.isRestDay &&
          todayWorkout.exercises.isNotEmpty) {
        // Only seed if the session is currently empty (never clobber in-progress
        // tracking if the user regenerates mid-session).
        final currentSession = ref.read(sessionProgressProvider);
        if (currentSession.exercises.isEmpty) {
          ref.read(sessionProgressProvider.notifier).setExercises(
                todayWorkout.exercises
                    .map((ex) => ExerciseProgress(
                          exerciseId: ex.id,
                          exerciseName: ex.name,
                          targetSets: ex.sets.length,
                          targetReps: ex.sets.isNotEmpty
                              ? ex.sets.first.targetReps
                              : 10,
                        ))
                    .toList(),
              );
        }
      }
      // ───────────────────────────────────────────────────────────────────────
      // Note: we intentionally do NOT call fetchActivePlan() here.
      // The local plan (savedWorkoutPlanProvider) is the source of truth after
      // generation. The backend notifier is only consulted when no local plan
      // exists (see WorkoutPage.initState), so there is nothing to refresh.

      if (mounted) {
        ref.read(workoutPlanBuilderProvider.notifier).setGenerating(false);
        
        // Use pop instead of go to handle modal dismissal better
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout plan generated successfully!'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(workoutPlanBuilderProvider.notifier).setGenerating(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate plan: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _getStepTitle(BuilderStep step) {
    switch (step) {
      case BuilderStep.equipment:
        return 'Your Equipment';
      case BuilderStep.muscles:
        return 'Target Muscles';
      case BuilderStep.schedule:
        return 'Schedule & Goals';
      case BuilderStep.summary:
        return 'Review Your Plan';
    }
  }

  IconData _getLevelIcon(FitnessLevel level) {
    switch (level) {
      case FitnessLevel.beginner:
        return Icons.sentiment_satisfied;
      case FitnessLevel.intermediate:
        return Icons.trending_up;
      case FitnessLevel.advanced:
        return Icons.whatshot;
      case FitnessLevel.athlete:
        return Icons.emoji_events;
    }
  }

  String _getLevelName(FitnessLevel level) {
    switch (level) {
      case FitnessLevel.beginner:
        return 'Beginner';
      case FitnessLevel.intermediate:
        return 'Intermediate';
      case FitnessLevel.advanced:
        return 'Advanced';
      case FitnessLevel.athlete:
        return 'Athlete';
    }
  }

  String _getGoalName(WorkoutGoal goal) {
    switch (goal) {
      case WorkoutGoal.weightLoss:
        return 'Weight Loss';
      case WorkoutGoal.muscleGain:
        return 'Muscle Gain';
      case WorkoutGoal.strength:
        return 'Strength';
      case WorkoutGoal.endurance:
        return 'Endurance';
      case WorkoutGoal.flexibility:
        return 'Flexibility';
      case WorkoutGoal.generalFitness:
        return 'General Fitness';
    }
  }
}
