import 'package:flutter/material.dart';
import '../../services/trivia_game_manager.dart';
import '../mainmenu_screen.dart';
import 'main_trivia_screen.dart';
import '../../services/game_service.dart';

class YouWonScreen extends StatefulWidget {
  final int totalPoints;
  const YouWonScreen({super.key, required this.totalPoints});

  @override
  State<YouWonScreen> createState() => _YouWonScreenState();
}

class _YouWonScreenState extends State<YouWonScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  int _gemsEarned = 0;
  int _coinsEarned = 0;
  bool _isPerfect = false;
  int _correct = 0;
  int _total = 0;

  // Entry animations
  late AnimationController _entryCtrl;
  late AnimationController _scoreCtrl;
  late AnimationController _rewardCtrl;
  late AnimationController _btnCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _titleScale;
  late Animation<double> _titleFade;
  late Animation<double> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _rewardFade;
  late Animation<double> _btnSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _calculateAndSaveRewards();
  }

  void _setupAnimations() {
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scoreCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _rewardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _titleScale = Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
    _titleFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn));

    _cardSlide = Tween(begin: 60.0, end: 0.0).animate(
        CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOutCubic));
    _cardFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeIn));

    _rewardFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _rewardCtrl, curve: Curves.easeIn));

    _btnSlide = Tween(begin: 40.0, end: 0.0).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOutCubic));

    _pulse = Tween(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  Future<void> _calculateAndSaveRewards() async {
    final gm = TriviaGameManager.instance;
    _gemsEarned = widget.totalPoints;
    _coinsEarned = gm.calculateCoins();
    _isPerfect = gm.isPerfectGame();
    _correct = gm.correctAnswers;
    _total = gm.questions.length;

    // Save Game Session directly to Laravel CMS via API
    await GameSessionService().saveTriviaSession(
      correctAnswers: _correct,
      wrongAnswers: gm.wrongAnswers,
      totalQuestions: _total,
      chancesUsed: gm.wrongAnswers,
      scoreEarned: _gemsEarned,
    );

    gm.endGame();
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Staggered animation sequence
    _entryCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _scoreCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _rewardCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _btnCtrl.forward();
  }

  _ResultTier get _tier {
    if (_total == 0) return _ResultTier.okay;
    final pct = _correct / _total;
    if (pct == 1.0) return _ResultTier.perfect;
    if (pct >= 0.7) return _ResultTier.great;
    if (pct >= 0.4) return _ResultTier.okay;
    return _ResultTier.tryAgain;
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _scoreCtrl.dispose();
    _rewardCtrl.dispose();
    _btnCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
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
            const Center(
                child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      );
    }

    final tier = _tier;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;

          return Stack(
            children: [
              // ── Background ──────────────────────────────────────
              Positioned.fill(
                child: Image.asset(
                  'assets/images/pngs/yellowbg.png',
                  fit: BoxFit.cover,
                ),
              ),

              // ── Dark gradient overlay for contrast ──────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha:0.10),
                        Colors.white60.withValues(alpha:0.35),
                        Colors.white70.withValues(alpha:0.55),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Content ─────────────────────────────────────────
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenW * 0.07,
                    vertical: screenH * 0.02,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: screenH * 0.03),

                      // ── TITLE BLOCK ────────────────────────────
                      AnimatedBuilder(
                        animation: _entryCtrl,
                        builder: (_, __) => Opacity(
                          opacity: _titleFade.value,
                          child: Transform.scale(
                            scale: _titleScale.value,
                            child: Column(
                              children: [
                                // Trophy / emoji icon with glow
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tier.glowColor.withValues(alpha:0.25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: tier.glowColor.withValues(alpha:0.5),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    tier.icon,
                                    style:
                                    TextStyle(fontSize: screenW * 0.17),
                                  ),
                                ),
                                SizedBox(height: screenH * 0.018),

                                // Result title with outline effect
                                _OutlinedText(
                                  text: tier.title,
                                  fontSize: screenW * 0.115,
                                  textColor: tier.color,
                                  outlineColor: Colors.black,
                                  outlineWidth: 3,
                                ),
                                SizedBox(height: screenH * 0.008),

                                // Subtitle
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha:0.35),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tier.subtitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: screenW * 0.042,
                                      color: Colors.white,
                                      fontFamily: 'LilitaOne',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: screenH * 0.035),

                      // ── SCORE CARD ─────────────────────────────
                      AnimatedBuilder(
                        animation: _scoreCtrl,
                        builder: (_, __) => Opacity(
                          opacity: _cardFade.value,
                          child: Transform.translate(
                            offset: Offset(0, _cardSlide.value),
                            child: _ScoreCard(
                              correct: _correct,
                              total: _total,
                              screenW: screenW,
                              screenH: screenH,
                              tierColor: tier.color,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: screenH * 0.025),

                      // ── REWARDS ROW ────────────────────────────
                      AnimatedBuilder(
                        animation: _rewardCtrl,
                        builder: (_, __) => Opacity(
                          opacity: _rewardFade.value,
                          child: Row(
                            children: [
                              Expanded(
                                child: _RewardCard(
                                  imagePath: 'assets/images/pngs/gem-green.png',
                                  value: '+$_gemsEarned',
                                  label: 'GEMS',
                                  cardColor: const Color(0xFF3D982D).withValues(alpha:0.3),
                                  borderColor: const Color(0xFF2ECC71),
                                  valueColor: const Color(0xFF2ECC71),
                                  screenW: screenW,
                                  screenH: screenH,
                                ),
                              ),
                              SizedBox(width: screenW * 0.04),
                              Expanded(
                                child: _RewardCard(
                                  imagePath: 'assets/images/pngs/coins.png',
                                  value: '+$_coinsEarned',
                                  label: 'COINS',
                                  cardColor: const Color(0xFFF4A700).withValues(alpha:0.3),
                                  borderColor: const Color(0xFFFFC200),
                                  valueColor: const Color(0xFFFFC200),
                                  screenW: screenW,
                                  screenH: screenH,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── PERFECT BONUS BANNER ───────────────────
                      if (_isPerfect) ...[
                        SizedBox(height: screenH * 0.018),
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Transform.scale(
                            scale: _pulse.value,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFAD00),
                                    Color(0xFFFF6B00)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha:0.5),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('⭐',
                                      style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PERFECT GAME BONUS!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'LilitaOne',
                                      fontSize: screenW * 0.042,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.white10,
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('⭐',
                                      style: TextStyle(fontSize: 20)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: screenH * 0.04),

                      // ── BUTTONS ────────────────────────────────
                      AnimatedBuilder(
                        animation: _btnCtrl,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _btnSlide.value),
                          child: Column(
                            children: [
                              // Play Again
                              _GameButton(
                                label: 'PLAY AGAIN',
                                gradientColors: const [
                                  Color(0xFFC86400),
                                  Color(0xFFDC9333),
                                ],
                                borderColor: const Color(0xFFE69600),
                                screenW: screenW,
                                screenH: screenH,
                                onTap: () {
                                  TriviaGameManager.instance.reset();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                        const MainTriviaScreen()),
                                  );
                                },
                              ),
                              SizedBox(height: screenH * 0.014),

                              // Back to Menu
                              _GameButton(
                                label: 'BACK TO MENU',
                                gradientColors: const [
                                  Color(0xFF644E45),
                                  Color(0xFF7A5B39),
                                ],
                                borderColor: Colors.white38,
                                screenW: screenW,
                                screenH: screenH,
                                onTap: () {
                                  TriviaGameManager.instance.reset();
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                        const MainMenuScreen()),
                                        (route) => false,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: screenH * 0.02),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── OUTLINED TEXT (stroke effect without black font) ──────────────────────────
class _OutlinedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color textColor;
  final Color outlineColor;
  final double outlineWidth;

  const _OutlinedText({
    required this.text,
    required this.fontSize,
    required this.textColor,
    required this.outlineColor,
    required this.outlineWidth,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'LilitaOne',
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
    );
    return Stack(
      children: [
        // Stroke layer
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth * 2
              ..color = outlineColor,
          ),
        ),
        // Fill layer
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(color: textColor),
        ),
      ],
    );
  }
}

// ── SCORE CARD ─────────────────────────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final int correct;
  final int total;
  final double screenW;
  final double screenH;
  final Color tierColor;

  const _ScoreCard({
    required this.correct,
    required this.total,
    required this.screenW,
    required this.screenH,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: screenH * 0.032,
        horizontal: screenW * 0.06,
      ),
      decoration: BoxDecoration(
        // Dark semi-transparent card — big contrast boost
        color: Colors.white.withValues(alpha:0.25),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tierColor.withValues(alpha:0.8), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha:0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
          color: tierColor.withValues(alpha:0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'YOUR SCORE',
            style: TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: screenW * 0.035,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
          SizedBox(height: screenH * 0.008),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$correct',
                  style: TextStyle(
                    fontFamily: 'LilitaOne',
                    fontSize: screenW * 0.22,
                    color: tierColor,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: tierColor.withValues(alpha:0.5),
                        blurRadius: 20,
                      )
                    ],
                  ),
                ),
                TextSpan(
                  text: ' / $total',
                  style: TextStyle(
                    fontFamily: 'LilitaOne',
                    fontSize: screenW * 0.13,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'CORRECT ANSWERS',
            style: TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: screenW * 0.033,
              color: Colors.white,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── REWARD CARD ────────────────────────────────────────────────────────────────
class _RewardCard extends StatelessWidget {
  final String imagePath;
  final String value;
  final String label;
  final Color cardColor;
  final Color borderColor;
  final Color valueColor;
  final double screenW;
  final double screenH;

  const _RewardCard({
    required this.imagePath,
    required this.value,
    required this.label,
    required this.cardColor,
    required this.borderColor,
    required this.valueColor,
    required this.screenW,
    required this.screenH,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: screenH * 0.022,
        horizontal: screenW * 0.03,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha:0.3),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha:0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            imagePath,
            width: screenW * 0.13,
            height: screenW * 0.13,
            fit: BoxFit.contain,
          ),
          SizedBox(height: screenH * 0.008),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: screenW * 0.072,
              color: valueColor,
              shadows: [
                Shadow(
                  color: borderColor.withValues(alpha:0.6),
                  blurRadius: 8,
                )
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: screenW * 0.03,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── GAME BUTTON ────────────────────────────────────────────────────────────────
class _GameButton extends StatefulWidget {
  final String label;
  final List<Color> gradientColors;
  final Color borderColor;
  final double screenW;
  final double screenH;
  final VoidCallback onTap;

  const _GameButton({
    required this.label,
    required this.gradientColors,
    required this.borderColor,
    required this.screenW,
    required this.screenH,
    required this.onTap,
  });

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: widget.screenH * 0.019),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[0].withValues(alpha:0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: widget.screenW * 0.062,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── RESULT TIERS ───────────────────────────────────────────────────────────────
enum _ResultTier { perfect, great, okay, tryAgain }

extension _ResultTierExt on _ResultTier {
  String get icon => switch (this) {
    _ResultTier.perfect => '🏆',
    _ResultTier.great => '🎉',
    _ResultTier.okay => '👍',
    _ResultTier.tryAgain => '😅',
  };

  String get title => switch (this) {
    _ResultTier.perfect => 'PERFECT!',
    _ResultTier.great => 'GREAT JOB!',
    _ResultTier.okay => 'NOT BAD!',
    _ResultTier.tryAgain => 'KEEP TRYING!',
  };

  String get subtitle => switch (this) {
    _ResultTier.perfect => 'You answered everything correctly!',
    _ResultTier.great => 'You really know your stuff!',
    _ResultTier.okay => 'Room to grow — keep playing!',
    _ResultTier.tryAgain => 'Practice makes perfect!',
  };

  Color get color => switch (this) {
    _ResultTier.perfect => const Color(0xFFFFD700),
    _ResultTier.great => const Color(0xFFFF8421),
    _ResultTier.okay => const Color(0xFF64B5F6),
    _ResultTier.tryAgain => const Color(0xFFFF6B6B),
  };

  Color get glowColor => switch (this) {
    _ResultTier.perfect => const Color(0xFFFFD700),
    _ResultTier.great => const Color(0xFFFF8421),
    _ResultTier.okay => const Color(0xFF64B5F6),
    _ResultTier.tryAgain => const Color(0xFFFF6B6B),
  };
}