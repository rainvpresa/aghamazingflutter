import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/sound_manager.dart';
import '../widgets/terms_dialog.dart';

// ─────────────────────────────────────────────
//  LAYOUT HELPER
// ─────────────────────────────────────────────
class _Layout {
  final bool isShort;

  _Layout(BuildContext context)
      : isShort = MediaQuery.of(context).size.height < 750;

  int get topFlex     => isShort ? 30 : 35;
  int get contentFlex => isShort ? 95 : 88;

  double get fieldH       => isShort ? 44.0 : 50.0;
  double get fieldSpacing => isShort ? 12.0 : 14.0;
  double get btnH         => isShort ? 44.0 : 50.0;
  double get sectionGap   => isShort ? 12.0 : 14.0;
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

  // Dropdown Selections
  String? _selectedRegion;
  String? _selectedAgeGroup;
  String? _selectedGender;

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

  final RegExp _emailRegex     = RegExp(r"^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$");
  final RegExp _numberRegex    = RegExp(r'\d');
  final RegExp _uppercaseRegex = RegExp(r'[A-Z]');

  // Backend Constant Lists (Matches AppUser Model Exactly)
  static const List<String> _regions = [
    'NCR - National Capital Region',
    'CAR - Cordillera Administrative Region',
    'Region I - Ilocos Region',
    'Region II - Cagayan Valley',
    'Region III - Central Luzon',
    'Region IV-A - CALABARZON',
    'MIMAROPA Region',
    'Region V - Bicol Region',
    'Region VI - Western Visayas',
    'Negros Island Region',
    'Region VII - Central Visayas',
    'Region VIII - Eastern Visayas',
    'Region IX - Zamboanga Peninsula',
    'Region X - Northern Mindanao',
    'Region XI - Davao Region',
    'Region XII - SOCCSKSARGEN',
    'Region XIII - Caraga',
    'BARMM - Bangsamoro Autonomous Region in Muslim Mindanao',
  ];

  static const List<String> _ageGroups = [
    'Under 18',
    '18 to 24',
    '25 to 34',
    '35 to 44',
    '45 to 54',
    '55+',
  ];

  static const List<String> _genders = ['M', 'F', 'Non-binary'];

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

  bool _validateNick(String v)  => v.trim().isNotEmpty && v.trim().length <= 50;
  bool _validateEmail(String v) => _emailRegex.hasMatch(v.trim());

  // Enforces Laravel Password Rules: min 8, uppercase, number
  bool _validatePass(String v)  =>
      v.length >= 8 && _numberRegex.hasMatch(v) && _uppercaseRegex.hasMatch(v);

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
      _isConfirmValid = _confirmCtl.text.isNotEmpty && _confirmCtl.text == v;
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
          _selectedRegion != null &&
          _selectedAgeGroup != null &&
          _selectedGender != null &&
          _acceptedTerms &&
          !_isCreating;

  // ─────────────────────────────────────────────
  //  CREATE ACCOUNT
  // ─────────────────────────────────────────────
  Future<void> _onCreatePressed() async {
    SoundManager.instance.playClick();
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

    final email       = _emailCtl.text.trim();
    final password    = _passCtl.text;
    final displayName = _nickCtl.text.trim();

    try {
      final result = await AuthService().registerWithEmailVerification(
        displayName: displayName,
        email: email,
        password: password,
        passwordConfirmation: password,
        region: _selectedRegion!,
        ageGroup: _selectedAgeGroup!,
        gender: _selectedGender!,
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
                  SoundManager.instance.playClick();
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
  //  PILL CONTAINER BUILDER
  // ─────────────────────────────────────────────
  Widget _buildPillField({
    required Widget child,
    bool touched = false,
    bool valid = false,
    required double height,
  }) {
    final bc = _borderColor(touched, valid);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.98),
        borderRadius: BorderRadius.circular(28),
        border: bc == Colors.transparent ? null : Border.all(color: bc, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
    );
  }

  void _showTermsAndConditions() {
    SoundManager.instance.playClick();
    TermsDialog.show(context);
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
          Positioned.fill(
            child: Image.asset(
              _bg,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.blue.shade200),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Expanded(flex: l.topFlex, child: const SizedBox()),
                    Expanded(
                      flex: l.contentFlex,
                      child: SingleChildScrollView(
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
                                    hintText: 'Nickname / Display Name',
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
                                      style: TextStyle(fontSize: l.fontSize(15)),
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
                                      style: TextStyle(fontSize: l.fontSize(15)),
                                      decoration: InputDecoration(
                                        hintText: 'Password (min 8, 1 uppercase, 1 num)',
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
                                    onPressed: () {
                                      SoundManager.instance.playClick();
                                      setState(() => _obscurePass = !_obscurePass);
                                    },
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
                                      style: TextStyle(fontSize: l.fontSize(15)),
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
                                    onPressed: () {
                                      SoundManager.instance.playClick();
                                      setState(() => _obscureConfirm = !_obscureConfirm);
                                    },
                                  ),
                                ]),
                              ),

                              SizedBox(height: l.fieldSpacing),

                              // Region Dropdown
                              _buildPillField(
                                height: l.fieldH,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _selectedRegion,
                                      hint: Text('Select Region', style: TextStyle(fontSize: l.fontSize(15), color: Colors.black54)),
                                      items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: l.fontSize(14))))).toList(),
                                      onChanged: (val) => setState(() => _selectedRegion = val),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: l.fieldSpacing),

                              // Row for Age Group and Gender
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildPillField(
                                      height: l.fieldH,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _selectedAgeGroup,
                                            hint: Text('Age Group', style: TextStyle(fontSize: l.fontSize(15), color: Colors.black54)),
                                            items: _ageGroups.map((a) => DropdownMenuItem(value: a, child: Text(a, style: TextStyle(fontSize: l.fontSize(14))))).toList(),
                                            onChanged: (val) => setState(() => _selectedAgeGroup = val),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildPillField(
                                      height: l.fieldH,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _selectedGender,
                                            hint: Text('Gender', style: TextStyle(fontSize: l.fontSize(15), color: Colors.black54)),
                                            items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(fontSize: l.fontSize(14))))).toList(),
                                            onChanged: (val) => setState(() => _selectedGender = val),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: l.sectionGap),

                              // Terms checkbox
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _acceptedTerms,
                                        onChanged: (v) {
                                          SoundManager.instance.playClick();
                                          setState(() => _acceptedTerms = v ?? false);
                                        },
                                        activeColor: const Color(0xFF1866B2),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _showTermsAndConditions, // Terms dialog function reference
                                      child: RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          text: 'I agree to the ',
                                          style: TextStyle(color: Colors.black87, fontSize: l.fontSize(14)),
                                          children: const [
                                            TextSpan(
                                              text: 'Terms and Conditions',
                                              style: TextStyle(color: Color(0xFF1957A8), fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
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
                                    color: _canCreate ? const Color(0xFF1866B2) : const Color(0xFF9BB0D1),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: _canCreate ? [const BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))] : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: _isCreating
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Text('Create', style: TextStyle(color: _canCreate ? Colors.white : Colors.white70, fontWeight: FontWeight.w600, fontSize: l.fontSize(16))),
                                ),
                              ),

                              SizedBox(height: l.sectionGap),

                              // Login link
                              GestureDetector(
                                onTap: () {
                                  SoundManager.instance.playClick();
                                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      text: 'Existing user? ',
                                      style: TextStyle(color: Colors.black87, fontSize: l.fontSize(14)),
                                      children: const [
                                        TextSpan(
                                          text: 'Login',
                                          style: TextStyle(color: Color(0xFF1957A8), fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
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