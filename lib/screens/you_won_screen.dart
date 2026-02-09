import 'package:flutter/material.dart';
import 'main_trivia_screen.dart';

class YouWonScreen extends StatelessWidget {
  const YouWonScreen({super.key});

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

          // You Won image
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

          // PLAY AGAIN button
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
          
          // HOME button
          Positioned(
            bottom: screenH * 0.04,
            left: screenW * 0.3,
            right: screenW * 0.3,
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/mainmenu', (route) => false),
              child: const Text(
                'BACK TO MENU',
                style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'LilitaOne'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
