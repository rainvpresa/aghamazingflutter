import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/userprofile_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const _bg = 'assets/images/backgrounds/profile_screen.png';
  static const backButtonAsset = 'assets/images/pngs/btn_back.png';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _profileAvatarPath;
  bool _loading = true;

  // Add Firebase references
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
    _loadProfileFromFirebase();
  }

  // NEW: Load from Firebase instead of SharedPreferences
  Future<void> _loadProfileFromFirebase() async {
    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        // User not logged in, redirect to login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // Get user profile from Firestore
      final profile = await _profileService.getUserProfile();

      if (profile != null) {
        _nameController.text = profile['displayName'] ?? '';
        _emailController.text = profile['email'] ?? user.email ?? '';
        _profileAvatarPath = profile['avatarPath']; // Stored avatar selection
      } else {
        // Fallback to Firebase Auth data if Firestore profile doesn't exist
        _nameController.text = user.displayName ?? '';
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

  // UPDATE: Save name to Firebase
  Future<void> _saveNameToFirebase() async {
    try {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name cannot be empty')),
        );
        return;
      }

      // Update in Firestore
      await _profileService.updateUserProfile(displayName: name);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving name: $e')),
      );
    }
  }

  // UPDATE: Save avatar to Firebase
  Future<void> _saveProfileAvatarPath(String assetPath) async {
    try {
      // Save to Firestore
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating picture: $e')),
      );
    }
  }

  Future<void> _showAvatarSelectionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose profile picture',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: GridView.builder(
                    itemCount: _avatarPool.length,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final asset = _avatarPool[index];
                      final selected = asset == _profileAvatarPath;
                      return GestureDetector(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _saveProfileAvatarPath(asset);
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              backgroundImage: AssetImage(asset),
                              radius: 36,
                              backgroundColor: Colors.grey.shade200,
                            ),
                            if (selected)
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.28),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.check, color: Colors.white),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _saveProfileAvatarPath('');
                  },
                  child: const Text('Remove / Reset to default'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // UPDATE: Email change via Firebase
  Future<void> _showEditEmailDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Change Email'),
          content: const Text(
            'To change your email, we\'ll send a verification link to your new email address. '
                'Please check your inbox and click the link to verify.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();

                // Firebase will send email verification automatically
                // when user calls verifyBeforeUpdateEmail()
                final user = _auth.currentUser;
                if (user != null) {
                  try {
                    // This requires re-authentication for security
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please contact support to change your email'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Contact Support'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email found for this account')),
      );
      return;
    }

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Text(
            'We will send a password reset link to:\n${user.email}\n\n'
                'Click the link in your email to reset your password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );

    if (shouldSend == true) {
      final result = await AuthService().sendPasswordResetEmail(
        email: user.email!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Success modal
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: Color(0xFF57BF0F),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Email Sent!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result['message'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Something went wrong')),
        );
      }
    }
  }

  // UPDATE: Logout with Firebase
  Future<void> _confirmLogout() async {
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (should == true) {
      try {
        // Use AuthService to logout
        await AuthService().logout();

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout error: $e')),
        );
      }
    }
  }

  Widget _buildProfileAvatar(double size) {
    final placeholder = CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white,
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: Colors.grey.shade400,
      ),
    );

    Widget avatar;
    if (_profileAvatarPath == null || _profileAvatarPath!.isEmpty) {
      avatar = placeholder;
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: AssetImage(_profileAvatarPath!),
        backgroundColor: Colors.white,
      );
    }

    return GestureDetector(
      onTap: _showAvatarSelectionSheet,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
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
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.edit,
              size: 18,
              color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 50,
        leadingWidth: 105,
        leading: Padding(
          padding: const EdgeInsets.all(0.0),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 68, minHeight: 70),
            icon: Image.asset(
              ProfileScreen.backButtonAsset,
              width: 167,
              height: 90,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              ProfileScreen._bg,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.blue.shade200,
              ),
            ),
          ),

          // Content with flexbox
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 20.0,
                        ),
                        child: Column(
                          children: [
                            // Top spacer
                            const Spacer(flex: 2),

                            // Profile section with less transparency
                            Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                maxWidth: screenW > 600 ? 500 : double.infinity,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFA726).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Center(child: _buildProfileAvatar(120)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _nameController.text.isEmpty
                                        ? 'Your name'
                                        : _nameController.text,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black38,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _emailController.text.isEmpty
                                        ? 'your.email@example.com'
                                        : _emailController.text,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Form fields container
                            Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                maxWidth: screenW > 600 ? 500 : double.infinity,
                              ),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Full name',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      hintText: 'Your full name',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Email',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _emailController,
                                          readOnly: true,
                                          decoration: InputDecoration(
                                            hintText: 'your.email@example.com',
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: _showEditEmailDialog,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2196F3),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _showResetPasswordDialog,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            side: const BorderSide(
                                              color: Color(0xFF2196F3),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Reset password',
                                            style: TextStyle(
                                              color: Color(0xFF2196F3),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _saveNameToFirebase,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF57BF0F),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Save profile',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFE53935),
                                        side: const BorderSide(
                                          color: Color(0xFFE53935),
                                          width: 2,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _confirmLogout,
                                      child: const Text(
                                        'Logout',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Bottom spacer
                            const Spacer(flex: 2),
                          ],
                        ),
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
}
