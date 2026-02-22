import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundManager {
  static final SoundManager instance = SoundManager._();
  SoundManager._();

  final AudioPlayer _musicPlayer = AudioPlayer();

  bool _musicEnabled = true;
  bool _initialized = false;
  String? _currentTrack;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.5);
      _initialized = true;
    } catch (e) {
      debugPrint('SoundManager init error: $e');
    }
  }

  Future<void> playMenuMusic() async {
    if (!_musicEnabled) return;
    if (_currentTrack == 'menu') return;
    _currentTrack = 'menu';
    try {
      await _musicPlayer.stop();
      await _musicPlayer.play(AssetSource('audio/app_bgm.mp3'));
    } catch (e) {
      debugPrint('playMenuMusic error: $e');
      _currentTrack = null; // reset so it can retry
    }
  }

  Future<void> playGameMusic() async {
    if (!_musicEnabled) return;
    if (_currentTrack == 'game') return;
    _currentTrack = 'game';
    try {
      await _musicPlayer.stop();
      await _musicPlayer.play(AssetSource('audio/game_bgm.mp3'));
    } catch (e) {
      debugPrint('playGameMusic error: $e');
      _currentTrack = null;
    }
  }

  Future<void> stopMusic() async {
    if (!_initialized) return;
    try {
      await _musicPlayer.stop();
      _currentTrack = null;
    } catch (e) {
      debugPrint('stopMusic error: $e');
    }
  }

  /// Plays a one-shot sound effect.
  void playClick() {
    if (!_initialized) return;
    try {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.release);
      player.play(AssetSource('audio/click1.mp3'));
    } catch (e) {
      debugPrint('Error playing click sound: $e');
    }
  }

  bool get musicEnabled => _musicEnabled;

  Future<void> toggleMusic() async {
    _musicEnabled = !_musicEnabled;
    try {
      if (_musicEnabled) {
        await _musicPlayer.resume();
      } else {
        await _musicPlayer.pause();
      }
    } catch (e) {
      debugPrint('toggleMusic error: $e');
    }
  }
}