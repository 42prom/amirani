import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';

/// Amber left-border error container with icon, message, and optional retry.
///
/// ```dart
/// AppErrorBanner(
///   message: 'Failed to load announcements',
///   retryLabel: 'Retry',
///   onRetry: () { ref.invalidate(announcementsProvider); },
/// )
/// ```
class AppErrorBanner extends StatelessWidget {
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const AppErrorBanner({
    super.key,
    required this.message,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: Colors.red.shade400, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.87),
                fontSize: 13,
              ),
            ),
          ),
          if (retryLabel != null && onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                retryLabel!,
                style: const TextStyle(
                  color: AppTheme.primaryBrand,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
