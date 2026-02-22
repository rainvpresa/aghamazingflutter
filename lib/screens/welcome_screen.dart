import 'package:flutter/material.dart';
import 'package:aghamazing1/services/sound_manager.dart';
import 'dart:math' as math;

class WelcomeScreen extends StatefulWidget {
  final bool embedded;
  const WelcomeScreen({super.key, this.embedded = false});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  static const _bg = 'assets/images/backgrounds/welcome_screen.png';

  late final AnimationController _shimmerController;
  late final AnimationController _wiggleController;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // play shimmer once
      await _shimmerController.forward();
      if (!mounted) return;

      // repeat wiggle loop
      while (mounted && !_pressed) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || _pressed) return;

        for (int i = 0; i < 4; i++) {
          if (!mounted || _pressed) return;
          _wiggleController.value = 0;
          await _wiggleController.forward();
        }
        _wiggleController.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  void _onStartPressed() {
    if (_pressed || widget.embedded) return;

    setState(() => _pressed = true);

    // play click sound (non-blocking)
    SoundManager.instance.playClick();

    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenH = constraints.maxHeight;
            final screenW = constraints.maxWidth;

            // keeps button visible across devices
            final buttonTop = (screenH * 0.78).clamp(0.0, screenH - 80.0);

            return Stack(
              children: [
                // Background
                Positioned.fill(
                  child: Image.asset(
                    _bg,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey.shade200),
                  ),
                ),

                // Start Button
                Positioned(
                  top: buttonTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_shimmerController, _wiggleController]),
                      builder: (context, _) {
                        final rotateRad =
                            math.sin(_wiggleController.value * 2 * math.pi) *
                                8 *
                                math.pi /
                                180;

                        final shimmerDone =
                            _shimmerController.status ==
                                AnimationStatus.completed;

                        return Transform.rotate(
                          angle: rotateRad,
                          child: SizedBox(
                            width: (screenW * 0.42).clamp(140.0, 220.0),
                            height: 52,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ElevatedButton(
                                  onPressed: widget.embedded
                                      ? null
                                      : _onStartPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1866B2),
                                    disabledBackgroundColor:
                                        const Color(0xFF1866B2),
                                    elevation: 4,
                                    shadowColor: Colors.black45,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 20,
                                    ),
                                  ),
                                  child: const Text(
                                    'Start',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                // shimmer overlay
                                if (!shimmerDone)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(28),
                                        child: CustomPaint(
                                          painter: _ShimmerPainter(
                                              _shimmerController.value),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  const _ShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const stripeW = 60.0;
    final cx = -stripeW + (size.width + stripeW * 2) * progress;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.7),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment((cx - stripeW) / size.width * 2 - 1, 0),
        end: Alignment((cx + stripeW) / size.width * 2 - 1, 0),
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}