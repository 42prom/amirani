import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized provider for secure storage.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Provider for SharedPreferences - must be overridden in main.dart
/// with the actual instance to avoid async initialization issues later.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider not overridden');
});

/// Emits true when the server returns 401 (token expired/revoked).
/// The auth listener in app.dart watches this and calls logout().
final sessionExpiredProvider = StateProvider<bool>((ref) => false);
