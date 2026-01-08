import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aghamazing/services/api_client.dart'; // <- use package import
import 'package:aghamazing/services/auth_api.dart';   // optional, for catching ApiException


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _bg = 'assets/images/backgrounds/register_screen.png';

  final _nickCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _nickTouched = false;
  bool _emailTouched = false;
  bool _passTouched = false;
  bool _confirmTouched = false;

  bool _isNickValid = false;
  bool _isEmailValid = false;
  bool _isPassValid = false;
  bool _isConfirmValid = false;

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isCreating = false;

  final RegExp _emailRegex = RegExp(r"^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$");
  final RegExp _numberRegex = RegExp(r'\d');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(_bg), context);
    });
  }

  @override
  void dispose() {
    _nickCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  // Validation rules:
  bool _validateNick(String v) => v.trim().isNotEmpty;
  bool _validateEmail(String v) => _emailRegex.hasMatch(v.trim());
  bool _validatePass(String v) => v.length >= 8 && _numberRegex.hasMatch(v);

  void _onNickChanged(String v) {
    setState(() {
      _nickTouched = true;
      _isNickValid = _validateNick(v);
    });
  }

  void _onEmailChanged(String v) {
    setState(() {
      _emailTouched = true;
      _isEmailValid = _validateEmail(v);
    });
  }

  void _onPassChanged(String v) {
    setState(() {
      _passTouched = true;
      _isPassValid = _validatePass(v);
      if (_confirmTouched) {
        _isConfirmValid = _confirmCtl.text.isNotEmpty && _confirmCtl.text == v;
      }
    });
  }

  void _onConfirmChanged(String v) {
    setState(() {
      _confirmTouched = true;
      _isConfirmValid = v.isNotEmpty && v == _passCtl.text;
    });
  }

  Color _borderColor(bool touched, bool valid) {
    if (!touched) return Colors.transparent;
    return valid ? Colors.green : Colors.red;
  }

  bool get _canCreate => _isNickValid && _isEmailValid && _isPassValid && _isConfirmValid && !_isCreating;

  Future<void> _onCreatePressed() async {
    // mark touched to show validation
    setState(() {
      _nickTouched = _emailTouched = _passTouched = _confirmTouched = true;
    });

    if (!_canCreate) return;

    setState(() => _isCreating = true);

    // show modal loader
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final username = _nickCtl.text.trim();
    final email = _emailCtl.text.trim();
    final password = _passCtl.text;

    try {
      // Call server registration
      final key = await authApi.registerUser(username: username, email: email, password: password);

      // Save pending verification email (like PlayerPrefs)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('PendingVerificationEmail', email);

      // Optionally request OTP (Unity code did this)
      await authApi.requestOtp(email: email);

      // Close loader
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success and navigate to OTP screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created. Check your email for verification'), backgroundColor: Colors.green),
        );

        // Navigate to OTP screen (either by name or route)
        Navigator.of(context).pushReplacementNamed('/otp');
      }
    } on ApiException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // Helper that builds a pill-shaped input with animated border color
  Widget _buildPillField({
    required Widget child,
    required bool touched,
    required bool valid,
    double height = 56,
  }) {
    final bc = _borderColor(touched, valid);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: bc == Colors.transparent ? null : Border.all(color: bc, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLarge = mq.size.width > 600;

    // Increased topSpacing so text fields and everything below are positioned lower
    final double topSpacing = isLarge ? mq.size.height * 0.08 : mq.size.height * 0.22;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _bg,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.blue.shade200),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isLarge ? 520 : 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: topSpacing),

                      // "Create an account" sits over the background artwork; include small spacing
                      const SizedBox(height: 8),

                      // Nickname field
                      _buildPillField(
                        touched: _nickTouched,
                        valid: _isNickValid,
                        child: TextField(
                          controller: _nickCtl,
                          onChanged: _onNickChanged,
                          decoration: const InputDecoration(
                            hintText: 'Nickname',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Email field with mail icon
                      _buildPillField(
                        touched: _emailTouched,
                        valid: _isEmailValid,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.mail_outline, color: Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _emailCtl,
                                onChanged: _onEmailChanged,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: 'Email',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Password
                      _buildPillField(
                        touched: _passTouched,
                        valid: _isPassValid,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.lock_outline, color: Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _passCtl,
                                onChanged: _onPassChanged,
                                obscureText: _obscurePass,
                                decoration: const InputDecoration(
                                  hintText: 'Password',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Confirm password
                      _buildPillField(
                        touched: _confirmTouched,
                        valid: _isConfirmValid,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.lock_outline, color: Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _confirmCtl,
                                onChanged: _onConfirmChanged,
                                obscureText: _obscureConfirm,
                                decoration: const InputDecoration(
                                  hintText: 'Confirm password',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ],
                        ),
                      ),

                      // increased gap to push Create button and subsequent items lower
                      const SizedBox(height: 30),

                      // Create button (pill) — disabled/enabled styles
                      GestureDetector(
                        onTap: _canCreate ? _onCreatePressed : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 52,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _canCreate ? const Color(0xFF1866B2) : const Color(0xFF9BB0D1),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: _canCreate
                                ? [
                              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                            ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: _isCreating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                            'Create',
                            style: TextStyle(
                              color: _canCreate ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Existing user? Login (match mock: small, subtle)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: RichText(
                            text: TextSpan(
                              text: 'Existing user? ',
                              style: TextStyle(color: Colors.black87, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: 'Login',
                                  style: TextStyle(
                                    color: const Color(0xFF1957A8),
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
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