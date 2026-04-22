import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/workout_plan_storage_service.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../../../../core/providers/session_progress_provider.dart';
import 'package:amirani_app/core/widgets/plan_source_badge.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';

class WorkoutPlanManagementCard extends ConsumerStatefulWidget {
  final MonthlyWorkoutPlanEntity plan;
  final bool isAIGenerated;
  final String? trainerName;

  const WorkoutPlanManagementCard({
    super.key,
    required this.plan,
    this.isAIGenerated = false,
    this.trainerName,
  });

  @override
  ConsumerState<WorkoutPlanManagementCard> createState() => _WorkoutPlanManagementCardState();
}

class _WorkoutPlanManagementCardState extends ConsumerState<WorkoutPlanManagementCard> {

  int _getCurrentWeekNumber(MonthlyWorkoutPlanEntity plan) {
    final today = DateTime.now();
    for (final week in plan.weeks) {
      if (today.isAfter(week.startDate.subtract(const Duration(days: 1))) &&
          today.isBefore(week.endDate.add(const Duration(days: 1)))) {
        return week.weekNumber;
      }
    }
    return 1;
  }

  Future<void> _repeatPlan(MonthlyWorkoutPlanEntity plan) async {
    final today = DateTime.now();
    final newStart = DateTime(today.year, today.month, today.day);
    final planLength = plan.endDate.difference(plan.startDate);
    final newEnd = newStart.add(planLength);

    // Rebuild all weeks with shifted dates and cleared completion state
    final newWeeks = plan.weeks.asMap().entries.map((weekEntry) {
      final weekIdx = weekEntry.key;
      final oldWeek = weekEntry.value;
      final newWeekStart = newStart.add(Duration(days: weekIdx * 7));
      final newWeekEnd = newWeekStart.add(const Duration(days: 6));

      final newDays = oldWeek.days.asMap().entries.map((dayEntry) {
        final dayIdx = dayEntry.key;
        final oldDay = dayEntry.value;
        final newDate = newStart.add(Duration(days: weekIdx * 7 + dayIdx));

        return oldDay.copyWith(
          date: newDate,
          isCompleted: false,
          startedAt: null,
          completedAt: null,
          exercises: oldDay.exercises
              .map((ex) => ex.copyWith(
                    isCompleted: false,
                    completedAt: null,
                    sets: ex.sets
                        .map((s) => s.copyWith(
                              isCompleted: false,
                              actualReps: null,
                              actualWeight: null,
                              completedAt: null,
                            ))
                        .toList(),
                  ))
              .toList(),
        );
      }).toList();

      return oldWeek.copyWith(
        startDate: newWeekStart,
        endDate: newWeekEnd,
        days: newDays,
      );
    }).toList();

    final repeatedPlan = plan.copyWith(
      startDate: newStart,
      endDate: newEnd,
      weeks: newWeeks,
      updatedAt: today,
    );

    await ref.read(workoutPlanStorageProvider).savePlan(repeatedPlan);

    // Seed today's session from the reset plan
    final todayWorkout = repeatedPlan.getDayPlan(today);
    if (todayWorkout != null &&
        !todayWorkout.isRestDay &&
        todayWorkout.exercises.isNotEmpty) {
      ref.read(sessionProgressProvider.notifier).setExercises(
            todayWorkout.exercises
                .map((ex) => ExerciseProgress(
                      exerciseId: ex.id,
                      exerciseName: ex.name,
                      targetSets: ex.sets.length,
                      targetReps:
                          ex.sets.isNotEmpty ? ex.sets.first.targetReps : 10,
                    ))
                .toList(),
          );
    } else {
      ref.read(sessionProgressProvider.notifier).setExercises([]);
    }

    ref.invalidate(savedWorkoutPlanProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan restarted from Week 1 — let\'s go!'),
          backgroundColor: Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildManageButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isExpired = today.isAfter(widget.plan.endDate);
    final isComplete = widget.plan.overallProgress >= 1.0;
    final isFinished = isExpired || isComplete;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isFinished
              ? const Color(0xFFFFD700).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          if (isFinished)
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.06),
              blurRadius: 20,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFinished ? Icons.emoji_events_rounded : Icons.tune_rounded,
                color: isFinished
                    ? const Color(0xFFFFD700)
                    : Colors.white54,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isFinished ? 'Plan Complete 🎉' : 'Manage Plan',
                style: TextStyle(
                  color:
                      isFinished ? const Color(0xFFFFD700) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Week ${_getCurrentWeekNumber(widget.plan)} of ${widget.plan.weeks.length}',
                  style: const TextStyle(
                    color: Color(0xFF2ECC71),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if (isFinished) ...[
            const SizedBox(height: 6),
            const Text(
              'You crushed it! Repeat this program or build a fresh one below.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              '${(widget.plan.overallProgress * 100).round()}% overall • '
              '${widget.plan.completedWorkouts}/${widget.plan.totalWorkouts} sessions done',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],

          if (PlanSourceBadge.fromPlan(
                isAIGenerated: widget.isAIGenerated,
                trainerName: widget.trainerName,
              ) !=
              null) ...[
            const SizedBox(height: 10),
            PlanSourceBadge.fromPlan(
              isAIGenerated: widget.isAIGenerated,
              trainerName: widget.trainerName,
            )!,
          ],

          const SizedBox(height: 14),

          Row(
            children: [
              if (isFinished) ...[
                Expanded(
                  child: _buildManageButton(
                    icon: Icons.replay_rounded,
                    label: 'Repeat Plan',
                    color: const Color(0xFF2ECC71),
                    onTap: () => _repeatPlan(widget.plan),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _buildManageButton(
                  icon: Icons.refresh_rounded,
                  label: 'Reload',
                  color: Colors.white38,
                  onTap: () => ref.invalidate(savedWorkoutPlanProvider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
