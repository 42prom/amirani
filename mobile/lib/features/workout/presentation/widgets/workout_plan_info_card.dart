import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';
import 'package:amirani_app/core/widgets/plan_source_badge.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';
import '../../domain/entities/workout_preferences_entity.dart';

class WorkoutPlanInfoCard extends StatelessWidget {
  final MonthlyWorkoutPlanEntity plan;
  final bool isAIGenerated;
  final String? trainerName;

  const WorkoutPlanInfoCard({
    super.key,
    required this.plan,
    this.isAIGenerated = false,
    this.trainerName,
  });

  Map<String, dynamic> _getWeekStatus() {
    final today = DateTime.now();
    int weekNum = 1;
    for (final week in plan.weeks) {
      if (today.isAfter(week.startDate.subtract(const Duration(days: 1))) &&
          today.isBefore(week.endDate.add(const Duration(days: 1)))) {
        weekNum = week.weekNumber;
        break;
      }
    }

    // Determine intensity phase (standard 4-week cycle)
    final cycleNum = (weekNum - 1) % 4; // 0, 1, 2, 3
    switch (cycleNum) {
      case 0: return {'label': 'BASE WEEK', 'color': const Color(0xFF2ECC71), 'icon': Icons.trending_flat};
      case 1: return {'label': 'OVERLOAD', 'color': Colors.amber, 'icon': Icons.trending_up};
      case 2: return {'label': 'PEAK PHASE', 'color': Colors.orangeAccent, 'icon': Icons.fireplace};
      case 3: return {'label': 'RECOVERY/DELOAD', 'color': Colors.lightBlueAccent, 'icon': Icons.ac_unit};
      default: return {'label': 'ACTIVE', 'color': Colors.white, 'icon': Icons.check};
    }
  }

  Widget _buildIntensityBadge() {
    final status = _getWeekStatus();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (status['color'] as Color).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (status['color'] as Color).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status['icon'] as IconData,
            color: status['color'] as Color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            status['label'] as String,
            style: TextStyle(
              color: status['color'] as Color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a human-readable split label — never shows raw enum names like "fullBody".
  String _splitLabel() {
    // 1. Check for custom muscle focus in the plan itself
    try {
      if (plan.weeks.isNotEmpty) {
        final allMuscles = plan.weeks
            .expand((w) => w.days)
            .expand((d) => d.targetMuscleGroups)
            .where((m) => m != MuscleGroup.fullBody && m != MuscleGroup.cardio)
            .map((m) => m.name[0].toUpperCase() + m.name.substring(1))
            .toSet()
            .toList();

        if (allMuscles.isNotEmpty) {
          // Join up to 2 muscles for a cleaner title (e.g. Chest & Shoulders Focus)
          final focus = allMuscles.take(2).join(' & ');
          final suffix = allMuscles.length > 2 ? ' +${allMuscles.length - 2}' : '';
          
          if (plan.split == TrainingSplit.custom) {
            return '$focus$suffix Focus';
          }
          return '$focus Focused Split';
        }
      }
    } catch (_) {}

    // 2. Fallback to standard split labels
    switch (plan.split) {
      case TrainingSplit.fullBody:
        return 'Full Body Split';
      case TrainingSplit.upperLower:
        return 'Upper / Lower Split';
      case TrainingSplit.pushPullLegs:
        return 'Push Pull Legs';
      case TrainingSplit.broSplit:
        return 'Bro Split';
      case TrainingSplit.custom:
        return 'Custom Focus';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBrand.withValues(alpha: 0.15),
            AppTheme.primaryBrand.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryBrand.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: AppTheme.primaryBrand,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _splitLabel(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.dailyTarget.durationMinutes} min • ${plan.dailyTarget.exercisesPerSession} exercises',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildIntensityBadge(),
            ],
          ),
          if (PlanSourceBadge.fromPlan(
                isAIGenerated: isAIGenerated,
                trainerName: trainerName,
              ) !=
              null) ...[
            const SizedBox(height: 10),
            PlanSourceBadge.fromPlan(
              isAIGenerated: isAIGenerated,
              trainerName: trainerName,
            )!,
          ],
        ],
      ),
    );
  }
}
