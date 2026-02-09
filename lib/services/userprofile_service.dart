import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'energy_manager.dart';
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
      debugPrint('Error getting user profile: $e');
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
      debugPrint('Error updating profile: $e');
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
      debugPrint('Error deleting account: $e');
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
      debugPrint('Error getting coins: $e');
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
      debugPrint('Error adding coins: $e');
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
      debugPrint('Error spending coins: $e');
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
      debugPrint('Error getting coin history: $e');
      return [];
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
      debugPrint('Error updating game stats: $e');
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
      debugPrint('Error getting game stats: $e');
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

  // ============================================================
  // LEADERBOARD
  // ============================================================

  /// Get leaderboard (top players by total score/gems)
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'userId': doc.id,
          'displayName': data['displayName'] ?? 'Anonymous',
          'profileImageUrl': data['profileImageUrl'],
          'totalScore': data['totalScore'] ?? 0,
          'gamesPlayed': data['gamesPlayed'] ?? 0,
          'gamesWon': data['gamesWon'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get user's leaderboard rank
  Future<int> getUserRank({String? userId}) async {
    try {
      String uid = userId ?? currentUserId!;

      // Get user's score
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return 0;

      int userScore = (userDoc.data() as Map<String, dynamic>)['totalScore'] ?? 0;

      // Count how many users have higher score
      QuerySnapshot higherScores = await _firestore
          .collection('users')
          .where('totalScore', isGreaterThan: userScore)
          .get();

      return higherScores.docs.length + 1; // +1 because rank starts at 1
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return 0;
    }
  }
} // <-- END OF UserProfileService CLASS

// ============================================================
// SESSION SERVICE (for UI state management)
// ============================================================
class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._();
  SessionService._();

  final UserProfileService _profileService = UserProfileService();

  // Properties
  int _bubblePower = 0;
  int _energy = 0;
  int _gems = 0;

  int get bubblePower => _bubblePower;
  int get energy => _energy;
  int get gems => _gems;

  StreamSubscription<DocumentSnapshot>? _subscription;
  Timer? _energyTimer;

  // Initialize - called from MainMenuScreen
  void init() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Listen to Firebase coins (bubble power) and gems
    _subscription = _profileService.streamUserProfile().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _bubblePower = data['coins'] ?? 0;
        _gems = data['totalScore'] ?? 0;
        notifyListeners();
      }
    });

    // Load local energy and update every second
    _loadLocalEnergy();
    _energyTimer = Timer.periodic(const Duration(seconds: 1), (_) => _loadLocalEnergy());
  }

  // Load energy from EnergyManager (local storage)
  Future<void> _loadLocalEnergy() async {
    _energy = await EnergyManager.instance.getCurrentEnergy();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _energyTimer?.cancel();
    super.dispose();
  }
}