import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import 'package:amirani_app/core/localization/l10n_keys.dart';
import '../../../../core/providers/session_progress_provider.dart';
import '../../../../core/services/workout_plan_storage_service.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';

class InteractiveExercisePill extends ConsumerStatefulWidget {
  final ExerciseProgress exercise;

  const InteractiveExercisePill({super.key, required this.exercise});

  @override
  ConsumerState<InteractiveExercisePill> createState() => _InteractiveExercisePillState();
}

class _InteractiveExercisePillState extends ConsumerState<InteractiveExercisePill> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    final status = widget.exercise.status;
    Color accentColor;
    final completedSets = widget.exercise.completedSets;
    final targetSets = widget.exercise.targetSets;

    String statusText;
    if (status == SetStatus.completed) {
      accentColor = const Color(0xFF2ECC71);
      statusText = "$targetSets/$targetSets ${L10n.workoutSets}";
    } else if (completedSets > 0) {
      accentColor = const Color(0xFF3498DB); // Blue for active progress
      statusText = "$completedSets/$targetSets ${L10n.workoutSets}";
    } else {
      accentColor = Colors.white54;
      statusText = "$targetSets ${L10n.workoutSets}";
    }

    Widget trailingIcon = _buildSetIndicator(status, accentColor, completedSets);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: status == SetStatus.completed
              ? const Color(0xFF2ECC71).withValues(alpha: 0.4)
              : widget.exercise.intensityStatus != IntensityStatus.normal
                  ? widget.exercise.intensityColor.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
          width: widget.exercise.intensityStatus != IntensityStatus.normal ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (status != SetStatus.notStarted)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
          if (widget.exercise.intensityStatus != IntensityStatus.normal)
            BoxShadow(
              color: widget.exercise.intensityColor.withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Icon(
                              _getExerciseIcon(widget.exercise.targetMuscles),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.exercise.exerciseName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4), // Visual balance for chevron
                                      child: Icon(
                                        _isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Text("•", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                    ),
                                    Text(
                                      "${widget.exercise.targetReps} ${L10n.workoutReps}",
                                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    if (widget.exercise.intensityStatus == IntensityStatus.peak) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
                                        ),
                                        child: Text("PEAK", style: TextStyle(color: const Color(0xFFF43F5E), fontSize: 8, fontWeight: FontWeight.w900)),
                                      ),
                                    ] else if (widget.exercise.intensityStatus == IntensityStatus.hard) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                        ),
                                        child: Text("HARD", style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 8, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                    if (widget.exercise.targetWeight != null && widget.exercise.targetWeight! > 0) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Text("•", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                      ),
                                      Text(
                                        "${widget.exercise.targetWeight}kg",
                                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                    if (widget.exercise.rpe != null) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Text("•", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                      ),
                                      Text(
                                        "RPE ${widget.exercise.rpe}",
                                        style: const TextStyle(color: Color(0xFFF1C40E), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                    if (widget.exercise.tempoEccentric != null) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Text("•", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                      ),
                                      Text(
                                        "${widget.exercise.tempoEccentric}/${widget.exercise.tempoPause}/${widget.exercise.tempoConcentric}",
                                        style: const TextStyle(color: Color(0xFF3498DB), fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(sessionProgressProvider.notifier)
                        .completeExerciseSet(widget.exercise.exerciseId);
                  },
                  child: trailingIcon,
                ),
              ),
            ],
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 16),
                  Center(
                    child: _buildExerciseMedia(widget.exercise.videoUrl),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        "MUSCLES",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.exercise.targetMuscles.map((m) => m.name.toUpperCase()).join(', '),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "HOW TO DO IT",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.exercise.instructions != null && widget.exercise.instructions!.isNotEmpty
                        ? widget.exercise.instructions!
                        : "Maintain proper form and control throughout the movement. Focus on the mind-muscle connection.",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (widget.exercise.progressionNote != null && widget.exercise.progressionNote!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "TRAINER NOTES",
                      style: TextStyle(
                        color: AppTokens.colorBrand,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.exercise.progressionNote!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    "SETS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...widget.exercise.sets.map((set) => _buildSetRowForInteractive(set)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getExerciseIcon(List<MuscleGroup> muscles) {
    if (muscles.isEmpty) return Icons.fitness_center;
    final primary = muscles.first;
    switch (primary) {
      case MuscleGroup.chest:
        return Icons.fitness_center;
      case MuscleGroup.back:
        return Icons.format_align_justify;
      case MuscleGroup.shoulders:
        return Icons.architecture;
      case MuscleGroup.biceps:
      case MuscleGroup.triceps:
      case MuscleGroup.forearms:
        return Icons.handyman;
      case MuscleGroup.quads:
      case MuscleGroup.hamstrings:
      case MuscleGroup.glutes:
      case MuscleGroup.calves:
        return Icons.directions_run;
      case MuscleGroup.abs:
      case MuscleGroup.obliques:
        return Icons.vibration;
      default:
        return Icons.fitness_center;
    }
  }

  Widget _buildExerciseMedia(String? videoUrl) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: videoUrl != null && videoUrl.isNotEmpty
            ? Image.network(
                videoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildMediaPlaceholder(),
              )
            : _buildMediaPlaceholder(),
      ),
    );
  }

  Widget _buildMediaPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, color: Colors.white24, size: 40),
          SizedBox(height: 8),
          Text(
            "Recommended: 1280x720 pixels (16:9)",
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRowForInteractive(ExerciseSetEntity set) {
    // Determine if this set is already completed based on completedSets counter
    final isSetCompleted = set.setNumber <= widget.exercise.completedSets;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSetCompleted
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color:
                    isSetCompleted ? const Color(0xFF2ECC71) : Colors.white24,
              ),
            ),
            child: Center(
              child: isSetCompleted
                  ? const Icon(Icons.check, size: 14, color: Color(0xFF2ECC71))
                  : Text(
                      '${set.setNumber}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            set.targetSeconds != null && set.targetSeconds! > 0
                ? '${set.targetSeconds}s hold'
                : '${set.targetReps} reps',
            style: TextStyle(
              color: isSetCompleted ? Colors.white54 : Colors.white,
              fontSize: 13,
              decoration: isSetCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const Spacer(),
          if (set.restSeconds > 0)
            Text(
              '${set.restSeconds}s rest',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildSetIndicator(
      SetStatus status, Color accentColor, int currentSet) {
    Widget child;
    Color bgColor;

    switch (status) {
      case SetStatus.notStarted:
        return Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24)),
          child: const Icon(Icons.radio_button_unchecked,
              color: Colors.white54, size: 24),
        );
      case SetStatus.stage1:
      case SetStatus.stage2:
      case SetStatus.stage3:
        child = Text("$currentSet",
            style: TextStyle(
                color: status == SetStatus.stage1 ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16));
        bgColor = accentColor;
        break;
      case SetStatus.completed:
        child = const Icon(Icons.check, color: Colors.black, size: 24);
        bgColor = accentColor;
        break;
    }

    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          boxShadow: [
            BoxShadow(color: bgColor.withValues(alpha: 0.4), blurRadius: 15)
          ]),
      child: Center(child: child),
    );
  }
}

