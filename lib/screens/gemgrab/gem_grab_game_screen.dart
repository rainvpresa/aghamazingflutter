import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/userprofile_service.dart';

class GemGrabGameScreen extends StatefulWidget {
  const GemGrabGameScreen({Key? key}) : super(key: key);

  @override
  State<GemGrabGameScreen> createState() => _GemGrabGameScreenState();
}

class _GemGrabGameScreenState extends State<GemGrabGameScreen> {
  int score = 0;
  int timeLeft = 30;
  bool isGameActive = false;
  Timer? gameTimer;
  List<FallingGem> gems = [];
  Random random = Random();

  int playsRemaining = 3;
  bool isLoading = true;

  // Screen dimensions
  late double screenHeight;

  @override
  void initState() {
    super.initState();
    loadPlaysRemaining();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }
// ---------------------- DEBUG RESET PLAY -------------------------------------
  Future<void> _resetPlaysDebug() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().substring(0, 10);

    await prefs.setString('gem_grab_date', today);
    await prefs.setInt('gem_grab_plays', 3);

    setState(() {
      playsRemaining = 3;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Plays reset to 3!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> loadPlaysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().substring(0, 10);
    final savedDate = prefs.getString('gem_grab_date') ?? '';

    if (savedDate != today) {
      await prefs.setString('gem_grab_date', today);
      await prefs.setInt('gem_grab_plays', 3);
      setState(() {
        playsRemaining = 3;
        isLoading = false;
      });
    } else {
      final plays = prefs.getInt('gem_grab_plays') ?? 3;
      setState(() {
        playsRemaining = plays;
        isLoading = false;
      });
    }
  }

  Future<void> decrementPlays() async {
    final prefs = await SharedPreferences.getInstance();
    final newPlays = playsRemaining - 1;
    await prefs.setInt('gem_grab_plays', newPlays);
    setState(() {
      playsRemaining = newPlays;
    });
  }

  void startGame() {
    if (playsRemaining <= 0) {
      showNoPlaysDialog();
      return;
    }

    decrementPlays();

    setState(() {
      score = 0;
      timeLeft = 30;
      isGameActive = true;
      gems.clear();
    });

    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
        if (timeLeft <= 0) {
          endGame();
        }
      });
    });

    scheduleNextGem();
  }

  void scheduleNextGem() {
    if (!isGameActive) return;

    final randomDelay = 300 + random.nextInt(900);

    Future.delayed(Duration(milliseconds: randomDelay), () {
      if (isGameActive && mounted) {
        spawnGem();
        scheduleNextGem();
      }
    });
  }

  void spawnGem() {
    final screenWidth = MediaQuery.of(context).size.width;

    // Random speed: 2 to 5 seconds for falling (slower = easier to see)
    final randomSpeed = 2.0 + (random.nextDouble() * 3.0);

    final gemId = DateTime.now().millisecondsSinceEpoch.toString() + random.nextInt(10000).toString();

    setState(() {
      gems.add(FallingGem(
        id: gemId,
        left: random.nextDouble() * (screenWidth - 60),
        points: random.nextInt(3) + 1, // 1-3 points
        fallDuration: randomSpeed,
        spawnTime: DateTime.now(),
      ));
    });

    // Remove gem ONLY after it reaches the bottom + some buffer
    // Calculate total time = fall duration + buffer for off-screen
    final removalTime = (randomSpeed * 1000).toInt() + 1000;

    Future.delayed(Duration(milliseconds: removalTime), () {
      if (mounted) {
        setState(() {
          gems.removeWhere((gem) => gem.id == gemId);
        });
      }
    });
  }

  void collectGem(String gemId, int points) {
    setState(() {
      gems.removeWhere((gem) => gem.id == gemId);
      score += points;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  void endGame() async {
    gameTimer?.cancel();
    setState(() {
      isGameActive = false;
      gems.clear();
    });

    final int coinsEarned = (score / 10).floor();
    final int gemsEarned = score;

    try {
      final profileService = UserProfileService();

      await profileService.addCoins(
        amount: coinsEarned,
        reason: 'Gem Grab game - Score: $score',
      );

      await profileService.updateGameStats(
        gamesPlayed: 1,
        totalScore: gemsEarned,
      );

      debugPrint('✅ Rewards saved: $coinsEarned coins, $gemsEarned gems');
    } catch (e) {
      debugPrint('❌ Error saving rewards: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Text(
          'Game Over!',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Score: $score',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '+$coinsEarned Bubble Power',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.diamond, color: Colors.pink, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '+$gemsEarned Gems',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gamepad, color: Colors.pink, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Plays Remaining: $playsRemaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (playsRemaining > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                startGame();
              },
              child: const Text('Play Again', style: TextStyle(color: Colors.blue)),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Main Menu', style: TextStyle(color: Colors.pink)),
          ),
        ],
      ),
    );
  }

  void showNoPlaysDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Text(
          '⏰ Out of Plays',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, size: 60, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              "You've used all 3 plays for today!",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Come back tomorrow for more! 🎮',
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Colors.pink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              GestureDetector(
                onLongPress: _resetPlaysDebug,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.diamond, color: Colors.pink),
                            const SizedBox(width: 8),
                            Text(
                              '$score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              '$timeLeft',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Plays Remaining Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: playsRemaining > 0
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: playsRemaining > 0 ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.gamepad,
                        color: playsRemaining > 0 ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Plays Today: $playsRemaining/3',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Game Area - FIXED: Use Stack properly
              Expanded(
                child: Stack(
                  children: [
                    // Falling gems - rendered first so they can be tapped
                    ...gems.map((gem) => GemWidget(
                      key: ValueKey(gem.id),
                      gem: gem,
                      screenHeight: MediaQuery.of(context).size.height,
                      onTap: () => collectGem(gem.id, gem.points),
                    )),

                    // Start/Instructions overlay - on top
                    if (!isGameActive)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '💎 GEM GRAB 💎',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Tap the falling gems\nto collect them!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '⚡ Watch out!\nGems fall at different speeds!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            ElevatedButton(
                              onPressed: playsRemaining > 0 ? startGame : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: playsRemaining > 0
                                    ? Colors.pink
                                    : Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                playsRemaining > 0
                                    ? 'START GAME'
                                    : 'NO PLAYS LEFT',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (playsRemaining <= 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  'Come back tomorrow! 🌅',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FallingGem {
  final String id;
  final double left;
  final int points;
  final double fallDuration; // in seconds
  final DateTime spawnTime;

  FallingGem({
    required this.id,
    required this.left,
    required this.points,
    required this.fallDuration,
    required this.spawnTime,
  });
}

class GemWidget extends StatefulWidget {
  final FallingGem gem;
  final double screenHeight;
  final VoidCallback onTap;

  const GemWidget({
    Key? key,
    required this.gem,
    required this.screenHeight,
    required this.onTap,
  }) : super(key: key);

  @override
  State<GemWidget> createState() => _GemWidgetState();
}

class _GemWidgetState extends State<GemWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fallAnimation;
  late AnimationController _tapController;
  late Animation<double> _tapScale;
  late Animation<double> _tapOpacity;

  bool _tapped = false;

  @override
  void initState() {
    super.initState();

    // Falling animation
    _controller = AnimationController(
      duration: Duration(milliseconds: (widget.gem.fallDuration * 1000).toInt()),
      vsync: this,
    );

    _fallAnimation = Tween<double>(begin: -100, end: widget.screenHeight).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.forward();

    // Tap animation (POP effect)
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Scale: 1.0 -> 1.3 (grows) -> 0.0 (disappears)
    _tapScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOut),
    );

    // Opacity: 1.0 -> 0.0 (fades out)
    _tapOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _tapController.dispose();
    super.dispose();
  }

  Color getGemColor(int points) {
    switch (points) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      case 3:
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  void _onTap() {
    if (_tapped) return;

    setState(() {
      _tapped = true;
    });

    HapticFeedback.mediumImpact();

    _tapController.forward().then((_) {
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fallAnimation,
      builder: (context, child) {
        return Positioned(
          left: widget.gem.left,
          top: _fallAnimation.value,
          child: GestureDetector(
            onTap: _onTap,
            child: ScaleTransition(
              scale: _tapScale,
              child: FadeTransition(
                opacity: _tapOpacity,
                child: Transform.scale(
                  scale: _tapped ? 1.15 : 1.0, // Initial grow
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          getGemColor(widget.gem.points).withOpacity(0.8),
                          getGemColor(widget.gem.points),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: getGemColor(widget.gem.points).withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.diamond,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}