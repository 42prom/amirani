import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../../../../core/providers/points_provider.dart';
import 'package:amirani_app/core/localization/l10n_keys.dart';
import '../providers/active_workout_session_provider.dart';

class ActiveWorkoutSessionPage extends ConsumerStatefulWidget {
  const ActiveWorkoutSessionPage({super.key});

  @override
  ConsumerState<ActiveWorkoutSessionPage> createState() =>
      _ActiveWorkoutSessionPageState();
}

class _ActiveWorkoutSessionPageState
    extends ConsumerState<ActiveWorkoutSessionPage> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  int _selectedRpe = 7;

  @override
  void initState() {
    super.initState();
    _resetInputs();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _resetInputs() {
    final session = ref.read(activeWorkoutSessionProvider);
    if (session == null) return;

    final ex = session.currentExercise;
    if (ex == null) return;

    // Pre-fill with last logged set values if available
    if (ex.loggedSets.isNotEmpty) {
      final last = ex.loggedSets.last;
      _weightController.text = last.weightKg.toString();
      _repsController.text = last.reps.toString();
      _selectedRpe = last.rpe ?? 7;
    } else {
      _weightController.text = '0';
      _repsController.text = ex.entity.targetReps.toString();
      _selectedRpe = 7;
    }
  }

  void _logSet() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;

    if (weight < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight cannot be negative')),
      );
      return;
    }

    if (reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter reps to log this set')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(activeWorkoutSessionProvider.notifier).logSet(
          weightKg: weight,
          reps: reps,
          rpe: _selectedRpe,
        );

    setState(() => _selectedRpe = 7);
  }

  Future<bool> _confirmQuit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.colorBgSurface,
        title: const Text('Quit Workout?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your progress for this session will be lost.',
          style: TextStyle(color: AppTokens.colorTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Going',
                style: TextStyle(color: AppTokens.colorTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ref.read(activeWorkoutSessionProvider.notifier).abandonWorkout();
              Navigator.pop(ctx, true);
            },
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    return result ?? false;
  }


  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeWorkoutSessionProvider);

    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('No active session')),
      );
    }

    if (session.phase == WorkoutPhase.completed) {
      return _WorkoutCompletedScreen(session: session);
    }

    if (session.phase == WorkoutPhase.resting) {
      return _RestTimerScreen(
        session: session,
        onSkip: () {
          ref.read(activeWorkoutSessionProvider.notifier).skipRest();
        },
      );
    }

    final exercise = session.currentExercise;
    if (exercise == null) {
      return const Scaffold(
          body: Center(child: Text('No exercise found')));
    }

    final completedSets = exercise.loggedSets.length;
    final totalSets = exercise.entity.targetSets;
    final setsLeft = totalSets - completedSets;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final navigator = Navigator.of(context);
          final quit = await _confirmQuit();
          if (quit && mounted) navigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white60),
          onPressed: () async {
            final navigator = Navigator.of(context);
            final quit = await _confirmQuit();
            if (quit && mounted) navigator.pop();
          },
        ),
        title: Text(
          session.routineName,
          style: const TextStyle(
              color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        actions: [
          _ElapsedTimer(startedAt: session.startedAt),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar ──────────────────────────────────────────────
          _SessionProgressBar(session: session),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Exercise name & index ─────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTokens.colorBrand.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${session.currentExerciseIndex + 1}',
                            style: const TextStyle(
                              color: AppTokens.colorBrand,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.entity.exerciseName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Target: $totalSets × ${exercise.entity.targetReps} reps  •  Rest: ${exercise.entity.restSeconds}s',
                              style: const TextStyle(
                                  color: AppTokens.colorTextSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Set indicators ─────────────────────────────────────
                  _SetIndicators(
                    totalSets: totalSets,
                    completedSets: completedSets,
                    loggedSets: exercise.loggedSets,
                  ),

                  const SizedBox(height: 28),

                  // ── Input fields ───────────────────────────────────────
                  if (setsLeft > 0) ...[
                    Text(
                      'Log Set ${completedSets + 1} of $totalSets',
                      style: const TextStyle(
                        color: AppTokens.colorTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InputField(
                            controller: _weightController,
                            label: 'Weight (kg)',
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InputField(
                            controller: _repsController,
                            label: L10n.workoutReps,
                            hint: exercise.entity.targetReps.toString(),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── RPE selector ────────────────────────────────────
                    _RpeSelector(
                      value: _selectedRpe,
                      onChanged: (v) => setState(() => _selectedRpe = v),
                    ),

                    const SizedBox(height: 24),

                    // ── Log set button ──────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.colorBrand,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _logSet,
                        child: Text(
                          setsLeft == 1 ? 'LOG FINAL SET' : 'LOG SET',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (setsLeft == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF2ECC71).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Color(0xFF2ECC71), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'All sets completed!',
                            style: TextStyle(
                              color: Color(0xFF2ECC71),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: session.isLastExercise
                              ? AppTokens.colorBrand
                              : Colors.white12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          ref
                              .read(activeWorkoutSessionProvider.notifier)
                              .nextExercise();
                          _resetInputs();
                        },
                        child: Text(
                          session.isLastExercise
                              ? 'FINISH WORKOUT'
                              : 'NEXT EXERCISE',
                          style: TextStyle(
                            color: session.isLastExercise
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Skip exercise ───────────────────────────────────────
                  if (!session.isLastExercise && setsLeft > 0)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(activeWorkoutSessionProvider.notifier)
                            .skipExercise();
                        _resetInputs();
                      },
                      child: const Text(
                        'Skip Exercise',
                        style:
                            TextStyle(color: AppTokens.colorTextSecondary, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // ── Upcoming exercises ──────────────────────────────────
                  if (session.exercises.length > 1)
                    _UpcomingExercises(session: session),
                ],
              ),
            ),
          ),
        ],
      ),
    )); // closes Scaffold + PopScope
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SessionProgressBar extends StatelessWidget {
  final ActiveWorkoutSessionState session;
  const _SessionProgressBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final total = session.exercises.length;
    final done = session.completedExerciseCount;
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      height: 4,
      color: Colors.white12,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(color: AppTokens.colorBrand),
      ),
    );
  }
}

class _ElapsedTimer extends StatefulWidget {
  final DateTime startedAt;
  const _ElapsedTimer({required this.startedAt});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  late final timer = Stream.periodic(const Duration(seconds: 1));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: timer,
      builder: (_, __) {
        final elapsed = DateTime.now().difference(widget.startedAt);
        final m = elapsed.inMinutes.toString().padLeft(2, '0');
        final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return Text(
          '$m:$s',
          style: const TextStyle(
            color: AppTokens.colorTextSecondary,
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}

class _SetIndicators extends StatelessWidget {
  final int totalSets;
  final int completedSets;
  final List<LoggedSet> loggedSets;

  const _SetIndicators({
    required this.totalSets,
    required this.completedSets,
    required this.loggedSets,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSets, (i) {
        final isDone = i < completedSets;
        final set = isDone ? loggedSets[i] : null;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < totalSets - 1 ? 8 : 0),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF2ECC71).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDone
                      ? const Color(0xFF2ECC71).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SET ${i + 1}',
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF2ECC71)
                          : Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isDone && set != null) ...[
                    Text(
                      '${set.weightKg.toStringAsFixed(set.weightKg % 1 == 0 ? 0 : 1)}kg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${set.reps} reps',
                      style: const TextStyle(
                        color: AppTokens.colorTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ] else
                    const Icon(Icons.remove, color: Colors.white24, size: 16),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTokens.colorTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Colors.white24, fontSize: 22),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: AppTokens.colorBrand, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          ),
        ),
      ],
    );
  }
}

class _RpeSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RpeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RPE (Effort Level)',
              style: TextStyle(
                color: AppTokens.colorTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            Text(
              '$value/10  ${_rpeLabel(value)}',
              style: const TextStyle(
                color: AppTokens.colorBrand,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(10, (i) {
            final rpe = i + 1;
            final isSelected = rpe == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(rpe),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: i < 9 ? 4 : 0),
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _rpeColor(rpe).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? _rpeColor(rpe)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$rpe',
                      style: TextStyle(
                        color: isSelected ? _rpeColor(rpe) : Colors.white38,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _rpeLabel(int rpe) {
    if (rpe <= 3) return '😴 Easy';
    if (rpe <= 5) return '😊 Moderate';
    if (rpe <= 7) return '💪 Hard';
    if (rpe <= 9) return '🔥 Very Hard';
    return '💀 Max';
  }

  Color _rpeColor(int rpe) {
    if (rpe <= 3) return const Color(0xFF2ECC71);
    if (rpe <= 5) return const Color(0xFFF39C12);
    if (rpe <= 7) return const Color(0xFFE67E22);
    if (rpe <= 9) return const Color(0xFFE74C3C);
    return const Color(0xFF8E44AD);
  }
}

class _UpcomingExercises extends StatelessWidget {
  final ActiveWorkoutSessionState session;
  const _UpcomingExercises({required this.session});

  @override
  Widget build(BuildContext context) {
    final upcoming = session.exercises
        .asMap()
        .entries
        .where((e) => e.key > session.currentExerciseIndex)
        .take(3)
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'UP NEXT',
          style: TextStyle(
            color: AppTokens.colorTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        ...upcoming.map((entry) {
          final idx = entry.key;
          final ex = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ex.entity.exerciseName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${ex.entity.targetSets}×${ex.entity.targetReps}',
                    style: const TextStyle(
                      color: AppTokens.colorTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Rest Timer Screen ────────────────────────────────────────────────────────

class _RestTimerScreen extends StatelessWidget {
  final ActiveWorkoutSessionState session;
  final VoidCallback onSkip;

  const _RestTimerScreen({required this.session, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final progress = session.restSecondsTotal > 0
        ? session.restSecondsLeft / session.restSecondsTotal
        : 0.0;

    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'REST',
                style: TextStyle(
                  color: AppTokens.colorTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTokens.colorBrand),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${session.restSecondsLeft}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        const Text(
                          'seconds',
                          style: TextStyle(
                            color: AppTokens.colorTextSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              if (session.currentExercise != null) ...[
                const Text(
                  'NEXT SET',
                  style: TextStyle(
                    color: AppTokens.colorTextSecondary,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session.currentExercise!.entity.exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set ${session.currentExercise!.loggedSets.length + 1} of ${session.currentExercise!.entity.targetSets}',
                  style: const TextStyle(
                      color: AppTokens.colorTextSecondary, fontSize: 14),
                ),
              ],
              const SizedBox(height: 48),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppTokens.colorBrand, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onSkip,
                child: const Text(
                  'Skip Rest',
                  style: TextStyle(
                      color: AppTokens.colorBrand,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Completion Screen ────────────────────────────────────────────────────────

class _WorkoutCompletedScreen extends ConsumerStatefulWidget {
  final ActiveWorkoutSessionState session;
  const _WorkoutCompletedScreen({required this.session});

  @override
  ConsumerState<_WorkoutCompletedScreen> createState() =>
      _WorkoutCompletedScreenState();
}

class _WorkoutCompletedScreenState
    extends ConsumerState<_WorkoutCompletedScreen> {
  @override
  Widget build(BuildContext context) {
    final duration = widget.session.completedAt != null
        ? widget.session.completedAt!.difference(widget.session.startedAt)
        : DateTime.now().difference(widget.session.startedAt);

    final totalSets = widget.session.exercises
        .fold(0, (sum, e) => sum + e.loggedSets.length);
    final totalVolume = widget.session.exercises.fold(
        0.0,
        (sum, e) => sum +
            e.loggedSets.fold(
                0.0, (s2, ls) => s2 + (ls.weightKg * ls.reps)));

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events,
                  color: AppTokens.colorBrand, size: 64),
              const SizedBox(height: 20),
              const Text(
                'WORKOUT COMPLETE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.session.routineName,
                style: const TextStyle(
                    color: AppTokens.colorTextSecondary, fontSize: 15),
              ),
              const SizedBox(height: 48),

              // ── Stats grid ──────────────────────────────────────────────
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
                  ),
                  _StatCard(
                    icon: Icons.fitness_center,
                    label: 'Exercises',
                    value: '${widget.session.exercises.length}',
                  ),
                  _StatCard(
                    icon: Icons.repeat,
                    label: 'Total Sets',
                    value: '$totalSets',
                  ),
                  _StatCard(
                    icon: Icons.trending_up,
                    label: 'Volume',
                    value: '${totalVolume.toStringAsFixed(0)} kg',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Points earned banner
              Builder(builder: (context) {
                final pts = ref.watch(pointsProvider);
                final earned = pts.lastAwardedPoints;
                if (earned == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTokens.colorBrand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTokens.colorBrand.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt,
                          color: AppTokens.colorBrand, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '+$earned pts  •  Total: ${pts.totalPoints}',
                        style: const TextStyle(
                          color: AppTokens.colorBrand,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.colorBrand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    ref
                        .read(activeWorkoutSessionProvider.notifier)
                        .reset();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2,
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
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTokens.colorBrand, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
                color: AppTokens.colorTextSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
