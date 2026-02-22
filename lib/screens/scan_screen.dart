import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:math';
import '../../services/energy_manager.dart';
import '../../services/sound_manager.dart';
import 'trivia_game1/main_trivia_screen.dart';
import 'number match/number_match_game_screen.dart';
import 'color game/color_game.dart';
import 'tictactoe_screen.dart';

// ═══════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════
class PopupFact {
  final String info;
  final String fact;

  const PopupFact({required this.info, required this.fact});

  factory PopupFact.fromFirestore(Map<String, dynamic> data) {
    return PopupFact(
      info: data['info'] as String? ?? 'Fun Fact',
      fact: data['fact'] as String? ?? '',
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════
class PopupFactService {
  PopupFactService._();
  static final PopupFactService instance = PopupFactService._();

  List<PopupFact>? _cache;

  static const List<PopupFact> _fallbackFacts = [
    PopupFact(info: 'Did you know?', fact: 'The ocean produces over 50% of Earth\'s oxygen.'),
    PopupFact(info: 'Fun Fact!',     fact: 'Honey never spoils — 3000-year-old honey was found in Egyptian tombs.'),
    PopupFact(info: 'Did you know?', fact: 'A day on Venus is longer than a year on Venus.'),
  ];

  Future<PopupFact?> getRandomFact() async {
    try {
      if (_cache == null) {
        debugPrint('🔍 PopupFactService: Fetching from Firestore...');
        final snapshot = await FirebaseFirestore.instance
            .collection('popup_facts')
            .get();
        debugPrint('✅ PopupFactService: Got ${snapshot.docs.length} docs');
        _cache = snapshot.docs.map((doc) {
          debugPrint('   Doc ID: ${doc.id} | data: ${doc.data()}');
          return PopupFact.fromFirestore(doc.data());
        }).toList();
      }

      if (_cache!.isEmpty) {
        debugPrint('⚠️ PopupFactService: Cache is empty — using fallback');
        return _fallbackFacts[Random().nextInt(_fallbackFacts.length)];
      }

      final shuffled = List<PopupFact>.from(_cache!)..shuffle();
      debugPrint('✅ PopupFactService: Returning fact → ${shuffled.first.info}');
      return shuffled.first;
    } catch (e) {
      debugPrint('❌ PopupFactService FAILED: $e');
      debugPrint('   → Using fallback fact instead');
      return _fallbackFacts[Random().nextInt(_fallbackFacts.length)];
    }
  }

  void clearCache() => _cache = null;
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

  final List<GameRoute> _games = [
    GameRoute(name: 'Trivia Challenge', route: (_) => const MainTriviaScreen()),
    GameRoute(name: 'Number Match',     route: (_) => const NumberMatchGameScreen()),
    GameRoute(name: 'Color Puzzle',     route: (_) => const ColorPuzzleGame()),
    GameRoute(name: 'Tic Tac Toe',      route: (_) => const TicTacToeStartScreen()),
  ];

  // ─── LIFECYCLE ───────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initializeCamera();

    SoundManager.instance.playGameMusic();
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

  // ─── TEXT RECOGNITION ────────────────────────────────────────
  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);

      const keywords = ["LIMITLESS", "BILLIARD", "BOWLING", "KTV", "BARCA"];

      bool found = false;
      for (final block in recognizedText.blocks) {
        if (keywords.any((k) => block.text.toUpperCase().contains(k))) {
          found = true;
          break;
        }
      }

      if (found && mounted) {
        await _cameraController?.stopImageStream();
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
    final rotation =
        InputImageRotationValue.fromRawValue(
            _cameraController!.description.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
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
        'fact',
        'trivia',
        'number_match',
        'color_puzzle',
        'tictactoe',
      ]);
      _shuffleBag.shuffle(Random());
      debugPrint('Shuffle bag refilled: $_shuffleBag');
    }
    final picked = _shuffleBag.removeLast();
    debugPrint('Picked from bag: $picked (${_shuffleBag.length} left)');
    return picked;
  }

  Future<void> _triggerRandomPopup() async {
    final option = _nextOption();

    if (option == 'fact') {
      final fact = await PopupFactService.instance.getRandomFact();
      if (!mounted) return;
      if (fact == null) {
        _showSpecificGame('trivia');
        return;
      }
      _showFactDialog(fact);
    } else {
      _showSpecificGame(option);
    }
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
          SoundManager.instance.playClick(); // 🔊
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: selectedGame.route),
          );
        },
        onRescan: () {
          SoundManager.instance.playClick(); // 🔊
          Navigator.of(context).pop();
          _restartScanning();
        },
      ),
    );
  }

  // ─── SHOW FACT DIALOG ────────────────────────────────────────
  void _showFactDialog(PopupFact fact) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FactPopupDialog(
        fact: fact,
        onRescan: () {
          SoundManager.instance.playClick(); // 🔊
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
        SoundManager.instance.playClick(); // 🔊
        Navigator.pop(context);
      },
      child: Container(
        width: 70, height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
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
            color: Colors.black.withOpacity(0.3),
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
// FACT POPUP DIALOG
// ═══════════════════════════════════════════════════════════════
class _FactPopupDialog extends StatelessWidget {
  final PopupFact fact;
  final VoidCallback onRescan;

  static const _blue  = Color(0xFF004A98);
  static const _red   = Color(0xFFED262A);
  static const _white = Color(0xFFFFFFFF);
  static const _dark  = Color(0xFF1E1E1E);

  const _FactPopupDialog({required this.fact, required this.onRescan});

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
              color: _blue.withOpacity(0.3),
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
              child: const Icon(
                  Icons.lightbulb_rounded, color: _white, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              fact.info.toUpperCase(),
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold,
                color: _blue, letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _blue.withOpacity(0), _blue, _blue.withOpacity(0),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              fact.fact,
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500,
                color: _dark, height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _buildButton(
              label: 'RESCAN',
              icon: Icons.refresh_rounded,
              color: _red,
              onTap: onRescan, // 🔊 sound called at the call site in _showFactDialog
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
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
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _white, size: 22),
                const SizedBox(width: 10),
                Text(label,
                  style: const TextStyle(
                    color: _white, fontSize: 16,
                    fontWeight: FontWeight.bold, letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
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
        widget.onStart(); // 🔊 sound called at the call site in _showSpecificGame
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
                SoundManager.instance.playClick(); // 🔊
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
              color: _blue.withOpacity(0.3),
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
                    _isCheckingEnergy ? null : widget.onRescan), // 🔊 sound called at call site
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
              color: onTap == null ? color.withOpacity(0.5) : color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.4),
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