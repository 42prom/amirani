import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';

enum TrainerAvatarSize { small, medium, large }

/// Circular trainer avatar with fallback initials + name label.
/// Used in gym page, chat page, assignment cards — one component, not three.
///
/// ```dart
/// TrainerAvatarChip(name: 'Ahmed Karimi', avatarUrl: trainer.avatarUrl)
/// TrainerAvatarChip.avatarOnly(name: 'Ahmed Karimi', size: TrainerAvatarSize.large)
/// ```
class TrainerAvatarChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final TrainerAvatarSize size;
  final bool showName;
  final VoidCallback? onTap;

  const TrainerAvatarChip({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = TrainerAvatarSize.medium,
    this.showName = true,
    this.onTap,
  });

  const TrainerAvatarChip.avatarOnly({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = TrainerAvatarSize.medium,
    this.onTap,
  }) : showName = false;

  double get _avatarDiameter => switch (size) {
        TrainerAvatarSize.small => 32,
        TrainerAvatarSize.medium => 40,
        TrainerAvatarSize.large => 56,
      };

  double get _fontSize => switch (size) {
        TrainerAvatarSize.small => 11,
        TrainerAvatarSize.medium => 13,
        TrainerAvatarSize.large => 15,
      };

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar();
    if (!showName) return GestureDetector(onTap: onTap, child: avatar);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: _fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final d = _avatarDiameter;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: d,
          height: d,
          memCacheWidth: (d * 2).toInt(),
          fit: BoxFit.cover,
          placeholder: (_, __) => _fallback(d),
          errorWidget: (_, __, ___) => _fallback(d),
        ),
      );
    }
    return _fallback(d);
  }

  Widget _fallback(double d) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryBrand.withValues(alpha: 0.15),
        border: Border.all(
          color: AppTheme.primaryBrand.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: AppTheme.primaryBrand,
            fontSize: d * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
