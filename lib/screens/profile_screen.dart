import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/avatar_service.dart';
import '../services/auth_service.dart';
import '../services/userprofile_service.dart';
import '../services/sound_manager.dart';
import '../widgets/avatar_picker_dialog.dart';
import 'login_screen.dart';

// ─────────────────────────────────────────────
//  LAYOUT HELPER  (same pattern as main menu)
// ─────────────────────────────────────────────
class _Layout {
  final bool isShort;

  _Layout(BuildContext context)
      : isShort = MediaQuery.of(context).size.height < 750;

  int get profileCardFlex => isShort ? 30 : 32;
  int get formCardFlex    => isShort ? 56 : 54;

  double avatarSize(double maxH) => isShort ? maxH * 0.13 : maxH * 0.14;
  double get hPad => isShort ? 14.0 : 16.0;
  double get vPad => isShort ? 5.0  : 8.0;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const _bg             = 'assets/images/backgrounds/profile_screen.png';
  static const backButtonAsset = 'assets/images/pngs/btn_back.png';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController  = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final AuthService _authService = AuthService();
  final UserProfileService _profileService = UserProfileService();
  final AvatarService _avatarService = AvatarService();

  String? _profileAvatarUrl;
  int?    _selectedAvatarId;
  bool    _loading = true;
  List<dynamic> _avatarPool = [];

  // Fallback avatars in case backend pool isn't loaded yet
  static const List<String> _fallbackAvatarAssets = [
    'assets/images/avatars/botttsNeutral-blue.png',
    'assets/images/avatars/botttsNeutral-yellow.png',
    'assets/images/avatars/botttsNeutral-cool.png',
    'assets/images/avatars/botttsNeutral-mad.png',
    'assets/images/avatars/botttsNeutral-brown.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Helper to safely load network or asset image providers for avatars
  ImageProvider? _getAvatarProvider(String? urlOrPath) {
    if (urlOrPath == null || urlOrPath.isEmpty) return null;
    final formattedUrl = ApiConfig.formatImageUrl(urlOrPath);

    // 🔍 PRINT THIS TO YOUR DEBUG CONSOLE:
    debugPrint('Attempting to load avatar URL: $formattedUrl');

    if (formattedUrl.startsWith('http://') || formattedUrl.startsWith('https://')) {
      return NetworkImage(formattedUrl);
    }
    return AssetImage(formattedUrl);
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = await _authService.getCurrentUser();
      final pool = await _avatarService.getAvatarPool();
      _avatarPool = pool;

      if (user == null) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      _nameController.text  = user['display_name'] ?? user['name'] ?? '';
      _emailController.text = user['email'] ?? '';
      _selectedAvatarId     = user['avatar_pool_id'];

      if (user['avatar_url'] != null) {
        _profileAvatarUrl = user['avatar_url'];
      } else if (_selectedAvatarId != null && _avatarPool.isNotEmpty) {
        final match = _avatarPool.firstWhere(
              (a) => a['id'] == _selectedAvatarId,
          orElse: () => null,
        );
        if (match != null) {
          _profileAvatarUrl = match['image_url'];
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveName() async {
    SoundManager.instance.playClick();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }
    try {
      final success = await _profileService.updateUserProfile(displayName: name);
      if (!mounted) return;
      if (success) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update name')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving name: $e')));
    }
  }

  Future<void> _saveAvatar({int? avatarId, String? imageUrl}) async {
    try {
      final success = await _profileService.updateUserProfile(avatarPoolId: avatarId);
      if (success) {
        setState(() {
          _selectedAvatarId = avatarId;
          _profileAvatarUrl = imageUrl;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update picture')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating picture: $e')));
    }
  }

  Future<void> _showAvatarSheet() async {
    SoundManager.instance.playClick();
    await AvatarPickerDialog.show(
      context,
      avatarPool: _avatarPool,
      fallbackAvatarAssets: _fallbackAvatarAssets,
      selectedAvatarId: _selectedAvatarId,
      profileAvatarUrl: _profileAvatarUrl,
      onAvatarSelected: (avatarId, imageUrl) {
        _saveAvatar(avatarId: avatarId, imageUrl: imageUrl);
      },
    );
  }

