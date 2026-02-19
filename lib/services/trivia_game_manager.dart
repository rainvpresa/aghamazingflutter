import 'trivia_service.dart';

class TriviaGameManager {
  TriviaGameManager._();
  static final TriviaGameManager instance = TriviaGameManager._();

  List<TriviaQuestion> _questions = [];
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;

  List<TriviaQuestion> get questions => _questions;
  int get currentIndex => _currentIndex;
  TriviaQuestion? get currentQuestion =>
      _questions.isEmpty ? null : _questions[_currentIndex];
  bool get hasMore => _currentIndex < _questions.length - 1;
  int get correctAnswers => _correctAnswers;
  int get wrongAnswers => _wrongAnswers;

  Future<void> loadAndStart({int count = 10}) async {
    _questions = await TriviaService.instance.getRandomQuestions(count: count);
    _currentIndex = 0;
    _correctAnswers = 0;
    _wrongAnswers = 0;
  }

  void nextQuestion() {
    if (hasMore) _currentIndex++;
  }

  void recordCorrectAnswer() => _correctAnswers++;
  void recordWrongAnswer() => _wrongAnswers++;

  bool isPerfectGame() =>
      _questions.isNotEmpty && _correctAnswers == _questions.length;

  /// 1 gem per correct answer, bonus 5 if perfect
  int calculateGems() {
    final base = _correctAnswers;
    final bonus = isPerfectGame() ? 5 : 0;
    return base + bonus;
  }

  /// 10 coins per correct answer, bonus 50 if perfect
  int calculateCoins() {
    final base = _correctAnswers * 10;
    final bonus = isPerfectGame() ? 50 : 0;
    return base + bonus;
  }

  void endGame() {
    // Keep stats readable by YouWonScreen before reset is called
    // Reset is called manually via reset() when playing again
  }

  void reset() {
    _questions = [];
    _currentIndex = 0;
    _correctAnswers = 0;
    _wrongAnswers = 0;
  }
}