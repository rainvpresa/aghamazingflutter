import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aghamazing/services/api_client.dart';
import 'package:aghamazing/services/auth_api.dart';
import 'fp_screen.dart';
import 'register_screen.dart';
import 'mainmenu_screen.dart';

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

  bool _loginHovered = false;
  bool _loginPressed = false;
  bool _forgotHovered = false;
  bool _forgotPressed = false;
  bool _registerHovered = false;
  bool _registerPressed = false;

  bool _isBusy = false;

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
      final key = await authApi.loginUser(email: email, password: password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('UserToken', key);
      await prefs.setString('UserEmail', email);

      if (_remember) {
        await prefs.setInt('RememberMe', 1);
        await prefs.setString('SavedEmail', email);
        final expiry = DateTime.now()
            .add(Duration(days: rememberMeSessionDays))
            .toIso8601String();
        await prefs.setString('SessionExpiry', expiry);
      } else {
        await prefs.setInt('RememberMe', 0);
        await prefs.remove('SavedEmail');
        await prefs.remove('SessionExpiry');
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Login successful'), backgroundColor: Colors.green));
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainMenuScreen()),
        );
      }
    } on ApiException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
      _passCtl.clear();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Login failed: $e'), backgroundColor: Colors.red));
      }
      _passCtl.clear();
    } finally {
      if (mounted)
        setState(() {
          _isBusy = false;
          _loginPressed = false;
        });
    }
  }

  Color get _mutedTextColor => const Color(0xFF8391A1);
  Color get _secondaryTextColor => const Color(0xFF636363);
  Color get _linkColor => const Color(0xFF1957A8);
  Color get _linkPressedColor => const Color(0xFF0F3E73);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;

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
                          // Top spacer - pushes content down from top
                          const Spacer(flex: 4),

                          // Main content container
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28.0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 24),

                                  // Form fields
                                  Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        // Email field
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

                                        // Password field
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

                                        // Remember me + Forgot password row
                                        Row(
                                          children: [
                                            Row(
                                              children: [
                                                SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: Checkbox(
                                                    value: _remember,
                                                    onChanged: (v) => setState(() =>
                                                    _remember = v ?? false),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Remember me',
                                                  style: TextStyle(
                                                      color: _mutedTextColor,
                                                      fontSize: 14),
                                                ),
                                              ],
                                            ),
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

                                        // Login button
                                        _buildAnimatedButton(),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Register row
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
                                                        RegisterScreen()));
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

                          // Bottom spacer - pushes logos to bottom
                          const Spacer(flex: 3),

                          // Bottom logos (if you have them in your background, this is optional)
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