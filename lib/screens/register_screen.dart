import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────
//  LAYOUT HELPER
// ─────────────────────────────────────────────
class _Layout {
  final bool isShort; // true on 1520x720 portrait (~720 logical height)

  _Layout(BuildContext context)
      : isShort = MediaQuery.of(context).size.height < 750;

  // Top spacer — reserves room for background artwork header
  int get topFlex     => isShort ? 45 : 48;
  int get contentFlex => isShort ? 80 : 74;

  double get fieldH       => isShort ? 44.0 : 52.0;
  double get fieldSpacing => isShort ? 14.0  : 16.0;
  double get btnH         => isShort ? 44.0 : 50.0;
  double get sectionGap   => isShort ? 14.0 : 16.0;
  double get hPad         => isShort ? 24.0 : 28.0;
  double fontSize(double base) => isShort ? base - 1 : base;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _bg = 'assets/images/backgrounds/register_screen.png';

  final _nickCtl    = TextEditingController();
  final _emailCtl   = TextEditingController();
  final _passCtl    = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _nickTouched    = false;
  bool _emailTouched   = false;
  bool _passTouched    = false;
  bool _confirmTouched = false;

  bool _isNickValid    = false;
  bool _isEmailValid   = false;
  bool _isPassValid    = false;
  bool _isConfirmValid = false;

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isCreating     = false;
  bool _acceptedTerms  = false;

  final RegExp _emailRegex  = RegExp(r"^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$");
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

  bool _validateNick(String v)  => v.trim().isNotEmpty;
  bool _validateEmail(String v) => _emailRegex.hasMatch(v.trim());
  bool _validatePass(String v)  => v.length >= 8 && _numberRegex.hasMatch(v);

  void _onNickChanged(String v) => setState(() {
    _nickTouched = true;
    _isNickValid = _validateNick(v);
  });

  void _onEmailChanged(String v) => setState(() {
    _emailTouched = true;
    _isEmailValid = _validateEmail(v);
  });

  void _onPassChanged(String v) => setState(() {
    _passTouched = true;
    _isPassValid = _validatePass(v);
    if (_confirmTouched) {
      _isConfirmValid =
          _confirmCtl.text.isNotEmpty && _confirmCtl.text == v;
    }
  });

  void _onConfirmChanged(String v) => setState(() {
    _confirmTouched = true;
    _isConfirmValid = v.isNotEmpty && v == _passCtl.text;
  });

  Color _borderColor(bool touched, bool valid) {
    if (!touched) return Colors.transparent;
    return valid ? Colors.green : Colors.red;
  }

  bool get _canCreate =>
      _isNickValid &&
          _isEmailValid &&
          _isPassValid &&
          _isConfirmValid &&
          _acceptedTerms &&
          !_isCreating;

