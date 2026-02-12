import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'fp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _bg = 'assets/images/backgrounds/login_screen.png';

  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  bool _loginHovered = false;
  bool _loginPressed = false;
  bool _forgotHovered = false;
  bool _forgotPressed = false;
  bool _registerHovered = false;
  bool _registerPressed = false;

  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(_bg), context);
    });
    _loadSavedEmail();
  }

  // Automatically load the last used email
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('LastUsedEmail') ?? '';
    if (savedEmail.isNotEmpty) {
      _emailCtl.text = savedEmail;
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtl.text.trim();
    final password = _passCtl.text;

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email')));
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a password')));
      return;
    }
    if (_isBusy) return;

    setState(() => _isBusy = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authService = AuthService();
      final result = await authService.loginWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true) {
        // Always save the email for next time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('LastUsedEmail', email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful'),
              backgroundColor: Colors.green,
            ),
          );

          // Firebase Auth's StreamBuilder in main.dart will automatically
          // navigate to MainMenuScreen - no manual navigation needed!
          // But we can still navigate immediately for better UX:
          Navigator.of(context).pushReplacementNamed('/mainmenu');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _passCtl.clear();
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
      _passCtl.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _loginPressed = false;
        });
      }
    }
  }

  Color get _mutedTextColor => const Color(0xFF8391A1);
  Color get _secondaryTextColor => const Color(0xFF636363);
  Color get _linkColor => const Color(0xFF1957A8);
  Color get _linkPressedColor => const Color(0xFF0F3E73);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _bg,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Container(color: Colors.blue.shade200),
            ),
          ),
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
                          const Spacer(flex: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28.0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 24),
                                  Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: _emailCtl,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: (v) => (v == null ||
                                              v.trim().isEmpty)
                                              ? 'Please enter email'
                                              : null,
                                          decoration: InputDecoration(
                                            hintText: 'Email',
                                            prefixIcon:
                                            const Icon(Icons.mail_outline),
                                            filled: true,
                                            fillColor:
                                            Colors.white.withOpacity(0.95),
                                            contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 18.0,
                                                horizontal: 16.0),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(28.0),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        TextFormField(
                                          controller: _passCtl,
                                          obscureText: _obscure,
                                          validator: (v) => (v == null ||
                                              v.isEmpty)
                                              ? 'Please enter password'
                                              : null,
                                          decoration: InputDecoration(
                                            hintText: 'Password',
                                            prefixIcon:
                                            const Icon(Icons.lock_outline),
                                            suffixIcon: IconButton(
                                              icon: Icon(_obscure
                                                  ? Icons.visibility_off
                                                  : Icons.visibility),
                                              onPressed: () => setState(
                                                      () => _obscure = !_obscure),
                                            ),
                                            filled: true,
                                            fillColor:
                                            Colors.white.withOpacity(0.95),
                                            contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 18.0,
                                                horizontal: 16.0),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(28.0),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Spacer(),
                                            MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              onEnter: (_) => setState(
                                                      () => _forgotHovered = true),
                                              onExit: (_) => setState(
                                                      () => _forgotHovered = false),
                                              child: GestureDetector(
                                                behavior:
                                                HitTestBehavior.opaque,
                                                onTapDown: (_) => setState(() =>
                                                _forgotPressed = true),
                                                onTapUp: (_) => setState(() {
                                                  _forgotPressed = false;
                                                  Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              FpScreen()));
                                                }),
                                                onTapCancel: () => setState(() =>
                                                _forgotPressed = false),
                                                child: AnimatedDefaultTextStyle(
                                                  duration: const Duration(
                                                      milliseconds: 140),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _forgotPressed
                                                        ? _linkPressedColor
                                                        : (_forgotHovered
                                                        ? _linkColor
                                                        : _secondaryTextColor),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  child: const Text(
                                                      'Forgot Password?'),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        _buildAnimatedButton(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: TextStyle(
                                            color: _secondaryTextColor,
                                            fontSize: 14),
                                      ),
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        onEnter: (_) => setState(
                                                () => _registerHovered = true),
                                        onExit: (_) => setState(
                                                () => _registerHovered = false),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (_) => setState(
                                                  () => _registerPressed = true),
                                          onTapUp: (_) => setState(() {
                                            _registerPressed = false;
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                    const RegisterScreen()));
                                          }),
                                          onTapCancel: () => setState(
                                                  () => _registerPressed = false),
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                                milliseconds: 140),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _registerPressed
                                                  ? _linkPressedColor
                                                  : (_registerHovered
                                                  ? _linkColor
                                                  : _linkColor),
                                              decoration:
                                              TextDecoration.underline,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            child: const Text('Register Now'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(flex: 3),
                          const SizedBox(height: 20),
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

  Widget _buildAnimatedButton() {
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
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Text(
            'Login',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ),
      ),
    );
  }
}