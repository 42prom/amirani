import 'package:flutter/material.dart';
import '../tokens/app_tokens.dart';

/// Standard shimmer skeleton loader.
///
/// ```dart
/// ShimmerBox(width: 200, height: 16)        // text skeleton
/// ShimmerBox.rounded(width: 80, height: 80) // avatar
/// ShimmerBox.card(height: 120)              // card skeleton
/// ```
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  const ShimmerBox.rounded({
    super.key,
    required this.width,
    required this.height,
  }) : borderRadius = 999;

  const ShimmerBox.card({
    super.key,
    double? width,
    required this.height,
  })  : width = width ?? double.infinity,
        borderRadius = AppTokens.radius20;

  final double width;
  final double height;
  final double? borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.borderRadius ?? AppTokens.radius8,
            ),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                AppTokens.colorBgSurface,
                AppTokens.colorBgSurfaceAlt,
                AppTokens.colorBgSurface,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built shimmer skeleton for a stat card row (3 cards).
class ShimmerStatRow extends StatelessWidget {
  const ShimmerStatRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : AppTokens.space8,
              right: i == 2 ? 0 : AppTokens.space8,
            ),
            child: const ShimmerBox.card(height: 80),
          ),
        ),
      ),
    );
  }
}

/// Pre-built shimmer skeleton for a list of items.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 4, this.itemHeight = 64});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.space12),
          child: ShimmerBox.card(height: itemHeight),
        ),
      ),
    );
  }
}
