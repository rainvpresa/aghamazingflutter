import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // Ensure base URL is loaded from here

class TriviaQuestion {
  final String id;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String category;
  final String difficulty;

  const TriviaQuestion({
    required this.id,
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.category,
    required this.difficulty,
  });

  factory TriviaQuestion.fromJson(Map<String, dynamic> json) {
    return TriviaQuestion(
      id: json['id']?.toString() ?? '',
      question: json['question'] as String? ?? '',
      choices: json['choices'] != null
          ? List<String>.from(json['choices'] as List)
          : [],
      correctIndex: json['correct_index'] ?? json['correctIndex'] ?? 0,
      category: json['category'] as String? ?? 'general',
      difficulty: json['difficulty'] as String? ?? 'easy',
    );
  }
}

class TriviaService {
  TriviaService._();
  static final TriviaService instance = TriviaService._();

  /// Fetches random questions from Laravel public endpoint: GET /api/trivia
  Future<List<TriviaQuestion>> getRandomQuestions({
    int count = 10,
    String? category,
    String? difficulty,
  }) async {
    try {
      final queryParams = <String, String>{
        'count': count.toString(),
        if (category != null) 'category': category,
        if (difficulty != null) 'difficulty': difficulty,
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/trivia')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);

        // Handles both direct array responses or wrapped JSON responses e.g. { "data": [...] }
        final List<dynamic> list = decoded.containsKey('data')
            ? decoded['data']
            : jsonDecode(response.body);

        return list.map((item) => TriviaQuestion.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        debugPrint('TriviaService HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('TriviaService exception: $e');
      return [];
    }
  }
}