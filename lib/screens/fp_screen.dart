import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class FpScreen extends StatefulWidget {
  const FpScreen({super.key});

  @override
  State<FpScreen> createState() => _FpScreenState();
}

class _FpScreenState extends State<FpScreen> {
  static const _bg = 'assets/images/backgrounds/fp_screen.png';

  final _emailCtl = TextEditingController();
  bool _isBusy = false;
  bool _buttonHovered = false;
  bool _buttonPressed = false;

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

    // Validate email
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

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      print('🔍 Attempting password reset for: $email');
      final authService = AuthService();
      final result = await authService.sendPasswordResetEmail(email: email);
      print('📊 Result: $result');

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true) {
        // Pass the message with masked email to the dialog
        _showSuccessDialog(result['message'] ?? 'Email sent successfully');
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to send reset email'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _sendResetEmail: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

  // PUT THE HELPER METHOD HERE
  List<TextSpan> _parseMessageWithBoldEmail(String message) {
    final emailPattern = RegExp(r'[a-zA-Z0-9*]+@[a-zA-Z0-9.]+');
    final match = emailPattern.firstMatch(message);

    if (match == null) {
      return [TextSpan(text: message)];
    }

    return [
      TextSpan(text: message.substring(0, match.start)),
      TextSpan(
        text: match.group(0),
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      TextSpan(text: message.substring(match.end)),
    ];
  }

  void _showSuccessDialog(String message) {  // Changed parameter
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(26.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Email Sent!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Message with masked email from result
                // Parse the message to make only the email bold
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    children: _parseMessageWithBoldEmail(message),
                  ),
                ),

                const SizedBox(height: 24),

                // OK Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to login
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1957A8),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              _bg,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Container(color: Colors.blue.shade200),
            ),
          ),

          // Content with responsive layout
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Back button
                          Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 185),

                          // Email Input Field - Centered with max width
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: TextFormField(
                                controller: _emailCtl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Enter your email',
                                  prefixIcon: const Icon(Icons.mail_outline),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.95),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 18.0,
                                    horizontal: 16.0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28.0),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Flexible spacer to push button to bottom
                          const Spacer(),

                          // Send Reset Link Button - Centered with max width
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28.0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: _buildSendButton(),
                            ),
                          ),

                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final double scale = _buttonPressed ? 0.98 : (_buttonHovered ? 1.02 : 1.0);
    final double elevation = _buttonPressed ? 2 : (_buttonHovered ? 10 : 6);
    final Duration animDur = const Duration(milliseconds: 140);
    final bool disabled = _isBusy;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _buttonHovered = true),
      onExit: (_) => setState(() {
        _buttonHovered = false;
        _buttonPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) {
          if (!disabled) setState(() => _buttonPressed = true);
        },
        onTapUp: (_) {
          if (!disabled) {
            setState(() => _buttonPressed = false);
            _sendResetEmail();
          }
        },
        onTapCancel: () => setState(() => _buttonPressed = false),
        child: AnimatedContainer(
          duration: animDur,
          transform: Matrix4.identity()..scale(scale),
          curve: Curves.easeOut,
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: disabled ? Colors.blue.shade200 : const Color(0xFF1957A8),
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
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text(
            'Send Reset Link',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}