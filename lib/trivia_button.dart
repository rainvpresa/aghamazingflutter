import 'package:flutter/material.dart';

enum AnswerState { idle, correct, wrong }

class TriviaButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final AnswerState state;
  final double width;
  final double height;

  const TriviaButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.state,
    required this.width,
    required this.height,
  });

  @override
  State<TriviaButton> createState() => _TriviaButtonState();
}

class _TriviaButtonState extends State<TriviaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.state == AnswerState.idle) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.state == AnswerState.idle) {
      widget.onPressed();
    }
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  Color _getBackgroundColor() {
    switch (widget.state) {
      case AnswerState.correct:
        return const Color(0xFF4CD964); // Green
      case AnswerState.wrong:
        return const Color(0xFFF44336); // Red
      case AnswerState.idle:
        return const Color(0xFF2196F3); // Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.width * 0.085,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.7),
                    offset: const Offset(2, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}