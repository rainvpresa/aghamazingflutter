import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import '../services/player_stats_service.dart';
import '../services/session_service.dart';
import '../services/energy_manager.dart';
import '../services/sound_manager.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'scan_screen.dart';
import '../screens/gemgrab/gem_grab_game_screen.dart';
import '../services/route_observer.dart';
import 'dart:math' as math;

class UiAssets {
  static Map<String, String>? _cache;
  static const String _configPath = 'assets/config/ui_assets.json';
  static Future<Map<String, String>> load() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString(_configPath);
    final decoded = json.decode(jsonStr);
    final map = <String, String>{};
    if (decoded is Map) {
      decoded.forEach((k, v) {
        if (v != null) map[k.toString()] = v.toString();
      });
    }
    _cache = map;
    return _cache!;
  }
  static void clearCache() => _cache = null;
}

const String kMascotCaption =
    "Say hello to Smarty the Mascot, your cheerful and helpful tour guide! "
    "She'll be with you every step of the way.";

class _Layout {
  final bool isShort;
  final bool isTablet;
  final double aspect;

  _Layout(BuildContext context)
      : isShort = MediaQuery.of(context).size.height < 750,
        isTablet =
            MediaQueryData.fromView(View.of(context)).size.shortestSide >= 600,
        aspect = MediaQueryData.fromView(View.of(context)).size.aspectRatio;

  // Tablet in a wide window (landscape, locked to portrait).
  // Normal tablet portrait is ~0.62, this window is ~0.75.
  bool get isWideTablet => isTablet && aspect > 0.70;
  int get mascotFlex      => isTablet ? 42 : (isShort ? 35 : 48);
  int get leaderboardFlex => isTablet ? 38 : (isShort ? 24 : 30);

  double get mascotTextBottom => isShort ? 0.85 : 0.80;
  double get topBarFraction    => isShort ? 0.06  : 0.05;
  double get gemGrabFraction =>
      isTablet ? (isWideTablet ? 0.08 : 0.075) : (isShort ? 0.08 : 0.065);
  double get bottomPadFraction => isShort ? 0.002 : 0.005;
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});
  static const String background = 'assets/images/backgrounds/mainmenu_screen.png';
  static const String mascotLottieDefault = 'assets/animations/smarty_flap.json';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: SessionService.instance,
      child: FutureBuilder<Map<String, String>>(
        future: UiAssets.load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(child: Image.asset(background, fit: BoxFit.cover)),
                  const Center(child: CircularProgressIndicator()),
                ],
              ),
            );
          }
          final assets = snapshot.data ?? {};
          return _MainMenuBody(uiAssets: assets);
        },
      ),
    );
  }
}

class _MainMenuBody extends StatefulWidget {
  final Map<String, String> uiAssets;
  const _MainMenuBody({required this.uiAssets});
  @override
  State<_MainMenuBody> createState() => _MainMenuBodyState();
}

class _MainMenuBodyState extends State<_MainMenuBody> with RouteAware {
  Timer? _energyRegenTimer;
  int _timeUntilNextRegen = 0;
  final int _maxEnergy = 100;

