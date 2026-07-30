import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class UserProfileService {
  final AuthService _authService = AuthService();

  // GET /api/app/auth/me
  Future<Map<String, dynamic>?> getUserProfile() async {
    final token = await _authService.getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/app/auth/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    return null;
  }

  // PUT /api/app/auth/profile
  Future<bool> updateUserProfile({String? displayName, int? avatarPoolId}) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/app/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (displayName != null) 'display_name': displayName,
          if (avatarPoolId != null) 'avatar_pool_id': avatarPoolId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }
}