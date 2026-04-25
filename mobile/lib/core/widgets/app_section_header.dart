import 'package:flutter/material.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';

/// Section title row with an optional amber trailing action.
///
/// ```dart
/// AppSectionHeader(
///   title: 'Announcements',
///   actionLabel: 'See all',
///   onAction: () { ... },
/// )
/// ```
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: AppTokens.colorBrand,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
