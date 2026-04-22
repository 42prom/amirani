import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../config/app_config.dart';

/// Displays a user avatar from either a local file path or a remote URL,
/// with an initials/icon fallback. Handles the profileImagePath field from
/// ProfileSyncState which may hold either type.
class UserAvatar extends StatelessWidget {
  final String? imagePath; // local file path OR remote URL
  final String? displayName;
  final double size;
  final Widget? badge; // e.g. online dot

  const UserAvatar({
    super.key,
    this.imagePath,
    this.displayName,
    this.size = 40,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _buildCircle(),
          if (badge != null) Positioned(bottom: 0, right: 0, child: badge!),
        ],
      ),
    );
  }

  Widget _buildCircle() {
    final path = imagePath;
    if (path != null && path.isNotEmpty) {
      final resolvedUrl = path.startsWith('http')
          ? path
          : AppConfig.resolveMediaUrl(path);

      if (resolvedUrl != null) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolvedUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => _fallback(),
            errorWidget: (_, __, ___) => _localOrFallback(path),
          ),
        );
      }

      // Local file path
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _localOrFallback(String path) {
    if (path.startsWith('http')) return _fallback();
    return ClipOval(
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final initials = _initials();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surfaceDark,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: initials != null
            ? Text(
                initials,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: size * 0.35,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Icon(Icons.person, color: Colors.white54, size: size * 0.55),
      ),
    );
  }

  String? _initials() {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return null;
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}
