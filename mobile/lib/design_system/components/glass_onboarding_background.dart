import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../tokens/app_tokens.dart';

class GlassOnboardingBackground extends StatelessWidget {
  final Widget child;

  const GlassOnboardingBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Gradient
        Container(
          decoration: BoxDecoration(
            gradient: AppTokens.gradientBackground,
          ),
        ),

        // 2. Animated Accent Circles (Deep behind)
        Positioned(
          top: -100,
          right: -50,
          child: _BlurredCircle(
            color: AppTokens.colorBrand.withValues(alpha: 0.15),
            size: 300,
            duration: 10.seconds,
          ),
        ),
        Positioned(
          bottom: 100,
          left: -100,
          child: _BlurredCircle(
            color: AppTokens.colorInfo.withValues(alpha: 0.1),
            size: 400,
            duration: 15.seconds,
          ),
        ),
        Positioned(
          top: 200,
          left: 50,
          child: _BlurredCircle(
            color: AppTokens.colorScoreSleep.withValues(alpha: 0.08),
            size: 250,
            duration: 12.seconds,
          ),
        ),

        // 3. The Content
        child,
      ],
    );
  }
}

class _BlurredCircle extends StatelessWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _BlurredCircle({
    required this.color,
    required this.size,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .move(
          begin: const Offset(-20, -20),
          end: const Offset(20, 20),
          duration: duration,
          curve: Curves.easeInOut,
        )
        .blur(
          begin: const Offset(50, 50),
          end: const Offset(80, 80),
        );
  }
}
