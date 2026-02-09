import 'package:flutter/foundation.dart';
import 'userprofile_service.dart'; // Import your service

class TriviaGameManager extends ChangeNotifier {
  static final TriviaGameManager instance = TriviaGameManager._();
  TriviaGameManager._();

  final UserProfileService _profileService = UserProfileService();

  int _wrongAnswers = 0;
  int _correctAnswers = 0;
  int _totalQuestions = 3;
  bool _gameInProgress = false;

  int get wrongAnswers => _wrongAnswers;
  int get correctAnswers => _correctAnswers;
  int get totalQuestions => _totalQuestions;
  bool get gameInProgress => _gameInProgress;

  // Calculate gems (points): 100 - (wrongAnswers × 20), minimum 0
  int calculateGems() {
    final gems = 100 - (_wrongAnswers * 20);
    return gems < 0 ? 0 : gems;
  }

  // Calculate coins: 10 base + 5 bonus for perfect game
  int calculateCoins() {
    int baseCoins = 10; // Base reward for completing
    if (_wrongAnswers == 0) {
      baseCoins += 5; // Perfect game bonus
    }
    return baseCoins;
  }

  // Check if perfect game (all 3 correct)
  bool isPerfectGame() => _wrongAnswers == 0;

  // Start new game
  void startGame() {
    _wrongAnswers = 0;
    _correctAnswers = 0;
    _gameInProgress = true;
    notifyListeners();
  }

  // Record correct answer
  void recordCorrectAnswer() {
    if (_gameInProgress) {
      _correctAnswers++;
      notifyListeners();
    }
  }

  // Record wrong answer
  void recordWrongAnswer() {
    if (_gameInProgress) {
      _wrongAnswers++;
      notifyListeners();
    }
  }

  // End game and save rewards to Firebase
  Future<bool> endGameAndSaveRewards() async {
    if (!_gameInProgress) return false;

    _gameInProgress = false;
    notifyListeners();

    final coins = calculateCoins();
    final gems = calculateGems();

    try {
      // Save coins (bubble power)
      await _profileService.addCoins(
        amount: coins,
        reason: isPerfectGame()
            ? 'Perfect trivia game! 🎉'
            : 'Trivia game completed',
      );

      // Save gems (points/totalScore) for leaderboard
      await _profileService.updateGameStats(
        gamesPlayed: 1,
        gamesWon: isPerfectGame() ? 1 : 0,
        totalScore: gems,
      );

      return true;
    } catch (e) {
      debugPrint('Error saving game rewards: $e');
      return false;
    }
  }

  // Simple end game without saving (if you need it)
  void endGame() {
    _gameInProgress = false;
    notifyListeners();
  }

  // Reset for new game
  void reset() {
    _wrongAnswers = 0;
    _correctAnswers = 0;
    _gameInProgress = false;
    notifyListeners();
  }
}