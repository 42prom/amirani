import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';

class AppNotifications {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF2ECC71),
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.error_outline,
      iconColor: const Color(0xFFE74C3C),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.info_outline,
      iconColor: AppTheme.primaryBrand,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color iconColor,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A2035), // surfaceDark
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: iconColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
