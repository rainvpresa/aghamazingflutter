import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aghamazing/services/api_client.dart';
import 'package:aghamazing/services/auth_api.dart';
import 'fp_screen.dart';
import 'register_screen.dart';
import 'mainmenu_screen.dart'; // navigate here on success

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _bg = 'assets/images/backgrounds/login_screen.png';

  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _remember = false;
  bool _obscure = true;

  // Interaction states for hover/press animations & link color changes
  bool _loginHovered = false;
  bool _loginPressed = false;
  bool _forgotHovered = false;
  bool _forgotPressed = false;
  bool _registerHovered = false;
  bool _registerPressed = false;

  // busy flag to prevent duplicate submits
  bool _isBusy = false;

  // Remember-me session days (same as Unity default)
  static const int rememberMeSessionDays = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(_bg), context);
    });
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getInt('RememberMe') ?? 0;
    if (remember == 1) {
      final savedEmail = prefs.getString('SavedEmail') ?? '';
      if (savedEmail.isNotEmpty) {
        _emailCtl.text = savedEmail;
        setState(() => _remember = true);
      }
      // Also optionally check session expiry and token here if you want auto-login
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  // New: login via API
  Future<void> _submit() async {
    // Simple client-side validation
    final email = _emailCtl.text.trim();
    final password = _passCtl.text;

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email')));
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a password')));
      return;
    }
    if (_isBusy) return;

    setState(() => _isBusy = true);

    // Show modal loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Call login API
      final key = await authApi.loginUser(email: email, password: password);

      // Persist token and email (PlayerPrefs equivalent)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('UserToken', key);
      await prefs.setString('UserEmail', email);

      // Handle Remember Me session storage like Unity:
      if (_remember) {
        await prefs.setInt('RememberMe', 1);
        await prefs.setString('SavedEmail', email);
        final expiry = DateTime.now().add(Duration(days: rememberMeSessionDays)).toIso8601String();
        await prefs.setString('SessionExpiry', expiry);
      } else {
        await prefs.setInt('RememberMe', 0);
        await prefs.remove('SavedEmail');
        await prefs.remove('SessionExpiry');
      }

      // Close loader
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login successful'), backgroundColor: Colors.green));
      }

      // Navigate to main menu (replace with your screen)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainMenuScreen()),
        );
      }
    } on ApiException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
      // Clear password field for security
      _passCtl.clear();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red));
      }
      _passCtl.clear();
    } finally {
      if (mounted) setState(() {
        _isBusy = false;
        _loginPressed = false;
      });
    }
  }

  Color get _mutedTextColor => const Color(0xFF8391A1); // remember me color (gray-blue)
  Color get _secondaryTextColor => const Color(0xFF636363); // darker gray used for "Forgot Password?" default
  Color get _linkColor => const Color(0xFF1957A8); // blue used for Register / links
  Color get _linkPressedColor => const Color(0xFF0F3E73); // darker blue when pressed

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLarge = mq.size.width > 600;

    // Use proportional spacing to adapt across screen heights
    final double topSpacing = isLarge ? mq.size.height * 0.08 : mq.size.height * 0.18;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _bg,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(color: Colors.blue.shade200),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isLarge ? 520 : 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: topSpacing),

                      // form fields laid over background
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtl,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter email' : null,
                              decoration: InputDecoration(
                                hintText: 'Email',
                                prefixIcon: const Icon(Icons.mail_outline),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.95),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28.0),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passCtl,
                              obscureText: _obscure,
                              validator: (v) => (v == null || v.isEmpty) ? 'Please enter password' : null,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.95),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28.0),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Remember + Forgot row
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _remember,
                                      onChanged: (v) => setState(() => _remember = v ?? false),
                                    ),
                                    Text(
                                      'Remember me',
                                      style: TextStyle(color: _mutedTextColor),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // "Forgot Password?" with hover/press color change & navigation
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => setState(() => _forgotHovered = true),
                                  onExit: (_) => setState(() => _forgotHovered = false),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (_) => setState(() => _forgotPressed = true),
                                    onTapUp: (_) => setState(() {
                                      _forgotPressed = false;
                                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FpScreen()));
                                    }),
                                    onTapCancel: () => setState(() => _forgotPressed = false),
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 140),
                                      style: TextStyle(
                                        color: _forgotPressed
                                            ? _linkPressedColor
                                            : (_forgotHovered ? _linkColor : _secondaryTextColor),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      child: const Text('Forgot Password?'),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Login button with hover/press animation
                            _buildAnimatedButton(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Register row: non-white text and clickable "Register Now"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: _secondaryTextColor),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) => setState(() => _registerHovered = true),
                            onExit: (_) => setState(() => _registerHovered = false),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) => setState(() => _registerPressed = true),
                              onTapUp: (_) => setState(() {
                                _registerPressed = false;
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterScreen()));
                              }),
                              onTapCancel: () => setState(() => _registerPressed = false),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 140),
                                style: TextStyle(
                                  color: _registerPressed
                                      ? _linkPressedColor
                                      : (_registerHovered ? _linkColor : _linkColor),
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                                child: const Text('Register Now'),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildAnimatedButton() {
    // Visual values when hovered/pressed
    final double scale = _loginPressed ? 0.98 : (_loginHovered ? 1.02 : 1.0);
    final double elevation = _loginPressed ? 2 : (_loginHovered ? 10 : 6);
    final Duration animDur = const Duration(milliseconds: 140);

    final bool disabled = _isBusy;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _loginHovered = true),
      onExit: (_) => setState(() {
        _loginHovered = false;
        _loginPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) {
          if (!disabled) setState(() => _loginPressed = true);
        },
        onTapUp: (_) {
          if (!disabled) {
            setState(() => _loginPressed = false);
            _submit();
          }
        },
        onTapCancel: () => setState(() => _loginPressed = false),
        child: AnimatedContainer(
          duration: animDur,
          transform: Matrix4.identity()..scale(scale),
          curve: Curves.easeOut,
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: disabled ? Colors.blue.shade200 : const Color(0xFF1957A8),
            borderRadius: BorderRadius.circular(28.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: elevation.toDouble(),
                offset: Offset(0, elevation / 2),
              )
            ],
          ),
          alignment: Alignment.center,
          child: _isBusy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text(
            'Login',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }
}