  // ─────────────────────────────────────────────
  //  TERMS DIALOG  (unchanged logic)
  // ─────────────────────────────────────────────
  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LayoutBuilder(builder: (context, constraints) {
          final screenSize = MediaQuery.of(context).size;
          final isSmallScreen = screenSize.width < 600;
          final isVerySmall = screenSize.width < 360;
          final dialogWidth = isVerySmall
              ? screenSize.width * 0.95
              : (isSmallScreen ? screenSize.width * 0.9 : 500.0);
          final dialogHeight = screenSize.height * 0.85;
          final hp = isVerySmall ? 12.0 : (isSmallScreen ? 16.0 : 20.0);

          return Dialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: EdgeInsets.symmetric(
                horizontal: isVerySmall ? 8 : 16, vertical: 24),
            child: Container(
              constraints:
              BoxConstraints(maxHeight: dialogHeight, maxWidth: dialogWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                    EdgeInsets.symmetric(horizontal: hp, vertical: hp),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1866B2),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Terms and Conditions',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isVerySmall ? 16 : 18,
                                  fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.white,
                              size: isVerySmall ? 20 : 24),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(hp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTermsSection('Introduction',
                              'Welcome to our application. By creating an account and using our services, you agree to be bound by these Terms and Conditions.',
                              isSmall: isVerySmall),
                          _buildTermsSection('Account Registration',
                              'You must provide accurate and complete information when creating your account. You are responsible for maintaining the confidentiality of your account credentials.',
                              isSmall: isVerySmall),
                          _buildTermsSection('User Responsibilities',
                              'You agree to use our services in compliance with all applicable laws and regulations.',
                              isSmall: isVerySmall),
                          _buildTermsSection('Privacy and Data',
                              'Your privacy is important to us. We collect and process your personal data in accordance with our Privacy Policy.',
                              isSmall: isVerySmall),
                          _buildTermsSection('Intellectual Property',
                              'All content, features, and functionality of our services are owned by us and protected by international copyright laws.',
                              isSmall: isVerySmall),
                          _buildTermsSection('Limitation of Liability',
                              'We provide our services "as is" without any warranties.',
                              isSmall: isVerySmall),
                          _buildTermsSection('Termination',
                              'We reserve the right to suspend or terminate your account at any time for violation of these terms.',
                              isSmall: isVerySmall),
                          _buildTermsSection('Changes to Terms',
                              'We may modify these Terms and Conditions at any time. Continued use constitutes acceptance.',
                              isSmall: isVerySmall),
                          _buildTermsSection('Contact Information',
                              'If you have any questions, please contact us through our support channels.',
                              isSmall: isVerySmall),
                          const SizedBox(height: 8),
                          Text('Last updated: January 2026',
                              style: TextStyle(
                                  fontSize: isVerySmall ? 11 : 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(hp),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1866B2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28)),
                        ),
                        child: const Text('Close',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildTermsSection(String title, String content,
      {bool isSmall = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: isSmall ? 15 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          SizedBox(height: isSmall ? 6 : 8),
          Text(content,
              style: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  color: Colors.black87,
                  height: 1.5)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  CREATE ACCOUNT
  // ─────────────────────────────────────────────
  Future<void> _onCreatePressed() async {
    setState(() {
      _nickTouched = _emailTouched = _passTouched = _confirmTouched = true;
    });
    if (!_canCreate) return;
    setState(() => _isCreating = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final email    = _emailCtl.text.trim();
    final password = _passCtl.text;
    final username = _nickCtl.text.trim();

    try {
      final result = await AuthService().registerWithEmailVerification(
        email: email,
        password: password,
        displayName: username,
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      if (result['success'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.email, color: Color(0xFF1866B2)),
              SizedBox(width: 12),
              Text('Verify Your Email'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('We\'ve sent a verification email to:'),
                const SizedBox(height: 8),
                Text(email,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text(
                    'Please check your inbox and click the verification link to activate your account.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Registration failed'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ─────────────────────────────────────────────
  //  PILL FIELD
  // ─────────────────────────────────────────────
  Widget _buildPillField({
    required Widget child,
    required bool touched,
    required bool valid,
    required double height,
  }) {
    final bc = _borderColor(touched, valid);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border:
        bc == Colors.transparent ? null : Border.all(color: bc, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
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
                final maxH = constraints.maxHeight;
                final maxW = constraints.maxWidth;

                return Column(
                  children: [

                    // ── Top spacer (clears background artwork header) ─
                    Expanded(flex: l.topFlex, child: const SizedBox()),

                    // ── Form content ─────────────────────────────────
                    Expanded(
                      flex: l.contentFlex,
                      child: SingleChildScrollView(
                        // Scroll safety for when keyboard is open
                        physics: const ClampingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: l.hPad),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              // Nickname
                              _buildPillField(
                                touched: _nickTouched,
                                valid: _isNickValid,
                                height: l.fieldH,
                                child: TextField(
                                  controller: _nickCtl,
                                  onChanged: _onNickChanged,
                                  style: TextStyle(fontSize: l.fontSize(15)),
                                  decoration: InputDecoration(
                                    hintText: 'Nickname',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: l.fieldH * 0.28),
                                  ),
                                ),
                              ),

                              SizedBox(height: l.fieldSpacing),

                              // Email
                              _buildPillField(
                                touched: _emailTouched,
                                valid: _isEmailValid,
                                height: l.fieldH,
                                child: Row(children: [
                                  const SizedBox(width: 12),
                                  const Icon(Icons.mail_outline,
                                      color: Colors.black54, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _emailCtl,
                                      onChanged: _onEmailChanged,
                                      keyboardType: TextInputType.emailAddress,
                                      style:
                                      TextStyle(fontSize: l.fontSize(15)),
                                      decoration: InputDecoration(
                                        hintText: 'Email',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: l.fieldH * 0.28),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ]),
                              ),

                              SizedBox(height: l.fieldSpacing),

                              // Password
                              _buildPillField(
                                touched: _passTouched,
                                valid: _isPassValid,
                                height: l.fieldH,
                                child: Row(children: [
                                  const SizedBox(width: 12),
                                  const Icon(Icons.lock_outline,
                                      color: Colors.black54, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _passCtl,
                                      onChanged: _onPassChanged,
                                      obscureText: _obscurePass,
                                      style:
                                      TextStyle(fontSize: l.fontSize(15)),
                                      decoration: InputDecoration(
                                        hintText: 'Password',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: l.fieldH * 0.28),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                        _obscurePass
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.black54,
                                        size: 20),
                                    onPressed: () => setState(
                                            () => _obscurePass = !_obscurePass),
                                  ),
                                ]),
                              ),

                              SizedBox(height: l.fieldSpacing),

                              // Confirm password
                              _buildPillField(
                                touched: _confirmTouched,
                                valid: _isConfirmValid,
                                height: l.fieldH,
                                child: Row(children: [
                                  const SizedBox(width: 12),
                                  const Icon(Icons.lock_outline,
                                      color: Colors.black54, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _confirmCtl,
                                      onChanged: _onConfirmChanged,
                                      obscureText: _obscureConfirm,
                                      style:
                                      TextStyle(fontSize: l.fontSize(15)),
                                      decoration: InputDecoration(
                                        hintText: 'Confirm password',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: l.fieldH * 0.28),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.black54,
                                        size: 20),
                                    onPressed: () => setState(() =>
                                    _obscureConfirm = !_obscureConfirm),
                                  ),
                                ]),
                              ),

                              SizedBox(height: l.sectionGap),

                              // Terms checkbox
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment:
                                  WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _acceptedTerms,
                                        onChanged: (v) => setState(
                                                () => _acceptedTerms = v ?? false),
                                        activeColor: const Color(0xFF1866B2),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(4)),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _showTermsAndConditions,
                                      child: RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          text: 'I agree to the ',
                                          style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: l.fontSize(14)),
                                          children: const [
                                            TextSpan(
                                              text: 'Terms and Conditions',
                                              style: TextStyle(
                                                color: Color(0xFF1957A8),
                                                fontWeight: FontWeight.w600,
                                                decoration:
                                                TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: l.sectionGap),

                              // Create button
                              GestureDetector(
                                onTap: _canCreate ? _onCreatePressed : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: l.btnH,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _canCreate
                                        ? const Color(0xFF1866B2)
                                        : const Color(0xFF9BB0D1),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: _canCreate
                                        ? [
                                      const BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 4))
                                    ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: _isCreating
                                      ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                      : Text(
                                    'Create',
                                    style: TextStyle(
                                      color: _canCreate
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: l.fontSize(16),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: l.sectionGap),

                              // Login link
                              GestureDetector(
                                onTap: () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen())),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6.0),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      text: 'Existing user? ',
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: l.fontSize(14)),
                                      children: const [
                                        TextSpan(
                                          text: 'Login',
                                          style: TextStyle(
                                            color: Color(0xFF1957A8),
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                            TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: l.sectionGap),
                            ],
                          ),
                        ),
                      ),
                    ),
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