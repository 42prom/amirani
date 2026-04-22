import 'package:flutter/material.dart';
import '../tokens/app_tokens.dart';

/// Single behavioral score ring — animated circular progress with label.
///
/// ```dart
/// ScoreRing(
///   score: 0.78,
///   label: 'Workout',
///   color: AppTokens.colorScoreWorkout,
/// )
/// ```
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.label,
    required this.color,
    this.size = 72,
    this.strokeWidth = 5,
    this.showPercent = true,
  });

  /// Value between 0.0 and 1.0
  final double score;
  final String label;
  final Color color;
  final double size;
  final double strokeWidth;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final pct = (score.clamp(0.0, 1.0) * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score.clamp(0.0, 1.0)),
            duration: AppTokens.animChart,
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: strokeWidth,
                      backgroundColor:
                          AppTokens.colorBorderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  if (showPercent)
                    Text(
                      '$pct',
                      style: TextStyle(
                        color: AppTokens.colorTextPrimary,
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppTokens.space6),
        SizedBox(
          width: size,
          child: Text(
            label,
            style: AppTokens.textLabelSm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Four-ring cluster — the behavioral dashboard widget.
///
/// ```dart
/// ScoreRingCluster(
///   workoutScore: 0.80,
///   dietScore: 0.65,
///   hydrationScore: 0.90,
///   sleepScore: 0.55,
/// )
/// ```
class ScoreRingCluster extends StatelessWidget {
  const ScoreRingCluster({
    super.key,
    required this.workoutScore,
    required this.dietScore,
    required this.hydrationScore,
    required this.sleepScore,
    this.ringSize = 72,
  });

  final double workoutScore;
  final double dietScore;
  final double hydrationScore;
  final double sleepScore;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ScoreRing(
          score: workoutScore,
          label: 'Workout',
          color: AppTokens.colorScoreWorkout,
          size: ringSize,
        ),
        ScoreRing(
          score: dietScore,
          label: 'Diet',
          color: AppTokens.colorScoreDiet,
          size: ringSize,
        ),
        ScoreRing(
          score: hydrationScore,
          label: 'Hydration',
          color: AppTokens.colorScoreHydration,
          size: ringSize,
        ),
        ScoreRing(
          score: sleepScore,
          label: 'Sleep',
          color: AppTokens.colorScoreSleep,
          size: ringSize,
        ),
      ],
    );
  }
}
