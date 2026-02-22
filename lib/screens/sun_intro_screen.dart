import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:aghamazing1/main.dart';
import 'package:aghamazing1/screens/welcome_screen.dart';

const _kCream = Color(0xFFFEF3DD);

class SunIntroScreen extends StatefulWidget {
  const SunIntroScreen({super.key});

  @override
  State<SunIntroScreen> createState() => _SunIntroScreenState();
}

class _SunIntroScreenState extends State<SunIntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  late final AnimationController _mainController;

  // Sun slides: peeks up, hangs, then rises off top
  late final Animation<Offset> _sunSlide;

  // Welcome screen starts below, rises up in sync with the sun's exit
  late final Animation<Offset> _welcomeSlide;

  @override
  void initState() {
    super.initState();

    _lottieController = AnimationController(vsync: this);

    // One shared controller drives everything in sync
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // Sun: peek up (0→35%), hang (35→75%), rise off top (75→100%)
    _sunSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, 1.0),
          end: const Offset(0, -0.3),
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, -0.3),
          end: const Offset(0, -0.3),
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, -0.3),
          end: const Offset(0, -2.5),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 25,
      ),
    ]).animate(_mainController);

    // Welcome screen: stays hidden below (0→75%), then rises up in sync (75→100%)
    _welcomeSlide = TweenSequence<Offset>([
      // Hold below screen while sun is peeking and hanging
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, 1.0),
          end: const Offset(0, 1.0),
        ),
        weight: 75,
      ),
      // Rise up together with the sun
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, 1.0),
          end: const Offset(0, 0.0),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 25,
      ),
    ]).animate(_mainController);

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mainController.forward();

    // After animation finishes, replace with AuthWrapper
    // (WelcomeScreen is now fully visible and in position)
    await Future.delayed(const Duration(milliseconds: 4300));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthWrapper(),
          // No transition — WelcomeScreen is already visually in place
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _kCream,
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Welcome screen slides up from below, revealed as sun rises
          SlideTransition(
            position: _welcomeSlide,
            child: const WelcomeScreen(embedded: true),
          ),

          // Sun sits on top, also sliding up
          Positioned(
            bottom: -size.width * 0.50,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _sunSlide,
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
    );
  }
}