import 'package:flutter/material.dart';
import '../tokens/app_tokens.dart';

enum _ButtonVariant { primary, secondary, danger, ghost }

/// Standard call-to-action button.
///
/// ```dart
/// PrimaryButton(
///   label: 'Start Workout',
///   onPressed: () {},
/// )
/// PrimaryButton.secondary(
///   label: 'Cancel',
///   onPressed: () {},
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 52,
  }) : _variant = _ButtonVariant.primary;

  const PrimaryButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 52,
  }) : _variant = _ButtonVariant.secondary;

  const PrimaryButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 52,
  }) : _variant = _ButtonVariant.danger;

  const PrimaryButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 52,
  }) : _variant = _ButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;
  final _ButtonVariant _variant;

  Color get _bgColor => switch (_variant) {
        _ButtonVariant.primary => AppTokens.colorBrand,
        _ButtonVariant.secondary =>
          AppTokens.colorBgSurface.withValues(alpha: 0.9),
        _ButtonVariant.danger => AppTokens.colorError,
        _ButtonVariant.ghost => Colors.transparent,
      };

  Color get _fgColor => switch (_variant) {
        _ButtonVariant.primary => Colors.black,
        _ButtonVariant.secondary => AppTokens.colorTextPrimary,
        _ButtonVariant.danger => Colors.white,
        _ButtonVariant.ghost => AppTokens.colorBrand,
      };

  Border? get _border => switch (_variant) {
        _ButtonVariant.secondary =>
          Border.all(color: AppTokens.colorBorderMedium),
        _ButtonVariant.ghost =>
          Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.4)),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: AnimatedOpacity(
        duration: AppTokens.animFast,
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          width: width ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(AppTokens.radius16),
            border: _border,
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(_fgColor),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: _fgColor, size: 18),
                          const SizedBox(width: AppTokens.space8),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: _fgColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only circular action button.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ??
              AppTokens.colorBgSurfaceAlt.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: AppTokens.colorBorderSubtle),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: color ?? AppTokens.colorTextSecondary,
        ),
      ),
    );
  }
}
