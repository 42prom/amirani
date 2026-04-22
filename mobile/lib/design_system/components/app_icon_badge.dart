import 'package:flutter/material.dart';
import '../tokens/app_tokens.dart';

/// Circular icon badge — used for section headers, empty states, and highlights.
///
/// ```dart
/// AppIconBadge(
///   icon: Icons.fitness_center,
///   color: AppTokens.colorBrand,
/// )
/// AppIconBadge.large(icon: Icons.lock_outline)
/// ```
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.size = 48,
    this.iconSize = 22,
  });

  const AppIconBadge.large({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
  })  : size = 72,
        iconSize = 32;

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppTokens.colorBrand;
    final bg = backgroundColor ?? fg.withValues(alpha: 0.12);
    final border = fg.withValues(alpha: 0.35);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Icon(icon, color: fg, size: iconSize),
    );
  }
}

/// Status chip — colored tag for subscription status, role badges, etc.
///
/// ```dart
/// StatusChip(label: 'Active', color: AppTokens.colorSuccess)
/// StatusChip(label: 'Expired', color: AppTokens.colorError)
/// ```
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space10,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: AppTokens.space4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Divider with optional label — for section separators.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Divider(
        color: AppTokens.colorBorderSubtle,
        height: AppTokens.space24,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppTokens.colorBorderSubtle)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space12),
            child: Text(label!, style: AppTokens.textCaption),
          ),
          Expanded(child: Divider(color: AppTokens.colorBorderSubtle)),
        ],
      ),
    );
  }
}