  Future<void> _showEditEmailDialog() async {
    SoundManager.instance.playClick();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Email'),
        content: const Text('To change your email, please contact support.'),
        actions: [
          TextButton(
              onPressed: () {
                SoundManager.instance.playClick();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              SoundManager.instance.playClick();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                  Text('Please contact support to change your email')));
            },
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    SoundManager.instance.playClick();
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No email found for this account')));
      return;
    }

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send a password reset link to:\n$email'),
        actions: [
          TextButton(
              onPressed: () {
                SoundManager.instance.playClick();
                Navigator.of(ctx).pop(false);
              },
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                SoundManager.instance.playClick();
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Send Link')),
        ],
      ),
    );

    if (shouldSend == true) {
      final result = await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;

      if (result['success'] == true) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    size: 64, color: Color(0xFF57BF0F)),
                const SizedBox(height: 16),
                const Text('Email Sent!',
                    style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(result['message'] ?? 'Check your email to reset password.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 14)),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    SoundManager.instance.playClick();
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF57BF0F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Got it',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message'] ?? 'Something went wrong')));
      }
    }
  }

  Future<void> _confirmLogout() async {
    SoundManager.instance.playClick();
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () {
                SoundManager.instance.playClick();
                Navigator.of(ctx).pop(false);
              },
              child: const Text('No')),
          ElevatedButton(
            onPressed: () {
              SoundManager.instance.playClick();
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (should == true) {
      try {
        await _authService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Logout error: $e')));
      }
    }
  }

  Widget _buildAvatar(double size) {
    Widget avatar;
    final imageProvider = _getAvatarProvider(_profileAvatarUrl);

    if (imageProvider == null) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white,
        child:
        Icon(Icons.person, size: size * 0.5, color: Colors.grey.shade400),
      );
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: imageProvider,
        backgroundColor: Colors.white,
      );
    }

    return GestureDetector(
      onTap: _showAvatarSheet,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: avatar,
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            padding: const EdgeInsets.all(5),
            child: const Icon(Icons.edit, size: 13, color: Colors.white),
          ),
        ],
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
          Positioned.fill(
            child: Image.asset(
              ProfileScreen._bg,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.orange.shade200),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
              builder: (context, constraints) {
                final maxH = constraints.maxHeight;
                final maxW = constraints.maxWidth;

                return Column(
                  children: [

                    // ── Back button row ──────────────────────
                    SizedBox(
                      height: maxH * 0.14,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            SoundManager.instance.playClick();
                            Navigator.of(context).pop();
                          },
                          child: Image.asset(
                            ProfileScreen.backButtonAsset,
                            width: maxW * 0.25,
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

                    // ── Profile card ─────────────────────────
                    Expanded(
                      flex: l.profileCardFlex,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: maxW * 0.06,
                          vertical: l.vPad,
                        ),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA726)
                                .withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                  Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8))
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              _buildAvatar(l.avatarSize(maxH)),
                              SizedBox(height: maxH * 0.012),
                              Text(
                                _nameController.text.isEmpty
                                    ? 'Your name'
                                    : _nameController.text,
                                style: TextStyle(
                                  fontSize: maxH * 0.026,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                        color: Colors.black38,
                                        blurRadius: 4)
                                  ],
                                ),
                              ),
                              SizedBox(height: maxH * 0.005),
                              Text(
                                _emailController.text.isEmpty
                                    ? 'your.email@example.com'
                                    : _emailController.text,
                                style: TextStyle(
                                  fontSize: maxH * 0.017,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                        color: Colors.black26,
                                        blurRadius: 4)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Form card ────────────────────────────
                    Expanded(
                      flex: l.formCardFlex,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          maxW * 0.06,
                          l.vPad,
                          maxW * 0.06,
                          maxH * 0.025,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: l.hPad,
                            vertical: maxH * 0.016,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                  Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                            children: [

                              // Full name field
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text('Full name',
                                      style: TextStyle(
                                          fontSize: maxH * 0.016,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black54)),
                                  SizedBox(height: maxH * 0.007),
                                  TextFormField(
                                    controller: _nameController,
                                    style: TextStyle(
                                        fontSize: maxH * 0.018),
                                    decoration: InputDecoration(
                                      hintText: 'Your full name',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                      EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: maxH * 0.011),
                                    ),
                                  ),
                                ],
                              ),

                              // Email field
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text('Email',
                                      style: TextStyle(
                                          fontSize: maxH * 0.016,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black54)),
                                  SizedBox(height: maxH * 0.007),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _emailController,
                                          readOnly: true,
                                          style: TextStyle(
                                              fontSize: maxH * 0.018),
                                          decoration: InputDecoration(
                                            hintText:
                                            'your.email@example.com',
                                            filled: true,
                                            fillColor:
                                            Colors.grey.shade50,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                              borderSide:
                                              BorderSide.none,
                                            ),
                                            contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical:
                                                maxH * 0.011),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: maxH * 0.058,
                                        child: ElevatedButton(
                                          onPressed: _showEditEmailDialog,
                                          style:
                                          ElevatedButton.styleFrom(
                                            backgroundColor:
                                            const Color(0xFF2196F3),
                                            padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14),
                                            shape:
                                            RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius
                                                    .circular(
                                                    12)),
                                          ),
                                          child: const Icon(Icons.edit,
                                              size: 16,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Reset password + Save profile
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: maxH * 0.058,
                                      child: OutlinedButton(
                                        onPressed: _showResetPasswordDialog,
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Color(0xFF2196F3)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(
                                                  12)),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Reset password',
                                            maxLines: 1,
                                            style: TextStyle(
                                                color: const Color(0xFF2196F3),
                                                fontWeight: FontWeight.w600,
                                                fontSize: maxH * 0.016),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: maxH * 0.058,
                                      child: ElevatedButton(
                                        onPressed: _saveName,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          const Color(0xFF57BF0F),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(
                                                  12)),
                                        ),
                                        child: Text('Save profile',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight:
                                                FontWeight.w600,
                                                fontSize:
                                                maxH * 0.016)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Logout
                              SizedBox(
                                width: double.infinity,
                                height: maxH * 0.058,
                                child: OutlinedButton(
                                  onPressed: _confirmLogout,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                    const Color(0xFFE53935),
                                    side: const BorderSide(
                                        color: Color(0xFFE53935),
                                        width: 2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                  ),
                                  child: Text('Logout',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: maxH * 0.017)),
                                ),
                              ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}