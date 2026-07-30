import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class PlayerStatsService {
  final AuthService _authService = AuthService();

  /// GET /api/app/leaderboard
  Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/app/leaderboard'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }
    return [];
  }

  /// GET /api/app/profile/stats
  Future<Map<String, dynamic>?> getPlayerStats() async {
    final token = await _authService.getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/app/profile/stats'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
    return null;
  }
}