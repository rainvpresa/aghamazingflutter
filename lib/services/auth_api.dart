import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

class AuthApi {
  // API endpoints
  final String registerUrl;
  final String loginUrl;
  final String otpRequestUrl;
  final String otpVerifyUrl;
  final Duration timeout;

  late final http.Client _client;

  AuthApi({
    required this.registerUrl,
    required this.loginUrl,
    required this.otpRequestUrl,
    required this.otpVerifyUrl,
    Duration? timeout,
    bool allowBadCertificateInDebug = true,
  }) : timeout = timeout ?? const Duration(seconds: 10) {
    // In debug builds allow a bad certificate callback (DEV ONLY)
    if (!kReleaseMode && allowBadCertificateInDebug) {
      final ioc = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      _client = IOClient(ioc);
    } else {
      _client = http.Client();
    }
  }

  // Clean up client when done
  void close() => _client.close();

  // Login user; returns server key (token) on success
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(loginUrl);
    final body = jsonEncode({
      'email': email,
      'password': password,
    });
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // some ngrok setups require this header to skip the browser warning:
      'ngrok-skip-browser-warning': 'true',
    };

    final resp = await _post(uri, headers, body);

    try {
      final data = jsonDecode(resp);
      if (data is Map && data['key'] is String && (data['key'] as String).isNotEmpty) {
        return data['key'] as String;
      } else {
        final err = _parseErrorMessage(data);
        throw ApiException(err ?? 'Login failed (unexpected response)');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Invalid login response');
    }
  }

  // Register user; returns server key (or token) on success
  Future<String> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(registerUrl);
    final body = jsonEncode({
      'username': username,
      'email': email,
      'password1': password,
      'password2': password,
    });

    final headers = {'Content-Type': 'application/json'};

    final resp = await _post(uri, headers, body);

    // Expecting JSON { "key": "..." }
    try {
      final data = jsonDecode(resp);
      if (data is Map && data['key'] is String && (data['key'] as String).isNotEmpty) {
        return data['key'] as String;
      } else {
        final err = _parseErrorMessage(data);
        throw ApiException(err ?? 'Registration failed (unexpected response)');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Invalid registration response');
    }
  }

  Future<void> requestOtp({required String email}) async {
    final uri = Uri.parse(otpRequestUrl);
    final body = jsonEncode({'email': email});
    final headers = {'Content-Type': 'application/json'};
    await _post(uri, headers, body);
  }

  Future<void> verifyOtp({required String email, required String otp}) async {
    final uri = Uri.parse(otpVerifyUrl);
    final body = jsonEncode({'email': email, 'otp': otp});
    final headers = {'Content-Type': 'application/json'};
    await _post(uri, headers, body);
  }

  // internal helper for POST with timeout + error parsing
  Future<String> _post(Uri uri, Map<String, String> headers, String body) async {
    http.Response res;
    try {
      final future = _client.post(uri, headers: headers, body: body);
      res = await future.timeout(timeout);
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } catch (e) {
      throw ApiException('Request failed: $e');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body;
    }

    // Non-successful response: try to parse JSON error message
    try {
      final decoded = jsonDecode(res.body);
      final err = _parseErrorMessage(decoded);
      throw ApiException(err ?? 'Server returned ${res.statusCode}');
    } catch (_) {
      throw ApiException('Server error: ${res.statusCode}');
    }
  }

  String? _parseErrorMessage(dynamic decoded) {
    if (decoded == null) return null;
    if (decoded is Map) {
      if (decoded['message'] is String) return decoded['message'] as String;
      if (decoded['error'] is String) return decoded['error'] as String;
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.isNotEmpty) return v;
      }
    } else if (decoded is String) {
      return decoded;
    }
    return null;
  }
}