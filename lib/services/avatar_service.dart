import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AvatarService {
  Future<List<dynamic>> getAvatarPool() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/avatars'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching avatars: $e');
    }
    return [];
  }
}