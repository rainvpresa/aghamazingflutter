import 'package:flutter/material.dart';
import 'package:aghamazing1/screens/login_screen.dart';
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

  // Shimmer: slow and obvious — 2 seconds
  late final AnimationController _shimmerController;
  // Wiggle: repeating loop
  late final AnimationController _wiggleController;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // slow & obvious
    );

    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    // Use postFrameCallback so widget is fully on screen first
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Play shimmer once
      await _shimmerController.forward();
      if (!mounted) return;

      // Wiggle every 2 seconds — one full sine cycle forward(), always ends at 0
      while (mounted && !_pressed) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || _pressed) return;
        // 4 full sine cycles (each forward() = one complete 0→peak→0 oscillation)
        for (int i = 0; i < 4; i++) {
          if (!mounted || _pressed) return;
          _wiggleController.value = 0;
          await _wiggleController.forward();
        }
        _wiggleController.value = 0; // guarantee back to 0 = straight
      }
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
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

            // Button
            Center(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.45,
                ),
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_shimmerController, _wiggleController]),
                  builder: (context, _) {
                    // Wiggle: ±8 degrees (bigger so it's obvious)
                    final rotateRad =
                        math.sin(_wiggleController.value * 2 * math.pi) * 8 * math.pi / 180;

                    final shimmerDone =
                        _shimmerController.status == AnimationStatus.completed;

                    return Transform.rotate(
                      angle: rotateRad,
                      child: SizedBox(
                        width: 160,
                        height: 48,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Button
                            ElevatedButton(
                              onPressed: widget.embedded
                                  ? null
                                  : () {
                                if (_pressed) return;
                                setState(() => _pressed = true);
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const LoginScreen()),
                                );
                              },
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

                            // Shimmer overlay
                            if (!shimmerDone)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
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
          Colors.white.withOpacity(0.7), // very bright so it's obvious
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