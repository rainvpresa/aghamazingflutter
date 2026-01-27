import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple app session/state manager used by MainMenu and other screens.
///
/// - Persists a few values in SharedPreferences (token/email already handled by login).
/// - Exposes in-memory values and ChangeNotifier updates so UI can listen to changes.
/// - Provides placeholder/simulated API methods you can later replace with real HTTP calls.
///
/// NOTE:
/// - Replace the simulated delays and logic with real API calls (use your AuthApi or another service)
///   once your backend provides endpoints for energy/tier/bubble power, etc.
class SessionService extends ChangeNotifier {
  SessionService._privateConstructor();

  static final SessionService instance = SessionService._privateConstructor();

  // Stored values
  int _energy = 10;
  int _bubblePower = 3;
  int _xp = 0;
  int _tier = 1;

  bool _initialized = false;

  // getters
  int get energy => _energy;
  int get bubblePower => _bubblePower;
  int get xp => _xp;
  int get tier => _tier;
  bool get initialized => _initialized;

  // simple tier thresholds for demo (example)
  final List<int> _tierThresholds = [0, 100, 300, 700, 1500];

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    _energy = prefs.getInt('energy') ?? 10;
    _bubblePower = prefs.getInt('bubblePower') ?? 3;
    _xp = prefs.getInt('xp') ?? 0;
    _tier = prefs.getInt('tier') ?? 1;

    _initialized = true;
    notifyListeners();
  }

  // Example: consume energy; returns true if successful
  Future<bool> consumeEnergy(int amount) async {
    // Simulate API latency
    await Future.delayed(const Duration(milliseconds: 300));

    if (_energy >= amount) {
      _energy -= amount;
      await _saveInt('energy', _energy);
      notifyListeners();
      return true;
    }
    return false;
  }

  // Example: add energy (e.g., from reward)
  Future<void> addEnergy(int amount) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _energy += amount;
    await _saveInt('energy', _energy);
    notifyListeners();
  }

  // Example: use bubble power
  Future<bool> useBubblePower(int amount) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (_bubblePower >= amount) {
      _bubblePower -= amount;
      await _saveInt('bubblePower', _bubblePower);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> addBubblePower(int amount) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _bubblePower += amount;
    await _saveInt('bubblePower', _bubblePower);
    notifyListeners();
  }

  // Add XP and handle tier up if threshold crossed
  Future<void> addXp(int amount) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _xp += amount;
    // determine new tier
    int newTier = _tier;
    for (int i = 0; i < _tierThresholds.length; i++) {
      if (_xp >= _tierThresholds[i]) newTier = i + 1;
    }
    _tier = newTier;
    await _saveInt('xp', _xp);
    await _saveInt('tier', _tier);
    notifyListeners();
  }

  // Reset (for debug)
  Future<void> resetDemoValues() async {
    _energy = 10;
    _bubblePower = 3;
    _xp = 0;
    _tier = 1;
    await _saveInt('energy', _energy);
    await _saveInt('bubblePower', _bubblePower);
    await _saveInt('xp', _xp);
    await _saveInt('tier', _tier);
    notifyListeners();
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }
}