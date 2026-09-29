import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl => 'https://aghamazing-dost.csf.ph';

  static String get register => '$baseUrl/api/app/auth/register';

  static String get login => '$baseUrl/api/app/auth/login';

  static String get me => '$baseUrl/api/app/auth/me';

  static String get logout => '$baseUrl/api/app/auth/logout';

  /// Transforms relative backend image paths (e.g., "/storage/avatars/...")
  /// into full clickable URLs.
  static String formatImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }
}