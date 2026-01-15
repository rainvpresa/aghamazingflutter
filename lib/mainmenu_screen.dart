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
        // ignore
        // ignore: avoid_print
        print('Precache failed $path: $e');
      }
    }
  }

  String asset(String key) => widget.uiAssets[key] ?? '';

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // --- asset original sizes you provided (used to compute aspect ratios) ---
    const orig = {
      'btn_scan': [280.0, 215.0],
      'btn_chatbot': [216.0, 144.0],
      'btn_profile': [216.0, 145.0],
      'btn_try': [244.0, 161.0],
      'btn_select': [669.0, 193.0],
      'energy': [280.0, 92.0],
      'bubble_power': [280.0, 92.0],
    };

    // --- tuning constants: fractions of screen width to use for each asset ---
    double selectFraction = 0.40;
    double tryFraction = 0.20;
    double profileFraction = 0.25;
    double chatFraction = 0.25;
    double scanFraction = 1.25;
    double topIconFraction = 0.20;

    double displayWidth(String key, double fraction) {
      final sizes = orig[key];
      if (sizes == null) return screenW * fraction;
      final w = sizes[0], h = sizes[1];
      final aspect = h / w;
      return screenW * fraction;
    }

    double displayHeight(String key, double fraction) {
      final sizes = orig[key];
      final w = sizes?[0] ?? 1.0;
      final h = sizes?[1] ?? 1.0;
      final aspect = h / w;
      return (screenW * fraction) * aspect;
    }

    final selectW = displayWidth('btn_select', selectFraction);
    final selectH = displayHeight('btn_select', selectFraction);

    final tryW = displayWidth('btn_try', tryFraction);
    final tryH = displayHeight('btn_try', tryFraction);

    final profileW = displayWidth('btn_profile', profileFraction);
    final profileH = displayHeight('btn_profile', profileFraction);

    final chatW = displayWidth('btn_chatbot', chatFraction);
    final chatH = displayHeight('btn_chatbot', chatFraction);

    final scanW = displayWidth('btn_scan', scanFraction);
    final scanH = displayHeight('btn_scan', scanFraction);

    final bubbleW = displayWidth('bubble_power', topIconFraction);
    final bubbleH = displayHeight('bubble_power', topIconFraction);

    final energyW = displayWidth('energy', topIconFraction);
    final energyH = displayHeight('energy', topIconFraction);

    final selectLeft = (screenW - selectW) / 1.16;
    final selectBottom = screenH * 0.03;

    final profileLeft = selectLeft + selectW * 0.62;
    final profileBottom = selectBottom + selectH * 0.30;

    final chatLeft = profileLeft + profileW + 8;
    final chatBottom = profileBottom;

    final mascotAsset = asset('mascot_lottie').isNotEmpty ? asset('mascot_lottie') : MainMenuScreen.mascotLottieDefault;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(MainMenuScreen.background, fit: BoxFit.cover)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // === GROUP 1: Bubble Power + Energy (Top Right) ===
                      Padding(
                        padding: const EdgeInsets.only(top: 0.5),
                        child: Row(
                          children: [
                            Consumer<SessionService>(
                              builder: (_, s, __) => IconStatButton(
                                assetPath: asset('bubble_power'),
                                width: bubbleW,
                                height: bubbleH,
                                value: s.bubblePower.toString(),
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bubble power tapped'))),
                                textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Consumer<SessionService>(
                              builder: (_, s, __) => IconStatButton(
                                assetPath: asset('energy'),
                                width: energyW,
                                height: energyH,
                                value: s.energy.toString(),
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Energy tapped'))),
                                textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: SizedBox(
                              width: screenW * 0.95,
                              height: screenH * 0.60,
                              // Quick fix: pass a small verticalNudge to lift the Lottie if it's visually low.
                              child: _MascotAnimation(
                                asset: mascotAsset,
                                width: screenW * 0.95,
                                height: screenH * 0.60,
                                verticalNudge: -0.08, // tweak this if needed (-0.12 .. 0.0)
                              ),
                            ),
                          ),

                          // ✅ SELECT button
                          Positioned(
                            left: selectLeft,
                            bottom: selectBottom,
                            child: SizedBox(
                              width: selectW,
                              height: selectH,
                              child: ImageAssetButton(
                                assetPath: asset('btn_select'),
                                width: selectW,
                                height: selectH,
                                fill: true,
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mascot Selected'))),
                                fallbackWidget: ElevatedButton(
                                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mascot Selected'))),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFf2c94c)),
                                  child: const Text('SELECT'),
                                ),
                              ),
                            ),
                          ),

                          // Profile + Chat positioned above SELECT button
                          Positioned(
                            right: screenW * 0.07,
                            bottom: selectBottom + selectH + 10,
                            child: Row(
                              children: [
                                ImageAssetButton(
                                  assetPath: asset('btn_profile'),
                                  width: profileW * 0.55,
                                  height: profileH * 0.55,
                                  fill: true,
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                                  fallbackWidget: const Icon(Icons.person, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                ImageAssetButton(
                                  assetPath: asset('btn_chatbot'),
                                  width: chatW * 0.55,
                                  height: chatH * 0.55,
                                  fill: true,
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                                  fallbackWidget: const Icon(Icons.chat_bubble, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: asset('leaderboard_bg').isNotEmpty ? DecorationImage(image: AssetImage(asset('leaderboard_bg')), fit: BoxFit.fill) : null,
                      color: asset('leaderboard_bg').isEmpty ? Colors.black.withOpacity(0.4) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (asset('leaderboard_emblem').isNotEmpty)
                              Image.asset(asset('leaderboard_emblem'), width: 44, height: 44)
                            else
                              Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('LEADERBOARDS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            ImageAssetButton(
                              assetPath: asset('btn_try'),
                              width: tryW,
                              height: tryH,
                              fill: true,
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TRY pressed'))),
                              fallbackWidget: ElevatedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TRY pressed'))), child: const Text('TRY')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const _LeaderboardItem(rank: 1, title: 'EPIC', color: Colors.orange),
                        const _LeaderboardItem(rank: 2, title: 'AWESOME', color: Colors.red),
                        const _LeaderboardItem(rank: 3, title: 'GOOD', color: Colors.green),
                        const SizedBox(height: 12),
                        if (asset('btn_gem_grab').isNotEmpty)
                          ImageAssetButton(
                            assetPath: asset('btn_gem_grab'),
                            width: double.infinity,
                            height: 56,
                            fill: true,
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Gem Grab'))),
                            fallbackWidget: const SizedBox.shrink(),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Gem Grab'))),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                            child: const Text('GEM GRAB'),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // === STANDALONE: AR Scan Button (placed AFTER SafeArea so it is on top and receives taps) ===
          Positioned(
            bottom: screenH * 0.56,
            left: 50,
            child: SizedBox(
              width: scanW * 0.12,
              height: scanH * 0.12,
              child: ImageAssetButton(
                assetPath: asset('btn_arscan'),
                width: scanW * 0.12,
                height: scanH * 0.12,
                fill: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ARScanScreen())),
                fallbackWidget: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// IconStatButton: image background with centered value (keeps value on top of artwork)
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
            // image background (fallback to simple colored box if missing)
            Image.asset(
              assetPath,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: width, height: height,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
              ),
            ),
            // centered value text
            Text(
              value,
              style: textStyle ?? const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// ImageAssetButton (unchanged except 'fill' support)
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
      if (fallbackWidget != null) return SizedBox(width: width, height: height, child: Center(child: fallbackWidget));
      return SizedBox(width: width, height: height, child: ElevatedButton(onPressed: onTap, child: const SizedBox()));
    }
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, st) {
          if (fallbackWidget != null) return SizedBox(width: width, height: height, child: Center(child: fallbackWidget));
          return SizedBox(width: width, height: height, child: ElevatedButton(onPressed: onTap, child: const SizedBox()));
        },
      ),
    );
  }
}

class _LeaderboardItem extends StatelessWidget {
  final int rank;
  final String title;
  final Color color;
  const _LeaderboardItem({Key? key, required this.rank, required this.title, required this.color}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color, child: Text('#$rank', style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Text('9999', style: TextStyle(color: Colors.white70))
        ],
      ),
    );
  }
}

/// Quick-fix Mascot animation: uses BoxFit.contain + optional vertical nudge + scale
class _MascotAnimation extends StatelessWidget {
  final String asset;
  final double width;
  final double height;
  /// small [-1..1] vertical nudge (negative moves up, positive moves down)
  final double verticalNudge;
  /// scale multiplier for the animation (1.0 = original size)
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
    // Wrap in SizedBox so Lottie knows the available area, use BoxFit.contain to avoid cropping,
    // Align to apply a small nudge if the art is off-center in the JSON, and Transform.scale to enlarge.
    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: Alignment(0, verticalNudge),
        child: FutureBuilder<ByteData>(
          future: rootBundle.load(asset),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(color: Colors.transparent, child: const Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Container(color: Colors.transparent, child: const Center(child: Icon(Icons.pets, size: 120, color: Colors.white)));
            }
            try {
              // Transform.scale enlarges the rendered animation inside the available box.
              // ClipRect prevents any accidental overflow from drawing outside the parent box.
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
              // ignore: avoid_print
              print('Lottie error $e\n$st');
              return Container(color: Colors.transparent, child: const Center(child: Icon(Icons.pets, size: 120, color: Colors.white)));
            }
          },
        ),
      ),
    );
  }
}