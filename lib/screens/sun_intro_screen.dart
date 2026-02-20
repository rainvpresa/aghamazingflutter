import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:aghamazing1/main.dart'; // 👈 imports AuthWrapper

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
      // Phase 1 — peek up from bottom
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, 1.2),
          end: const Offset(0, 0.25),
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      // Phase 2 — hang out bouncing
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, 0.25),
          end: const Offset(0, 0.25),
        ),
        weight: 40,
      ),
      // Phase 3 — rise off screen upward
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, 0.25),
          end: const Offset(0, -1.5),
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
  } // 👈 this closing brace was missing

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
        backgroundColor: const Color(0xFF0D0D1A),
        body: Stack(
          children: [
            // Subtle radial glow behind sun
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _slideController,
                builder: (_, __) {
                  final progress = _slideController.value;
                  final glowOpacity = progress < 0.35
                      ? (progress / 0.35).clamp(0.0, 1.0) * 0.4
                      : progress > 0.75
                      ? ((1.0 - progress) / 0.25).clamp(0.0, 1.0) * 0.4
                      : 0.4;
                  return Container(
                    height: size.height * 0.5,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.bottomCenter,
                        radius: 1.2,
                        colors: [
                          const Color(0xFFFFD700).withOpacity(glowOpacity),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // The Lottie sun, sliding in/out
            SlideTransition(
              position: _slideAnimation,
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  child: Lottie.asset(
                    'assets/animations/sunshine.json',
                    controller: _lottieController,
                    onLoaded: (composition) {
                      _lottieController
                        ..duration = composition.duration
                        ..repeat();
                    },
                    fit: BoxFit.contain,
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