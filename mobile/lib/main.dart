import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/service_availability.dart';
import 'core/data/local_db_service.dart';
import 'core/providers/storage_providers.dart';
import 'core/services/payment/stripe_service.dart';
import 'app.dart';

void main() {
  // ── Global Flutter error boundary ────────────────────────────────────────
  // Must be set before ensureInitialized to catch framework errors from init.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      debugPrint('[Flutter Error] ${details.exceptionAsString()}');
    }
  };

  // Wrap everything in a single zone so WidgetsFlutterBinding and runApp
  // live in the same zone — prevents "zone mismatch" warnings.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Load environment variables (graceful: missing file is non-fatal in CI/production)
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {}

      // Initialize Firebase (Safely checks for configuration before attempting init)
      if (!kIsWeb) {
        try {
          await Firebase.initializeApp();
          debugPrint('[Firebase] Successfully initialized.');
          ServiceAvailability.firebase = true;
        } catch (e) {
          debugPrint('─────────────────────────────────────────────────────────────────');
          debugPrint('[PREMIUM ADVISORY] Firebase configuration missing.');
          debugPrint('Push notifications and Google Auth will be disabled.');
          debugPrint('Please add google-services.json / GoogleService-Info.plist');
          debugPrint('─────────────────────────────────────────────────────────────────');
          ServiceAvailability.firebase = false;
        }
      }

      // Initialize Hive/SecureStorage
      await LocalDBService.init();

      // Initialize Stripe
      StripeService.init();

      // Initialize SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const AmiraniApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('[Zone Error] $error\n$stack');
    },
  );
}
