import 'package:flutter/material.dart';
import '../../services/trivia_game_manager.dart';
import '../../services/userprofile_service.dart';
import '../mainmenu_screen.dart';
import 'main_trivia_screen.dart';

class YouWonScreen extends StatefulWidget {
  const YouWonScreen({super.key});

  @override
  State<YouWonScreen> createState() => _YouWonScreenState();
}

class _YouWonScreenState extends State<YouWonScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateAndSaveRewards();
  }

  Future<void> _calculateAndSaveRewards() async {
    final gameManager = TriviaGameManager.instance;

    // Calculate rewards
    final gemsEarned = gameManager.calculateGems();
    final coinsEarned = gameManager.calculateCoins();
    final isPerfectGame = gameManager.isPerfectGame();

    // Save rewards to Firebase
    try {
      final profileService = UserProfileService();

      // Add coins
      await profileService.addCoins(
        amount: coinsEarned,
        reason: isPerfectGame
            ? 'Perfect Trivia Game (3/3 correct)'
            : 'Trivia Game Completed (${gameManager.correctAnswers}/3 correct)',
      );

      // Update game stats (gems are stored in totalScore)
      await profileService.updateGameStats(
        gamesPlayed: 1,
        gamesWon: 1,
        totalScore: gemsEarned,
      );

      debugPrint('✅ Rewards saved: $gemsEarned gems, $coinsEarned coins');
    } catch (e) {
      debugPrint('❌ Error saving rewards: $e');
    }

    // End game
    gameManager.endGame();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;

    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/pngs/yellowbg.png',
                fit: BoxFit.cover,
              ),
            ),
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pngs/yellowbg.png',
              fit: BoxFit.cover,
            ),
          ),

          // You Won image (YOUR ORIGINAL)
          Positioned(
            top: screenH * 0.05,
            left: screenW * 0.05,
            right: screenW * 0.05,
            height: screenH * 0.75,
            child: Image.asset(
              'assets/images/pngs/you_won.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text(
                  'YOU WON!',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'LilitaOne',
                  ),
                ),
              ),
            ),
          ),

          // PLAY AGAIN button (YOUR ORIGINAL)
          Positioned(
            bottom: screenH * 0.12,
            left: screenW * 0.18,
            right: screenW * 0.18,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CD964),
                padding: EdgeInsets.symmetric(
                  vertical: screenH * 0.02,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
              ),
              onPressed: () {
                TriviaGameManager.instance.reset();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainTriviaScreen()),
                );
              },
              child: Text(
                'PLAY AGAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenW * 0.075,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'LilitaOne',
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(2, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // HOME button (YOUR ORIGINAL)
          Positioned(
            bottom: screenH * 0.04,
            left: screenW * 0.3,
            right: screenW * 0.3,
            child: TextButton(
              onPressed: () {
                TriviaGameManager.instance.reset();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainMenuScreen()),
                      (route) => false,
                );
              },
              child: const Text(
                'BACK TO MENU',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'LilitaOne',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}