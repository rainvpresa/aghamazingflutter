import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:aghamazing1/main.dart';

// Exact cream from Lottie JSON: [0.9961, 0.9529, 0.8667] = rgb(254, 243, 221)
const _kCream = Color(0xFFFEF3DD);

class SunIntroScreen extends StatefulWidget {
  const SunIntroScreen({super.key});

  @override
  State<SunIntroScreen> createState() => _SunIntroScreenState();
}

class _SunIntroScreenState extends State<SunIntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _lottieController = AnimationController(vsync: this);

    _slideController = AnimationController(vsync: this);
    _slideAnimation = TweenSequence<Offset>([
      // Phase 1 — rise up from below screen
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, 1.0),
          end: const Offset(0, -0.3),
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      // Phase 2 — hang out bouncing
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, -0.3),
          end: const Offset(0, -0.3),
        ),
        weight: 40,
      ),
      // Phase 3 — rise off screen upward
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, -0.3),
          end: const Offset(0, -2.5),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_slideController);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));

    _slideController.duration = const Duration(milliseconds: 3500);
    _slideController.forward();

    await Future.delayed(const Duration(milliseconds: 2600));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthWrapper(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        // Scaffold fills the whole screen with cream —
        // the Lottie bg layer is hidden so there's no seam
        backgroundColor: _kCream,
        body: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              bottom: -size.width * 0.3,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: SizedBox(
                  width: size.width,
                  height: size.width * 1.1,
                  child: Lottie.asset(
                    'assets/animations/sunshine.json',
                    controller: _lottieController,
                    onLoaded: (composition) {
                      _lottieController
                        ..duration = composition.duration
                        ..repeat();
                    },
                    fit: BoxFit.contain,
                    // Hide the Lottie's own bg rectangle entirely.
                    // The layer name is "bg" and slot sid is "BG" per the JSON.
                    delegates: LottieDelegates(
                      values: [
                        ValueDelegate.opacity(
                          const ['bg', 'Group 17', '**'],
                          value: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}