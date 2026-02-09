import 'package:shared_preferences/shared_preferences.dart';

class EnergyManager {
  static final EnergyManager instance = EnergyManager._();
  EnergyManager._();

  // Constants
  static const int maxEnergy = 100;
  static const int energyPerPlay = 5;
  static const int energyRegenMinutes = 5;
  static const int dailyEnergyGrant = 100;

  // SharedPreferences keys
  static const String _keyEnergy = 'current_energy';
  static const String _keyLastUpdate = 'last_energy_update';
  static const String _keyLastDailyReset = 'last_daily_reset';
  static const String _keyLastSyncTime = 'last_energy_sync_time';

  // ============================================================
  // CORE ENERGY METHODS
  // ============================================================

  /// Initialize energy system (call on app start)
  Future<void> initialize() async {
    await _checkDailyReset();
    await _regenerateEnergy();
  }

  /// Get current energy
  Future<int> getCurrentEnergy() async {
    // First regenerate any pending energy
    await _regenerateEnergy();

    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyEnergy) ?? maxEnergy;
  }

  /// Use energy (when playing game)
  Future<bool> useEnergy({int amount = energyPerPlay}) async {
    await _regenerateEnergy();

    final prefs = await SharedPreferences.getInstance();
    int currentEnergy = prefs.getInt(_keyEnergy) ?? maxEnergy;

    if (currentEnergy < amount) {
      return false; // Not enough energy
    }

    int newEnergy = currentEnergy - amount;
    await prefs.setInt(_keyEnergy, newEnergy);
    await prefs.setString(_keyLastUpdate, DateTime.now().toIso8601String());

    return true;
  }

  /// Get time until next energy point (in seconds)
  Future<int> getSecondsUntilNextEnergy() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString(_keyLastUpdate);

    if (lastUpdateStr == null) {
      return 0; // Energy can regenerate immediately
    }

    final lastUpdate = DateTime.parse(lastUpdateStr);
    final now = DateTime.now();
    final timePassed = now.difference(lastUpdate);

    // Calculate seconds since last full 5-minute interval
    final secondsSinceLastRegen = timePassed.inSeconds % (energyRegenMinutes * 60);
    final secondsUntilNext = (energyRegenMinutes * 60) - secondsSinceLastRegen;

    return secondsUntilNext;
  }

  /// Check if user has enough energy
  Future<bool> hasEnoughEnergy({int required = energyPerPlay}) async {
    int current = await getCurrentEnergy();
    return current >= required;
  }

  /// Get time until full energy (in seconds)
  Future<int> getSecondsUntilFull() async {
    int currentEnergy = await getCurrentEnergy();

    if (currentEnergy >= maxEnergy) {
      return 0;
    }

    int energyNeeded = maxEnergy - currentEnergy;
    int secondsNeeded = energyNeeded * energyRegenMinutes * 60;

    // Account for partial progress toward next energy point
    int secondsUntilNext = await getSecondsUntilNextEnergy();

    return secondsNeeded - (energyRegenMinutes * 60) + secondsUntilNext;
  }

  // ============================================================
  // SYNC METHODS (Hybrid approach - sync with Firebase)
  // ============================================================

  /// Sync local energy with Firebase
  /// Call this periodically or when internet connection is restored
  Future<bool> syncWithFirebase(
      Future<bool> Function(int energy) firebaseUpdateFn,
      ) async {
    try {
      int currentEnergy = await getCurrentEnergy();

      // Update Firebase with current local energy
      bool success = await firebaseUpdateFn(currentEnergy);

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _keyLastSyncTime,
          DateTime.now().toIso8601String(),
        );
      }

      return success;
    } catch (e) {
      print('Error syncing energy with Firebase: $e');
      return false;
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final syncTimeStr = prefs.getString(_keyLastSyncTime);
    return syncTimeStr != null ? DateTime.parse(syncTimeStr) : null;
  }

  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================

  /// Regenerate energy based on time passed
  Future<void> _regenerateEnergy() async {
    final prefs = await SharedPreferences.getInstance();

    int currentEnergy = prefs.getInt(_keyEnergy) ?? maxEnergy;

    // If already at max, no need to regenerate
    if (currentEnergy >= maxEnergy) {
      await prefs.setInt(_keyEnergy, maxEnergy);
      return;
    }

    final lastUpdateStr = prefs.getString(_keyLastUpdate);

    if (lastUpdateStr == null) {
      // First time, set to max
      await prefs.setInt(_keyEnergy, maxEnergy);
      await prefs.setString(_keyLastUpdate, DateTime.now().toIso8601String());
      return;
    }

    final lastUpdate = DateTime.parse(lastUpdateStr);
    final now = DateTime.now();
    final timePassed = now.difference(lastUpdate);

    // Calculate how many energy points to add (1 per 5 minutes)
    int minutesPassed = timePassed.inMinutes;
    int energyToAdd = minutesPassed ~/ energyRegenMinutes;

    if (energyToAdd > 0) {
      int newEnergy = (currentEnergy + energyToAdd).clamp(0, maxEnergy);
      await prefs.setInt(_keyEnergy, newEnergy);

      // Update timestamp to account for energy added
      // This prevents "losing" partial progress
      final energyAddedMinutes = energyToAdd * energyRegenMinutes;
      final newLastUpdate = lastUpdate.add(Duration(minutes: energyAddedMinutes));
      await prefs.setString(_keyLastUpdate, newLastUpdate.toIso8601String());
    }
  }

  /// Check and perform daily energy reset (100 energy per day)
  Future<void> _checkDailyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString(_keyLastDailyReset);
    final now = DateTime.now();

    if (lastResetStr == null) {
      // First time, grant energy
      await prefs.setInt(_keyEnergy, dailyEnergyGrant);
      await prefs.setString(_keyLastDailyReset, _getDateKey(now));
      await prefs.setString(_keyLastUpdate, now.toIso8601String());
      return;
    }

    final todayKey = _getDateKey(now);

    if (lastResetStr != todayKey) {
      // New day! Grant daily energy
      await prefs.setInt(_keyEnergy, dailyEnergyGrant);
      await prefs.setString(_keyLastDailyReset, todayKey);
      await prefs.setString(_keyLastUpdate, now.toIso8601String());
    }
  }

  /// Get date key for daily reset (YYYY-MM-DD)
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // DEBUG/ADMIN METHODS (Remove in production)
  // ============================================================

  /// Reset energy to max (for testing)
  Future<void> resetEnergy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyEnergy, maxEnergy);
    await prefs.setString(_keyLastUpdate, DateTime.now().toIso8601String());
  }

  /// Set custom energy amount (for testing)
  Future<void> setEnergy(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyEnergy, amount.clamp(0, maxEnergy));
    await prefs.setString(_keyLastUpdate, DateTime.now().toIso8601String());
  }

  /// Clear all energy data (for testing)
  Future<void> clearEnergyData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEnergy);
    await prefs.remove(_keyLastUpdate);
    await prefs.remove(_keyLastDailyReset);
    await prefs.remove(_keyLastSyncTime);
  }

  // ============================================================
  // STATS/INFO METHODS
  // ============================================================

  /// Get formatted time string until next energy
  Future<String> getTimeUntilNextEnergyFormatted() async {
    int seconds = await getSecondsUntilNextEnergy();
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Get formatted time string until full energy
  Future<String> getTimeUntilFullFormatted() async {
    int totalSeconds = await getSecondsUntilFull();

    if (totalSeconds == 0) return 'Full';

    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Get energy info as a map
  Future<Map<String, dynamic>> getEnergyInfo() async {
    int current = await getCurrentEnergy();
    int secondsNext = await getSecondsUntilNextEnergy();
    int secondsFull = await getSecondsUntilFull();

    return {
      'current': current,
      'max': maxEnergy,
      'percentage': (current / maxEnergy * 100).toInt(),
      'secondsUntilNext': secondsNext,
      'secondsUntilFull': secondsFull,
      'canPlay': current >= energyPerPlay,
      'energyNeeded': energyPerPlay,
    };
  }
}