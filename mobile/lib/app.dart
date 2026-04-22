import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/change_password_page.dart';
import 'features/gym/presentation/pages/gym_self_registration_page.dart';
import 'core/widgets/app_navigation_shell.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/workout/presentation/pages/workout_page.dart';
import 'features/workout/presentation/pages/active_workout_session_page.dart';
import 'features/diet/presentation/pages/diet_page.dart';
import 'features/gym/presentation/pages/gym_page.dart';
import 'features/challenge/presentation/pages/challenge_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/dashboard/presentation/providers/recovery_provider.dart';
import 'features/diet/presentation/providers/diet_provider.dart';
import 'features/gym/presentation/providers/gym_provider.dart';
import 'features/gym/presentation/providers/gym_access_provider.dart';
import 'features/gym/presentation/providers/membership_provider.dart';
import 'features/gym/presentation/providers/sessions_provider.dart';
import 'features/gym/presentation/providers/support_provider.dart';
import 'features/gym/presentation/providers/trainer_assignment_provider.dart';
import 'features/gym/presentation/providers/announcements_provider.dart';
import 'features/home/presentation/providers/water_tracker_provider.dart';
import 'features/onboarding/presentation/pages/onboarding_flow_page.dart';
import 'features/profile/presentation/providers/profile_sync_provider.dart';
import 'features/progress/presentation/pages/progress_page.dart';
import 'features/progress/presentation/providers/progress_provider.dart';
import 'features/workout/presentation/providers/workout_provider.dart';
import 'core/providers/user_gym_state_provider.dart';
import 'core/providers/storage_providers.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/app_lifecycle_sync_service.dart';
import 'core/providers/app_boot_provider.dart';
import 'core/widgets/offline_banner.dart';
import 'core/localization/l10n_keys.dart';
import 'core/localization/l10n_provider.dart';

// Listenable that notifies GoRouter when auth state changes
class RouterListenable extends ChangeNotifier {
  final Ref _ref;
  RouterListenable(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
    _ref.listen(appBootProvider, (_, __) => notifyListeners());
  }
}

final routerListenableProvider = Provider((ref) => RouterListenable(ref));

// Basic GoRouter configuration
final goRouterProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerListenableProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) async {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      // ── 1. Wait for Auth Verification + Boot Pre-warm ──────────────────────
      // Stay on splash until both auth resolves AND caches are pre-warmed.
      if (authState is AuthInitial || authState is AuthLoading) {
        return (loc == '/') ? null : '/';
      }
      // Auth has settled — ensure boot pre-warm has completed (non-blocking: 3s timeout built-in)
      final bootAsync = ref.read(appBootProvider);
      if (bootAsync.isLoading) return (loc == '/') ? null : '/';

      // ── 2. Handle Authenticated Users ──────────────────────────────────────
      if (authState is AuthAuthenticated) {
        // If logged in, skip login and onboarding
        if (loc == '/' || loc == '/login' || loc == '/onboarding') return '/challenge';
        return null;
      }

      // ── 2b. Forced password change (e.g. new Branch Admin accounts) ─────────
      if (authState is AuthMustChangePassword) {
        if (loc != '/change-password') return '/change-password';
        return null;
      }

      // ── 3. Handle Guest / Unauthenticated ──────────────────────────────────
      // Check if onboarding has been completed (use pre-initialized provider)
      final prefs = ref.read(sharedPreferencesProvider);
      final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

      // Logic:
      //  A. Not done onboarding? Go there.
      //  B. Done onboarding? Go to login (unless already there).
      if (!onboardingDone) {
        if (loc != '/onboarding') return '/onboarding';
        return null;
      }

      // Onboarding IS done, but user is NOT authenticated.
      // They must be at /login.
      if (loc != '/login' && loc != '/onboarding') return '/login';
      if (loc == '/onboarding') return '/login';

      return (loc == '/') ? '/login' : null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/gym-register',
        builder: (context, state) {
          final gymId = state.uri.queryParameters['gymId'] ?? '';
          final code = state.uri.queryParameters['code'] ?? '';
          return GymSelfRegistrationPage(gymId: gymId, registrationCode: code);
        },
      ),
      GoRoute(
        path: '/workout/session',
        builder: (context, state) => const ActiveWorkoutSessionPage(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (context, state) => const WorkoutPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/diet',
                builder: (context, state) => const DietPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/challenge',
                builder: (context, state) => const ChallengePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gym',
                builder: (context, state) => const GymPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressPage(),
              ),
            ],
          ),
        ],
      )
    ],
  );
});

