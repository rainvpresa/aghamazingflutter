import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/sound_manager.dart';

// ─────────────────────────────────────────────
//  LAYOUT HELPER
// ─────────────────────────────────────────────
class _Layout {
  final bool isShort; // true on 1520x720 portrait

  _Layout(BuildContext context)
      : isShort = MediaQuery.of(context).size.height < 750;

  // Three-zone flex: top spacer / middle spacer / bottom padding
  int get topFlex    => isShort ? 7 : 12;
  int get middleFlex => isShort ? 10 : 16;
  int get bottomFlex => isShort ? 8  : 12;

  double get fieldH => isShort ? 46.0 : 52.0;
  double get btnH   => isShort ? 55.0 : 55.0;
  double get hPad   => isShort ? 28.0 : 36.0;
}

class FpScreen extends StatefulWidget {
  const FpScreen({super.key});

  @override
  State<FpScreen> createState() => _FpScreenState();
}

class _FpScreenState extends State<FpScreen> {
  static const _bg = 'assets/images/backgrounds/fp_screen.png';

  final _emailCtl = TextEditingController();
  bool _isBusy          = false;
  bool _buttonHovered   = false;
  bool _buttonPressed   = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(_bg), context);
    });
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_isBusy) return;
    setState(() => _isBusy = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
      const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final result =
      await AuthService().sendPasswordResetEmail(email: email);
      if (!mounted) return;
      Navigator.of(context).pop();

      if (result['success'] == true) {
        _showSuccessDialog(result['message'] ?? 'Email sent successfully');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Failed to send reset email'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _buttonPressed = false;
        });
      }
    }
  }

  List<TextSpan> _parseMessageWithBoldEmail(String message) {
    final emailPattern = RegExp(r'[a-zA-Z0-9*]+@[a-zA-Z0-9.]+');
    final match = emailPattern.firstMatch(message);
    if (match == null) return [TextSpan(text: message)];
    return [
      TextSpan(text: message.substring(0, match.start)),
      TextSpan(
          text: match.group(0),
          style: const TextStyle(fontWeight: FontWeight.bold)),
      TextSpan(text: message.substring(match.end)),
    ];
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(26.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 50),
                ),
                const SizedBox(height: 20),
                const Text('Email Sent!',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade700),
                    children: _parseMessageWithBoldEmail(message),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      SoundManager.instance.playClick();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1957A8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Text('OK',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendButton(_Layout l) {
    final double scale =
    _buttonPressed ? 0.98 : (_buttonHovered ? 1.02 : 1.0);
    final double elevation =
    _buttonPressed ? 2 : (_buttonHovered ? 10 : 6);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _buttonHovered = true),
      onExit: (_) => setState(() {
        _buttonHovered = false;
        _buttonPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) {
          if (!_isBusy) setState(() => _buttonPressed = true);
        },
        onTapUp: (_) {
          if (!_isBusy) {
            SoundManager.instance.playClick();
            setState(() => _buttonPressed = false);
            _sendResetEmail();
          }
        },
        onTapCancel: () => setState(() => _buttonPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          transform: Matrix4.identity()..scale(scale),
          curve: Curves.easeOut,
          height: l.btnH,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isBusy
                ? Colors.blue.shade200
                : const Color(0xFF1957A8),
            borderRadius: BorderRadius.circular(28.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: elevation,
                offset: Offset(0, elevation / 2),
              )
            ],
          ),
          alignment: Alignment.center,
          child: _isBusy
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : const Text(
            'Send Reset Link',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = _Layout(context);

    return Scaffold(
      body: Stack(
        children: [
          // ── Background — BoxFit.fill so it never shrinks ──────────
          Positioned.fill(
            child: Image.asset(
              _bg,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.blue.shade200),
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;

                return Column(
                  children: [

                    // ── Back button row ──────────────────────────────
                    SizedBox(
                      height: constraints.maxHeight * 0.09,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            SoundManager.instance.playClick();
                            Navigator.of(context).pop();
                          },
                          child: Image.asset(
                            'assets/images/pngs/btn_back.png',
                            width: maxW * 0.23,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Top spacer — clears background header artwork ──
                    Expanded(flex: l.topFlex, child: const SizedBox()),

                    // ── Email field ───────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: l.hPad),
                      child: SizedBox(
                        height: l.fieldH,
                        child: TextFormField(
                          controller: _emailCtl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            prefixIcon: const Icon(Icons.mail_outline),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.95),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14.0, horizontal: 16.0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Middle spacer ─────────────────────────────────
                    Expanded(flex: l.middleFlex, child: const SizedBox()),

                    // ── Send button ───────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: l.hPad),
                      child: _buildSendButton(l),
                    ),

                    // ── Bottom padding ────────────────────────────────
                    Expanded(flex: l.bottomFlex, child: const SizedBox()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
