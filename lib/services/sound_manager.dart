import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundManager {
  static final SoundManager instance = SoundManager._();
  SoundManager._();

  // Change these two numbers to adjust loudness (0.0 - 1.0)
  static const double _musicVolume = 0.3;
  static const double _sfxVolume = 0.4;

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer(); // one reusable click player

  bool _musicEnabled = true;
  bool _initialized = false;
  String? _currentTrack;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // Use the media volume stream and don't fight over audio focus,
      // so clicks don't interrupt the music.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );

      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicVolume);

      await _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
      await _sfxPlayer.setVolume(_sfxVolume);

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
      _currentTrack = null;
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

  /// One-shot click sound (reuses a single player).
  void playClick() {
    if (!_initialized) return;
    try {
      _sfxPlayer.stop();
      _sfxPlayer.play(AssetSource('audio/click1.mp3'), volume: _sfxVolume);
    } catch (e) {
      debugPrint('Error playing click sound: $e');
    }
  }

  bool get musicEnabled => _musicEnabled;

  Future<void> toggleMusic() async {
    _musicEnabled = !_musicEnabled;
    try {
      if (_musicEnabled) {
        // Start the right track again if nothing is playing yet
        if (_currentTrack == null) {
          await playMenuMusic();
        } else {
          await _musicPlayer.resume();
        }
      } else {
        await _musicPlayer.pause();
      }
    } catch (e) {
      debugPrint('toggleMusic error: $e');
    }
  }
}