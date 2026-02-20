import 'package:flutter/material.dart';
import 'package:aghamazing1/screens/login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _bg = 'assets/images/backgrounds/welcome_screen.png';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(_bg), context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final shortSide = isLandscape ? constraints.maxHeight : constraints.maxWidth;

          // Scale button size relative to the short side of the screen
          final buttonWidth = shortSide * 0.38;
          final buttonHeight = shortSide * 0.15;
          final buttonFontSize = shortSide * 0.042;
          final buttonRadius = buttonHeight / 2;

          // In portrait, push button ~65% down. In landscape, ~60% down.
          final topFraction = isLandscape ? 0.55 : 0.65;

          return SizedBox.expand(
            child: Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: Image.asset(
                    _bg,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        Container(color: Colors.grey.shade200),
                  ),
                ),

                // Button positioned proportionally
                Positioned(
                  top: constraints.maxHeight * topFraction,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1866B2),
                          elevation: 4,
                          shadowColor: Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(buttonRadius),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: buttonHeight * 0.25,
                            horizontal: buttonWidth * 0.12,
                          ),
                        ),
                        child: Text(
                          'Start',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}