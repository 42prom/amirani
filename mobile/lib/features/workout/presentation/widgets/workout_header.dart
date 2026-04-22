import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amirani_app/theme/app_theme.dart';
import 'package:amirani_app/core/widgets/user_avatar.dart';
import '../../../profile/presentation/widgets/profile_settings_modal.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';

class WorkoutHeader extends ConsumerWidget {
  const WorkoutHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileSync = ref.watch(profileSyncProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => ProfileSettingsModal.show(context),
                child: UserAvatar(
                  imagePath: profileSync.profileImagePath,
                  displayName: profileSync.fullName,
                  size: 40,
                  badge: Container(
                    height: 12,
                    width: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryBrand,
                      border: Border.all(color: AppTheme.backgroundDark, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hello,',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500)),
                  Text(
                      profileSync.firstName.isNotEmpty
                          ? profileSync.firstName
                          : (profileSync.fullName.isNotEmpty
                              ? profileSync.fullName.split(' ')[0]
                              : 'Your Name'),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ],
          ),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceDark.withValues(alpha: 0.5),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Icon(Icons.light_mode, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }
}
