import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // USER PROFILE OPERATIONS
  // ============================================================

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile({String? userId}) async {
    try {
      String uid = userId ?? currentUserId!;
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Stream user profile (real-time updates)
  Stream<DocumentSnapshot> streamUserProfile({String? userId}) {
    String uid = userId ?? currentUserId!;
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    String? displayName,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      String uid = currentUserId!;
      Map<String, dynamic> updates = {};

      if (displayName != null) updates['displayName'] = displayName;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);

        // Also update Firebase Auth display name if provided
        if (displayName != null) {
          await _auth.currentUser?.updateDisplayName(displayName);
        }
      }

      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  /// Delete user account
  Future<bool> deleteUserAccount() async {
    try {
      String uid = currentUserId!;

      // Delete user data from Firestore
      await _firestore.collection('users').doc(uid).delete();

      // Delete all user sessions
      QuerySnapshot sessions = await _firestore
          .collection('sessions')
          .where('userId', isEqualTo: uid)
          .get();

      for (var doc in sessions.docs) {
        await doc.reference.delete();
      }

      // Delete Firebase Auth account
      await _auth.currentUser?.delete();

      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // ============================================================
  // COINS MANAGEMENT
  // ============================================================

  /// Get current coins
  Future<int> getCoins({String? userId}) async {
    try {
      String uid = userId ?? currentUserId!;
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['coins'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting coins: $e');
      return 0;
    }
  }

  /// Add coins (after winning a game)
  Future<bool> addCoins({required int amount, String? reason}) async {
    try {
      String uid = currentUserId!;

      // Use transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(uid);
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception('User does not exist');
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int currentCoins = data['coins'] ?? 0;
        int newCoins = currentCoins + amount;

        // Update coins
        transaction.update(userRef, {'coins': newCoins});

        // Log transaction
        transaction.set(_firestore.collection('coinTransactions').doc(), {
          'userId': uid,
          'amount': amount,
          'type': 'earned',
          'reason': reason ?? 'Game reward',
          'timestamp': FieldValue.serverTimestamp(),
          'balanceBefore': currentCoins,
          'balanceAfter': newCoins,
        });
      });

      return true;
    } catch (e) {
      print('Error adding coins: $e');
      return false;
    }
  }

  /// Spend coins
  Future<bool> spendCoins({required int amount, String? reason}) async {
    try {
      String uid = currentUserId!;

      // Use transaction to ensure data consistency
      bool success = false;

      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(uid);
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception('User does not exist');
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int currentCoins = data['coins'] ?? 0;

        // Check if user has enough coins
        if (currentCoins < amount) {
          success = false;
          return;
        }

        int newCoins = currentCoins - amount;

        // Update coins
        transaction.update(userRef, {'coins': newCoins});

        // Log transaction
        transaction.set(_firestore.collection('coinTransactions').doc(), {
          'userId': uid,
          'amount': amount,
          'type': 'spent',
          'reason': reason ?? 'Purchase',
          'timestamp': FieldValue.serverTimestamp(),
          'balanceBefore': currentCoins,
          'balanceAfter': newCoins,
        });

        success = true;
      });

      return success;
    } catch (e) {
      print('Error spending coins: $e');
      return false;
    }
  }

  /// Get coin transaction history
  Future<List<Map<String, dynamic>>> getCoinHistory({int limit = 20}) async {
    try {
      String uid = currentUserId!;
      QuerySnapshot snapshot = await _firestore
          .collection('coinTransactions')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting coin history: $e');
      return [];
    }
  }

  // ============================================================
  // ENERGY MANAGEMENT
  // ============================================================

  /// Get current energy
  Future<int> getEnergy({String? userId}) async {
    try {
      String uid = userId ?? currentUserId!;
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['energy'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting energy: $e');
      return 0;
    }
  }

  /// Use energy (when playing a game)
  Future<bool> useEnergy({required int amount}) async {
    try {
      String uid = currentUserId!;

      bool success = false;

      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(uid);
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception('User does not exist');
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int currentEnergy = data['energy'] ?? 0;

        // Check if user has enough energy
        if (currentEnergy < amount) {
          success = false;
          return;
        }

        int newEnergy = currentEnergy - amount;

        // Update energy
        transaction.update(userRef, {
          'energy': newEnergy,
          'lastEnergyUpdate': FieldValue.serverTimestamp(),
        });

        success = true;
      });

      return success;
    } catch (e) {
      print('Error using energy: $e');
      return false;
    }
  }

  /// Restore energy (can be called periodically or after certain actions)
  Future<bool> restoreEnergy({required int amount}) async {
    try {
      String uid = currentUserId!;

      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(uid);
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception('User does not exist');
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int currentEnergy = data['energy'] ?? 0;
        int maxEnergy = data['maxEnergy'] ?? 100; // Default max energy

        int newEnergy = (currentEnergy + amount).clamp(0, maxEnergy);

        transaction.update(userRef, {
          'energy': newEnergy,
          'lastEnergyUpdate': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      print('Error restoring energy: $e');
      return false;
    }
  }

  /// Set max energy
  Future<bool> setMaxEnergy({required int maxEnergy}) async {
    try {
      String uid = currentUserId!;
      await _firestore.collection('users').doc(uid).update({
        'maxEnergy': maxEnergy,
      });
      return true;
    } catch (e) {
      print('Error setting max energy: $e');
      return false;
    }
  }

  // ============================================================
  // GAME STATS
  // ============================================================

  /// Update game statistics
  Future<bool> updateGameStats({
    int? gamesPlayed,
    int? gamesWon,
    int? totalScore,
  }) async {
    try {
      String uid = currentUserId!;

      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(uid);
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception('User does not exist');
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        Map<String, dynamic> updates = {};

        if (gamesPlayed != null) {
          int current = data['gamesPlayed'] ?? 0;
          updates['gamesPlayed'] = current + gamesPlayed;
        }

        if (gamesWon != null) {
          int current = data['gamesWon'] ?? 0;
          updates['gamesWon'] = current + gamesWon;
        }

        if (totalScore != null) {
          int current = data['totalScore'] ?? 0;
          updates['totalScore'] = current + totalScore;
        }

        if (updates.isNotEmpty) {
          transaction.update(userRef, updates);
        }
      });

      return true;
    } catch (e) {
      print('Error updating game stats: $e');
      return false;
    }
  }

  /// Get game statistics
  Future<Map<String, dynamic>> getGameStats({String? userId}) async {
    try {
      String uid = userId ?? currentUserId!;
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'gamesPlayed': data['gamesPlayed'] ?? 0,
          'gamesWon': data['gamesWon'] ?? 0,
          'totalScore': data['totalScore'] ?? 0,
          'winRate': _calculateWinRate(
            data['gamesPlayed'] ?? 0,
            data['gamesWon'] ?? 0,
          ),
        };
      }
      return {
        'gamesPlayed': 0,
        'gamesWon': 0,
        'totalScore': 0,
        'winRate': 0.0,
      };
    } catch (e) {
      print('Error getting game stats: $e');
      return {
        'gamesPlayed': 0,
        'gamesWon': 0,
        'totalScore': 0,
        'winRate': 0.0,
      };
    }
  }

  double _calculateWinRate(int gamesPlayed, int gamesWon) {
    if (gamesPlayed == 0) return 0.0;
    return (gamesWon / gamesPlayed) * 100;
  }
}

// ============================================================
// SESSION SERVICE (for UI state management)
// ============================================================

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._();
  SessionService._();

  final UserProfileService _profileService = UserProfileService();

  // Your existing properties
  int _bubblePower = 0;
  int _energy = 0;

  int get bubblePower => _bubblePower;
  int get energy => _energy;

  StreamSubscription<DocumentSnapshot>? _subscription;

  // Initialize - called from MainMenuScreen
  void init() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Listen to real-time updates from Firestore
    _subscription = _profileService.streamUserProfile().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _bubblePower = data['coins'] ?? 0;  // Use coins as bubble power
        _energy = data['energy'] ?? 0;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}