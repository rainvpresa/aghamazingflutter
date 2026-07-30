import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class GameSessionService {
  final AuthService _authService = AuthService();

  /// Shared helper to handle authorized POST requests to game endpoints
  Future<bool> _postGameSession(String endpoint, Map<String, dynamic> body) async {
    final token = await _authService.getToken();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/app/game/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Game session logged ($endpoint)');
        return true;
      }
      debugPrint('❌ Failed ($endpoint): ${response.statusCode} | ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Exception logging session ($endpoint): $e');
      return false;
    }
  }

  /// POST /api/app/game/trivia
  Future<bool> saveTriviaSession({
    required int correctAnswers,
    required int wrongAnswers,
    required int totalQuestions,
    required int chancesUsed,
    required int scoreEarned,
    int durationSeconds = 0,
  }) async {
    return _postGameSession('trivia', {
      'score_earned': scoreEarned,
      'correct_answers': correctAnswers,
      'wrong_answers': wrongAnswers,
      'total_questions': totalQuestions,
      'chances_used': chancesUsed,
      'duration_seconds': durationSeconds,
    });
  }

  /// POST /api/app/game/tictactoe
  Future<bool> saveTicTacToeSession({
    required String result, // 'win', 'loss', or 'draw'
    required int scoreEarned,
    int durationSeconds = 0,
  }) async {
    return _postGameSession('tictactoe', {
      'result': result,
      'score_earned': scoreEarned,
      'duration_seconds': durationSeconds,

    });
  }

  /// POST /api/app/game/numbermatch
  Future<bool> saveNumberMatchSession({
    required int finalScore,
    required int highestTile,
    required int levelReached,
    required int coinsEarned,
    int durationSeconds = 0,
  }) async {
    return _postGameSession('numbermatch', {
      'score_earned': finalScore,
      'highest_tile': highestTile,
      'level_reached': levelReached,
      'coins_earned': coinsEarned,
      'duration_seconds': durationSeconds,
    });
  }

  /// POST /api/app/game/gem-grab
  Future<bool> saveGemGrabSession({
    required int scoreEarned,
    required int gemsCollected,
    required int coinsEarned,
    required int playsRemaining,
    int durationSeconds = 30,
  }) async {
    return _postGameSession('gem-grab', {
      'score_earned': scoreEarned,
      'gems_collected': gemsCollected,
      'coins_earned': coinsEarned,
      'plays_remaining': playsRemaining,
      'duration_seconds': durationSeconds,
    });
  }
  /// POST /api/app/game/color-puzzle
  Future<bool> saveColorPuzzleSession({
    required int scoreEarned,
    required int coinsEarned,
    required int moveCount,
    int optimalMoves = 12,
    int durationSeconds = 0,
  }) async {
    return _postGameSession('color-puzzle', {
      'score_earned': scoreEarned,
      'coins_earned': coinsEarned,
      'move_count': moveCount,
      'optimal_moves': optimalMoves,
      'duration_seconds': durationSeconds,
    });
  }
}