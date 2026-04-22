import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../../../../core/providers/session_progress_provider.dart';

class WorkoutProgressCard extends StatelessWidget {
  final SessionProgressState sessionProgress;

  const WorkoutProgressCard({super.key, required this.sessionProgress});

  @override
  Widget build(BuildContext context) {
    final progress = sessionProgress.workoutProgress;
    final completedExercises = sessionProgress.completedExercises;
    final totalExercises = sessionProgress.totalExercises;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Progress",
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                    completedExercises >= totalExercises && totalExercises > 0
                        ? "Workout Complete!"
                        : "$completedExercises of $totalExercises exercises",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (sessionProgress.estimatedDurationMinutes > 0) ...[
                      _buildMetric(Icons.timer_outlined, "${sessionProgress.estimatedDurationMinutes}m"),
                      const SizedBox(width: 12),
                    ],
                    if (sessionProgress.estimatedCaloriesBurned > 0) ...[
                      _buildMetric(Icons.local_fire_department_outlined, "${sessionProgress.estimatedCaloriesBurned} kcal"),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                    completedExercises >= totalExercises && totalExercises > 0
                        ? "Great job! Rest well."
                        : "Tap exercise to log sets",
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            height: 72,
            width: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 6,
                    color: Colors.black.withValues(alpha: 0.5)),
                CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    color: progress >= 1.0
                        ? const Color(0xFF2ECC71)
                        : progress >= 0.5
                            ? const Color(0xFF1877F2)
                            : AppTheme.primaryBrand,
                    strokeCap: StrokeCap.round),
                Center(
                    child: Text("${(progress * 100).round()}%",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.primaryBrand),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class WorkoutTodayProgressCard extends StatelessWidget {
  final int completedExercises;
  final int totalExercises;

  const WorkoutTodayProgressCard({
    super.key,
    required this.completedExercises,
    required this.totalExercises,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        totalExercises > 0 ? completedExercises / totalExercises : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Progress",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                completedExercises == totalExercises && totalExercises > 0
                    ? "Workout Complete!"
                    : "$completedExercises of $totalExercises exercises",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                completedExercises == totalExercises && totalExercises > 0
                    ? "Great job! Rest well."
                    : "Tap exercise to log completion",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          SizedBox(
            height: 72,
            width: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  color: progress >= 1.0
                      ? const Color(0xFF2ECC71)
                      : progress >= 0.5
                          ? const Color(0xFF1877F2)
                          : AppTheme.primaryBrand,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    "${(progress * 100).round()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
