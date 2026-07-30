import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  // Save bearer token locally
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setBool('isLoggedIn', true);
  }

  // Get saved bearer token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Clear session on logout or token expiration
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.setBool('isLoggedIn', false);
  }

  // Check login state
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // POST /api/app/auth/register
  Future<Map<String, dynamic>> registerWithEmailVerification({
    required String displayName,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String region,
    required String ageGroup,
    required String gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'display_name': displayName,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'region': region,
          'age_group': ageGroup,
          'gender': gender,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Validation error'
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // POST /api/app/auth/login
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }
        return {
          'success': true,
          'message': 'Login successful',
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid credentials.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // GET /api/app/auth/me
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.me),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        await _clearSession();
        return null;
      }
    } catch (e) {
      return null;
    }
  }

// Forgot Password
  Future<Map<String, dynamic>> sendPasswordResetEmail({required String email}) async {
    return _sendEmailAction('/api/app/auth/forgot-password', email);
  }

  // Resend Verification Email (Reusing the same underlying POST logic)
  Future<Map<String, dynamic>> resendVerification({required String email}) async {
    return _sendEmailAction('/api/app/auth/resend-verification', email);
  }

  // Helper method using standard http package
  Future<Map<String, dynamic>> _sendEmailAction(String endpoint, String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Action completed successfully.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Request failed.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // POST /api/app/auth/logout
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse(ApiConfig.logout),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      debugPrint('Logout request error: $e');
    } finally {
      await _clearSession();
    }
  }
}
