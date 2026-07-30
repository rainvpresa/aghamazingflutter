import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../../services/sound_manager.dart'; // 🔊 added
import '../../widgets/game_quit_handler.dart';
import '../../services/game_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THEME TOKENS
// ─────────────────────────────────────────────────────────────────────────────
class _GG {
  static const purple      = Color(0xFF9B2FFF);
  static const purpleDark  = Color(0xFF5A0FBB);
  static const orange      = Color(0xFFFF8C00);
  static const orangeLight = Color(0xFFFFB74D);
  static const green       = Color(0xFF39E14B);
  static const greenDark   = Color(0xFF1CA12A);
  static const pink        = Color(0xFFFF3D8B);
  static const pinkLight   = Color(0xFFFF85B3);
  static const red         = Color(0xFFFF3B3B);
  static const gold        = Color(0xFFFFD700);
  static const white       = Colors.white;
  static const black       = Colors.black;
  static const panelBg     = Color(0xFF1E0B3A);

  static const String fontFamily = 'LilitaOne';

  static List<BoxShadow> glow(Color c, {double spread = 4, double blur = 14}) => [
    BoxShadow(color: c.withValues(alpha:0.75), blurRadius: blur, spreadRadius: spread),
    BoxShadow(color: c.withValues(alpha:0.35), blurRadius: blur * 2.2, spreadRadius: spread * 0.5),
  ];

  static Border glowBorder(Color c, {double width = 2.5}) =>
      Border.all(color: c, width: width);

  static LinearGradient panelGrad(Color top, Color bot) =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [top, bot]);

  static LinearGradient get glossOverlay => const LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.55],
  );

  static TextStyle get scoreLabel => const TextStyle(
    fontFamily: fontFamily,
    color: white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5,
    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 4, offset: Offset(1, 2))],
  );

  static TextStyle get playsLabel => const TextStyle(
    fontFamily: fontFamily,
    color: white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4,
  );

  static TextStyle get btnLabel => const TextStyle(
    fontFamily: fontFamily,
    color: white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5,
    shadows: [Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 3))],
  );
}

class _SleepingLottie extends StatefulWidget {
  final double size;
  const _SleepingLottie({this.size = 200});

  @override
  State<_SleepingLottie> createState() => _SleepingLottieState();
}

class _SleepingLottieState extends State<_SleepingLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          'assets/animations/sleeping.json',
          controller: _ctrl,
          frameRate: FrameRate.max,
          onLoaded: (composition) {
            _ctrl
              ..duration = composition.duration
              ..repeat();
          },
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}

class _GlossyPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final Color iconColor;

  const _GlossyPill({
    required this.icon, required this.label,
    required this.accent, this.iconColor = _GG.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: _GG.panelGrad(_GG.panelBg.withValues(alpha:0.92), _GG.panelBg),
        border: _GG.glowBorder(accent),
        boxShadow: _GG.glow(accent, blur: 12, spread: 1),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Container(decoration: BoxDecoration(gradient: _GG.glossOverlay)),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: iconColor, size: 18,
              shadows: [Shadow(color: iconColor.withValues(alpha:0.8), blurRadius: 8)]),
          const SizedBox(width: 7),
          Text(label, style: _GG.scoreLabel),
        ]),
      ]),
    );
  }
}

class _ArcadeButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color top;
  final Color bottom;
  final Color shadow;
  final IconData? icon;

  const _ArcadeButton({
    required this.label, required this.onTap,
    this.top    = _GG.green,
    this.bottom = _GG.greenDark,
    this.shadow = _GG.green,
    this.icon,
  });

  @override
  State<_ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<_ArcadeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [widget.top, widget.bottom],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.bottom.withValues(alpha:0.9),
                blurRadius: 0, spreadRadius: 0,
                offset: Offset(0, _pressed ? 1 : 5),
              ),
              ..._GG.glow(widget.shadow, blur: 18, spread: _pressed ? 0 : 2),
            ],
            border: Border.all(color: _GG.white.withValues(alpha:0.25), width: 1.5),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Positioned(
              top: 0, left: 0, right: 0, bottom: 14,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [_GG.white.withValues(alpha:0.32), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: _GG.white, size: 22,
                        shadows: [Shadow(color: _GG.black.withValues(alpha:0.4), blurRadius: 4)]),
                    const SizedBox(width: 10),
                  ],
                  Text(widget.label, style: _GG.btnLabel),
                ]),
          ]),
        ),
      ),
    );
  }
}

