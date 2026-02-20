import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/userprofile_service.dart';
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

  String? _profileAvatarPath;
  bool    _loading = true;

  final FirebaseAuth       _auth           = FirebaseAuth.instance;
  final FirebaseFirestore  _firestore      = FirebaseFirestore.instance;
  final UserProfileService _profileService = UserProfileService();

  static const List<String> _avatarPool = [
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

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      final profile = await _profileService.getUserProfile();
      if (profile != null) {
        _nameController.text  = profile['displayName'] ?? '';
        _emailController.text = profile['email'] ?? user.email ?? '';
        _profileAvatarPath    = profile['avatarPath'];
      } else {
        _nameController.text  = user.displayName ?? '';
        _emailController.text = user.email ?? '';
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }
    try {
      await _profileService.updateUserProfile(displayName: name);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving name: $e')));
    }
  }

  Future<void> _saveAvatar(String assetPath) async {
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'avatarPath': assetPath});
      setState(() => _profileAvatarPath = assetPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating picture: $e')));
    }
  }

  Future<void> _showAvatarSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Choose profile picture',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: GridView.builder(
                  itemCount: _avatarPool.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (_, i) {
                    final a        = _avatarPool[i];
                    final selected = a == _profileAvatarPath;
                    return GestureDetector(
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _saveAvatar(a);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            backgroundImage: AssetImage(a),
                            radius: 36,
                            backgroundColor: Colors.grey.shade200,
                          ),
                          if (selected)
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.28),
                                border:
                                Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.check, color: Colors.white),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _saveAvatar('');
                },
                child: const Text('Remove / Reset to default'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditEmailDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Email'),
        content: const Text('To change your email, please contact support.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
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
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No email found for this account')));
      return;
    }
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send a password reset link to:\n${user.email}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Send Link')),
        ],
      ),
    );
    if (shouldSend == true) {
      final result =
      await AuthService().sendPasswordResetEmail(email: user.email!);
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
                Text(result['message'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 14)),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
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
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (should == true) {
      try {
        await AuthService().logout();
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
    if (_profileAvatarPath == null || _profileAvatarPath!.isEmpty) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white,
        child:
        Icon(Icons.person, size: size * 0.5, color: Colors.grey.shade400),
      );
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: AssetImage(_profileAvatarPath!),
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
                    color: Colors.black.withOpacity(0.2),
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
          // ── Background (same as main menu) ──────────────────────
          Positioned.fill(
            child: Image.asset(
              ProfileScreen._bg,
              fit: BoxFit.fill, // fills entire screen on all resolutions including 1520x720
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.orange.shade200),
            ),
          ),

          // ── Content ─────────────────────────────────────────────
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
                    // Height is large enough to clear the "Profile"
                    // title bar that's baked into the background image
                    SizedBox(
                      height: maxH * 0.14,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
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
                                .withOpacity(0.88),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                  Colors.black.withOpacity(0.15),
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
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                  Colors.black.withOpacity(0.10),
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
                                          onPressed:
                                          _showEditEmailDialog,
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
                                        onPressed:
                                        _showResetPasswordDialog,
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