import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/gym/presentation/providers/membership_provider.dart';
import '../../../features/gym/presentation/providers/sessions_provider.dart';
import '../../design_system/tokens/app_tokens.dart';
import '../localization/l10n_keys.dart';
import '../providers/day_selector_providers.dart';
import 'offline_banner.dart';

class AppNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigationShell({super.key, required this.navigationShell});

  void _onTap(WidgetRef ref, int index) {
    // Reset day selectors when switching tabs to ensure "Today" is always shown first
    if (index == 0) {
      ref.read(workoutDaySelectorProvider.notifier).state = DateTime.now().weekday - 1;
    } else if (index == 1) {
      ref.read(dietDaySelectorProvider.notifier).state = DateTime.now().weekday - 1;
    }

    // Auto-refresh membership + sessions when switching to the Gym tab
    if (index == 3) {
      ref.read(membershipProvider.notifier).fetch();
      ref.read(sessionsProvider.notifier).refresh();
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      body: Stack(
        children: [
          // Push page content above the floating nav bar
          Padding(
            padding: EdgeInsets.only(
              bottom: 64 + MediaQuery.of(context).padding.bottom,
            ),
            child: navigationShell,
          ),
          // Offline connectivity banner — slides in from top when no network
          const Positioned(top: 0, left: 0, right: 0, child: OfflineBanner()),
          // Floating Glass Bottom Nav
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 100, // Explicit height to cover floating button
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Hit-testable area for the background bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.only(
                          top: 4,
                          bottom: MediaQuery.of(context).padding.bottom + 8,
                          left: 24,
                          right: 24),
                      decoration: BoxDecoration(
                        color: AppTokens.colorBgPrimary.withValues(alpha: 0.95),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildNavItem(
                              icon: Icons.calendar_today,
                              label: L10n.navWorkout,
                              isActive: navigationShell.currentIndex == 0,
                              onTap: () => _onTap(ref, 0)),
                          _buildNavItem(
                              icon: Icons.restaurant_menu,
                              label: L10n.navDiet,
                              isActive: navigationShell.currentIndex == 1,
                              onTap: () => _onTap(ref, 1)),

                          const SizedBox(width: 64), // Space for center button

                          _buildNavItem(
                              icon: Icons.fitness_center,
                              label: L10n.navGym,
                              isActive: navigationShell.currentIndex == 3,
                              onTap: () => _onTap(ref, 3)),
                          _buildNavItem(
                              icon: Icons.bar_chart,
                              label: L10n.navDashboard,
                              isActive: navigationShell.currentIndex == 4,
                              onTap: () => _onTap(ref, 4)),
                        ],
                      ),
                    ),
                  ),

                  // Floating Button
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTap(ref, 2),
                      child: Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTokens.colorBgSurface,
                          border: Border.all(
                              color: AppTokens.colorBgPrimary, width: 4),
                          boxShadow: navigationShell.currentIndex == 2
                              ? [
                                  BoxShadow(
                                      color: AppTokens.colorBrand
                                          .withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      spreadRadius: 2),
                                ]
                              : null,
                        ),
                        child: Icon(Icons.emoji_events,
                            color: navigationShell.currentIndex == 2
                                ? AppTokens.colorBrand
                                : const Color(0xFF888888),
                            size: 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavItem(
      {required IconData icon,
      required String label,
      required bool isActive,
      required VoidCallback onTap}) {
    final color = isActive ? AppTokens.colorBrand : const Color(0xFF888888);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