class _PlaysDots extends StatelessWidget {
  final int remaining;
  final int total;
  const _PlaysDots({required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < remaining;
        final color = remaining > 0 ? _GG.green : _GG.red;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: filled ? 12 : 10, height: filled ? 12 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : color.withValues(alpha:0.22),
              border: Border.all(color: color.withValues(alpha:0.7), width: 1.5),
              boxShadow: filled ? _GG.glow(color, blur: 6, spread: 0) : null,
            ),
          ),
        );
      }),
    );
  }
}

class _GemGrabDialog extends StatelessWidget {
  final String title;
  final Color  titleColor;
  final IconData icon;
  final Color  iconColor;
  final Widget content;
  final List<Widget> actions;

  const _GemGrabDialog({
    required this.title,      required this.titleColor,
    required this.icon,       required this.iconColor,
    required this.content,    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF2A1050), Color(0xFF14082A)],
          ),
          border: Border.all(color: _GG.purple.withValues(alpha:0.6), width: 2),
          boxShadow: [
            ..._GG.glow(_GG.purple, blur: 30, spread: 4),
            const BoxShadow(color: Color(0xCC000000), blurRadius: 40, offset: Offset(0, 20)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(children: [
            Positioned(top: 0, left: 0, right: 0, height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [_GG.white.withValues(alpha:0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _GG.panelGrad(iconColor.withValues(alpha:0.25), iconColor.withValues(alpha:0.08)),
                    border: Border.all(color: iconColor.withValues(alpha:0.6), width: 2),
                    boxShadow: _GG.glow(iconColor, blur: 18, spread: 2),
                  ),
                  child: Icon(icon, color: iconColor, size: 44,
                      shadows: [Shadow(color: iconColor, blurRadius: 12)]),
                ),
                const SizedBox(height: 14),
                Text(title, style: TextStyle(
                  fontFamily: _GG.fontFamily,
                  color: titleColor, fontSize: 24, fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: titleColor.withValues(alpha:0.5), blurRadius: 12)],
                )),
                const SizedBox(height: 18),
                content,
                const SizedBox(height: 20),
                ...actions,
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GemGrabLogoFallback extends StatelessWidget {
  final double fontSize;
  const _GemGrabLogoFallback({this.fontSize = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: _GG.panelGrad(_GG.purple, _GG.purpleDark),
        border: Border.all(color: _GG.pinkLight, width: 3),
        boxShadow: _GG.glow(_GG.purple, blur: 24, spread: 3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.diamond_rounded, color: _GG.pinkLight, size: fontSize,
            shadows: const [Shadow(color: _GG.pink, blurRadius: 10)]),
        const SizedBox(width: 10),
        Text('GEM GRAB!', style: TextStyle(
          fontFamily: _GG.fontFamily,
          color: _GG.white, fontSize: fontSize, fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [Shadow(color: _GG.pink.withValues(alpha:0.8), blurRadius: 12)],
        )),
        const SizedBox(width: 10),
        Icon(Icons.diamond_rounded, color: _GG.gold, size: fontSize * 0.8,
            shadows: const [Shadow(color: _GG.gold, blurRadius: 10)]),
      ]),
    );
  }
}

class _WarningChip extends StatelessWidget {
  final bool compact;
  const _WarningChip({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _GG.panelGrad(
            _GG.orange.withValues(alpha:0.22), _GG.orange.withValues(alpha:0.08)),
        border: Border.all(color: _GG.orange.withValues(alpha:0.7), width: 2),
        boxShadow: _GG.glow(_GG.orange, blur: 10, spread: 0),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flash_on_rounded, color: _GG.orange,
            size: compact ? 16 : 20,
            shadows: const [Shadow(color: _GG.orange, blurRadius: 8)]),
        const SizedBox(width: 6),
        Text('Watch out! Gems fall\nat different speeds!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: _GG.fontFamily,
                fontSize: compact ? 11 : 13, color: _GG.orange,
                fontWeight: FontWeight.w800, height: 1.3)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GemGrabGameScreen extends StatefulWidget {
  const GemGrabGameScreen({super.key});

  @override
  State<GemGrabGameScreen> createState() => _GemGrabGameScreenState();
}

class _GemGrabGameScreenState extends State<GemGrabGameScreen>
    with TickerProviderStateMixin, GameQuitHandler {
  int score     = 0;
  int timeLeft  = 30;
  bool isGameActive = false;
  Timer? gameTimer;
  List<FallingGem> gems = [];
  Random random = Random();

  int  playsRemaining = 3;
  bool isLoading      = true;

  double _gameAreaWidth  = 0;
  double _gameAreaHeight = 0;

  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double>   _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 🔊 Keep menu BGM playing — ensures menu music is active even if another
    // screen (e.g. scan screen) switched to game music before arriving here.
    SoundManager.instance.playMenuMusic();
    loadPlaysRemaining();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _floatController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _pulseController.dispose();
    _floatController.dispose();
    // 🔊 No music call here — menu music is already playing and continues
    // seamlessly back in the main menu without any restart.
    super.dispose();
  }

  Future<void> loadPlaysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().substring(0, 10);
    final savedDate = prefs.getString('gem_grab_date') ?? '';
    if (savedDate != today) {
      await prefs.setString('gem_grab_date', today);
      await prefs.setInt('gem_grab_plays', 3);
      setState(() { playsRemaining = 3; isLoading = false; });
    } else {
      setState(() {
        playsRemaining = prefs.getInt('gem_grab_plays') ?? 3;
        isLoading = false;
      });
    }
  }

  Future<void> decrementPlays() async {
    final prefs = await SharedPreferences.getInstance();
    final n = playsRemaining - 1;
    await prefs.setInt('gem_grab_plays', n);
    setState(() => playsRemaining = n);
  }

  // ── QUIT LOGIC ─────────────────────────────────────────────────────────────
  void _onBackPressed() {
    if (!isGameActive) {
      Navigator.of(context).pop();
      return;
    }

    gameTimer?.cancel();
    setState(() => isGameActive = false);

    showQuitConfirmDialog(
      context,
      onConfirm: _doQuit,
      onCancel: _resumeGame,
    );
  }

  void _resumeGame() {
    if (!mounted) return;
    setState(() => isGameActive = true);
    gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => timeLeft--);
        if (timeLeft <= 0) endGame();
      }
    });
    scheduleNextGem();
  }

  void _doQuit() {
    gameTimer?.cancel();
    setState(() {
      isGameActive = false;
      gems.clear();
    });
    endGame();
  }

  // ── GAME LOGIC ─────────────────────────────────────────────────────────────
  void startGame() {
    if (playsRemaining <= 0) { showNoPlaysDialog(); return; }
    decrementPlays();
    setState(() { score = 0; timeLeft = 30; isGameActive = true; gems.clear(); });
    gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() { timeLeft--; if (timeLeft <= 0) endGame(); });
      }
    });
    scheduleNextGem();
  }

  void scheduleNextGem() {
    if (!isGameActive) return;
    Future.delayed(Duration(milliseconds: 300 + random.nextInt(900)), () {
      if (isGameActive && mounted) { spawnGem(); scheduleNextGem(); }
    });
  }

  void spawnGem() {
    final sw = _gameAreaWidth > 0 ? _gameAreaWidth : 300;
    final speed = 2.0 + random.nextDouble() * 3.0;
    final id = DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(10000).toString();
    setState(() {
      gems.add(FallingGem(
        id: id,
        left: random.nextDouble() * (sw - 60),
        points: random.nextInt(3) + 1,
        fallDuration: speed,
        spawnTime: DateTime.now(),
      ));
    });
    Future.delayed(Duration(milliseconds: (speed * 1000).toInt() + 1000), () {
      if (mounted) setState(() => gems.removeWhere((g) => g.id == id));
    });
  }

  void collectGem(String gemId, int points) {
    setState(() { gems.removeWhere((g) => g.id == gemId); score += points; });
    HapticFeedback.mediumImpact();
  }

  void endGame() async {
    gameTimer?.cancel();
    setState(() { isGameActive = false; gems.clear(); });

    final coinsEarned = (score / 10).floor();
    final gemsEarned  = score;

    try {
      // Single call to Laravel backend — handles stats, coins, and session logging!
      await GameSessionService().saveGemGrabSession(
        scoreEarned: score,
        gemsCollected: gemsEarned,
        coinsEarned: coinsEarned,
        playsRemaining: playsRemaining,
        durationSeconds: 30,
      );
    } catch (e) {
      debugPrint('❌ Error saving Gem Grab session: $e');
    }

    if (mounted) _showGameOverDialog(coinsEarned, gemsEarned);
  }

  // ── DIALOGS ────────────────────────────────────────────────────────────────
  void _showGameOverDialog(int coins, int gemsEarned) {
    // 🔧 FIX: use dialogCtx (dialog's own BuildContext) for the first pop so
    // the dialog is dismissed correctly, then use the game screen's `context`
    // for the second pop to return to the main menu.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _GemGrabDialog(
        title: 'GAME OVER',
        titleColor: _GG.gold,
        icon: Icons.stars_rounded,
        iconColor: _GG.gold,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogStat('Score',       '$score',      Icons.diamond_rounded,  _GG.pink),
          const SizedBox(height: 10),
          _dialogStat('+Coins', '$coins',   Icons.star_rounded,      _GG.gold),
          const SizedBox(height: 10),
          _dialogStat('+Gems',       '$gemsEarned', Icons.diamond,          _GG.purple),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Plays left: ', style: TextStyle(
              fontFamily: _GG.fontFamily, color: _GG.white, fontSize: 13,
            )),
            _PlaysDots(remaining: playsRemaining, total: 3),
          ]),
        ]),
        actions: [
          if (playsRemaining > 0) ...[
            _ArcadeButton(
                label: 'PLAY AGAIN', icon: Icons.replay,
                onTap: () {
                  Navigator.of(dialogCtx).pop(); // ✅ dismiss dialog
                  startGame();
                },
                top: _GG.green, bottom: _GG.greenDark, shadow: _GG.green),
            const SizedBox(height: 8),
          ],
          _ArcadeButton(
              label: 'MAIN MENU', icon: Icons.home_rounded,
              onTap: () {
                Navigator.of(dialogCtx).pop(); // ✅ dismiss dialog first
                Navigator.of(context).pop();   // ✅ then pop game screen → back to main menu
              },
              top: _GG.purple, bottom: _GG.purpleDark, shadow: _GG.purple),
        ],
      ),
    );
  }

  void showNoPlaysDialog() {
    // 🔧 Same fix: use dialogCtx for the dialog pop, context for the game pop.
    showDialog(
      context: context,
      builder: (dialogCtx) => _GemGrabDialog(
        title: 'OUT OF PLAYS',
        titleColor: _GG.orange,
        icon: Icons.hourglass_bottom_rounded,
        iconColor: _GG.orange,
        content: const Column(mainAxisSize: MainAxisSize.min, children: [
          Text("You've used all 3 plays for today!",
              style: TextStyle(
                fontFamily: _GG.fontFamily,
                color: _GG.white, fontSize: 16, fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center),
          SizedBox(height: 8),
          Text('Come back tomorrow for more! 🌅',
              style: TextStyle(
                fontFamily: _GG.fontFamily,
                color: Color(0xAAFFFFFF), fontSize: 14,
              ),
              textAlign: TextAlign.center),
          SizedBox(height: 12),
          _PlaysDots(remaining: 0, total: 3),
        ]),
        actions: [
          _ArcadeButton(
              label: 'OK',
              onTap: () {
                Navigator.of(dialogCtx).pop(); // ✅ dismiss dialog first
                Navigator.of(context).pop();   // ✅ then pop game screen → back to main menu
              },
              top: _GG.purple, bottom: _GG.purpleDark, shadow: _GG.purple),
        ],
      ),
    );
  }

  Widget _dialogStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha:0.12),
        border: Border.all(color: color.withValues(alpha:0.45), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(icon, color: color, size: 18,
              shadows: [Shadow(color: color, blurRadius: 8)]),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              fontFamily: _GG.fontFamily,
              color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        Text(value, style: _GG.scoreLabel.copyWith(fontSize: 16)),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _onBackPressed,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _GG.panelGrad(
                  _GG.panelBg.withValues(alpha:0.9),
                  _GG.panelBg,
                ),
                border: _GG.glowBorder(_GG.purple.withValues(alpha:0.8)),
                boxShadow: _GG.glow(_GG.purple, blur: 10, spread: 0),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _GG.white,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          _GlossyPill(
            icon: Icons.diamond_rounded,
            label: '$score',
            accent: _GG.pink,
            iconColor: _GG.pink,
          ),
          const SizedBox(width: 10),
          _GlossyPill(
            icon: Icons.timer_rounded,
            label: '$timeLeft',
            accent: timeLeft <= 10 ? _GG.red : _GG.orange,
            iconColor: timeLeft <= 10 ? _GG.red : _GG.orangeLight,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaysIndicator() {
    final color = playsRemaining > 0 ? _GG.green : _GG.red;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: _GG.panelGrad(
              _GG.panelBg.withValues(alpha:0.88), _GG.panelBg),
          border: Border.all(color: color.withValues(alpha:0.7), width: 1.8),
          boxShadow: _GG.glow(color, blur: 10, spread: 0),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sports_esports_rounded, color: color, size: 40,
                  shadows: [Shadow(color: color, blurRadius: 6)]),
              const SizedBox(width: 10),
              Text('Plays Today:',
                  style: _GG.playsLabel.copyWith(
                      color: _GG.white.withValues(alpha:0.8))),
              const SizedBox(width: 8),
              _PlaysDots(remaining: playsRemaining, total: 3),
            ]),
      ),
    );
  }

  Widget _buildPortraitStartOverlay(double w, double h) {
    return playsRemaining > 0
        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Spacer(),
      ScaleTransition(scale: _pulseAnimation,
          child: Image.asset('assets/images/pngs/gemgrab.png',
              width: w * 0.80, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const _GemGrabLogoFallback())),
      const SizedBox(height: 12),
      Image.asset('assets/images/pngs/gemgrab_subtext.png',
          width: w * 0.55, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
              'Catch the falling gems!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xCCFFFFFF)))),
      const SizedBox(height: 8),
      Image.asset('assets/images/pngs/gemgrab_warning.png',
          width: w * 0.42, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _WarningChip()),
      const SizedBox(height: 28),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.12),
        child: GestureDetector(
          onTap: startGame,
          child: Image.asset('assets/images/pngs/gemgrab_start.png',
              width: w * 0.60, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _ArcadeButton(
                  label: 'START GAME', onTap: startGame,
                  icon: Icons.play_arrow_rounded)),
        ),
      ),
      const Spacer(),
    ])
        : _buildOutOfPlaysOverlay(w);
  }

  Widget _buildLandscapeStartOverlay(double w, double h) {
    return playsRemaining > 0
        ? Row(children: [
      Expanded(flex: 5,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ScaleTransition(scale: _pulseAnimation,
                child: Image.asset('assets/images/pngs/gemgrab.png',
                    width: w * 0.38, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const _GemGrabLogoFallback(fontSize: 26))),
            const SizedBox(height: 8),
            Image.asset('assets/images/pngs/gemgrab_subtext.png',
                width: w * 0.28, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                    'Catch the falling gems!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xCCFFFFFF)))),
          ])),
      Expanded(flex: 5,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset('assets/images/pngs/gemgrab_warning.png',
                width: w * 0.22, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const _WarningChip(compact: true)),
            const SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.04),
              child: GestureDetector(
                onTap: startGame,
                child: Image.asset('assets/images/pngs/gemgrab_start.png',
                    width: w * 0.30, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _ArcadeButton(
                        label: 'START GAME', onTap: startGame,
                        icon: Icons.play_arrow_rounded)),
              ),
            ),
          ])),
    ])
        : _buildOutOfPlaysOverlay(w);
  }

  Widget _buildOutOfPlaysOverlay(double w) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _SleepingLottie(size: w * 0.52),
      const SizedBox(height: 6),
      const Text(
        '⏰ OUT OF PLAYS',
        style: TextStyle(
          fontFamily: _GG.fontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: _GG.orange,
          letterSpacing: 1,
          shadows: [Shadow(color: Color(0x88000000), blurRadius: 6)],
        ),
      ),
      const SizedBox(height: 18),
      Container(
        margin: EdgeInsets.symmetric(horizontal: w * 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _GG.orange.withValues(alpha:0.30),
          border: Border.all(color: _GG.orange.withValues(alpha:0.65), width: 1.8),
          boxShadow: _GG.glow(_GG.orange, blur: 12, spread: 0),
        ),
        child: const Column(children: [
          Text(
            "You've used all 3 plays for today!",
            style: TextStyle(
              fontFamily: _GG.fontFamily,
              color: _GG.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Come back tomorrow for more! 🌅',
            style: TextStyle(
              fontFamily: _GG.fontFamily,
              color: Color(0xCCFFFFFF),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
      const SizedBox(height: 24),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.1),
        child: _ArcadeButton(
            label: 'BACK TO MENU',
            onTap: () => Navigator.of(context).pop(), // ✅ no dialog in the way here
            top: _GG.purple, bottom: _GG.purpleDark, shadow: _GG.purple,
            icon: Icons.home_rounded),
      ),
    ]);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        body: Stack(children: [
          Positioned.fill(
            child: Image.asset('assets/images/backgrounds/gemgrab_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final bool isLandscape =
                  constraints.maxWidth > constraints.maxHeight;

              return Column(children: [
                _buildTopBar(),
                _buildPlaysIndicator(),
                Expanded(
                  child: LayoutBuilder(builder: (ctx, gc) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_gameAreaWidth  != gc.maxWidth ||
                          _gameAreaHeight != gc.maxHeight) {
                        setState(() {
                          _gameAreaWidth  = gc.maxWidth;
                          _gameAreaHeight = gc.maxHeight;
                        });
                      }
                    });

                    return Stack(children: [
                      ...gems.map((gem) => GemWidget(
                        key: ValueKey(gem.id), gem: gem,
                        gameAreaHeight: gc.maxHeight,
                        onTap: () => collectGem(gem.id, gem.points),
                      )),

                      if (!isGameActive)
                        Positioned.fill(
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                            child: isLandscape
                                ? _buildLandscapeStartOverlay(
                                gc.maxWidth, gc.maxHeight)
                                : _buildPortraitStartOverlay(
                                gc.maxWidth, gc.maxHeight),
                          ),
                        ),
                    ]);
                  }),
                ),
              ]);
            }),
          ),
        ]),
      ),
    );
  }
}

