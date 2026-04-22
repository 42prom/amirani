import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    // Priority: 1. --dart-define, 2. .env file
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('API_BASE_URL not found in environment or .env file');
    }
    return url;
  }

  static String get socketUrl {
    const envUrl = String.fromEnvironment('SOCKET_URL');
    if (envUrl.isNotEmpty) return envUrl;

    final url = dotenv.env['SOCKET_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('SOCKET_URL not found in environment or .env file');
    }
    return url;
  }

  static String get mediaBaseUrl {
    final baseUrl = apiBaseUrl;
    if (baseUrl.endsWith('/api')) {
      return baseUrl.substring(0, baseUrl.length - 4);
    }
    return baseUrl;
  }

  static String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final base = mediaBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$base$cleanPath';
  }
}

