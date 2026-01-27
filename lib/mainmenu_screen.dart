import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'services/session_service.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'arscan_screen.dart';

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
  const MainMenuScreen({Key? key}) : super(key: key);
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
  const _MainMenuBody({Key? key, required this.uiAssets}) : super(key: key);
  @override
  State<_MainMenuBody> createState() => _MainMenuBodyState();
}

class _MainMenuBodyState extends State<_MainMenuBody> {
  @override
  void initState() {
    super.initState();
    SessionService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precache());
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
        print('Precache failed $path: $e');
      }
    }
  }

  String asset(String key) => widget.uiAssets[key] ?? '';

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
                fit: BoxFit.cover
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Top stats row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Consumer<SessionService>(
                                  builder: (_, s, __) => IconStatButton(
                                    assetPath: asset('bubble_power'),
                                    width: topIconW,
                                    height: topIconW * 0.35,
                                    value: s.bubblePower.toString(),
                                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Bubble power tapped')),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Consumer<SessionService>(
                                  builder: (_, s, __) => IconStatButton(
                                    assetPath: asset('energy'),
                                    width: topIconW,
                                    height: topIconW * 0.35,
                                    value: s.energy.toString(),
                                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Energy tapped')),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Mascot section with flexible space
                          Expanded(
                            flex: 5,
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
                                  bottom: screenH * 0.12,
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

                                // Profile & Chat buttons (stacked vertically on right)
                                Positioned(
                                  right: 16,
                                  bottom: screenH * 0.09,
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
                                  bottom: screenH * 0.03,
                                  child: ImageAssetButton(
                                    assetPath: asset('btn_select'),
                                    width: selectW,
                                    height: selectW * 0.30,
                                    fill: true,
                                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Mascot Selected')),
                                    ),
                                    fallbackWidget: ElevatedButton(
                                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Mascot Selected')),
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

                          // Leaderboards section
                          Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                image: asset('leaderboard_bg').isNotEmpty
                                    ? DecorationImage(
                                  image: AssetImage(asset('leaderboard_bg')),
                                  fit: BoxFit.fill,
                                )
                                    : null,
                                color: asset('leaderboard_bg').isEmpty
                                    ? Colors.black.withOpacity(0.4)
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                          decoration: const BoxDecoration(
                                            color: Colors.purple,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'LEADERBOARDS',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ImageAssetButton(
                                        assetPath: asset('btn_try'),
                                        width: tryW,
                                        height: tryW * 0.66,
                                        fill: true,
                                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('TRY pressed')),
                                        ),
                                        fallbackWidget: ElevatedButton(
                                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('TRY pressed')),
                                          ),
                                          child: const Text('TRY'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const _LeaderboardItem(
                                    rank: 1,
                                    title: 'EPIC',
                                    color: Colors.orange,
                                  ),
                                  const _LeaderboardItem(
                                    rank: 2,
                                    title: 'AWESOME',
                                    color: Colors.red,
                                  ),
                                  const _LeaderboardItem(
                                    rank: 3,
                                    title: 'GOOD',
                                    color: Colors.green,
                                  ),
                                  const SizedBox(height: 12),
                                  if (asset('btn_gem_grab').isNotEmpty)
                                    ImageAssetButton(
                                      assetPath: asset('btn_gem_grab'),
                                      width: double.infinity,
                                      height: 56,
                                      fill: true,
                                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Open Gem Grab')),
                                      ),
                                      fallbackWidget: const SizedBox.shrink(),
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Open Gem Grab')),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                      ),
                                      child: const Text('GEM GRAB'),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 1),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
    Key? key,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.value,
    this.textStyle,
    this.onTap,
  }) : super(key: key);

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
              errorBuilder: (_, __, ___) => Container(
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

/// ImageAssetButton
class ImageAssetButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final Widget? fallbackWidget;
  final bool fill;

  const ImageAssetButton({
    Key? key,
    required this.assetPath,
    required this.onTap,
    this.width,
    this.height,
    this.fallbackWidget,
    this.fill = false,
  }) : super(key: key);

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

class _LeaderboardItem extends StatelessWidget {
  final int rank;
  final String title;
  final Color color;
  const _LeaderboardItem({
    Key? key,
    required this.rank,
    required this.title,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Text(
              '#$rank',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const Text(
            '9999',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Mascot animation
class _MascotAnimation extends StatelessWidget {
  final String asset;
  final double width;
  final double height;
  final double verticalNudge;
  final double scale;

  const _MascotAnimation({
    Key? key,
    required this.asset,
    required this.width,
    required this.height,
    this.verticalNudge = 0.0,
    this.scale = 1.2,
  }) : super(key: key);

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
              print('Lottie error $e\n$st');
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