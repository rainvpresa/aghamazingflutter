import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/energy_manager.dart';
import '../../services/sound_manager.dart';
import 'trivia_game1/main_trivia_screen.dart';
import 'number match/number_match_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'color game/color_game.dart';
import 'tictactoe_screen.dart';

// ═══════════════════════════════════════════════════════════════
// MODELS & SERVICES FOR DYNAMIC MARKERS
// ═══════════════════════════════════════════════════════════════

class MarkerModel {
  final int id;
  final String keyword;
  final String? title;

  MarkerModel({required this.id, required this.keyword, this.title});

  factory MarkerModel.fromJson(Map<String, dynamic> json) {
    return MarkerModel(
      id: json['id'] as int,
      keyword: (json['keyword'] as String).toUpperCase(),
      title: json['title'] as String?,
    );
  }
}

class MarkerService {
  MarkerService._();
  static final MarkerService instance = MarkerService._();

  // 1. Fetch active markers from Laravel: GET /api/markers
  Future<List<MarkerModel>> fetchActiveMarkers() async {
    try {
      final response = await http.get(
        Uri.parse('https://your-laravel-api.com/api/markers'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => MarkerModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching markers: $e');
    }
    return [];
  }

  // 2. Log scan for analytics in Laravel: POST /api/app/game/scan
  Future<void> logMarkerScan(String keyword, String authToken) async {
    try {
      await http.post(
        Uri.parse('https://your-laravel-api.com/api/app/game/scan'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'keyword': keyword}), // Matches Laravel's expected 'keyword' key
      );
    } catch (e) {
      debugPrint('Error logging scan analytics: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// GAME ROUTE MODEL
// ═══════════════════════════════════════════════════════════════
class GameRoute {
  final String name;
  final Widget Function(BuildContext) route;
  GameRoute({required this.name, required this.route});
}

// ═══════════════════════════════════════════════════════════════
// SCAN SCREEN
// ═══════════════════════════════════════════════════════════════
class ARScanScreen extends StatefulWidget {
  const ARScanScreen({super.key});

  @override
  State<ARScanScreen> createState() => _ARScanScreenState();
}

class _ARScanScreenState extends State<ARScanScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  bool _isBusy = false;
  bool _isCameraInitialized = false;
  late AnimationController _scanAnimationController;

  // Stores dynamically loaded markers from Laravel
  List<MarkerModel> _dynamicMarkers = [];

  final List<GameRoute> _games = [
    GameRoute(name: 'Trivia Challenge', route: (_) => const MainTriviaScreen()),
    GameRoute(name: 'Number Match',     route: (_) => const NumberMatchGameScreen()),
    GameRoute(name: 'Color Puzzle',     route: (_) => const ColorPuzzleGame()),
    GameRoute(name: 'Tic Tac Toe',      route: (_) => const TicTacToeStartScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadMarkersFromApi();
    _initializeCamera();

    SoundManager.instance.playGameMusic();
  }

  /// Fetches markers dynamically from the Laravel CMS
  Future<void> _loadMarkersFromApi() async {
    final markers = await MarkerService.instance.fetchActiveMarkers();
    if (mounted) {
      setState(() => _dynamicMarkers = markers);
    }
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _cameraController?.dispose();
    _textRecognizer.close();

    SoundManager.instance.playMenuMusic();
    super.dispose();
  }

  // ─── CAMERA SETUP ────────────────────────────────────────────
  Future<void> _initializeCamera() async {
    await Permission.camera.request();
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController?.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
      _cameraController?.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

// ─── DYNAMIC TEXT RECOGNITION ─────────────────────────────────
  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted || _dynamicMarkers.isEmpty) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);

      MarkerModel? matchedMarker;

      // Match against dynamically loaded keywords from CMS
      for (final block in recognizedText.blocks) {
        final text = block.text.toUpperCase();
        for (final marker in _dynamicMarkers) {
          if (text.contains(marker.keyword)) {
            matchedMarker = marker;
            break;
          }
        }
        if (matchedMarker != null) break;
      }

      if (matchedMarker != null && mounted) {
        await _cameraController?.stopImageStream();

        // 1. Fetch your user's stored Sanctum auth token from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final String token = prefs.getString('auth_token') ?? '';

        // 2. Pass matchedMarker.keyword and the real user token to Laravel
        MarkerService.instance.logMarkerScan(matchedMarker.keyword, token);

        _triggerRandomPopup();
      }
    } catch (e) {
      debugPrint('Scan error: $e');
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(
        _cameraController!.description.sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ─── SHUFFLE BAG RANDOMIZER ──────────────────────────────────
  final List<String> _shuffleBag = [];

  String _nextOption() {
    if (_shuffleBag.isEmpty) {
      _shuffleBag.addAll([
        'trivia',
        'number_match',
        'color_puzzle',
        'tictactoe',
      ]);
      _shuffleBag.shuffle(Random());
    }
    return _shuffleBag.removeLast();
  }

  Future<void> _triggerRandomPopup() async {
    final option = _nextOption();
    _showSpecificGame(option);
  }

  void _showSpecificGame(String gameKey) {
    final gameMap = {
      'trivia':       _games[0],
      'number_match': _games[1],
      'color_puzzle': _games[2],
      'tictactoe':    _games[3],
    };
    final selectedGame = gameMap[gameKey] ?? _games[0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameSelectionDialog(
        gameName: selectedGame.name,
        onStart: () {
          SoundManager.instance.playClick();
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: selectedGame.route),
          );
        },
        onRescan: () {
          SoundManager.instance.playClick();
          Navigator.of(context).pop();
          _restartScanning();
        },
      ),
    );
  }

  void _restartScanning() {
    setState(() => _isBusy = false);
    _cameraController?.startImageStream(_processCameraImage);
  }

  // ─── BUILD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;
          final scanFrameWidth  = screenW * 0.75;
          final scanFrameHeight = screenH * 0.5;
          final bottomCardWidth = screenW * 0.5;

          return Stack(
            children: [
              Positioned.fill(child: CameraPreview(_cameraController!)),
              Positioned.fill(
                child: Column(
                  children: [
                    Flexible(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 8,
                            left: 8,
                          ),
                          child: _buildBackButton(),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 5,
                      child: Center(
                        child: Container(
                          width: scanFrameWidth,
                          height: scanFrameHeight,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom + 40,
                          ),
                          child: _buildScanCard(bottomCardWidth),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        SoundManager.instance.playClick();
        Navigator.pop(context);
      },
      child: Container(
        width: 70, height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Image.asset(
          'assets/images/pngs/btn_back.png',
          width: 70, height: 50, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.arrow_back, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildScanCard(double cardWidth) {
    return Container(
      width: cardWidth.clamp(150.0, 400.0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 10, spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF004A98),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('DOST-STII',
                    style: TextStyle(
                        color: Colors.grey, fontSize: 10,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                Text('Scan',
                    style: TextStyle(
                        color: Colors.black, fontSize: 16,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GAME SELECTION DIALOG
// ═══════════════════════════════════════════════════════════════
class _GameSelectionDialog extends StatefulWidget {
  final String gameName;
  final VoidCallback onStart;
  final VoidCallback onRescan;

  const _GameSelectionDialog({
    required this.gameName,
    required this.onStart,
    required this.onRescan,
  });

  @override
  State<_GameSelectionDialog> createState() => _GameSelectionDialogState();
}

class _GameSelectionDialogState extends State<_GameSelectionDialog> {
  static const _blue  = Color(0xFF004A98);
  static const _red   = Color(0xFFED262A);
  static const _white = Color(0xFFFFFFFF);
  static const _dark  = Color(0xFF1E1E1E);

  bool _isCheckingEnergy = false;

  Future<void> _handlePlayButtonPressed() async {
    setState(() => _isCheckingEnergy = true);
    try {
      final hasEnergy =
      await EnergyManager.instance.hasEnoughEnergy(required: 10);

      if (!hasEnergy) {
        if (!mounted) return;
        _showAlert('Not Enough Energy',
            'You need 10 energy to play. Wait for it to regenerate!');
        setState(() => _isCheckingEnergy = false);
        return;
      }

      final success = await EnergyManager.instance.useEnergy(amount: 10);

      if (success) {
        widget.onStart();
      } else {
        if (!mounted) return;
        _showAlert('Error', 'Something went wrong. Please try again.');
        setState(() => _isCheckingEnergy = false);
      }
    } catch (e) {
      debugPrint('Energy error: $e');
      if (!mounted) return;
      _showAlert('Error', 'Something went wrong. Please try again.');
      setState(() => _isCheckingEnergy = false);
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () {
                SoundManager.instance.playClick();
                Navigator.pop(ctx);
              },
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.85).clamp(280.0, 400.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _blue, width: 4),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha:0.3),
              blurRadius: 20, spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70, height: 70,
              decoration: const BoxDecoration(
                  color: _blue, shape: BoxShape.circle),
              child: const Icon(Icons.stars, color: _white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('GAME',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: _blue, letterSpacing: 2),
                textAlign: TextAlign.center),
            const Text('UNLOCKED!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: _blue, letterSpacing: 2),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(widget.gameName,
                style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w600, color: _dark),
                textAlign: TextAlign.center,
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 4),
                  Text('Costs 10 Energy',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                _buildButton('PLAY', _blue, Icons.play_arrow,
                    _isCheckingEnergy ? null : _handlePlayButtonPressed,
                    isLoading: _isCheckingEnergy),
                const SizedBox(height: 12),
                _buildButton('RESCAN', _red, Icons.refresh,
                    _isCheckingEnergy ? null : widget.onRescan),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
      String text, Color color, IconData icon, VoidCallback? onTap, {
        bool isLoading = false,
      }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: onTap == null ? color.withValues(alpha:0.5) : color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha:0.4),
                    blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: _white, strokeWidth: 2),
                  )
                else
                  Icon(icon, color: _white, size: 22),
                const SizedBox(width: 10),
                Text(text,
                  style: const TextStyle(color: _white, fontSize: 16,
                      fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}