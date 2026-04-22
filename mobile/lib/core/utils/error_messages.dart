import 'package:dio/dio.dart';

/// Converts raw exceptions into user-friendly messages.
/// Never exposes stack traces, server internals, or tokens to the UI.
class ErrorMessages {
  ErrorMessages._();

  static String from(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
    if (error is DioException) {
      return _fromDio(error, fallback);
    }
    // Avoid leaking internal Dart error strings
    return fallback;
  }

  static String _fromDio(DioException e, String fallback) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Pull down to retry when online.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 401) return 'Session expired. Please log in again.';
        if (status == 403) return 'You don\'t have permission to do that.';
        if (status == 404) return 'The requested data was not found.';
        if (status == 422 || status == 400) {
          // Surface validation message from server if safe
          final msg = e.response?.data?['message'] as String?;
          if (msg != null && msg.length < 120) return msg;
          return 'Invalid request. Please check your input.';
        }
        if (status >= 500) return 'Server error. We\'re looking into it.';
        return fallback;
      case DioExceptionType.cancel:
        return fallback;
      default:
        return fallback;
    }
  }
}
