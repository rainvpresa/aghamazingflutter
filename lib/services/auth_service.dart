import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============================================================
  // REGISTRATION WITH EMAIL VERIFICATION
  // ============================================================

  /// Register with email verification
  Future<Map<String, dynamic>> registerWithEmailVerification({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      debugPrint('🚀 Starting registration for: $email');

      // Create account - Firebase will handle if email already exists
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user == null) {
        debugPrint('❌ User creation returned null');
        return {
          'success': false,
          'message': 'Account creation failed'
        };
      }

      debugPrint('✅ Firebase Auth account created: ${result.user!.uid}');

      // Skip display name update due to Firebase plugin bug
      debugPrint('⚠️ Skipping display name update (will set in Firestore instead)');

      // Create user profile in Firestore FIRST (while user is still authenticated)
      try {
        debugPrint('📝 About to create Firestore profile...');
        await _createUserProfile(
          userId: result.user!.uid,
          email: email,
          displayName: displayName,
        );
        debugPrint('✅ Firestore profile creation completed');
      } catch (firestoreError) {
        debugPrint('❌ Firestore creation failed: $firestoreError');

        // Delete the auth user if Firestore creation fails
        try {
          await result.user!.delete();
          debugPrint('🗑️ Auth user deleted due to Firestore failure');
        } catch (deleteError) {
          debugPrint('⚠️ Could not delete auth user: $deleteError');
        }

        return {
          'success': false,
          'message': 'Failed to create user profile: ${firestoreError.toString()}'
        };
      }

      // Send verification email
      debugPrint('📧 Sending verification email...');
      try {
        await result.user!.sendEmailVerification();
        debugPrint('✅ Verification email sent successfully');
      } catch (emailError) {
        debugPrint('⚠️ Error sending verification email: $emailError');
      }

      // Sign out the user so they have to verify first
      debugPrint('🚪 Signing out user...');
      await _auth.signOut();
      debugPrint('✅ User signed out');

      debugPrint('🎉 Registration completed successfully!');
      return {
        'success': true,
        'message': 'Account created! Please check $email for verification link.',
        'user': result.user
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
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
      debugPrint('❌ Unexpected error: $e');
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
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return {
          'success': false,
          'message': 'Invalid email or password'
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
      return '${localPart[0]}***@$domain';
    } else {
      final firstChar = localPart[0];
      final lastChar = localPart[localPart.length - 1];
      final maskLength = localPart.length - 2;
      final masked = '*' * (maskLength > 4 ? 4 : maskLength);

      return '$firstChar$masked$lastChar@$domain';
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================
  Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      debugPrint('🔍 Attempting to send password reset to: $email');

      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ Password reset email request completed');

      final maskedEmail = _maskEmail(email);

      return {
        'success': true,
        'message': 'If an account exists, a password reset link has been sent to $maskedEmail. Please check your inbox and spam folder.',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');

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
      debugPrint('❌ Unexpected error: $e');
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
      if (currentUser != null) {
        final userId = currentUser!.uid;
        // Clear local session first
        await _clearSession();
        // Sign out
        await _auth.signOut();

        // Update logout time in Firestore asynchronously
        _firestore
            .collection('sessions')
            .where('userId', isEqualTo: userId)
            .where('logoutTime', isEqualTo: null)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({
              'logoutTime': FieldValue.serverTimestamp(),
            });
          }
        }).catchError((e) {
          debugPrint('Error updating session logout: $e');
        });
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Create user profile in Firestore
  Future<void> _createUserProfile({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    try {
      debugPrint('🔍 Attempting to create user profile for: $userId');

      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'displayName': displayName,
        'coins': 0,
        'energy': 100,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User profile created successfully in Firestore!');
    } catch (e) {
      debugPrint('❌ Error creating user profile: $e');
      rethrow;
    }
  }

  /// Save session locally
  Future<void> _saveSession(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setBool('isLoggedIn', true);

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
