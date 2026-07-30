import 'package:flutter/material.dart';
import '../../widgets/trivia_button.dart';
import '../../widgets/confetti_effect.dart';
import '../../services/trivia_game_manager.dart';
import '../../services/trivia_service.dart';
import '../../widgets/game_quit_handler.dart';
import 'you_won_screen.dart';

class MainTriviaScreen extends StatefulWidget {
  const MainTriviaScreen({super.key});

  @override
  State<MainTriviaScreen> createState() => _MainTriviaScreenState();
}

class _MainTriviaScreenState extends State<MainTriviaScreen>
    with TickerProviderStateMixin, GameQuitHandler {
  static const int _totalQuestions = 5;
  static const int _maxChances = 3;
  static const int _pointsPerCorrect = 50;
  static const int _pointsPerWrong = 20;

  List<AnswerState> _answerStates = [];
  bool _showConfetti = false;
  bool _showGoodJob = false;
  bool _isLoading = true;
  String? _errorMessage;

  int _litStars = 0;
  int _totalPoints = 0;
  int _chancesLeft = _maxChances;
  bool _answered = false;

  final List<AnimationController> _starControllers = [];
  final List<Animation<double>> _starScaleAnims = [];

  late AnimationController _heartShakeController;
  late Animation<double> _heartShakeAnim;

  TriviaQuestion? get _current => TriviaGameManager.instance.currentQuestion;

  @override
  void initState() {
    super.initState();
    _initStarAnimations();
    _initHeartShakeAnimation();
    _checkEnergyAndStartGame();
  }

  void _initStarAnimations() {
    for (int i = 0; i < _totalQuestions; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      final anim = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.5)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 50),
        TweenSequenceItem(
            tween: Tween(begin: 1.5, end: 1.0)
                .chain(CurveTween(curve: Curves.bounceOut)),
            weight: 50),
      ]).animate(ctrl);
      _starControllers.add(ctrl);
      _starScaleAnims.add(anim);
    }
  }

  void _initHeartShakeAnimation() {
    _heartShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartShakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 8, end: -4), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 25),
    ]).animate(_heartShakeController);
  }

  Future<void> _checkEnergyAndStartGame() async {
    try {
      await TriviaGameManager.instance.loadAndStart(count: _totalQuestions);
      if (!mounted) return;

      if (TriviaGameManager.instance.questions.isEmpty) {
        setState(() {
          _errorMessage = 'No questions available. Please try again later.';
          _isLoading = false;
        });
        return;
      }

      _resetAnswerStates();
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error starting game: $e');
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _resetAnswerStates() {
    final count = _current?.choices.length ?? 4;
    _answerStates = List.filled(count, AnswerState.idle);
    _chancesLeft = _maxChances;
    _answered = false; // ← reset for next question
  }

  void _checkAnswer(int choiceIndex) {
    final question = _current;
    if (question == null) return;
    if (_answered) return;
    if (_answerStates[choiceIndex] != AnswerState.idle) return;

    if (choiceIndex == question.correctIndex) {
      TriviaGameManager.instance.recordCorrectAnswer(); // ← was missing
      setState(() {
        _answered = true;
        _totalPoints += _pointsPerCorrect;
        _answerStates[choiceIndex] = AnswerState.correct;
        _showConfetti = true;
        _showGoodJob = true;
      });

      if (_litStars < _totalQuestions) {
        _starControllers[_litStars].forward(from: 0);
        setState(() => _litStars++);
      }

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _goToNext();
      });
    } else {
      TriviaGameManager.instance.recordWrongAnswer();
      _heartShakeController.forward(from: 0);

      setState(() {
        _answerStates[choiceIndex] = AnswerState.wrong;
        _totalPoints = (_totalPoints - _pointsPerWrong).clamp(0, 9999);
        _chancesLeft--;
      });

      if (_chancesLeft <= 0) {
        setState(() {
          for (int i = 0; i < _answerStates.length; i++) {
            if (_answerStates[i] == AnswerState.idle) {
              _answerStates[i] = AnswerState.wrong;
            }
          }
        });
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          _goToNext();
        });
      }
    }
  }

  void _goToNext() {
    if (TriviaGameManager.instance.hasMore) {
      TriviaGameManager.instance.nextQuestion();
      setState(() {
        _showConfetti = false;
        _showGoodJob = false;
        _resetAnswerStates();
      });
    } else {
      _endGame();
    }
  }

  void _endGame() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => YouWonScreen(totalPoints: _totalPoints),
      ),
    );
  }

  void _onBackPressed() {
    if (_isLoading || _errorMessage != null) {
      Navigator.pop(context);
      return;
    }

    showQuitConfirmDialog(
      context,
      onConfirm: _endGame,
    );
  }

  @override
  void dispose() {
    for (final c in _starControllers) {
      c.dispose();
    }
    _heartShakeController.dispose();
    super.dispose();
  }

  TextStyle _ts({
    required double size,
    Color color = Colors.white,
    Color shadowColor = Colors.black38,
    double shadowBlur = 4,
    Offset shadowOffset = const Offset(2, 2),
  }) {
    return TextStyle(
      fontFamily: 'LilitaOne',
      fontSize: size,
      color: color,
      fontWeight: FontWeight.w400,
      shadows: [
        Shadow(
            color: shadowColor, blurRadius: shadowBlur, offset: shadowOffset),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/pngs/yellowbg.png',
                  fit: BoxFit.cover),
            ),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/pngs/yellowbg.png',
                  fit: BoxFit.cover),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final question = _current!;
    final categoryLabel = switch (question.category) {
      'scientist' => 'IDENTIFY THE SCIENTIST',
      'technology' => 'SCIENCE & TECHNOLOGY',
      'math' => 'MATHEMATICS',
      _ => 'TRIVIA',
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;

            final catFontSize = (screenW * 0.048).clamp(14.0, 22.0);
            final qFontSize = (screenW * 0.052).clamp(17.0, 26.0);
            final starSize = (screenW * 0.09).clamp(28.0, 45.0);
            final btnHeight = (screenH * 0.085).clamp(50.0, 78.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/pngs/yellowbg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),

                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: screenH * 0.17,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/pngs/wood.png',
                                fit: BoxFit.fill,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              left: 0,
                              width: screenW * 0.20,
                              height: screenH * 0.07,
                              child: GestureDetector(
                                onTap: _onBackPressed,
                                child: Image.asset(
                                  'assets/images/pngs/back_btn.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: screenH * 0.01,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_totalQuestions, (i) {
                                  final isLit = i < _litStars;
                                  return AnimatedBuilder(
                                    animation: _starScaleAnims[i],
                                    builder: (_, __) => Transform.scale(
                                      scale: isLit
                                          ? _starScaleAnims[i].value
                                          : 1.0,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: screenW * 0.01),
                                        child: Image.asset(
                                          isLit
                                              ? 'assets/images/pngs/yellow_star.png'
                                              : 'assets/images/pngs/empty_star.png',
                                          width: starSize,
                                          height: starSize,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenW * 0.06,
                          vertical: screenH * 0.012,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('⭐ $_totalPoints pts',
                                  style: _ts(size: 14)),
                            ),
                            AnimatedBuilder(
                              animation: _heartShakeAnim,
                              builder: (_, __) => Transform.translate(
                                offset: Offset(_heartShakeAnim.value, 0),
                                child: Row(
                                  children: List.generate(_maxChances, (i) {
                                    final isActive = i < _chancesLeft;
                                    return Icon(
                                      isActive
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isActive
                                          ? Colors.red
                                          : Colors.white38,
                                      size: 26,
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        flex: 38,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenW * 0.06),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: screenH * 0.06,
                                child: Image.asset(
                                  'assets/images/pngs/question_top.png',
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Positioned(
                                top: screenH * 0.05,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Image.asset(
                                  'assets/images/pngs/question_bottom.png',
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: screenH * 0.06,
                                child: Center(
                                  child: Text(
                                    categoryLabel,
                                    textAlign: TextAlign.center,
                                    style: _ts(
                                      size: catFontSize,
                                      color: const Color(0xFFFFAD16),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: screenH * 0.055,
                                left: screenW * 0.05,
                                right: screenW * 0.05,
                                bottom: 0,
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      question.question,
                                      textAlign: TextAlign.center,
                                      style: _ts(size: qFontSize)
                                          .copyWith(height: 1.3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: screenH * 0.015),

                      Expanded(
                        flex: 48,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenW * 0.06),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              question.choices.length,
                                  (i) => SizedBox(
                                width: double.infinity,
                                height: btnHeight,
                                child: TriviaButton(
                                  text: question.choices[i],
                                  width: double.infinity,
                                  height: btnHeight,
                                  state: _answerStates[i],
                                  onPressed: () => _checkAnswer(i),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: screenH * 0.015),
                    ],
                  ),
                ),

                if (_showConfetti)
                  const ConfettiEffect(
                      duration: Duration(milliseconds: 1000)),

                if (_showGoodJob)
                  LayoutBuilder(builder: (ctx, cons) {
                    return Center(
                      child: Image.asset(
                        'assets/images/pngs/GOOD JOB!.png',
                        width: cons.maxWidth * 0.8,
                        fit: BoxFit.contain,
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
