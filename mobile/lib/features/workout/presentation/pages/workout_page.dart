import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../../../../core/providers/session_progress_provider.dart';
import '../../../../core/services/workout_plan_storage_service.dart';
import '../../../../core/utils/app_notifications.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';
import '../../../profile/presentation/widgets/profile_settings_modal.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../../../gym/presentation/providers/membership_provider.dart';
import '../../../gym/presentation/providers/trainer_assignment_provider.dart';
import '../providers/workout_provider.dart';
import '../../../../core/providers/day_selector_providers.dart';
import '../../../../core/providers/tier_limits_provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import 'workout_plan_builder_page.dart';

// Import newly extracted widgets
import '../widgets/workout_header.dart';
import 'package:amirani_app/core/widgets/app_day_selector.dart';
import '../widgets/workout_plan_info_card.dart';
import '../widgets/workout_plan_management_card.dart';
import '../widgets/workout_progress_card.dart';
import 'package:amirani_app/core/widgets/premium_state_card.dart';
import '../widgets/workout_exercise_list.dart';

class WorkoutPage extends ConsumerStatefulWidget {
  const WorkoutPage({super.key});

  @override
  ConsumerState<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends ConsumerState<WorkoutPage> {
  @override
  void initState() {
    super.initState();
    // Always fetch — notifier is offline-first and uses cache while loading.
    Future.microtask(() {
      if (mounted) ref.read(workoutNotifierProvider.notifier).fetchActivePlan();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _initSessionProgressFromPlan(MonthlyWorkoutPlanEntity plan) {
    final session = ref.read(sessionProgressProvider);
    // Use the active plan flag to avoid double-initialization while respecting rest days (empty lists)
    if (session.isWorkoutPlanActive) return;

    final todayWorkout = plan.getDayPlan(DateTime.now());
    
    // Map exercises if today is a workout day
    final List<ExerciseProgress> exercises = [];
    if (todayWorkout != null && !todayWorkout.isRestDay && todayWorkout.exercises.isNotEmpty) {
      exercises.addAll(todayWorkout.exercises.map((ex) => ExerciseProgress(
            exerciseId: ex.id,
            exerciseName: ex.name,
            targetSets: ex.sets.length,
            targetReps: ex.sets.isNotEmpty ? ex.sets.first.targetReps : 10,
            sets: ex.sets,
            completedSets: ex.sets.where((s) => s.isCompleted).length,
            videoUrl: ex.videoUrl,
            imageUrl: ex.imageUrl,
            instructions: ex.instructions,
            targetWeight: ex.sets.isNotEmpty ? ex.sets.first.targetWeight : null,
            rpe: ex.sets.isNotEmpty ? ex.sets.first.rpe : null,
            tempoEccentric: ex.sets.isNotEmpty ? ex.sets.first.tempoEccentric : null,
            tempoPause: ex.sets.isNotEmpty ? ex.sets.first.tempoPause : null,
            tempoConcentric: ex.sets.isNotEmpty ? ex.sets.first.tempoConcentric : null,
            progressionNote: ex.progressionNote,
            targetMuscles: ex.targetMuscles,
          )));
    }

    // Always call setExercises to mark the plan as active in session state, 
    // even if it's an empty list for a rest day.
    ref.read(sessionProgressProvider.notifier).setExercises(exercises);
  }

  // --- Day Helpers ---
  bool _activeDayIsToday(int activeDay) {
    return (DateTime.now().weekday - 1) == activeDay;
  }

  String _getDayLabel(int dayIndex) {
    const labels = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return labels[dayIndex.clamp(0, 6)];
  }

  DailyWorkoutPlanEntity? _getWorkoutForSelectedDay(
      MonthlyWorkoutPlanEntity plan, int activeDay) {
    final today = DateTime.now();
    final mondayOfThisWeek =
        today.subtract(Duration(days: today.weekday - 1));
    final targetDate = DateTime(
      mondayOfThisWeek.year,
      mondayOfThisWeek.month,
      mondayOfThisWeek.day + activeDay,
    );

    // Premium logic: A plan shouldn't show workouts before its start date
    // Normalize dates to midnight for comparison
    final normalizedTarget = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final normalizedStart = DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day);
    
    if (normalizedTarget.isBefore(normalizedStart)) {
      return null;
    }

    // Exact calendar-date match
    for (final week in plan.weeks) {
      for (final day in week.days) {
        if (day.date.year == targetDate.year &&
            day.date.month == targetDate.month &&
            day.date.day == targetDate.day) {
          return day;
        }
      }
    }

    // Fallback: same weekday pattern from week 1 (only if that week 1 day is >= startDate)
    if (plan.weeks.isNotEmpty) {
      for (final day in plan.weeks.first.days) {
        if (day.date.weekday - 1 == activeDay) {
          // Even as fallback, respect the start date for this specific date
          return day;
        }
      }
    }
    return null;
  }


  Future<void> _showNewTrainerPlanDialog(WorkoutNewTrainerPlan newPlan) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTokens.colorBrand.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center, color: AppTokens.colorBrand, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'New Plan Assigned',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your trainer has assigned you a new workout plan:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTokens.colorBrand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    newPlan.plan.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${newPlan.plan.routines.length} session${newPlan.plan.routines.length == 1 ? '' : 's'} · ${newPlan.plan.difficulty}',
                    style: const TextStyle(color: AppTokens.colorBrand, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(workoutNotifierProvider.notifier).dismissNewPlan();
            },
            child: Text('Later', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.colorBrand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(workoutNotifierProvider.notifier).acceptNewPlan(newPlan.plan, newPlan.monthly);
            },
            child: const Text('Load Plan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final activeDay = ref.watch(workoutDaySelectorProvider);
    final state = ref.watch(workoutNotifierProvider);
    final savedPlan = ref.watch(savedWorkoutPlanProvider);
    final membershipState = ref.watch(membershipProvider);

    final bool isLinkedToGym = membershipState is MembershipLoaded &&
        membershipState.memberships.any((m) => m.isActive || m.isPending);
    final bool isActiveMember = membershipState is MembershipLoaded &&
        membershipState.memberships.any((m) => m.isActive);

    // Show acceptance prompt when trainer assigns a new plan
    ref.listen<WorkoutState>(workoutNotifierProvider, (_, next) {
      if (next is WorkoutNewTrainerPlan && mounted) {
        _showNewTrainerPlanDialog(next);
      }
    });

    // Auto-populate session progress
    ref.listen<AsyncValue<MonthlyWorkoutPlanEntity?>>(savedWorkoutPlanProvider,
        (_, next) {
      next.whenData((plan) {
        if (plan != null && mounted) _initSessionProgressFromPlan(plan);
      });
    });

    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const WorkoutHeader(),
            Expanded(
              child: RefreshIndicator(
                color: AppTokens.colorBrand,
                onRefresh: () async {
                  await ref.read(workoutNotifierProvider.notifier).fetchActivePlan();
                  await ref.read(sessionProgressProvider.notifier).syncDown();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: _buildBody(state, context, savedPlan, isLinkedToGym, isActiveMember, activeDay),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    WorkoutState state,
    BuildContext context,
    AsyncValue<MonthlyWorkoutPlanEntity?> savedPlan,
    bool isLinkedToGym,
    bool isActiveMember,
    int activeDay,
  ) {
    final sessionProgress = ref.watch(sessionProgressProvider);

    return savedPlan.when(
      data: (plan) {
        if (state is WorkoutGenerating && plan != null) {
          return Column(
            children: [
              _buildGeneratingBanner(),
              _buildSavedPlanView(plan, isLinkedToGym, isActiveMember, activeDay),
            ],
          );
        }
        if (plan != null) {
          return _buildSavedPlanView(plan, isLinkedToGym, isActiveMember, activeDay);
        }

        // Live fallback: if state already has a plan (WorkoutLoaded), show the rich view 
        // by converting on-the-fly. This prevents the "Legacy" fallback when a new plan 
        // is fetched but not yet fully persisted to local storage.
        if (state is WorkoutLoaded) {
          final user = ref.read(currentUserProvider);
          final transientMonthly = plan?.copyWith() ?? state.plan.toMonthlyEntity(user?.id ?? state.plan.id);
          return _buildSavedPlanView(transientMonthly, isLinkedToGym, isActiveMember, activeDay);
        }

        return _buildLegacyBody(state, sessionProgress, isLinkedToGym, isActiveMember, activeDay);
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100.0),
          child: CircularProgressIndicator(color: AppTokens.colorBrand),
        ),
      ),
      error: (_, __) => _buildLegacyBody(state, sessionProgress, isLinkedToGym, isActiveMember, activeDay),
    );
  }

  Widget _buildLegacyBody(
      WorkoutState state, SessionProgressState sessionProgress, bool isLinkedToGym, bool isActiveMember, int activeDay) {
    if (state is WorkoutLoading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.only(top: 100.0),
        child: CircularProgressIndicator(color: AppTokens.colorBrand),
      ));
    }

    if (state is WorkoutError) {
      if (sessionProgress.exercises.isNotEmpty) {
        return _buildActivePlanFromSession(sessionProgress, isLinkedToGym, isActiveMember, activeDay);
      }
      // canRetry means a generation job failed/timed out — the user can try again.
      // Show active cards (isOffline: false) so they can re-trigger generation.
      return _buildGeneratePlanPrompt(
        isOffline: !state.canRetry,
        isLinkedToGym: isLinkedToGym,
        isActiveMember: isActiveMember,
        activeDay: activeDay,
      );
    }

    if (state is WorkoutEmpty) {
      if (sessionProgress.exercises.isNotEmpty) {
        return _buildActivePlanFromSession(sessionProgress, isLinkedToGym, isActiveMember, activeDay);
      }
      return _buildGeneratePlanPrompt(isOffline: false, isLinkedToGym: isLinkedToGym, isActiveMember: isActiveMember, activeDay: activeDay);
    }

    if (state is WorkoutLoaded) {
      if (sessionProgress.exercises.isNotEmpty) {
        return _buildActivePlanFromSession(sessionProgress, isLinkedToGym, isActiveMember, activeDay);
      }
      return _buildActivePlanView(state.plan, isLinkedToGym, isActiveMember, activeDay);
    }

    if (state is WorkoutGenerating) {
      if (sessionProgress.exercises.isNotEmpty) {
        return _buildActivePlanFromSession(sessionProgress, isLinkedToGym, isActiveMember, activeDay);
      }
      return Column(
        children: [
          _buildGeneratingBanner(),
          const SizedBox(height: 100),
          const Center(child: CircularProgressIndicator(color: AppTokens.colorBrand)),
        ],
      );
    }

    if (state is WorkoutDismissed) {
      return _buildGeneratePlanPrompt(isOffline: false, isLinkedToGym: isLinkedToGym, isActiveMember: isActiveMember, activeDay: activeDay);
    }

    // Fallback — always show the generate prompt rather than a blank screen
    return _buildGeneratePlanPrompt(isOffline: false, isLinkedToGym: isLinkedToGym, isActiveMember: isActiveMember, activeDay: activeDay);
  }

  Widget _buildGeneratingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.colorBrand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTokens.colorBrand),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Creating your workout plan…',
              style: TextStyle(
                  color: AppTokens.colorBrand,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlanView(
      MonthlyWorkoutPlanEntity plan, bool isLinkedToGym, bool isActiveMember, int activeDay) {
    final workoutState = ref.watch(workoutNotifierProvider);
    final assignmentState = ref.watch(trainerAssignmentProvider);

    final bool isAIGenerated = workoutState is WorkoutLoaded && workoutState.plan.isAIGenerated;
    final String? trainerName = assignmentState is TrainerAssignmentLoaded
        ? assignmentState.assignedTrainer?.fullName
        : null;

    final isToday = _activeDayIsToday(activeDay);
    final isPastDay = activeDay < (DateTime.now().weekday - 1);
    final selectedWorkout = _getWorkoutForSelectedDay(plan, activeDay);

    final headerLabel = isToday ? "Today's Workout" : _getDayLabel(activeDay);

    final doneCount = selectedWorkout?.completedExercises ?? 0;
    final totalCount = selectedWorkout?.exercises.length ?? 0;
    final isDayComplete = selectedWorkout?.isCompleted ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDaySelector(
          activeDay: activeDay,
          onDaySelected: (day) => ref.read(workoutDaySelectorProvider.notifier).state = day,
          daysWithTasks: plan.weeks.isNotEmpty 
            ? plan.weeks.first.days
                .where((d) => !d.isRestDay && d.exercises.isNotEmpty)
                .where((d) {
                  final normalizedDay = DateTime(d.date.year, d.date.month, d.date.day);
                  final normalizedStart = DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day);
                  return !normalizedDay.isBefore(normalizedStart);
                })
                .map((d) => d.date.weekday - 1)
                .toSet()
            : {},
        ),
        const SizedBox(height: 24),

        WorkoutPlanInfoCard(plan: plan, isAIGenerated: isAIGenerated, trainerName: trainerName),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      headerLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isPastDay) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HISTORY',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (selectedWorkout != null && !selectedWorkout.isRestDay) ...[
                  Text(
                    selectedWorkout.workoutName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTokens.colorBrand,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (selectedWorkout.targetMuscleGroups.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selectedWorkout.targetMuscleGroups.take(4).map((m) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          m.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ],
            ),
            if (selectedWorkout != null && !selectedWorkout.isRestDay)
              Text(
                "$doneCount/$totalCount Done",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDayComplete
                      ? const Color(0xFF2ECC71)
                      : Colors.white54,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (selectedWorkout == null)
          _buildNoWorkoutCard(
            message: activeDay < (DateTime.now().weekday - 1) ? 'No record for this day' : 'Plan starts soon',
            subtitle: activeDay < (DateTime.now().weekday - 1) 
              ? 'This session was before your current plan activated.' 
              : 'Your new personalized plan will begin on ${_formatDate(plan.startDate)}.',
          )
        else if (selectedWorkout.isRestDay)
          _buildRestDayCard()
        else
          ...selectedWorkout.exercises.map((ex) => RealExercisePill(exercise: ex, date: selectedWorkout.date)),

        const SizedBox(height: 24),

        if (selectedWorkout != null && !selectedWorkout.isRestDay)
          WorkoutTodayProgressCard(
            completedExercises: selectedWorkout.completedExercises,
            totalExercises: selectedWorkout.exercises.length,
          ),

        const SizedBox(height: 24),

        WorkoutPlanManagementCard(plan: plan, isAIGenerated: isAIGenerated, trainerName: trainerName),

        const SizedBox(height: 24),

        const Text(
          'Build New Plan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildCreateCard('Home Plan', 'auto_awesome', Colors.amber, false, isActiveMember)),
            if (isLinkedToGym) ...[
              const SizedBox(width: 16),
              Expanded(child: _buildCreateCard('Gym Plan', 'auto_awesome', Colors.blueAccent, false, isActiveMember)),
            ],
          ],
        ),
      ],
    );
  }

  // --- Legacy Fallback Views ---

  Widget _buildActivePlanView(WorkoutPlanEntity plan, bool isLinkedToGym, bool isActiveMember, int activeDay) {
    if (plan.routines.isEmpty) {
      return _buildGeneratePlanPrompt(isOffline: false, isLinkedToGym: isLinkedToGym, isActiveMember: isActiveMember, activeDay: activeDay);
    }
    final routine = plan.routines.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDaySelector(
          activeDay: activeDay,
          onDaySelected: (day) => ref.read(workoutDaySelectorProvider.notifier).state = day,
        ),
        const SizedBox(height: 24),
        const Text("Today's exercise",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        // Mock non interactive pills
        ...routine.exercises.map((ex) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTokens.colorBgSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black45,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.white54, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.exerciseName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text("${ex.targetSets} Sets",
                              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text("•", style: TextStyle(color: Colors.white54, fontSize: 10))),
                          Text("${ex.targetReps} Reps",
                              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ),
      ],
    );
  }

  Widget _buildActivePlanFromSession(SessionProgressState sessionProgress, bool isLinkedToGym, bool isActiveMember, int activeDay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDaySelector(
          activeDay: activeDay,
          onDaySelected: (day) => ref.read(workoutDaySelectorProvider.notifier).state = day,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Today's exercise",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(
                "${sessionProgress.completedExercises}/${sessionProgress.totalExercises} Done",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: sessionProgress.completedExercises == sessionProgress.totalExercises
                        ? const Color(0xFF2ECC71)
                        : Colors.white54)),
          ],
        ),
        const SizedBox(height: 16),
        ...sessionProgress.exercises.map((exercise) => InteractiveExercisePill(exercise: exercise)),
        const SizedBox(height: 24),
        WorkoutProgressCard(sessionProgress: sessionProgress),
        const SizedBox(height: 32),
        const Text("Build New Plan",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildCreateCard("Home Plan", "auto_awesome", Colors.amber, false, isActiveMember)),
            if (isLinkedToGym) ...[
              const SizedBox(width: 16),
              Expanded(child: _buildCreateCard("Gym Plan", "auto_awesome", Colors.blueAccent, false, isActiveMember)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildGeneratePlanPrompt({required bool isOffline, required bool isLinkedToGym, required bool isActiveMember, required int activeDay}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDaySelector(
          activeDay: activeDay,
          onDaySelected: (day) => ref.read(workoutDaySelectorProvider.notifier).state = day,
        ),
        const SizedBox(height: 24),
        const Text("Today's exercise",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        if (isOffline)
          const PremiumStateCard(
            icon: Icons.wifi_off_rounded,
            title: 'AI Engine Offline',
            subtitle: 'We will generate your personalized plan once you reconnect.',
          )
        else
          const PremiumStateCard(
            icon: Icons.auto_awesome_rounded,
            title: 'No Plan Active',
            subtitle: 'Create your personalized journey using the builders below.',
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildCreateCard("Home Plan", "auto_awesome", Colors.amber, isOffline, isActiveMember)),
            if (isLinkedToGym) ...[
              const SizedBox(width: 16),
              Expanded(child: _buildCreateCard("Gym Plan", "auto_awesome", Colors.blueAccent, isOffline, isActiveMember)),
            ],
          ],
        )
      ],
    );
  }

  Widget _buildCreateCard(String title, String iconString, Color tint, bool isOffline, bool isActiveMember) {
    final bool isHome = title == "Home Plan";
    final syncState = ref.watch(profileSyncProvider);
    final tierAsync = ref.watch(tierLimitsProvider);

    return GestureDetector(
      onTap: isOffline
          ? null
          : () {
              if (title == "Gym Plan" && !isActiveMember) {
                AppNotifications.showError(context, 'Gym Membership Approval Pending');
                return;
              }
              if (!syncState.hasMedicalData) {
                AppNotifications.showError(context, 'Health Profile Required for AI Generation');
                ProfileSettingsModal.show(context);
                return;
              }
              // Tier limit guard
              final limits = tierAsync.valueOrNull;
              if (limits != null) {
                if (limits.isOfflineFallback) {
                  AppNotifications.showError(
                      context, 'Unable to verify your plan access. Please check your connection and try again.');
                  return;
                }
                if (!limits.canAccessAICoach) {
                  AppNotifications.showError(
                      context, 'AI Workout Planner requires a Premium or Gym Member plan');
                  return;
                }
                if (!limits.canMakeRequest) {
                  AppNotifications.showError(
                      context, limits.remainingLabel);
                  return;
                }
              }
              WorkoutPlanBuilderPage.show(
                context,
                isHome ? WorkoutPlanType.home : WorkoutPlanType.gym,
              );
            },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: AppTokens.colorBgSurface,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: 0.15),
              Colors.black,
            ],
          ),
          image: DecorationImage(
            image: NetworkImage(isHome
                ? 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'
                : 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.5), BlendMode.darken),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black45,
                  border: Border.all(color: Colors.white10),
                ),
                child: Icon(Icons.auto_awesome, color: tint, size: 16),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFF1C40E), Color(0xFFD4AC0D)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppTokens.colorBrand.withValues(alpha: 0.2), blurRadius: 15)
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: (isOffline || (title == "Gym Plan" && !isActiveMember)) ? 0.5 : 1.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon((title == "Gym Plan" && !isActiveMember) ? Icons.lock : Icons.bolt, color: Colors.black, size: 16),
                          const SizedBox(width: 4),
                          Text((title == "Gym Plan" && !isActiveMember) ? "Pending Approval" : "Build with AI", style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Display placeholders ---

  Widget _buildNoWorkoutCard({String? message, String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, color: Colors.white.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 16),
          Text(message ?? 'No workout scheduled', 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle ?? 'Take a rest, or use the AI button below to create a new session.',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRestDayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.self_improvement, color: Colors.blueAccent, size: 48),
          SizedBox(height: 16),
          Text('Rest Day', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Recovery is essential for muscle growth.\nStay hydrated and get good sleep!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
