import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({super.key});

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class _MiniGameScreenState extends State<MiniGameScreen> {
  int _score = 0;
  int _timeLeft = 30;
  Timer? _timer;
  List<Bubble> _bubbles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          _spawnBubble();
        } else {
          _timer?.cancel();
          _showGameOver();
        }
      });
    });
  }

  void _spawnBubble() {
    setState(() {
      _bubbles.add(Bubble(
        id: DateTime.now().millisecondsSinceEpoch,
        x: _random.nextDouble() * 300,
        y: _random.nextDouble() * 500,
        color: Colors.blue.withOpacity(0.7),
      ));
    });
  }

  void _popBubble(int id) {
    setState(() {
      _bubbles.removeWhere((b) => b.id == id);
      _score += 10;
    });
  }

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Text('Your Score: $_score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Exit game
            },
            child: const Text('Exit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _score = 0;
                _timeLeft = 30;
                _bubbles.clear();
              });
              _startGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          // Bubbles
          ..._bubbles.map((bubble) => Positioned(
            left: bubble.x,
            top: bubble.y,
            child: GestureDetector(
              onTap: () => _popBubble(bubble.id),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: bubble.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(child: Icon(Icons.bolt, color: Colors.yellow)),
              ),
            ),
          )),

          // UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Score: $_score', 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('Time: $_timeLeft', 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Bubble {
  final int id;
  final double x;
  final double y;
  final Color color;
  Bubble({required this.id, required this.x, required this.y, required this.color});
}
