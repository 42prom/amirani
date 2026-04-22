import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';

/// Consistent loading spinner. Always uses [AppTheme.primaryBrand] amber color.
///
/// - Standard (24px): use inside full-screen loaders, card centers
/// - Inline (16px): use inside buttons or small containers
///
/// ```dart
/// const AppSpinner()           // 24px
/// const AppSpinner.inline()    // 16px
/// AppSpinner(size: 32)         // custom
/// ```
class AppSpinner extends StatelessWidget {
  final double size;

  const AppSpinner({super.key, this.size = 24});
  const AppSpinner.inline({super.key}) : size = 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: size <= 16 ? 2.0 : 2.5,
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBrand),
      ),
    );
  }
}
