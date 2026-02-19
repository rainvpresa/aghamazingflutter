import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/userprofile_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THEME TOKENS  — single source of truth for every colour / style
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

  static List<BoxShadow> glow(Color c, {double spread = 4, double blur = 14}) => [
    BoxShadow(color: c.withOpacity(0.75), blurRadius: blur, spreadRadius: spread),
    BoxShadow(color: c.withOpacity(0.35), blurRadius: blur * 2.2, spreadRadius: spread * 0.5),
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

  static const TextStyle scoreLabel = TextStyle(
    color: white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5,
    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 4, offset: Offset(1, 2))],
  );
  static const TextStyle playsLabel = TextStyle(
    color: white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4,
  );
  static const TextStyle btnLabel = TextStyle(
    color: white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5,
    shadows: [Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 3))],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  REUSABLE GLOSSY PILL  (score / timer chips)
// ─────────────────────────────────────────────────────────────────────────────
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
        gradient: _GG.panelGrad(_GG.panelBg.withOpacity(0.92), _GG.panelBg),
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
              shadows: [Shadow(color: iconColor.withOpacity(0.8), blurRadius: 8)]),
          const SizedBox(width: 7),
          Text(label, style: _GG.scoreLabel),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ARCADE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ArcadeButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color top;
  final Color bottom;
  final Color shadow;
  final double width;
  final IconData? icon;

  const _ArcadeButton({
    required this.label, required this.onTap,
    this.top    = _GG.green,
    this.bottom = _GG.greenDark,
    this.shadow = _GG.green,
    this.width  = double.infinity,
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
          width: widget.width,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [widget.top, widget.bottom],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.bottom.withOpacity(0.9),
                blurRadius: 0, spreadRadius: 0,
                offset: Offset(0, _pressed ? 1 : 5),
              ),
              ..._GG.glow(widget.shadow, blur: 18, spread: _pressed ? 0 : 2),
            ],
            border: Border.all(color: _GG.white.withOpacity(0.25), width: 1.5),
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
                      colors: [_GG.white.withOpacity(0.32), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: _GG.white, size: 22,
                        shadows: [Shadow(color: _GG.black.withOpacity(0.4), blurRadius: 4)]),
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

// ─────────────────────────────────────────────────────────────────────────────
//  PLAYS DOTS INDICATOR
// ─────────────────────────────────────────────────────────────────────────────
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
              color: filled ? color : color.withOpacity(0.22),
              border: Border.all(color: color.withOpacity(0.7), width: 1.5),
              boxShadow: filled ? _GG.glow(color, blur: 6, spread: 0) : null,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PRETTY DIALOG
// ─────────────────────────────────────────────────────────────────────────────
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
          border: Border.all(color: _GG.purple.withOpacity(0.6), width: 2),
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
                    colors: [_GG.white.withOpacity(0.08), Colors.transparent],
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
                    gradient: _GG.panelGrad(iconColor.withOpacity(0.25), iconColor.withOpacity(0.08)),
                    border: Border.all(color: iconColor.withOpacity(0.6), width: 2),
                    boxShadow: _GG.glow(iconColor, blur: 18, spread: 2),
                  ),
                  child: Icon(icon, color: iconColor, size: 44,
                      shadows: [Shadow(color: iconColor, blurRadius: 12)]),
                ),
                const SizedBox(height: 14),
                Text(title, style: TextStyle(
                  color: titleColor, fontSize: 24, fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: titleColor.withOpacity(0.5), blurRadius: 12)],
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