class RealExercisePill extends ConsumerStatefulWidget {
  final PlannedExerciseEntity exercise;
  final DateTime date;

  const RealExercisePill({
    super.key,
    required this.exercise,
    required this.date,
  });

  @override
  ConsumerState<RealExercisePill> createState() => _RealExercisePillState();
}

class _RealExercisePillState extends ConsumerState<RealExercisePill> {
  bool _isExpanded = false;

  void _onIncrementSet(PlannedExerciseEntity exercise) {
    // Update in-memory session state first for immediate UI feedback
    ref.read(sessionProgressProvider.notifier).completeExerciseSet(
      exercise.id,
      isTrainerPlan: true,
    );
    // Persist to Hive so completion survives app restarts
    ref.read(workoutPlanStorageProvider).incrementPlannedSetCompletion(
      date: widget.date,
      exerciseId: exercise.id,
    );
  }

  void _onMarkAllComplete(PlannedExerciseEntity exercise) {
    // Update in-memory state
    ref.read(sessionProgressProvider.notifier).markExerciseComplete(
      exercise.id,
      isTrainerPlan: true,
    );
    // Persist to Hive and invalidate the saved plan provider so WorkoutPage rebuilds
    ref.read(workoutPlanStorageProvider).markAllSetsComplete(
      date: widget.date,
      exerciseId: exercise.id,
    ).then((_) => ref.invalidate(savedWorkoutPlanProvider));
  }

