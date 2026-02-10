import 'package:flutter/material.dart';
import '../../widgets/trivia_button.dart';
import '../../widgets/confetti_effect.dart';
import '../../services/trivia_game_manager.dart';
import 'trivia3_screen.dart';

class Trivia2Screen extends StatefulWidget {
  const Trivia2Screen({super.key});

  @override
  State<Trivia2Screen> createState() => _Trivia2ScreenState();
}

class _Trivia2ScreenState extends State<Trivia2Screen> {
  AnswerState _answer1State = AnswerState.idle;
  AnswerState _answer2State = AnswerState.idle;
  AnswerState _answer3State = AnswerState.idle; // ISAAC NEWTON (correct)
  AnswerState _answer4State = AnswerState.idle;
  bool _showConfetti = false;
  bool _showGoodJob = false;

  void _checkAnswer(int answerIndex) {
    if (answerIndex == 3 && _answer3State == AnswerState.idle) {
      TriviaGameManager.instance.recordCorrectAnswer();
      setState(() {
        _answer1State = AnswerState.idle;
        _answer2State = AnswerState.idle;
        _answer3State = AnswerState.correct;
        _answer4State = AnswerState.idle;
        _showConfetti = true;
        _showGoodJob = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Trivia3Screen()),
        );
      });
      return;
    }

    if (answerIndex != 3) {
      TriviaGameManager.instance.recordWrongAnswer();
    }

    setState(() {
      switch (answerIndex) {
        case 1:
          if (_answer1State == AnswerState.idle) _answer1State = AnswerState.wrong;
          break;
        case 2:
          if (_answer2State == AnswerState.idle) _answer2State = AnswerState.wrong;
          break;
        case 4:
          if (_answer4State == AnswerState.idle) _answer4State = AnswerState.wrong;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pngs/yellowbg.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenH * 0.21,
            child: Image.asset(
              'assets/images/pngs/wood.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(
            top: screenH * 0.245,
            left: screenW * 0.14,
            width: screenW * 0.72,
            height: screenH * 0.053,
            child: Image.asset(
              'assets/images/pngs/question_top.png',
              fit: BoxFit.fill,
            ),
          ),

          Positioned(
            top: screenH * 0.280,
            left: screenW * 0.14,
            width: screenW * 0.72,
            height: screenH * 0.243,
            child: Image.asset(
              'assets/images/pngs/question_isaac.png',
              fit: BoxFit.contain,
            ),
          ),

          Positioned(
            top: screenH * 0.253,
            left: screenW * 0.15,
            width: screenW * 0.70,
            child: Text(
              'IDENTIFY THE SCIENTIST',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFFAD16),
                fontSize: screenW * 0.055,
                fontWeight: FontWeight.bold,
                fontFamily: 'LilitaOne',
              ),
            ),
          ),

          Positioned(
            top: screenH * 0.05,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          Positioned(
            top: screenH * 0.564,
            left: screenW * 0.144,
            width: screenW * 0.71,
            child: TriviaButton(
              text: 'ALBERT EINSTEIN',
              width: screenW * 0.71,
              height: screenH * 0.078,
              state: _answer1State,
              onPressed: () => _checkAnswer(1),
            ),
          ),
          Positioned(
            top: screenH * 0.671,
            left: screenW * 0.143,
            width: screenW * 0.71,
            child: TriviaButton(
              text: 'CHARLES BABBAGE',
              width: screenW * 0.71,
              height: screenH * 0.078,
              state: _answer2State,
              onPressed: () => _checkAnswer(2),
            ),
          ),
          Positioned(
            top: screenH * 0.781,
            left: screenW * 0.133,
            width: screenW * 0.71,
            child: TriviaButton(
              text: 'ISAAC NEWTON',
              width: screenW * 0.71,
              height: screenH * 0.078,
              state: _answer3State,
              onPressed: () => _checkAnswer(3),
            ),
          ),
          Positioned(
            top: screenH * 0.888,
            left: screenW * 0.132,
            width: screenW * 0.71,
            child: TriviaButton(
              text: 'NIELS BOHR',
              width: screenW * 0.71,
              height: screenH * 0.078,
              state: _answer4State,
              onPressed: () => _checkAnswer(4),
            ),
          ),

          if (_showConfetti)
            const ConfettiEffect(
              duration: Duration(milliseconds: 1000),
            ),

          if (_showGoodJob)
            Center(
              child: Image.asset(
                'assets/images/pngs/GOOD JOB!.png',
                width: screenW * 0.8,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }
}