// ─────────────────────────────────────────────────────────────────────────────
//  FALLBACK WIDGETS (shown if PNG assets are missing)
// ─────────────────────────────────────────────────────────────────────────────
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
            shadows: [Shadow(color: _GG.pink, blurRadius: 10)]),
        const SizedBox(width: 10),
        Text('GEM GRAB!', style: TextStyle(
          color: _GG.white, fontSize: fontSize, fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [Shadow(color: _GG.pink.withOpacity(0.8), blurRadius: 12)],
        )),
        const SizedBox(width: 10),
        Icon(Icons.diamond_rounded, color: _GG.gold, size: fontSize * 0.8,
            shadows: [Shadow(color: _GG.gold, blurRadius: 10)]),
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
            _GG.orange.withOpacity(0.22), _GG.orange.withOpacity(0.08)),
        border: Border.all(color: _GG.orange.withOpacity(0.7), width: 2),
        boxShadow: _GG.glow(_GG.orange, blur: 10, spread: 0),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flash_on_rounded, color: _GG.orange,
            size: compact ? 16 : 20,
            shadows: [Shadow(color: _GG.orange, blurRadius: 8)]),
        const SizedBox(width: 6),
        Text('Watch out! Gems fall\nat different speeds!',
            textAlign: TextAlign.center,
            style: TextStyle(
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
  const GemGrabGameScreen({Key? key}) : super(key: key);

  @override
  State<GemGrabGameScreen> createState() => _GemGrabGameScreenState();
}

class _GemGrabGameScreenState extends State<GemGrabGameScreen>
    with TickerProviderStateMixin {
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
  late Animation<double>   _floatAnimation;

  @override
  void initState() {
    super.initState();
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
    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
        CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ── DEBUG ──────────────────────────────────────────────────────────────────
  Future<void> _resetPlaysDebug() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().substring(0, 10);
    await prefs.setString('gem_grab_date', today);
    await prefs.setInt('gem_grab_plays', 3);
    setState(() => playsRemaining = 3);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Plays reset to 3!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    }
  }

  // ── PERSISTENCE ────────────────────────────────────────────────────────────
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

  // ── GAME LOGIC ─────────────────────────────────────────────────────────────
  void startGame() {
    if (playsRemaining <= 0) { showNoPlaysDialog(); return; }
    decrementPlays();
    setState(() { score = 0; timeLeft = 30; isGameActive = true; gems.clear(); });
    gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() { timeLeft--; if (timeLeft <= 0) endGame(); });
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
      final svc = UserProfileService();
      await svc.addCoins(amount: coinsEarned, reason: 'Gem Grab game - Score: $score');
      await svc.updateGameStats(gamesPlayed: 1, totalScore: gemsEarned);
    } catch (e) { debugPrint('❌ $e'); }
    _showGameOverDialog(coinsEarned, gemsEarned);
  }

  // ── DIALOGS ────────────────────────────────────────────────────────────────
  void _showGameOverDialog(int coins, int gemsEarned) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GemGrabDialog(
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
            const Text('Plays left: ',
                style: TextStyle(color: _GG.white, fontSize: 13)),
            _PlaysDots(remaining: playsRemaining, total: 3),
          ]),
        ]),
        actions: [
          if (playsRemaining > 0) ...[
            _ArcadeButton(
                label: 'PLAY AGAIN', icon: Icons.replay,
                onTap: () { Navigator.pop(context); startGame(); },
                top: _GG.green, bottom: _GG.greenDark, shadow: _GG.green),
            const SizedBox(height: 8),
          ],
          _ArcadeButton(
              label: 'MAIN MENU', icon: Icons.home_rounded,
              onTap: () { Navigator.pop(context); Navigator.pop(context); },
              top: _GG.purple, bottom: _GG.purpleDark, shadow: _GG.purple),
        ],
      ),
    );
  }

  void showNoPlaysDialog() {
    showDialog(
      context: context,
      builder: (_) => _GemGrabDialog(
        title: 'OUT OF PLAYS',
        titleColor: _GG.orange,
        icon: Icons.hourglass_bottom_rounded,
        iconColor: _GG.orange,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("You've used all 3 plays for today!",
              style: TextStyle(color: _GG.white, fontSize: 16,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Come back tomorrow for more! 🌅',
              style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          _PlaysDots(remaining: 0, total: 3),
        ]),
        actions: [
          _ArcadeButton(
              label: 'OK',
              onTap: () { Navigator.pop(context); Navigator.pop(context); },
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
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.45), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(icon, color: color, size: 18,
              shadows: [Shadow(color: color, blurRadius: 8)]),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        Text(value, style: _GG.scoreLabel.copyWith(fontSize: 16)),
      ]),
    );
  }

  // ── CHROME WIDGETS ─────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return GestureDetector(
      onLongPress: _resetPlaysDebug,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          // Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _GG.panelGrad(
                    _GG.panelBg.withOpacity(0.9), _GG.panelBg),
                border: _GG.glowBorder(_GG.purple.withOpacity(0.8)),
                boxShadow: _GG.glow(_GG.purple, blur: 10, spread: 0),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _GG.white, size: 18),
            ),
          ),
          const Spacer(),
          // Score
          _GlossyPill(
              icon: Icons.diamond_rounded, label: '$score',
              accent: _GG.pink, iconColor: _GG.pink),
          const SizedBox(width: 10),
          // Timer — turns red when ≤ 10 s
          _GlossyPill(
            icon: Icons.timer_rounded, label: '$timeLeft',
            accent: timeLeft <= 10 ? _GG.red : _GG.orange,
            iconColor: timeLeft <= 10 ? _GG.red : _GG.orangeLight,
          ),
        ]),
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
              _GG.panelBg.withOpacity(0.88), _GG.panelBg),
          border: Border.all(color: color.withOpacity(0.7), width: 1.8),
          boxShadow: _GG.glow(color, blur: 10, spread: 0),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sports_esports_rounded, color: color, size: 40,
                  shadows: [Shadow(color: color, blurRadius: 6)]),
              const SizedBox(width: 10),
              Text('Plays Today:',
                  style: _GG.playsLabel.copyWith(
                      color: _GG.white.withOpacity(0.8))),
              const SizedBox(width: 8),
              _PlaysDots(remaining: playsRemaining, total: 3),
            ]),
      ),
    );
  }

  // ── START OVERLAYS ─────────────────────────────────────────────────────────
  Widget _buildPortraitStartOverlay(double w, double h) {
    return playsRemaining > 0
        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Spacer(),
      ScaleTransition(scale: _pulseAnimation,
          child: Image.asset('assets/images/pngs/gemgrab.png',
              width: w * 0.80, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _GemGrabLogoFallback())),
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
          errorBuilder: (_, __, ___) => _WarningChip()),
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
                    errorBuilder: (_, __, ___) => _GemGrabLogoFallback(fontSize: 26))),
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
                errorBuilder: (_, __, ___) => _WarningChip(compact: true)),
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
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _GG.panelGrad(
              _GG.orange.withOpacity(0.3), _GG.orange.withOpacity(0.1)),
          border: Border.all(color: _GG.orange, width: 2),
          boxShadow: _GG.glow(_GG.orange, blur: 20, spread: 2),
        ),
        child: const Icon(Icons.hourglass_bottom_rounded,
            size: 64, color: _GG.orange),
      ),
      const SizedBox(height: 18),
      const Text('⏰ OUT OF PLAYS', style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900, color: _GG.orange,
        letterSpacing: 1,
        shadows: [Shadow(color: Color(0x88000000), blurRadius: 6)],
      )),
      const SizedBox(height: 16),
      Container(
        margin: EdgeInsets.symmetric(horizontal: w * 0.06),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _GG.orange.withOpacity(0.1),
          border: Border.all(color: _GG.orange.withOpacity(0.5), width: 1.5),
        ),
        child: Column(children: const [
          Text("You've used all 3 plays for today!",
              style: TextStyle(color: _GG.white, fontSize: 15,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          SizedBox(height: 8),
          Text('Come back tomorrow for more! 🌅',
              style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      ),
      const SizedBox(height: 24),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.1),
        child: _ArcadeButton(
            label: 'BACK TO MENU', onTap: () => Navigator.pop(context),
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

    return Scaffold(
      body: Stack(children: [
        // Background image
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
                    // Falling gems
                    ...gems.map((gem) => GemWidget(
                      key: ValueKey(gem.id), gem: gem,
                      gameAreaHeight: gc.maxHeight,
                      onTap: () => collectGem(gem.id, gem.points),
                    )),

                    // Start overlay
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
//  GEM WIDGET  — glossy gems with point badge + inner highlight
// ─────────────────────────────────────────────────────────────────────────────
class GemWidget extends StatefulWidget {
  final FallingGem gem;
  final double     gameAreaHeight;
  final VoidCallback onTap;

  const GemWidget({
    Key? key, required this.gem,
    required this.gameAreaHeight, required this.onTap,
  }) : super(key: key);

  @override
  State<GemWidget> createState() => _GemWidgetState();
}

class _GemWidgetState extends State<GemWidget> with TickerProviderStateMixin {
  late AnimationController _fall;
  late AnimationController _tap;
  late Animation<double>   _fallAnim, _tapScale, _tapOpacity;
  bool _tapped = false;

  static const List<List<Color>> _palettes = [
    [Color(0xFF64B5F6), Color(0xFF1565C0)],  // 1 pt – blue
    [Color(0xFFCE93D8), Color(0xFF6A1B9A)],  // 2 pt – purple
    [Color(0xFFFF80AB), Color(0xFFC2185B)],  // 3 pt – pink
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
                      BoxShadow(color: colors[0].withOpacity(0.7),
                          blurRadius: 14, spreadRadius: 2),
                      BoxShadow(color: colors[1].withOpacity(0.4),
                          blurRadius: 24),
                    ],
                    border:
                    Border.all(color: colors[0].withOpacity(0.6), width: 2),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    // Gloss highlight
                    Positioned(top: 6, left: 8, width: 18, height: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: _GG.white.withOpacity(0.35),
                        ),
                      ),
                    ),
                    Icon(Icons.diamond_rounded, color: _GG.white, size: 30,
                        shadows: [
                          Shadow(color: _GG.white.withOpacity(0.6),
                              blurRadius: 8),
                        ]),
                    // Point badge
                    Positioned(bottom: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _GG.black.withOpacity(0.55),
                        ),
                        child: Text('${widget.gem.points}',
                            style: const TextStyle(
                                color: _GG.white, fontSize: 9,
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