  IconData _getExerciseIcon(MuscleGroup muscle) {
    switch (muscle) {
      case MuscleGroup.chest:
        return Icons.fitness_center;
      case MuscleGroup.back:
        return Icons.accessibility_new;
      case MuscleGroup.shoulders:
        return Icons.accessibility;
      case MuscleGroup.biceps:
      case MuscleGroup.triceps:
      case MuscleGroup.forearms:
        return Icons.sports_martial_arts;
      case MuscleGroup.quads:
      case MuscleGroup.hamstrings:
      case MuscleGroup.glutes:
      case MuscleGroup.calves:
        return Icons.directions_walk;
      case MuscleGroup.abs:
      case MuscleGroup.obliques:
        return Icons.sports_gymnastics;
      case MuscleGroup.traps:
      case MuscleGroup.neck:
        return Icons.accessibility_new;
      case MuscleGroup.adductors:
        return Icons.directions_walk;
      case MuscleGroup.fullBody:
        return Icons.sports;
      case MuscleGroup.cardio:
        return Icons.directions_run;
    }
  }

  String _getExerciseInstructions(PlannedExerciseEntity exercise) {
    if (exercise.instructions != null && exercise.instructions!.isNotEmpty) {
      return exercise.instructions!;
    }
    return '1. Maintain proper form throughout\n2. Control the movement\n3. Breathe steadily\n4. Rest as needed between sets';
  }

