import 'package:flutter/foundation.dart';
import 'player_stats_service.dart';
import 'energy_manager.dart';

class SessionService extends ChangeNotifier {
  SessionService._privateConstructor();
  static final SessionService instance = SessionService._privateConstructor();

  final PlayerStatsService _statsService = PlayerStatsService();

  int _bubblePower = 0; // Maps directly to `coins` in AppUser backend
  int _gems = 0;
  int _energy = 100;

  int get bubblePower => _bubblePower;
  int get gems => _gems;
  int get energy => _energy;

  /// Initialize session on app / screen start
  Future<void> init() async {
    await EnergyManager.instance.initialize();
    await fetchStats();
  }

  /// Fetch stats from Laravel backend API
  Future<void> fetchStats() async {
    try {
      final stats = await _statsService.getPlayerStats();
      if (stats != null) {
        // 'coins' from AppUser DB mapped to bubblePower in UI
        _bubblePower = stats['coins'] ?? _bubblePower;
        _gems = stats['gems'] ?? _gems;
        _energy = stats['energy'] ?? await EnergyManager.instance.getCurrentEnergy();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching session stats: $e');
      // Fallback local energy read
      _energy = await EnergyManager.instance.getCurrentEnergy();
      notifyListeners();
    }
  }

  /// Update energy locally & notify UI consumers
  void setEnergy(int newEnergy) {
    _energy = newEnergy;
    notifyListeners();
  }

  /// Add / Subtract gems dynamically
  void updateGems(int amount) {
    _gems += amount;
    notifyListeners();
  }

  /// Add / Subtract coins dynamically
  void updateBubblePower(int amount) {
    _bubblePower += amount;
    notifyListeners();
  }
}