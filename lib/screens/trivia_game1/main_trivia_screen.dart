import 'package:flutter/material.dart';
import '../../widgets/trivia_button.dart';
import '../../widgets/confetti_effect.dart';
import '../../services/trivia_game_manager.dart';
import '../../services/energy_manager.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkEnergyAndStartGame();
  }

  Future<void> _checkEnergyAndStartGame() async {
    const int energyCost = 10;

    try {
      final currentEnergy = await EnergyManager.instance.getCurrentEnergy();
      
      if (currentEnergy < energyCost) {
        if (!mounted) return;

        // Not enough energy - show dialog and go back
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Not Enough Energy'),
            content: Text('You need $energyCost energy to play.\nYou have: $currentEnergy'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Exit trivia
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Deduct energy
      final success = await EnergyManager.instance.useEnergy(amount: energyCost);
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to consume energy')),
        );
        Navigator.of(context).pop();
        return;
      }

      // Start game logic
      TriviaGameManager.instance.startGame();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error starting game: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _checkAnswer(int answerIndex) {
    if (answerIndex == 2 && _answer2State == AnswerState.idle) {
      // Correct answer
      TriviaGameManager.instance.recordCorrectAnswer();
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

    // Wrong answer - record it
    TriviaGameManager.instance.recordWrongAnswer();

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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
              onTap: () {
                TriviaGameManager.instance.reset(); // Reset game if user quits
                Navigator.pop(context);
              },
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
