import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Attribution pill shown on workout and diet plan cards.
/// Exactly one badge is shown per card — AI or trainer, never both.
///
/// ```dart
/// PlanSourceBadge.ai()
/// PlanSourceBadge.trainer(name: 'Ahmed Karimi')
/// ```
class PlanSourceBadge extends StatelessWidget {
  final bool _isAI;
  final String? _trainerName;

  const PlanSourceBadge.ai({super.key})
      : _isAI = true,
        _trainerName = null;

  const PlanSourceBadge.trainer({super.key, required String name})
      : _isAI = false,
        _trainerName = name;

  /// Returns null if neither condition applies — caller should skip rendering.
  static PlanSourceBadge? fromPlan({
    required bool isAIGenerated,
    String? trainerName,
  }) {
    if (isAIGenerated) return const PlanSourceBadge.ai();
    if (trainerName != null && trainerName.isNotEmpty) {
      return PlanSourceBadge.trainer(name: trainerName);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final label = _isAI ? '🤖  AI Generated' : '👤  From: $_trainerName';
    final color = _isAI ? AppTheme.primaryBrand : AppTheme.primaryBrand;
    final bg = _isAI
        ? AppTheme.primaryBrand.withValues(alpha: 0.15)
        : AppTheme.primaryBrand.withValues(alpha: 0.10);
    final border = _isAI
        ? AppTheme.primaryBrand.withValues(alpha: 0.35)
        : AppTheme.primaryBrand.withValues(alpha: 0.25);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