class FallingGem {
  final String id;
  final double left;
  final int    points;
  final double fallDuration;
  final DateTime spawnTime;

  FallingGem({
    required this.id,   required this.left,
    required this.points, required this.fallDuration,
    required this.spawnTime,
  });
}

class GemWidget extends StatelessWidget {
  final FallingGem gem;
  final double     gameAreaHeight;
  final VoidCallback onTap;

  const GemWidget({
    super.key, required this.gem,
    required this.gameAreaHeight, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GemWidgetStateful(gem: gem, gameAreaHeight: gameAreaHeight, onTap: onTap);
  }
}

class _GemWidgetStateful extends StatefulWidget {
  final FallingGem gem;
  final double     gameAreaHeight;
  final VoidCallback onTap;

  const _GemWidgetStateful({
    required this.gem,
    required this.gameAreaHeight, required this.onTap,
  });

  @override
  State<_GemWidgetStateful> createState() => _GemWidgetState();
}

class _GemWidgetState extends State<_GemWidgetStateful> with TickerProviderStateMixin {
  late AnimationController _fall;
  late AnimationController _tap;
  late Animation<double>   _fallAnim, _tapScale, _tapOpacity;
  bool _tapped = false;

  static const List<List<Color>> _palettes = [
    [Color(0xFF64B5F6), Color(0xFF1565C0)],
    [Color(0xFFCE93D8), Color(0xFF6A1B9A)],
    [Color(0xFFFF80AB), Color(0xFFC2185B)],
  ];