class AmiraniApp extends ConsumerStatefulWidget {
  const AmiraniApp({super.key});

  @override
  ConsumerState<AmiraniApp> createState() => _AmiraniAppState();
}

class _AmiraniAppState extends ConsumerState<AmiraniApp> {
  late final AppLifecycleSyncService _lifecycleSync;

  @override
  void initState() {
    super.initState();
    _lifecycleSync = ref.read(appLifecycleSyncProvider);
    _lifecycleSync.register();
    L10n.init(ref.read(l10nProvider.notifier));
  }

  @override
  void dispose() {
    _lifecycleSync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    // When the user first authenticates, flush pending onboarding data and
    // trigger an immediate plan fetch so trainer-assigned plans are available
    // on the very first session.
    // When the server returns 401, force logout regardless of local auth state.
    ref.listen<bool>(sessionExpiredProvider, (_, expired) {
      if (expired) {
        ref.read(sessionExpiredProvider.notifier).state = false;
        ref.read(authNotifierProvider.notifier).logout();
      }
    });

    ref.listen<AsyncValue<bool>>(isOfflineProvider, (previous, next) {
      final wasOffline = previous?.valueOrNull == true;
      final isNowOnline = next.valueOrNull == false;
      if (wasOffline && isNowOnline) {
        ref.read(dashboardNotifierProvider.notifier).fetchDashboardMetrics();
        ref.read(progressProvider.notifier).load();
        ref.read(membershipProvider.notifier).fetch();
        ref.read(sessionsProvider.notifier).refresh();
      }
    });

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      final wasAuthenticated = previous is AuthAuthenticated;
      if (!wasAuthenticated && next is AuthAuthenticated) {
        ref.read(profileSyncProvider.notifier).applyPendingOnboardingData();
        PushNotificationService.init(ref, router);
        _lifecycleSync.onAuthenticated();
      }

      // On logout: invalidate all user-data providers so stale data never leaks
      // to the next user session.
      if (wasAuthenticated && next is! AuthAuthenticated) {
        ref.read(l10nProvider.notifier).resetToEnglish();
        ref.invalidate(dashboardNotifierProvider);
        ref.invalidate(recoveryProvider);
        ref.invalidate(dietNotifierProvider);
        ref.invalidate(gymNotifierProvider);
        ref.invalidate(gymAccessProvider);
        ref.invalidate(membershipProvider);
        ref.invalidate(sessionsProvider);
        ref.invalidate(supportProvider);
        ref.invalidate(trainerAssignmentProvider);
        ref.invalidate(announcementsProvider);
        ref.invalidate(waterTrackerProvider);
        ref.invalidate(progressProvider);
        ref.invalidate(workoutNotifierProvider);
        ref.invalidate(userGymStateProvider);
        ref.invalidate(profileSyncProvider);
      }
    });

    return MaterialApp.router(
      title: 'Amirani',
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        // AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
      ],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(appBootProvider);

    final String statusText = boot.when(
      data: (_) => 'Ready',
      loading: () => 'Loading your data…',
      error: (_, __) => 'Starting up…',
    );

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo mark
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBrand.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: AppTheme.primaryBrand,
                size: 34,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AMIRANI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your Personal Fitness Platform',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryBrand.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              statusText,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
