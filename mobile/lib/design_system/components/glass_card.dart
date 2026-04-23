import 'dart:ui';
import 'package:flutter/material.dart';
import '../tokens/app_tokens.dart';

/// Standard glass-morphism card used throughout the Amirani UI.
///
/// Usage:
/// ```dart
/// GlassCard(
///   child: Text('Hello'),
/// )
/// ```
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.borderColor,
    this.backgroundColor,
    this.shadows,
    this.onTap,
    this.width,
    this.height,
    this.gradientGlass,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Gradient? gradientGlass;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(AppTokens.radius24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppTokens.blurStandard,
          sigmaY: AppTokens.blurStandard,
        ),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            gradient: gradientGlass ?? AppTokens.gradientGlass,
            borderRadius:
                borderRadius ?? BorderRadius.circular(AppTokens.radius24),
            border: Border.all(
              color: borderColor ??
                  Colors.white.withValues(alpha: AppTokens.glassBorderOpacity),
              width: 1.5,
            ),
            boxShadow: shadows ?? AppTokens.shadowCard,
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTokens.space24),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }
}

/// A slimmer variant with less padding, suitable for list items.
class GlassCardCompact extends StatelessWidget {
  const GlassCardCompact({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space12,
          ),
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      onTap: onTap,
      child: child,
    );
  }
}
