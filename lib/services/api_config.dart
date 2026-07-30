import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  static String get register => '$baseUrl/api/app/auth/register';

  static String get login => '$baseUrl/api/app/auth/login';

  static String get me => '$baseUrl/api/app/auth/me';

  static String get logout => '$baseUrl/api/app/auth/logout';

  /// Transforms relative backend image paths (e.g., "/storage/avatars/...")
  /// into full clickable URLs based on current environment platform.
  static String formatImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';

    String formatted = path;

    // Swap localhost/127.0.0.1 with 10.0.2.2 for Android network requests
    if (!kIsWeb && Platform.isAndroid) {
      formatted = formatted
          .replaceAll('http://localhost:8000', baseUrl)
          .replaceAll('http://127.0.0.1:8000', baseUrl);
    }

    if (formatted.startsWith('http://') || formatted.startsWith('https://')) {
      return formatted;
    }

    final cleanPath = formatted.startsWith('/') ? formatted : '/$formatted';
    return '$baseUrl$cleanPath';
  }
}