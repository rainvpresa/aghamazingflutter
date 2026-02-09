import 'package:flutter/material.dart';
import 'dart:math';

class ConfettiEffect extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onComplete;

  const ConfettiEffect({
    super.key,
    this.duration = const Duration(milliseconds: 1000),
    this.onComplete,
  });

  @override
  State<ConfettiEffect> createState() => _ConfettiEffectState();
}

class _ConfettiEffectState extends State<ConfettiEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(30, (_) => _ConfettiParticle());

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _animation.value,
              size: MediaQuery.of(context).size,
            ),
            size: MediaQuery.of(context).size,
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double rotationSpeed;
  final double fallSpeed;
  double rotation = 0;

  _ConfettiParticle() :
        x = Random().nextDouble(),
        y = -0.2 - Random().nextDouble() * 0.3,
        size = 0.01 + Random().nextDouble() * 0.03,
        color = _randomColor(),
        rotationSpeed = 0.5 + Random().nextDouble() * 2.0,
        fallSpeed = 0.8 + Random().nextDouble() * 1.2;

  static Color _randomColor() {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.pink,
    ];
    return colors[Random().nextInt(colors.length)];
  }

  void update(double progress) {
    rotation += rotationSpeed * progress;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  final Size size;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint();

    for (final particle in particles) {
      particle.update(progress);

      // Calculate position based on progress
      final x = particle.x * canvasSize.width;
      final y = particle.y * canvasSize.height + progress * canvasSize.height * particle.fallSpeed;

      // Draw confetti piece (triangle)
      final path = Path();
      final centerX = x;
      final centerY = y;
      final radius = particle.size * canvasSize.width;

      // Rotate the triangle
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(particle.rotation);

      path.moveTo(0, -radius);
      path.lineTo(-radius * 0.866, radius * 0.5);
      path.lineTo(radius * 0.866, radius * 0.5);
      path.close();

      paint.color = particle.color.withOpacity(1.0 - progress);
      canvas.drawPath(path, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}