  List<Map<String, dynamic>> _leaderboardData = [];
  bool _isLoadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    SessionService.instance.init();
    SoundManager.instance.playMenuMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precache();
      _startEnergyRegenTimer();
      _loadLeaderboard();
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    debugPrint('MENU didPopNext -> refreshing');
    SessionService.instance.fetchStats();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoadingLeaderboard = true);
    try {
      // Calling GET /api/app/leaderboard via PlayerStatsService
      final List<dynamic> data = await PlayerStatsService().getLeaderboard();

      if (mounted) {
        setState(() {
          _leaderboardData = List<Map<String, dynamic>>.from(data);
          _isLoadingLeaderboard = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      if (mounted) setState(() => _isLoadingLeaderboard = false);
    }
  }

  Future<void> _precache() async {
    final ctx = context;
    final imagePaths = widget.uiAssets.values.where((p) {
      final low = p.toLowerCase();
      return low.endsWith('.png') || low.endsWith('.jpg') ||
          low.endsWith('.jpeg') || low.endsWith('.webp');
    }).toSet();
    for (final path in imagePaths) {
      try {
        await precacheImage(AssetImage(path), ctx);
      } catch (e) {
        debugPrint('Precache failed $path: $e');
      }
    }
  }

  void _startEnergyRegenTimer() {
    _energyRegenTimer?.cancel();
    _energyRegenTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      final info = await EnergyManager.instance.getEnergyInfo();
      final int current = info['current'] ?? 0;
      final int secondsNext = info['secondsUntilNext'] ?? 0;

      // Keep SessionService updated so UI reflects regenerated energy automatically
      SessionService.instance.setEnergy(current);

      if (current < _maxEnergy) {
        if (mounted) setState(() => _timeUntilNextRegen = secondsNext);
      } else {
        if (mounted && _timeUntilNextRegen != 0) setState(() => _timeUntilNextRegen = 0);
      }
    });
  }

  String asset(String key) => widget.uiAssets[key] ?? '';

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final real = MediaQueryData.fromView(View.of(context)).size;
    final isTablet = real.shortestSide >= 600;
    final screenW = math.min(
      real.width,
      real.height * (isTablet ? 0.58 : 0.46),
    );

    final l = _Layout(context);
    final bool t = l.isTablet;
    final bool wide = l.isWideTablet;
    final double bk = wide ? 1.25 : 1.0; // bigger buttons on wide tablets

    final double selectW  = screenW * 0.43;
    final double profileW = screenW * 0.16 * bk;
    final double chatW    = screenW * 0.16 * bk;
    final double scanW    = screenW * 0.16 * bk;
    final double topIconW = screenW * 0.24;

    final double selectH  = selectW  * 0.30;
    final double profileH = profileW * 0.55;
    final double chatH    = chatW    * 0.55;
    final double scanH    = scanW    * 0.80;
    final double topIconH = topIconW * 0.32;

    final mascotAsset = asset('mascot_lottie').isNotEmpty
        ? asset('mascot_lottie')
        : MainMenuScreen.mascotLottieDefault;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(MainMenuScreen.background, fit: BoxFit.cover),
          ),
          SafeArea(
            child: Center(
              child: SizedBox(
                width: wide ? real.width : screenW,
                height: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {

                    final double bgScale = math.max(real.width / 1186, real.height / 2576);
                    final double bgH     = 2576 * bgScale;
                    final double woodY   = (real.height - bgH) / 2 + 0.555 * bgH;
                    final double safeTop = MediaQueryData.fromView(View.of(context)).padding.top;
                    final double topBarH = constraints.maxHeight * l.topBarFraction;
                    final double tabletMascotH =
                    (woodY - safeTop - topBarH).clamp(screenW * 0.7, screenW * 1.0);
                    // ── Mascot area (bird + label + caption + buttons) ──
                    final Widget mascotStack = LayoutBuilder(
                      builder: (context, mc) {
                        final double w = screenW;
                        final double h = mc.maxHeight;
                        final double capFont = t ? w * (wide ? 0.036 : 0.040) : w * (l.isShort ? 0.028 : 0.030);
                        final double capBottom = t ? w * (wide ? 0.020 : 0.03) : h * 0.02;

                        return Stack(
                          clipBehavior: t ? Clip.none : Clip.hardEdge,
                          children: [
                            // Bird
                            if (t)
                              Positioned(
                                top: wide ? h * 0.10 : h * 0.04,
                                left: wide ? (real.width - w * 0.96) / 2 : w * 0.02,
                                width: w * 0.96,
                                height: wide ? h * 0.74 : h * 0.80,
                                child: _MascotAnimation(
                                  asset: mascotAsset,
                                  width: w * 0.96,
                                  height: wide ? h * 0.74 : h * 0.80,
                                  scale: wide ? 1.4 : 1.15,
                                ),
                              )
                            else
                              Center(
                                child: SizedBox(
                                  width: w * 0.94,
                                  height: h * 0.95,
                                  child: _MascotAnimation(
                                    asset: mascotAsset,
                                    width: w * 0.94,
                                    height: h * 0.95,
                                    verticalNudge: -0.08,
                                    scale: 1.2,
                                  ),
                                ),
                              ),

                            // Mascot label (further left on tablet)
                            Positioned(
                              top: t ? (wide ? 0.0 : h * 0.01) : null,
                              bottom: t ? null : h * l.mascotTextBottom,
                              left: t ? (wide ? -w * 0.09 : -w * 0.10) : w * -0.08,
                              right: t ? null : w * 0.40,
                              child: Image.asset(
                                asset('smarty_header'),
                                fit: BoxFit.contain,
                                width: t ? (wide ? w * 0.56 : w * 0.62) : null,
                                height: t
                                    ? null
                                    : h * (l.isShort ? 0.18 : 0.20),
                              ),
                            ),

                            // Caption as real text
                            Positioned(
                              left: wide ? w * 0.03 : null,
                              bottom: capBottom,
                              width: wide ? mc.maxWidth - selectW - w * 0.12 : w * (t ? 0.47 : 0.46),
                              child: Text(
                                kMascotCaption,
                                maxLines: 5,
                                style: TextStyle(
                                  fontFamily: 'LilitaOne',
                                  color: Colors.white,
                                  fontSize: capFont,
                                  height: 1.15,
                                  shadows: const [
                                    Shadow(offset: Offset(1.2, 1.2), color: Colors.black),
                                    Shadow(offset: Offset(-1.2, 1.2), color: Colors.black),
                                    Shadow(offset: Offset(1.2, -1.2), color: Colors.black),
                                    Shadow(offset: Offset(-1.2, -1.2), color: Colors.black),
                                  ],
                                ),
                              ),
                            ),

                            // Scan
                              Positioned(
                                left: wide ? w * 0.10 : w * 0.02,
                                bottom: t ? (wide ? w * 0.17 : w * 0.27) : h * 0.23,
                                child: ImageAssetButton(
                                assetPath: asset('btn_arscan'),
                                width: scanW,
                                height: scanH,
                                fill: true,
                                onTap: () {
                                  SoundManager.instance.playClick();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ARScanScreen()),
                                  );
                                },
                                fallbackWidget: const Icon(Icons.qr_code_scanner, color: Colors.white),
                              ),
                            ),

                            // Profile + Chat
                            Positioned(
                              right: w * (wide ? 0.008 : 0.045),
                              bottom: t ? w * 0.02 + selectH + w * 0.02 : h * 0.16,
                              child: wide
                                  ? Builder(builder: (_) {
                                final double gap = w * 0.008;
                                final double bw = selectW * 0.36; // was (selectW - 2 * gap) / 3 same total width as Coming Soon
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    ImageAssetButton(
                                      assetPath: asset('btn_profile'),
                                      width: bw,
                                      height: bw * 0.55,
                                      fill: true,
                                      onTap: () {
                                        SoundManager.instance.playClick();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                        );
                                      },
                                      fallbackWidget: const Icon(Icons.person, color: Colors.white),
                                    ),
                                    SizedBox(width: gap),
                                    ImageAssetButton(
                                      assetPath: asset('btn_chatbot'),
                                      width: bw,
                                      height: bw * 0.55,
                                      fill: true,
                                      onTap: () {
                                        SoundManager.instance.playClick();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                                        );
                                      },
                                      fallbackWidget: const Icon(Icons.chat_bubble, color: Colors.white),
                                    ),
                                  ],
                                );
                              })
                                  : Row(
                                children: [
                                  ImageAssetButton(
                                    assetPath: asset('btn_profile'),
                                    width: profileW,
                                    height: profileH,
                                    fill: true,
                                    onTap: () {
                                      SoundManager.instance.playClick();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                      );
                                    },
                                    fallbackWidget: const Icon(Icons.person, color: Colors.white),
                                  ),
                                  SizedBox(width: w * 0.02),
                                  ImageAssetButton(
                                    assetPath: asset('btn_chatbot'),
                                    width: chatW,
                                    height: chatH,
                                    fill: true,
                                    onTap: () {
                                      SoundManager.instance.playClick();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                                      );
                                    },
                                    fallbackWidget: const Icon(Icons.chat_bubble, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),

                            // Coming Soon
                            Positioned(
                              right: w * 0.04,
                              bottom: t ? w * 0.02 : h * (l.isShort ? 0.02 : 0.03),
                              child: ImageAssetButton(
                                assetPath: asset('btn_select'),
                                width: selectW,
                                height: selectH,
                                fill: true,
                                onTap: () {
                                  SoundManager.instance.playClick();
                                  showStyledSnackBar(
                                    context,
                                    title: 'Future Shop',
                                    message: 'Coins can be used here!',
                                    backgroundColor: const Color(0xFF00B894),
                                    icon: Icons.check_circle,
                                    iconColor: Colors.white,
                                  );
                                },
                                fallbackWidget: ElevatedButton(
                                  onPressed: () {
                                    SoundManager.instance.playClick();
                                    showStyledSnackBar(
                                      context,
                                      title: 'Mascot Selected',
                                      message: 'Smarty is now your active mascot!',
                                      backgroundColor: const Color(0xFF00B894),
                                      icon: Icons.check_circle,
                                      iconColor: Colors.white,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFf2c94c),
                                  ),
                                  child: const Text('SELECT'),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );

                    final Widget mascotSection = t
                        ? SizedBox(
                      height: tabletMascotH,
                      child: mascotStack,
                    )
                        : Expanded(flex: l.mascotFlex, child: mascotStack);
                    final double lbW = wide ? screenW * 0.90 : screenW;

                    return Column(
                      children: [
                        // ── Top stats row ──────────────────────────────
                        SizedBox(
                          height: constraints.maxHeight * l.topBarFraction,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenW * 0.02,
                              vertical: constraints.maxHeight * 0.001,
                            ),
                            child: Row(
                              mainAxisAlignment: wide ? MainAxisAlignment.end : MainAxisAlignment.end,
                              children: [
                                Consumer<SessionService>(
                                  builder: (context, s, _) => IconStatButton(
                                    assetPath: asset('bubble_power'),
                                    width: topIconW,
                                    height: topIconH,
                                    value: s.bubblePower.toString(),
                                    onTap: () {
                                      SoundManager.instance.playClick();
                                      showStyledSnackBar(
                                        context,
                                        title: 'Bubble Power',
                                        message: 'You have ${s.bubblePower} coins',
                                        backgroundColor: const Color(0xFFF2C94C),
                                        icon: Icons.star,
                                        iconColor: Colors.white,
                                      );
                                    },
                                    textStyle: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenW * 0.032,
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenW * 0.025),
                                Consumer<SessionService>(
                                  builder: (context, s, _) => IconStatButton(
                                    assetPath: asset('gems'),
                                    width: topIconW,
                                    height: topIconH,
                                    value: s.gems.toString(),
                                    onTap: () {
                                      SoundManager.instance.playClick();
                                      showStyledSnackBar(
                                        context,
                                        title: 'Gems',
                                        message: 'You have ${s.gems} gems',
                                        backgroundColor: const Color(0xFF6C5CE7),
                                        icon: Icons.diamond,
                                        iconColor: Colors.white,
                                      );
                                    },
                                    textStyle: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenW * 0.032,
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenW * 0.025),
                                Consumer<SessionService>(
                                  builder: (context, s, _) => _EnergyDisplay(
                                    assetPath: asset('energy'),
                                    width: topIconW,
                                    height: topIconH,
                                    currentEnergy: s.energy,
                                    maxEnergy: _maxEnergy,
                                    timeLeft: _timeUntilNextRegen,
                                    onTap: () {
                                      SoundManager.instance.playClick();
                                      showStyledSnackBar(
                                        context,
                                        title: 'Energy',
                                        message: s.energy < _maxEnergy
                                            ? 'Next regen in: ${_formatTime(_timeUntilNextRegen)}'
                                            : 'Energy is full!',
                                        backgroundColor: const Color(0xFFE84393),
                                        icon: Icons.bolt,
                                        iconColor: Colors.white,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Mascot section ─────────────────────────────
                        mascotSection,

                        // ── Leaderboard section ────────────────────────
                        Expanded(
                          flex: l.leaderboardFlex,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? (constraints.maxWidth - screenW * 1.04) / 2 : lbW * 0.020,
                              vertical: constraints.maxHeight * 0.0025,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(lbW * 0.015),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                image: asset('leaderboard_bg').isNotEmpty
                                    ? DecorationImage(
                                  image: AssetImage(asset('leaderboard_bg')),
                                  fit: BoxFit.cover,
                                  alignment: t ? Alignment.topCenter : Alignment.center,
                                )
                                    : null,
                                color: asset('leaderboard_bg').isEmpty
                                    ? Colors.black.withValues(alpha: 0.4)
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: lbW * 0.01),
                                    child: Row(
                                      children: [
                                        if (asset('leaderboard_emblem').isNotEmpty)
                                          Image.asset(
                                            asset('leaderboard_emblem'),
                                            width: lbW * 0.11,
                                            height: lbW * 0.11,
                                          )
                                        else
                                          Container(
                                            width: lbW * 0.11,
                                            height: lbW * 0.11,
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.amber.withValues(alpha: 0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.emoji_events,
                                              color: Colors.white,
                                              size: lbW * 0.08,
                                            ),
                                          ),
                                        const Spacer(),
                                        Container(
                                          width: lbW * 0.10,
                                          height: lbW * 0.10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6C5CE7),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                SoundManager.instance.playClick();
                                                _loadLeaderboard();
                                              },
                                              borderRadius: BorderRadius.circular(12),
                                              child: Icon(
                                                Icons.refresh,
                                                color: Colors.white,
                                                size: lbW * 0.065,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: _isLoadingLeaderboard
                                        ? const Center(
                                      child: CircularProgressIndicator(color: Colors.amber),
                                    )
                                        : _leaderboardData.isEmpty
                                        ? Center(
                                      child: Text(
                                        'No players yet!\nBe the first to play!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: lbW * 0.035,
                                        ),
                                      ),
                                    )
                                        : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: _leaderboardData.length > 5
                                          ? 5
                                          : _leaderboardData.length,
                                      itemBuilder: (context, index) {
                                        final player = _leaderboardData[index];
                                        return _LeaderboardItem(
                                          rank: index + 1,
                                          displayName: player['display_name'] ??
                                              player['name'] ??
                                              'Anonymous',
                                          score: player['total_score'] ??
                                              player['coins'] ??
                                              player['score'] ??
                                              0,
                                          avatarPath: player['avatar']?['image_url'] ?? '',
                                          itemBgAsset: asset('leaderboard_item_bg'),
                                          rankBadgeAsset: asset('rank_${index + 1}_badge'),
                                          rankLabelAsset: asset('rank_${index + 1}_label'),
                                          screenWidth: lbW,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Gem Grab button ────────────────────────────
                        SizedBox(
                          height: constraints.maxHeight * l.gemGrabFraction,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: screenW * 0.015),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: screenW * (wide ? 0.66 : 0.60)),
                                child: AspectRatio(
                                  aspectRatio: 983 / 278,
                                  child: asset('btn_gem_grab').isNotEmpty
                                      ? ImageAssetButton(
                                    assetPath: asset('btn_gem_grab'),
                                    width: double.infinity,
                                    height: double.infinity,
                                    fill: true,
                                    onTap: () {
                                      SoundManager.instance.playClick();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const GemGrabGameScreen(),
                                        ),
                                      );
                                    },
                                    fallbackWidget: const SizedBox.shrink(),
                                  )
                                      : ElevatedButton(
                                    onPressed: () {
                                      SoundManager.instance.playClick();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const GemGrabGameScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      minimumSize: const Size(double.infinity, 48),
                                    ),
                                    child: const Text('GEM GRAB'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: constraints.maxHeight * l.bottomPadFraction),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _energyRegenTimer?.cancel();
    super.dispose();
  }
}

/// IconStatButton: image background with centered value
class IconStatButton extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final String value;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  const IconStatButton({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.value,
    this.textStyle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              assetPath,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Text(
              value,
              style: textStyle ??
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.032,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Energy display with timer
class _EnergyDisplay extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final int currentEnergy;
  final int maxEnergy;
  final int timeLeft;
  final VoidCallback? onTap;

  const _EnergyDisplay({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.currentEnergy,
    required this.maxEnergy,
    required this.timeLeft,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              assetPath,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Text(
              '$currentEnergy',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.032,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// ImageAssetButton
class ImageAssetButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final Widget? fallbackWidget;
  final bool fill;

  const ImageAssetButton({
    super.key,
    required this.assetPath,
    required this.onTap,
    this.width,
    this.height,
    this.fallbackWidget,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final BoxFit fit = fill ? BoxFit.fill : BoxFit.contain;
    if (assetPath.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: fallbackWidget ??
              ElevatedButton(onPressed: onTap, child: const SizedBox()),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, st) => SizedBox(
          width: width,
          height: height,
          child: Center(
            child: fallbackWidget ??
                ElevatedButton(onPressed: onTap, child: const SizedBox()),
          ),
        ),
      ),
    );
  }
}

/// Leaderboard item
class _LeaderboardItem extends StatelessWidget {
  final int rank;
  final String displayName;
  final int score;
  final String avatarPath;
  final String itemBgAsset;
  final String rankBadgeAsset;
  final String rankLabelAsset;
  final double screenWidth;

  const _LeaderboardItem({
    required this.rank,
    required this.displayName,
    required this.score,
    required this.avatarPath,
    required this.itemBgAsset,
    required this.rankBadgeAsset,
    required this.rankLabelAsset,
    required this.screenWidth,
  });

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFFFC11E);
      case 2: return const Color(0xFFFE9898);
      case 3: return const Color(0xFF98FE98);
      default: return const Color(0xFF98EBFE);
    }
  }

  String _getRankTitle(int rank) {
    switch (rank) {
      case 1: return 'EPIC';
      case 2: return 'AWESOME';
      case 3: return 'GOOD';
      default: return 'SMARTY';
    }
  }

  void _showPlayerModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a3e),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getRankColor(rank).withValues(alpha:0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarPath.isNotEmpty
                      ? Image.network(
                    avatarPath,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _getRankColor(rank),
                      child: Center(
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                          ),
                        ),
                      ),
                    ),
                  )
                      : Container(
                    color: _getRankColor(rank),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '#$rank ${_getRankTitle(rank)}',
                style: TextStyle(
                  color: _getRankColor(rank),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6C5CE7), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, color: Color(0xFF6C5CE7), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '$score Gems',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    SoundManager.instance.playClick();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundManager.instance.playClick();
        _showPlayerModal(context);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: screenWidth * 0.02,
        ),
        decoration: BoxDecoration(
          image: itemBgAsset.isNotEmpty
              ? DecorationImage(image: AssetImage(itemBgAsset), fit: BoxFit.fill)
              : null,
          color: itemBgAsset.isEmpty ? Colors.black26 : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: screenWidth * 0.125,
              height: screenWidth * 0.125,
              child: rankBadgeAsset.isNotEmpty
                  ? Image.asset(
                rankBadgeAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildFallbackBadge(),
              )
                  : _buildFallbackBadge(),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '#$rank ',
                        style: TextStyle(
                          color: _getRankColor(rank),
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                      Text(
                        _getRankTitle(rank),
                        style: TextStyle(
                          color: _getRankColor(rank),
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.005),
                  Text(
                    displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.03,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: screenWidth * 0.01,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.diamond, color: const Color(0xFF6C5CE7), size: screenWidth * 0.04),
                  SizedBox(width: screenWidth * 0.01),
                  Text(
                    score.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBadge() {
    return Container(
      width: screenWidth * 0.125,
      height: screenWidth * 0.125,
      decoration: BoxDecoration(
        color: _getRankColor(rank),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getRankColor(rank).withValues(alpha:0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.04,
          ),
        ),
      ),
    );
  }
}

/// Custom styled SnackBar
void showStyledSnackBar(BuildContext context, {
  required String title,
  required String message,
  required Color backgroundColor,
  required IconData icon,
  Color iconColor = Colors.white,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Mascot animation
class _MascotAnimation extends StatelessWidget {
  final String asset;
  final double width;
  final double height;
  final double verticalNudge;
  final double scale;

  const _MascotAnimation({
    required this.asset,
    required this.width,
    required this.height,
    this.verticalNudge = 0.0,
    this.scale = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: Alignment(0, verticalNudge),
        child: ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Lottie.asset(
              asset,
              width: width,
              height: height,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              repeat: true,
              animate: true,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.pets, size: 120, color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}