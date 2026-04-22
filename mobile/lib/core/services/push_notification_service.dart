import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:amirani_app/core/config/service_availability.dart';
import 'package:amirani_app/core/network/dio_provider.dart';
import 'package:amirani_app/features/gym/presentation/providers/membership_provider.dart';
import 'package:amirani_app/features/workout/presentation/providers/workout_provider.dart';
import 'package:amirani_app/features/diet/presentation/providers/diet_provider.dart';
import 'package:amirani_app/core/services/workout_plan_storage_service.dart';
import 'package:amirani_app/core/services/diet_plan_storage_service.dart';
import 'package:amirani_app/core/providers/session_progress_provider.dart';

// ─── Background handler (top-level, outside class) ───────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Guard: background isolate must initialise Firebase independently.
  // If configuration files are missing, skip silently instead of crashing.
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (_) {
    return;
  }
  debugPrint('[FCM BG] ${message.notification?.title}: ${message.notification?.body}');
}

// ─── Local notifications channel ─────────────────────────────────────────────

const _androidChannel = AndroidNotificationChannel(
  'amirani_high',
  'Amirani Notifications',
  description: 'Gym access, payments, support replies and system alerts',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

// ─── Service ─────────────────────────────────────────────────────────────────

class PushNotificationService {
  static Future<void> init(WidgetRef ref, GoRouter router) async {
    if (kIsWeb) return;

    // Skip entirely when Firebase was not initialised at startup
    // (google-services.json / GoogleService-Info.plist missing).
    if (!ServiceAvailability.firebase) {
      debugPrint('[FCM] Firebase not available — push notifications disabled.');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // Set up Android notification channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      // Init local notifications plugin
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // Foreground message display
      FirebaseMessaging.onMessage.listen((message) {
        // Zero-latency membership status refresh
        if (message.data['type'] == 'MEMBERSHIP_UPDATE') {
          debugPrint('[FCM] Membership update received, refreshing state...');
          ref.read(membershipProvider.notifier).fetch();
        }

        // Zero-latency synchronization triggered by trainer updates
        if (message.data['type'] == 'SYNC_DOWN') {
          final planType = message.data['planType'] as String?;
          debugPrint('[FCM] Sync trigger received (type=$planType), refreshing caches…');
          
          // Refresh the core synchronization layer (profile, status, etc.)
          // This ensures that the Pull-to-Refresh equivalent happens in the background.
          // We use the top-level sync service to ensure consistency.
          // Note: syncDown is available via the session provider
          unawaited(ref.read(sessionProgressProvider.notifier).syncDown());

          if (planType == 'workout' || planType == null) {
            ref.invalidate(savedWorkoutPlanProvider);
            unawaited(ref.read(workoutNotifierProvider.notifier).fetchActivePlan());
          }
          if (planType == 'diet' || planType == null) {
            ref.invalidate(savedDietPlanProvider);
            unawaited(ref.read(dietNotifierProvider.notifier).fetchActivePlan());
          }
        }

        // Trainer plan assignment — clear local cache and trigger a fresh fetch
        if (message.data['type'] == 'PLAN_ASSIGNED') {
          final planType = message.data['planType'] as String?;
          debugPrint('[FCM] Plan assigned (type=$planType), synchronizing state…');
          
          if (planType == 'workout' || planType == null) {
            unawaited(() async {
              await ref.read(workoutPlanStorageProvider).deletePlan();
              ref.invalidate(savedWorkoutPlanProvider);
              await ref.read(workoutNotifierProvider.notifier).fetchActivePlan();
            }());
          }
          if (planType == 'diet' || planType == null) {
            unawaited(() async {
              await ref.read(dietPlanStorageProvider).deletePlan();
              ref.invalidate(savedDietPlanProvider);
              await ref.read(dietNotifierProvider.notifier).fetchActivePlan();
            }());
          }
        }

        final notification = message.notification;
        if (notification == null) return;
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: '@mipmap/launcher_icon',
            ),
          ),
        );
      });

      // Handle notification taps (background)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleMessage(message, router);
      });

      // Handle notification taps (cold start)
      unawaited(messaging.getInitialMessage().then((message) {
        if (message != null) {
          _handleMessage(message, router);
        }
      }));

      // Foreground FCM presentation on iOS
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Register token with backend
      await _registerToken(ref);

      // Re-register on token refresh
      messaging.onTokenRefresh
          .listen((token) => _sendTokenToBackend(ref, token));
    } catch (e) {
      debugPrint('[FCM] initialization failed: $e');
    }
  }

  static Future<void> _registerToken(WidgetRef ref) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = kIsWeb
          ? null
          : Platform.isIOS
              ? await messaging.getAPNSToken()
              : await messaging.getToken();
      if (token != null) await _sendTokenToBackend(ref, token);
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  static Future<void> _sendTokenToBackend(WidgetRef ref, String token) async {
    try {
      final dio = ref.read(dioProvider);
      final field = (!kIsWeb && Platform.isIOS) ? 'apnsToken' : 'fcmToken';
      await dio.patch('/notifications/preferences', data: {field: token});
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Failed to register token: $e');
    }
  }

  static void _handleMessage(RemoteMessage message, GoRouter router) {
    final path = message.data['path'] as String?;
    if (path != null && path.isNotEmpty) {
      debugPrint('[FCM] Navigating to $path based on notification tap');
      router.go(path);
    }
  }
}
