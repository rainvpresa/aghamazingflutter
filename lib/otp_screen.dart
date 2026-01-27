import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aghamazing/services/api_client.dart';
import 'package:aghamazing/services/auth_api.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({Key? key}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _bg = 'assets/images/backgrounds/otp_screen.png';

  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  String _email = '';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadPendingEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(_bg), context);
    });
  }

  Future<void> _loadPendingEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _email = prefs.getString('PendingVerificationEmail') ?? '');
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _otp.trim();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complete 4-digit OTP'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isBusy = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await authApi.verifyOtp(email: _email, otp: otp);

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP verified successfully!'), backgroundColor: Colors.green),
      );

      // Navigate to login or main menu
      Navigator.of(context).pushReplacementNamed('/login');
    } on ApiException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verification failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            if (value.isNotEmpty) {
              // Move to next field
              if (index < 3) {
                _focusNodes[index + 1].requestFocus();
              } else {
                // Last field - unfocus to hide keyboard
                _focusNodes[index].unfocus();
              }
            } else if (value.isEmpty && index > 0) {
              // Move to previous field on backspace
              _focusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    final isSmall = screenWidth < 360;
    final isLarge = screenWidth > 600;

    // Responsive sizing
    final double topSpacing = isLarge
        ? screenHeight * 0.25
        : screenHeight * 0.35;
    final double horizontalPadding = isSmall ? 20.0 : 28.0;
    final double boxSize = isSmall ? 55.0 : 60.0;
    final double boxHeight = isSmall ? 65.0 : 70.0;
    final double boxSpacing = isSmall ? 12.0 : 16.0;

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              _bg,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue.shade200,
                      Colors.green.shade200,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 20.0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLarge ? 500.0 : 400.0,
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(height: topSpacing),

                          // OTP input boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (int i = 0; i < 4; i++) ...[
                                SizedBox(
                                  width: boxSize,
                                  height: boxHeight,
                                  child: _buildOtpBox(i),
                                ),
                                if (i < 3) SizedBox(width: boxSpacing),
                              ],
                            ],
                          ),

                          SizedBox(height: isSmall ? 40 : 50),

                          // Continue button
                          GestureDetector(
                            onTap: _isBusy ? null : _verifyOtp,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: isSmall ? 50 : 56,
                              width: double.infinity,
                              constraints: BoxConstraints(
                                maxWidth: isSmall ? 280 : 320,
                              ),
                              decoration: BoxDecoration(
                                color: _isBusy
                                    ? const Color(0xFF9BB0D1)
                                    : const Color(0xFF1866B2),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: _isBusy
                                    ? null
                                    : const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
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
                                  : Text(
                                'Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmall ? 15 : 16,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Debug: Show email (optional - remove in production)
                          if (_email.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Verification sent to: $_email',
                                style: TextStyle(
                                  fontSize: isSmall ? 12 : 13,
                                  color: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Resend OTP option
                          GestureDetector(
                            onTap: _isBusy ? null : _resendOtp,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Didn\'t receive code? Resend',
                                style: TextStyle(
                                  color: const Color(0xFF1957A8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmall ? 13 : 14,
                                  decoration: TextDecoration.underline,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
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

  Future<void> _resendOtp() async {
    if (_email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email found'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isBusy = true);

    try {
      await authApi.requestOtp(email: _email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent successfully!'), backgroundColor: Colors.green),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend OTP: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}