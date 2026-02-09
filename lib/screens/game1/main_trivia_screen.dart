import 'package:flutter/material.dart';
import '../widgets/trivia_button.dart';
import '../widgets/confetti_effect.dart';
import 'trivia2_screen.dart';

class MainTriviaScreen extends StatefulWidget {
  const MainTriviaScreen({super.key});

  @override
  State<MainTriviaScreen> createState() => _MainTriviaScreenState();
}

class _MainTriviaScreenState extends State<MainTriviaScreen> {
  AnswerState _answer1State = AnswerState.idle;
  AnswerState _answer2State = AnswerState.idle; // CHARLES BABBAGE (correct)
  AnswerState _answer3State = AnswerState.idle;
  AnswerState _answer4State = AnswerState.idle;
  bool _showConfetti = false;
  bool _showGoodJob = false;

  void _checkAnswer(int answerIndex) {
    if (answerIndex == 2 && _answer2State == AnswerState.idle) {
      setState(() {
        _answer1State = AnswerState.idle;
        _answer2State = AnswerState.correct;
        _answer3State = AnswerState.idle;
        _answer4State = AnswerState.idle;
        _showConfetti = true;
        _showGoodJob = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Trivia2Screen()),
        );
      });
      return;
    }

    setState(() {
      switch (answerIndex) {
        case 1:
          if (_answer1State == AnswerState.idle) _answer1State = AnswerState.wrong;
          break;
        case 3:
          if (_answer3State == AnswerState.idle) _answer3State = AnswerState.wrong;
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

          // Scientist Image
          Positioned(
            top: screenH * 0.280,
            left: screenW * 0.14,
            width: screenW * 0.72,
            height: screenH * 0.243,
            child: Image.asset(
              'assets/images/pngs/question_bottom.png',
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
            top: screenH * 0.01,
            left: screenW * -0.01,
            width: screenW * 0.21,
            height: screenH * 0.048,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Image.asset(
                'assets/images/pngs/back_btn.png',
                fit: BoxFit.fill,
              ),
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
