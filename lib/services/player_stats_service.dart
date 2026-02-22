import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GAME TYPE CONSTANTS  — use these strings when saving sessions
// ─────────────────────────────────────────────────────────────────────────────
class GameType {
  static const String trivia      = 'trivia';
  static const String colorPuzzle = 'color_puzzle';
  static const String numberMatch = 'number_match';
  static const String gemGrab     = 'gem_grab';
  static const String ticTacToe   = 'tic_tac_toe';
}

// ─────────────────────────────────────────────────────────────────────────────
//  PLAYER STATS SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class PlayerStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ===========================================================================
  // SAVE METHODS — one per game type
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // TRIVIA
  // Call this in YouWonScreen (or wherever the game ends) alongside addCoins().
  //
  // Example:
  //   await PlayerStatsService().saveTriviaSession(
  //     correctAnswers: _litStars,
  //     wrongAnswers: totalWrong,
  //     totalQuestions: 5,
  //     chancesUsed: _maxChances - _chancesLeft,
  //     scoreEarned: _totalPoints,
  //   );
  // ---------------------------------------------------------------------------
  Future<bool> saveTriviaSession({
    required int correctAnswers,
    required int wrongAnswers,
    required int totalQuestions,
    required int chancesUsed,
    required int scoreEarned,
  }) async {
    final double accuracy = totalQuestions > 0
        ? (correctAnswers / totalQuestions) * 100
        : 0.0;

    final bool isPerfect = correctAnswers == totalQuestions;

    return _saveSession(
      gameType: GameType.trivia,
      scoreEarned: scoreEarned,
      extraFields: {
        'correctAnswers': correctAnswers,
        'wrongAnswers':   wrongAnswers,
        'totalQuestions': totalQuestions,
        'chancesUsed':    chancesUsed,
        'accuracy':       double.parse(accuracy.toStringAsFixed(2)),
        'isPerfectGame':  isPerfect,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // COLOR PUZZLE
  // Call this inside _saveRewards() in ColorPuzzleGame, after updateGameStats().
  //
  // Example:
  //   await PlayerStatsService().saveColorPuzzleSession(
  //     moveCount: moveCount,
  //     optimalMoves: 12,   // already defined as optimalMoves in your code
  //     scoreEarned: points,
  //     coinsEarned: coins,
  //   );
  // ---------------------------------------------------------------------------
  Future<bool> saveColorPuzzleSession({
    required int moveCount,
    required int optimalMoves,
    required int scoreEarned,
    required int coinsEarned,
  }) async {
    final int extraMoves = (moveCount - optimalMoves).clamp(0, 9999);

    return _saveSession(
      gameType: GameType.colorPuzzle,
      scoreEarned: scoreEarned,
      extraFields: {
        'moveCount':    moveCount,
        'optimalMoves': optimalMoves,
        'extraMoves':   extraMoves,
        'coinsEarned':  coinsEarned,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NUMBER MATCH (2048)
  // Call this inside saveNumberMatchRewards() extension, after updateGameStats().
  //
  // Example:
  //   await PlayerStatsService().saveNumberMatchSession(
  //     finalScore: score,
  //     highestTile: _highestTile,
  //     levelReached: _level,
  //     coinsEarned: coinsEarned,
  //   );
  // ---------------------------------------------------------------------------
  Future<bool> saveNumberMatchSession({
    required int finalScore,
    required int highestTile,
    required int levelReached,
    required int coinsEarned,
  }) async {
    final bool reached2048 = highestTile >= 2048;

    return _saveSession(
      gameType: GameType.numberMatch,
      scoreEarned: finalScore,
      extraFields: {
        'highestTile':  highestTile,
        'levelReached': levelReached,
        'coinsEarned':  coinsEarned,
        'reached2048':  reached2048,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // GEM GRAB (mini game — 3 plays per day)
  // Call this inside endGame() in GemGrabGameScreen, after updateGameStats().
  //
  // Example:
  //   await PlayerStatsService().saveGemGrabSession(
  //     gemsCollected: score,
  //     coinsEarned: coinsEarned,
  //     playsRemaining: playsRemaining,
  //   );
  // ---------------------------------------------------------------------------
  Future<bool> saveGemGrabSession({
    required int gemsCollected,
    required int coinsEarned,
    required int playsRemaining,
  }) async {
    return _saveSession(
      gameType: GameType.gemGrab,
      scoreEarned: gemsCollected,
      extraFields: {
        'gemsCollected':  gemsCollected,
        'coinsEarned':    coinsEarned,
        'playsRemaining': playsRemaining,
        'gameDuration':   30, // always 30 seconds
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TIC TAC TOE
  // Call this inside _gameOver() in TicTacToeGameScreen.
  //
  // Example:
  //   await PlayerStatsService().saveTicTacToeSession(
  //     result: 'win',   // 'win', 'loss', or 'tie'
  //     scoreEarned: coinsEarned,
  //   );
  // ---------------------------------------------------------------------------
  Future<bool> saveTicTacToeSession({
    required String result, // 'win', 'loss', or 'tie'
    required int scoreEarned,
  }) async {
    assert(
    ['win', 'loss', 'tie'].contains(result),
    'result must be "win", "loss", or "tie"',
    );

    return _saveSession(
      gameType: GameType.ticTacToe,
      scoreEarned: scoreEarned,
      extraFields: {
        'result': result,
        'isWin':  result == 'win',
        'isLoss': result == 'loss',
        'isTie':  result == 'tie',
      },
    );
  }

  // ===========================================================================
  // READ METHODS
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Get a player's full game history, newest first.
  // Optionally filter by gameType using GameType constants.
  //
  // Example:
  //   final history = await PlayerStatsService().getPlayerHistory(
  //     gameType: GameType.trivia,
  //   );
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getPlayerHistory({
    String? userId,
    String? gameType,
    int limit = 20,
  }) async {
    try {
      final uid = userId ?? currentUserId!;

      Query query = _firestore
          .collection('playerStats')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (gameType != null) {
        query = query.where('gameType', isEqualTo: gameType);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting player history: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Get aggregated stats broken down per game type for one player.
  //
  // Returns a map like:
  // {
  //   'trivia':       { totalGames, totalScore, avgAccuracy, perfectGames },
  //   'color_puzzle': { totalGames, totalScore, bestScore, avgMoves },
  //   'number_match': { totalGames, totalScore, bestScore, highestTileEver },
  //   'gem_grab':     { totalGames, totalScore, bestScore, totalGems },
  //   'tic_tac_toe':  { totalGames, totalScore, wins, losses, ties, winRate },
  // }
  // ---------------------------------------------------------------------------
  Future<Map<String, Map<String, dynamic>>> getPlayerStatsByGame({
    String? userId,
  }) async {
    try {
      final uid = userId ?? currentUserId!;

      final snapshot = await _firestore
          .collection('playerStats')
          .where('userId', isEqualTo: uid)
          .get();

      // Group sessions by gameType
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['gameType'] as String? ?? 'unknown';
        grouped.putIfAbsent(type, () => []).add(data);
      }

      // Aggregate each group
      final Map<String, Map<String, dynamic>> result = {};
      for (final entry in grouped.entries) {
        result[entry.key] = _aggregateSessions(entry.key, entry.value);
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error getting player stats by game: $e');
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // Admin dashboard: aggregated stats for ALL players, sorted by totalScore.
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllPlayersStats({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('playerStats')
          .get();

      // Group by userId
      final Map<String, List<Map<String, dynamic>>> byUser = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final uid = data['userId'] as String? ?? '';
        if (uid.isEmpty) continue;
        byUser.putIfAbsent(uid, () => []).add(data);
      }

      // Fetch display names in batches of 30 (Firestore whereIn limit)
      final userIds = byUser.keys.toList();
      final Map<String, String> displayNames = {};
      for (int i = 0; i < userIds.length; i += 30) {
        final batch = userIds.sublist(i, (i + 30).clamp(0, userIds.length));
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in usersSnapshot.docs) {
          displayNames[doc.id] =
              (doc.data() as Map<String, dynamic>)['displayName'] ?? 'Anonymous';
        }
      }

      // Build one summary row per user
      final List<Map<String, dynamic>> rows = [];
      for (final entry in byUser.entries) {
        final uid      = entry.key;
        final sessions = entry.value;

        int totalScore = 0;
        final Map<String, int> gameBreakdown = {};

        for (final s in sessions) {
          totalScore += (s['scoreEarned'] as num?)?.toInt() ?? 0;
          final type = s['gameType'] as String? ?? 'unknown';
          gameBreakdown[type] = (gameBreakdown[type] ?? 0) + 1;
        }

        rows.add({
          'userId':        uid,
          'displayName':   displayNames[uid] ?? 'Anonymous',
          'totalGames':    sessions.length,
          'totalScore':    totalScore,
          'gameBreakdown': gameBreakdown, // e.g. { 'trivia': 5, 'gem_grab': 12 }
        });
      }

      rows.sort((a, b) =>
          (b['totalScore'] as int).compareTo(a['totalScore'] as int));

      return rows.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error getting all players stats: $e');
      return [];
    }
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  /// Core save — all public save methods funnel through here.
  Future<bool> _saveSession({
    required String gameType,
    required int scoreEarned,
    required Map<String, dynamic> extraFields,
  }) async {
    try {
      final uid = currentUserId;
      if (uid == null) {
        debugPrint('❌ Cannot save session: user not logged in');
        return false;
      }

      await _firestore.collection('playerStats').add({
        'userId':      uid,
        'gameType':    gameType,
        'scoreEarned': scoreEarned,
        'timestamp':   FieldValue.serverTimestamp(),
        ...extraFields,
      });

      debugPrint('✅ [$gameType] session saved for $uid');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving [$gameType] session: $e');
      return false;
    }
  }

  /// Compute aggregate stats for a list of sessions of the same game type.
  Map<String, dynamic> _aggregateSessions(
      String gameType,
      List<Map<String, dynamic>> sessions,
      ) {
    final int totalGames = sessions.length;
    int totalScore = 0;
    for (final s in sessions) {
      totalScore += (s['scoreEarned'] as num?)?.toInt() ?? 0;
    }

    final Map<String, dynamic> base = {
      'totalGames': totalGames,
      'totalScore': totalScore,
    };

    switch (gameType) {

      case GameType.trivia:
        int totalCorrect   = 0;
        int totalQuestions = 0;
        int perfectGames   = 0;
        for (final s in sessions) {
          totalCorrect   += (s['correctAnswers'] as num?)?.toInt() ?? 0;
          totalQuestions += (s['totalQuestions'] as num?)?.toInt() ?? 0;
          if (s['isPerfectGame'] == true) perfectGames++;
        }
        base['totalCorrectAnswers'] = totalCorrect;
        base['avgAccuracy'] = totalQuestions > 0
            ? double.parse(((totalCorrect / totalQuestions) * 100).toStringAsFixed(2))
            : 0.0;
        base['perfectGames'] = perfectGames;
        break;

      case GameType.colorPuzzle:
        int bestScore  = 0;
        int totalMoves = 0;
        for (final s in sessions) {
          final score = (s['scoreEarned'] as num?)?.toInt() ?? 0;
          if (score > bestScore) bestScore = score;
          totalMoves += (s['moveCount'] as num?)?.toInt() ?? 0;
        }
        base['bestScore'] = bestScore;
        base['avgMoves']  = totalGames > 0
            ? double.parse((totalMoves / totalGames).toStringAsFixed(1))
            : 0.0;
        break;

      case GameType.numberMatch:
        int bestScore   = 0;
        int highestTile = 0;
        int reached2048 = 0;
        for (final s in sessions) {
          final score = (s['scoreEarned'] as num?)?.toInt() ?? 0;
          final tile  = (s['highestTile'] as num?)?.toInt() ?? 0;
          if (score > bestScore)   bestScore   = score;
          if (tile  > highestTile) highestTile = tile;
          if (s['reached2048'] == true) reached2048++;
        }
        base['bestScore']        = bestScore;
        base['highestTileEver']  = highestTile;
        base['timesReached2048'] = reached2048;
        break;

      case GameType.gemGrab:
        int bestScore = 0;
        int totalGems = 0;
        for (final s in sessions) {
          final score = (s['scoreEarned'] as num?)?.toInt() ?? 0;
          if (score > bestScore) bestScore = score;
          totalGems += (s['gemsCollected'] as num?)?.toInt() ?? 0;
        }
        base['bestScore'] = bestScore;
        base['totalGems'] = totalGems;
        break;

      case GameType.ticTacToe:
        int wins   = 0;
        int losses = 0;
        int ties   = 0;
        for (final s in sessions) {
          if (s['isWin']  == true) wins++;
          if (s['isLoss'] == true) losses++;
          if (s['isTie']  == true) ties++;
        }
        base['wins']    = wins;
        base['losses']  = losses;
        base['ties']    = ties;
        base['winRate'] = totalGames > 0
            ? double.parse(((wins / totalGames) * 100).toStringAsFixed(2))
            : 0.0;
        break;
    }

    return base;
  }
}