  @override
  void initState() {
    super.initState();
    _fall = AnimationController(
        duration: Duration(
            milliseconds: (widget.gem.fallDuration * 1000).toInt()),
        vsync: this);
    _fallAnim =
        Tween<double>(begin: -60, end: widget.gameAreaHeight + 10).animate(
            CurvedAnimation(parent: _fall, curve: Curves.linear));
    _fall.forward();

    _tap = AnimationController(
        duration: const Duration(milliseconds: 350), vsync: this);
    _tapScale = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _tap, curve: Curves.easeOut));
    _tapOpacity = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _tap, curve: Curves.easeOut));
  }

  @override
  void dispose() { _fall.dispose(); _tap.dispose(); super.dispose(); }

  void _onTap() {
    if (_tapped) return;
    setState(() => _tapped = true);
    HapticFeedback.mediumImpact();
    _tap.forward().then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    final idx    = (widget.gem.points - 1).clamp(0, 2);
    final colors = _palettes[idx];

    return AnimatedBuilder(
      animation: _fallAnim,
      builder: (_, __) => Positioned(
        left: widget.gem.left,
        top: _fallAnim.value,
        child: GestureDetector(
          onTap: _onTap,
          child: ScaleTransition(scale: _tapScale,
            child: FadeTransition(opacity: _tapOpacity,
              child: Transform.scale(scale: _tapped ? 1.2 : 1.0,
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                        colors: [colors[0], colors[1]]),
                    boxShadow: [
                      BoxShadow(color: colors[0].withValues(alpha:0.7),
                          blurRadius: 14, spreadRadius: 2),
                      BoxShadow(color: colors[1].withValues(alpha:0.4),
                          blurRadius: 24),
                    ],
                    border:
                    Border.all(color: colors[0].withValues(alpha:0.6), width: 2),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned(top: 6, left: 8, width: 18, height: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withValues(alpha:0.35),
                        ),
                      ),
                    ),
                    Icon(Icons.diamond_rounded, color: Colors.white, size: 30,
                        shadows: [
                          Shadow(color: Colors.white.withValues(alpha:0.6),
                              blurRadius: 8)
                        ]),
                    Positioned(bottom: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha:0.55),
                        ),
                        child: Text('${widget.gem.points}',
                            style: const TextStyle(
                                fontFamily: _GG.fontFamily,
                                color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}