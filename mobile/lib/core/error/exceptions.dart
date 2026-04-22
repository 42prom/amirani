/// Base class for all data-layer exceptions
abstract class AppException implements Exception {
  final String message;
  final int? statusCode;
  const AppException(this.message, {this.statusCode});

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

/// Thrown when the server returns a non-2xx response
class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

/// Thrown when Hive / SQLite operations fail
class CacheException extends AppException {
  const CacheException(super.message);
}

/// Thrown when there is no internet connectivity
class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection']);
}

/// Thrown for business rule violations from backend
class BusinessException extends AppException {
  final String code;
  const BusinessException(super.message, {required this.code});
}

/// Thrown when JWT is expired or invalid
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Session expired']);
}

/// Thrown for Stripe payment errors
class PaymentException extends AppException {
  final String? stripeCode;
  const PaymentException(super.message, {this.stripeCode});
}
