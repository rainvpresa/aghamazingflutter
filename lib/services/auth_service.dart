import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async'; // For StreamSubscription

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Store OTP temporarily (in production, store in Firestore with expiry)
  String? _generatedOTP;
  String? _pendingEmail;
  String? _pendingPassword;
  String? _pendingDisplayName;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============================================================
  // REGISTRATION WITH EMAIL OTP
  // ============================================================

  /// Register with email verification (no OTP)
  Future<Map<String, dynamic>> registerWithEmailVerification({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      print('🚀 Starting registration for: $email');

      // Check if email already exists
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        print('⚠️ Email already exists');
        return {
          'success': false,
          'message': 'Email already registered. Please login instead.',
          'userExists': true,
        };
      }

      print('✅ Email is available, creating Firebase Auth account...');

      // Create account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user == null) {
        print('❌ User creation returned null');
        return {
          'success': false,
          'message': 'Account creation failed'
        };
      }

      print('✅ Firebase Auth account created: ${result.user!.uid}');

// Skip display name update due to Firebase plugin bug
      print('⚠️ Skipping display name update (will set in Firestore instead)');

      // Create user profile in Firestore FIRST (while user is still authenticated)
      try {
        print('📝 About to create Firestore profile...');
        await _createUserProfile(
          userId: result.user!.uid,
          email: email,
          displayName: displayName,
        );
        print('✅ Firestore profile creation completed');
      } catch (firestoreError) {
        print('❌ Firestore creation failed: $firestoreError');
        print('❌ Error details: ${firestoreError.toString()}');

        // Delete the auth user if Firestore creation fails
        try {
          await result.user!.delete();
          print('🗑️ Auth user deleted due to Firestore failure');
        } catch (deleteError) {
          print('⚠️ Could not delete auth user: $deleteError');
        }

        return {
          'success': false,
          'message': 'Failed to create user profile: ${firestoreError.toString()}'
        };
      }

      // Send verification email
      print('📧 Sending verification email...');
      try {
        await result.user!.sendEmailVerification();
        print('✅ Verification email sent successfully');
      } catch (emailError) {
        print('⚠️ Error sending verification email: $emailError');
        // Don't fail registration if email fails - user can resend later
      }

      // NOW sign out the user so they have to verify first
      print('🚪 Signing out user...');
      await _auth.signOut();
      print('✅ User signed out');

      print('🎉 Registration completed successfully!');
      return {
        'success': true,
        'message': 'Account created! Please check $email for verification link.',
        'user': result.user
      };
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        return {
          'success': false,
          'message': 'This email is already registered. Please login instead.',
          'userExists': true,
        };
      } else if (e.code == 'weak-password') {
        return {
          'success': false,
          'message': 'Password is too weak. Use at least 6 characters.'
        };
      } else {
        return {
          'success': false,
          'message': 'Registration failed: ${e.message}'
        };
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Check if email is verified
        if (!result.user!.emailVerified) {
          await _auth.signOut();
          return {
            'success': false,
            'message': 'Please verify your email before logging in. Check your inbox.',
            'needsVerification': true,
          };
        }

        // Update last login
        await _firestore.collection('users').doc(result.user!.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });

        // Save session
        await _saveSession(result.user!.uid);

        return {
          'success': true,
          'message': 'Login successful',
          'user': result.user
        };
      }

      return {
        'success': false,
        'message': 'Login failed'
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return {
          'success': false,
          'message': 'No account found with this email'
        };
      } else if (e.code == 'wrong-password') {
        return {
          'success': false,
          'message': 'Incorrect password'
        };
      } else if (e.code == 'invalid-email') {
        return {
          'success': false,
          'message': 'Invalid email format'
        };
      } else if (e.code == 'invalid-credential') {
        return {
          'success': false,
          'message': 'Invalid email or password'
        };
      } else {
        return {
          'success': false,
          'message': 'Login failed: ${e.message}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  /// Mask email for privacy (e.g., r****a@gmail.com)
  String _maskEmail(String email) {
    if (!email.contains('@')) return email;

    final parts = email.split('@');
    final localPart = parts[0];
    final domain = parts[1];

    if (localPart.length <= 2) {
      // For very short emails, show first char only
      return '${localPart[0]}***@$domain';
    } else {
      // Show first and last char, mask the middle
      final firstChar = localPart[0];
      final lastChar = localPart[localPart.length - 1];
      final maskLength = localPart.length - 2;
      final masked = '*' * (maskLength > 4 ? 4 : maskLength); // Max 4 asterisks

      return '$firstChar$masked$lastChar@$domain';
    }
  }

// ============================================================
// FORGOT PASSWORD (PASSWORD RESET VIA EMAIL)
// ============================================================
  /// Send password reset email
  Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      print('🔍 Attempting to send password reset to: $email');

      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Password reset email request completed');

      final maskedEmail = _maskEmail(email);

      return {
        'success': true,
        'message': 'If an account exists, a password reset link has been sent to $maskedEmail. Please check your inbox and spam folder.',
      };
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');

      if (e.code == 'invalid-email') {
        return {
          'success': false,
          'message': 'Invalid email format'
        };
      } else if (e.code == 'user-not-found') {
        final maskedEmail = _maskEmail(email);
        return {
          'success': true,
          'message': 'If an account exists, a password reset link has been sent to $maskedEmail.',
        };
      } else if (e.code == 'too-many-requests') {
        return {
          'success': false,
          'message': 'Too many attempts. Please try again later.'
        };
      } else {
        return {
          'success': false,
          'message': 'Error: ${e.message}'
        };
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }
  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      // Update logout time in Firestore
      if (currentUser != null) {
        await _firestore
            .collection('sessions')
            .where('userId', isEqualTo: currentUser!.uid)
            .where('logoutTime', isEqualTo: null)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({
              'logoutTime': FieldValue.serverTimestamp(),
            });
          }
        });
      }

      // Clear local session
      await _clearSession();

      // Sign out
      await _auth.signOut();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Generate random 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Clear pending registration/reset data
  void _clearPendingData() {
    _generatedOTP = null;
    _pendingEmail = null;
    _pendingPassword = null;
    _pendingDisplayName = null;
  }

  /// Create user profile in Firestore
  Future<void> _createUserProfile({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    try {
      print('🔍 Attempting to create user profile for: $userId');
      print('📧 Email: $email');
      print('👤 Display Name: $displayName');

      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'displayName': displayName,
        'coins': 0, // Starting coins
        'energy': 100, // Starting energy
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      print('✅ User profile created successfully in Firestore!');
    } catch (e) {
      print('❌ Error creating user profile: $e');
      print('❌ Error type: ${e.runtimeType}');
      rethrow; // Re-throw so registration can handle it
    }
  }

  /// Save session locally
  Future<void> _saveSession(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setBool('isLoggedIn', true);

    // Also save to Firestore
    await _firestore.collection('sessions').add({
      'userId': userId,
      'loginTime': FieldValue.serverTimestamp(),
      'logoutTime': null,
    });
  }

  /// Clear local session
  Future<void> _clearSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.setBool('isLoggedIn', false);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// Get saved user ID
  Future<String?> getSavedUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }
}