  Widget _buildExerciseMedia(String? url) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildMediaPlaceholder(),
              )
            : _buildMediaPlaceholder(),
      ),
    );
  }

  Widget _buildMediaPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, color: Colors.white24, size: 40),
          SizedBox(height: 8),
          Text(
            "Recommended: 1280x720 pixels (16:9)",
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(ExerciseSetEntity set, PlannedExerciseEntity exercise) {
    final isSetCompleted = set.isCompleted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSetCompleted
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color:
                    isSetCompleted ? const Color(0xFF2ECC71) : Colors.white24,
              ),
            ),
            child: Center(
              child: isSetCompleted
                  ? const Icon(Icons.check, size: 14, color: Color(0xFF2ECC71))
                  : Text(
                      '${set.setNumber}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            set.targetSeconds != null && set.targetSeconds! > 0
                ? '${set.targetSeconds}s hold'
                : '${set.targetReps} reps',
            style: TextStyle(
              color: isSetCompleted ? Colors.white54 : Colors.white,
              fontSize: 13,
              decoration: isSetCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const Spacer(),
          if (set.restSeconds > 0)
            Text(
              '${set.restSeconds}s rest',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = widget.date.year == today.year && 
                    widget.date.month == today.month && 
                    widget.date.day == today.day;

    final isCompleted = widget.exercise.isCompleted;
    final completedSets = widget.exercise.sets.where((s) => s.isCompleted).length;
    final totalSets = widget.exercise.sets.length;

    Color accentColor;
    String statusText;
    Widget trailingIcon;

    if (isCompleted) {
      accentColor = const Color(0xFF2ECC71);
      statusText = "$totalSets/$totalSets Sets";
      trailingIcon = GestureDetector(
        onTap: () => _onIncrementSet(widget.exercise),
        onLongPress: () => _onMarkAllComplete(widget.exercise),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: const Icon(Icons.check, color: Colors.black, size: 24),
        ),
      );
    } else if (completedSets > 0) {
      accentColor = const Color(0xFF3498DB); 
      statusText = "$completedSets/$totalSets Sets";
      trailingIcon = GestureDetector(
        onTap: () => _onIncrementSet(widget.exercise),
        onLongPress: () => _onMarkAllComplete(widget.exercise),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: Center(
            child: Text(
              "$completedSets",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    } else {
      accentColor = Colors.white54;
      statusText = "$totalSets Sets";
      trailingIcon = GestureDetector(
        onTap: () => _onIncrementSet(widget.exercise),
        onLongPress: () => _onMarkAllComplete(widget.exercise),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(
            Icons.radio_button_unchecked,
            color: Colors.white54,
            size: 24,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isToday ? AppTokens.colorBgSurface : AppTokens.colorBgPrimary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF2ECC71).withValues(alpha: 0.4)
              : widget.exercise.rpe != null && widget.exercise.rpe! >= 7
                  ? (widget.exercise.rpe! >= 9 ? const Color(0xFFF43F5E) : const Color(0xFFF59E0B)).withValues(alpha: 0.4)
                  : isToday 
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.03),
          width: widget.exercise.rpe != null && widget.exercise.rpe! >= 7 ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (completedSets > 0 && isToday)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
          if (widget.exercise.rpe != null && widget.exercise.rpe! >= 7)
            BoxShadow(
              color: (widget.exercise.rpe! >= 9 ? const Color(0xFFF43F5E) : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Opacity(
        opacity: isToday ? 1.0 : 0.6,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
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
                            child: Icon(
                              _getExerciseIcon(widget.exercise.targetMuscles.isNotEmpty
                                  ? widget.exercise.targetMuscles.first
                                  : MuscleGroup.fullBody),
                              color: isCompleted ? Colors.white : Colors.white54,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.exercise.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isToday ? Colors.white : Colors.white70,
                                        ),
                                      ),
                                    ),
                                    if (!isToday) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'LOCKED',
                                          style: TextStyle(
                                            color: Colors.white24,
                                            fontSize: 7,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Icon(
                                        _isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                    ),
                                    if (widget.exercise.isSwapped)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTokens.colorBrand.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          "SWAPPED",
                                          style: TextStyle(
                                            color: AppTokens.colorBrand,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: isToday ? accentColor : Colors.white38,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Text("•", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                    ),
                                    Text(
                                      widget.exercise.repsDisplay,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    if (widget.exercise.rpe != null && widget.exercise.rpe! > 0) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Text("•", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                      ),
                                      Text(
                                        "RPE ${widget.exercise.rpe}",
                                        style: TextStyle(
                                          color: widget.exercise.rpe! >= 9 ? const Color(0xFFF43F5E) : const Color(0xFFF59E0B), 
                                          fontSize: 12, 
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ],
                                    if (widget.exercise.tempoEccentric != null && widget.exercise.tempoEccentric! > 0) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Text("•", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                      ),
                                      Text(
                                        "${widget.exercise.tempoEccentric}/${widget.exercise.tempoPause}/${widget.exercise.tempoConcentric}",
                                        style: const TextStyle(color: Color(0xFF3498DB), fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: trailingIcon,
                ),
              ],
            ),
            if (_isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 16),
                    Center(
                      child: _buildExerciseMedia(widget.exercise.videoUrl),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          "MUSCLES",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.exercise.targetMuscles.map((m) => m.name).join(', '),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "HOW TO DO IT",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getExerciseInstructions(widget.exercise),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (widget.exercise.progressionNote != null && widget.exercise.progressionNote!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "COACH TIPS",
                        style: TextStyle(
                          color: AppTokens.colorBrand,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.exercise.progressionNote!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      "SETS",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...widget.exercise.sets.map((set) => _buildSetRow(set, widget.exercise)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
