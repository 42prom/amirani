import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';
import '../providers/storage_providers.dart';

/// Logs retry events without leaking auth tokens or sensitive headers.
void _safeRetryLog(String msg) {
  // Strip Authorization header values before logging
  final sanitized = msg.replaceAll(RegExp(r'Bearer [A-Za-z0-9\-._~+/]+=*'), 'Bearer [REDACTED]');
  debugPrint('[Retry] $sanitized');
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final secureStorage = ref.watch(secureStorageProvider);
  dio.interceptors.add(AuthInterceptor(
    secureStorage: secureStorage,
    onUnauthorized: () async {
      ref.read(sessionExpiredProvider.notifier).state = true;
    },
  ));

  dio.interceptors.add(RetryInterceptor(
    dio: dio,
    logPrint: _safeRetryLog,
    retries: 5, // Increase to 5 for better stability during slow restarts
    retryDelays: const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 6),
    ],
    retryableExtraStatuses: {502, 503, 504}, // Retry on tunnel/gateway errors
  ));

  return dio;
});
