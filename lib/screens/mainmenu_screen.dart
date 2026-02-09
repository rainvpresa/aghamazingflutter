import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import '../services/userprofile_service.dart';
import '../services/energy_manager.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'arscan_screen.dart';
import '../screens/gemgrab/gem_grab_game_screen.dart';

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
class _MainMenuBodyState extends State<_MainMenuBody> {
  Timer? _energyRegenTimer;
  int _timeUntilNextRegen = 0;
  final int _maxEnergy = 100;

  // Leaderboard state
  List<Map<String, dynamic>> _leaderboardData = [];
  bool _isLoadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    SessionService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precache();
      _startEnergyRegenTimer();
      _loadLeaderboard(); // Load leaderboard data
    });
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoadingLeaderboard = true);
    try {
      final data = await UserProfileService().getLeaderboard(limit: 5);
      if (mounted) {
        setState(() {
          _leaderboardData = data;
          _isLoadingLeaderboard = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      if (mounted) {
        setState(() => _isLoadingLeaderboard = false);
      }
    }
  }

  Future<void> _precache() async {
    final ctx = context;
    final imagePaths = widget.uiAssets.values.where((p) {
      final low = p.toLowerCase();
      return low.endsWith('.png') || low.endsWith('.jpg') || low.endsWith('.jpeg') || low.endsWith('.webp');
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

    // Start timer that updates every second
    _energyRegenTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      final info = await EnergyManager.instance.getEnergyInfo();
      final int current = info['current'] ?? 0;
      final int secondsNext = info['secondsUntilNext'] ?? 0;

      if (current < _maxEnergy) {
        if (mounted) {
          setState(() {
            _timeUntilNextRegen = secondsNext;
          });
        }
      } else {
        if (mounted && _timeUntilNextRegen != 0) {
          setState(() {
            _timeUntilNextRegen = 0;
          });
        }
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
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;

    // Responsive sizing for buttons
    final double selectW = screenW * 0.40;
    final double profileW = screenW * 0.18;
    final double chatW = screenW * 0.18;
    final double scanW = screenW * 0.15;
    final double tryW = screenW * 0.20;
    final double topIconW = screenW * 0.20;

    final mascotAsset = asset('mascot_lottie').isNotEmpty
        ? asset('mascot_lottie')
        : MainMenuScreen.mascotLottieDefault;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              MainMenuScreen.background,
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Bubble Power
                      Consumer<SessionService>(
                        builder: (context, s, _) => IconStatButton(
                          assetPath: asset('bubble_power'),
                          width: topIconW,
                          height: topIconW * 0.35,
                          value: s.bubblePower.toString(),
                          onTap: () => showStyledSnackBar(
                            context,
                            title: 'Bubble Power',
                            message: 'You have ${s.bubblePower} coins',
                            backgroundColor: const Color(0xFFF2C94C),
                            icon: Icons.star,
                            iconColor: Colors.white,
                          ),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Gems
                      Consumer<SessionService>(
                        builder: (context, s, _) => IconStatButton(
                          assetPath: asset('gems'),
                          width: topIconW,
                          height: topIconW * 0.35,
                          value: s.gems.toString(),
                          onTap: () => showStyledSnackBar(
                            context,
                            title: 'Gems',
                            message: 'You have ${s.gems} gems',
                            backgroundColor: const Color(0xFF6C5CE7),
                            icon: Icons.diamond,
                            iconColor: Colors.white,
                          ),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Energy with Timer
                      Consumer<SessionService>(
                        builder: (context, s, _) => _EnergyDisplay(
                          assetPath: asset('energy'),
                          width: topIconW,
                          height: topIconW * 0.35,
                          currentEnergy: s.energy,
                          maxEnergy: _maxEnergy,
                          timeLeft: _timeUntilNextRegen,
                          onTap: () => showStyledSnackBar(
                            context,
                            title: 'Energy',
                            message: s.energy < _maxEnergy
                                ? 'Next regen in: ${_formatTime(_timeUntilNextRegen)}'
                                : 'Energy is full!',
                            backgroundColor: const Color(0xFFE84393),
                            icon: Icons.bolt,
                            iconColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Mascot section - EXPANDED
                Expanded(
                  child: Stack(
                    children: [
                      // Centered mascot
                      Center(
                        child: SizedBox(
                          width: screenW * 0.94,
                          height: screenH * 0.44,
                          child: _MascotAnimation(
                            asset: mascotAsset,
                            width: screenW * 0.94,
                            height: screenH * 0.44,
                            verticalNudge: -0.08,
                            scale: 1.2,
                          ),
                        ),
                      ),

                      // AR Scan button (left side)
                      Positioned(
                        bottom: 90,
                        left: 16,
                        child: ImageAssetButton(
                          assetPath: asset('btn_arscan'),
                          width: scanW,
                          height: scanW * 0.88,
                          fill: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ARScanScreen()),
                          ),
                          fallbackWidget: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Profile & Chat buttons
                      Positioned(
                        right: 18,
                        bottom: 65,
                        child: Row(
                          children: [
                            ImageAssetButton(
                              assetPath: asset('btn_profile'),
                              width: profileW * 0.90,
                              height: profileW * 0.56,
                              fill: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              ),
                              fallbackWidget: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ImageAssetButton(
                              assetPath: asset('btn_chatbot'),
                              width: chatW * 0.90,
                              height: chatW * 0.56,
                              fill: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                              ),
                              fallbackWidget: const Icon(
                                Icons.chat_bubble,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // SELECT button
                      Positioned(
                        right: 16,
                        bottom: 10,
                        child: ImageAssetButton(
                          assetPath: asset('btn_select'),
                          width: selectW,
                          height: selectW * 0.30,
                          fill: true,
                          onTap: () => showStyledSnackBar(
                            context,
                            title: 'Mascot Selected',
                            message: 'Smarty is now your active mascot!',
                            backgroundColor: const Color(0xFF00B894),
                            icon: Icons.check_circle,
                            iconColor: Colors.white,
                          ),
                          fallbackWidget: ElevatedButton(
                            onPressed: () => showStyledSnackBar(
                              context,
                              title: 'Mascot Selected',
                              message: 'Smarty is now your active mascot!',
                              backgroundColor: const Color(0xFF00B894),
                              icon: Icons.check_circle,
                              iconColor: Colors.white,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFf2c94c),
                            ),
                            child: const Text('SELECT'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Leaderboards section - FIXED HEIGHT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
                  child: Container(
                    width: double.infinity,
                    height: 280, // Fixed height for leaderboard container
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      image: asset('leaderboard_bg').isNotEmpty
                          ? DecorationImage(
                        image: AssetImage(asset('leaderboard_bg')),
                        fit: BoxFit.cover,
                      )
                          : null,
                      color: asset('leaderboard_bg').isEmpty
                          ? Colors.black.withValues(alpha: 0.4)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (asset('leaderboard_emblem').isNotEmpty)
                              Image.asset(
                                asset('leaderboard_emblem'),
                                width: 44,
                                height: 44,
                              )
                            else
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: SizedBox.shrink(),
                            ),
                            ImageAssetButton(
                              assetPath: asset('btn_try'),
                              width: tryW,
                              height: tryW * 0.66,
                              fill: true,
                              onTap: _loadLeaderboard,
                              fallbackWidget: ElevatedButton(
                                onPressed: _loadLeaderboard,
                                child: const Text('TRY'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Scrollable leaderboard items
                        Expanded(
                          child: _isLoadingLeaderboard
                              ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                            ),
                          )
                              : _leaderboardData.isEmpty
                              ? const Center(
                            child: Text(
                              'No players yet!\nBe the first to play!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          )
                              : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _leaderboardData.length,
                            itemBuilder: (context, index) {
                              final player = _leaderboardData[index];
                              return _LeaderboardItem(
                                rank: index + 1,
                                displayName: player['displayName'] ?? 'Anonymous',
                                score: player['totalScore'] ?? 0,
                                itemBgAsset: asset('leaderboard_item_bg'),
                                rankBadgeAsset: asset('rank_${index + 1}_badge'),
                                rankLabelAsset: asset('rank_${index + 1}_label'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Gem Grab button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: screenW * 0.60,
                      ),
                      child: AspectRatio(
                        aspectRatio: 983 / 278,
                        child: asset('btn_gem_grab').isNotEmpty
                            ? ImageAssetButton(
                          assetPath: asset('btn_gem_grab'),
                          width: double.infinity,
                          height: double.infinity,
                          fill: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GemGrabGameScreen(),
                            ),
                          ),
                          fallbackWidget: const SizedBox.shrink(),
                        )
                            : ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GemGrabGameScreen(),
                            ),
                          ),
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

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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
              style: textStyle ?? const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isRegenerating = currentEnergy < maxEnergy;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background image
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

            // Energy text and timer
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$currentEnergy',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isRegenerating) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(timeLeft),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
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
      if (fallbackWidget != null) {
        return SizedBox(
          width: width,
          height: height,
          child: Center(child: fallbackWidget),
        );
      }
      return SizedBox(
        width: width,
        height: height,
        child: ElevatedButton(
          onPressed: onTap,
          child: const SizedBox(),
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
        errorBuilder: (ctx, err, st) {
          if (fallbackWidget != null) {
            return SizedBox(
              width: width,
              height: height,
              child: Center(child: fallbackWidget),
            );
          }
          return SizedBox(
            width: width,
            height: height,
            child: ElevatedButton(
              onPressed: onTap,
              child: const SizedBox(),
            ),
          );
        },
      ),
    );
  }
}

/// Updated Leaderboard Item with dynamic data
/// Updated Leaderboard Item with better scaling
/// Updated Leaderboard Item with proper scaling
/// Updated Leaderboard Item with dynamic data
class _LeaderboardItem extends StatelessWidget {
  final int rank;
  final String displayName;
  final int score;
  final String itemBgAsset;
  final String rankBadgeAsset;
  final String rankLabelAsset;

  const _LeaderboardItem({
    required this.rank,
    required this.displayName,
    required this.score,
    required this.itemBgAsset,
    required this.rankBadgeAsset,
    required this.rankLabelAsset,
  });

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFC11E); // Epic - Gold
      case 2:
        return const Color(0xFFFE9898); // Awesome - Pink
      case 3:
        return const Color(0xFF98FE98); // Good - Green
      default:
        return const Color(0xFF98EBFE); // Smarty - Cyan
    }
  }

  String _getRankTitle(int rank) {
    switch (rank) {
      case 1:
        return 'EPIC';
      case 2:
        return 'AWESOME';
      case 3:
        return 'GOOD';
      default:
        return 'SMARTY';
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
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rank badge at top
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _getRankColor(rank),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getRankColor(rank).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
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
              const SizedBox(height: 16),

              // Player name
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

              // Rank title
              Text(
                '#$rank ${_getRankTitle(rank)}',
                style: TextStyle(
                  color: _getRankColor(rank),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),

              // Score display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.2),
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

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
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
      onTap: () => _showPlayerModal(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          image: itemBgAsset.isNotEmpty
              ? DecorationImage(
            image: AssetImage(itemBgAsset),
            fit: BoxFit.fill,
          )
              : null,
          color: itemBgAsset.isEmpty ? Colors.black26 : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Rank Badge
            SizedBox(
              width: 50,
              height: 50,
              child: rankBadgeAsset.isNotEmpty
                  ? Image.asset(
                rankBadgeAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildFallbackBadge(),
              )
                  : _buildFallbackBadge(),
            ),

            const SizedBox(width: 12),

            // Rank Title and Username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rank Title (e.g., "#1 EPIC")
                  Row(
                    children: [
                      Text(
                        '#$rank ',
                        style: TextStyle(
                          color: _getRankColor(rank),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _getRankTitle(rank),
                        style: TextStyle(
                          color: _getRankColor(rank),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Username
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Score with gem icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.diamond,
                    color: Color(0xFF6C5CE7),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    score.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _getRankColor(rank),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getRankColor(rank).withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
/// Custom styled SnackBar that matches app theme
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
              color: Colors.white.withOpacity(0.2),
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
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
        child: FutureBuilder<ByteData>(
          future: rootBundle.load(asset),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.transparent,
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Container(
                color: Colors.transparent,
                child: const Center(
                  child: Icon(Icons.pets, size: 120, color: Colors.white),
                ),
              );
            }
            try {
              return ClipRect(
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
                  ),
                ),
              );
            } catch (e, st) {
              debugPrint('Lottie error $e\n$st');
              return Container(
                color: Colors.transparent,
                child: const Center(
                  child: Icon(Icons.pets, size: 120, color: Colors.white),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
