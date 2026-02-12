import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:math';
import '../../services/energy_manager.dart';
import 'trivia_game1/main_trivia_screen.dart';
import 'number match/number_match_game_screen.dart';
import 'color game/color_game.dart';

class ARScanScreen extends StatefulWidget {
  const ARScanScreen({super.key});

  @override
  State<ARScanScreen> createState() => _ARScanScreenState();
}

class _ARScanScreenState extends State<ARScanScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isBusy = false;
  bool _isCameraInitialized = false;
  late AnimationController _scanAnimationController;

  // List of available games
  final List<GameRoute> _games = [
    GameRoute(
      name: 'Trivia Challenge',
      route: (_) => const MainTriviaScreen(),
    ),
    GameRoute(
      name: 'Number Match',
      route: (_) => const NumberMatchGameScreen(),
    ),
    GameRoute(
      name: 'Color Puzzle',
      route: (_) => const ColorPuzzleGame(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await Permission.camera.request();
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
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

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);
      final keywords = ["LIMITLESS", "BILLIARD", "BOWLING", "KTV", "BARCA"];

      bool found = false;
      for (TextBlock block in recognizedText.blocks) {
        String text = block.text.toUpperCase();
        if (keywords.any((key) => text.contains(key))) {
          found = true;
          break;
        }
      }

      if (found && mounted) {
        await _cameraController?.stopImageStream();
        _navigateToRandomGame();
      }
    } catch (e) {
      debugPrint('Scan error: $e');
    } finally {
      _isBusy = false;
    }
  }

  void _navigateToRandomGame() {
    final random = Random();
    final selectedGame = _games[random.nextInt(_games.length)];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GameSelectionDialog(
        gameName: selectedGame.name,
        onStart: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: selectedGame.route),
          );
        },
        onRescan: () {
          Navigator.of(context).pop();
          _restartScanning();
        },
      ),
    );
  }

  void _restartScanning() {
    setState(() {
      _isBusy = false;
    });
    _cameraController?.startImageStream(_processCameraImage);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final sensorOrientation = _cameraController!.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

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

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Get available screen dimensions
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;

          // Responsive sizing
          final scanFrameWidth = screenW * 0.75;
          final scanFrameHeight = screenH * 0.5;
          final bottomCardWidth = screenW * 0.5;

          return Stack(
            children: [
              // Camera Preview - Full Screen
              Positioned.fill(
                child: CameraPreview(_cameraController!),
              ),

              // Main Content Column with Flexbox
              Positioned.fill(
                child: Column(
                  children: [
                    // Top section with back button
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

                    // Middle section with scan frame
                    Flexible(
                      flex: 5,
                      child: Center(
                        child: Container(
                          width: scanFrameWidth,
                          height: scanFrameHeight,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    // Bottom section with scan card
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
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 70,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Image.asset(
          'assets/images/pngs/btn_back.png',
          width: 70,
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildScanCard(double cardWidth) {
    return Container(
      width: cardWidth.clamp(150.0, 400.0), // Ensure valid width range
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App Icon - DOST-STII Blue
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF004A98), // Yale Blue
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Text Content - Expanded to fill remaining space
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DOST-STII',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Scan',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Game Selection Dialog with Energy Check
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
  // DOST-STII Brand Colors
  static const Color yaleBlue = Color(0xFF004A98);
  static const Color redPigment = Color(0xFFED262A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color eerieBlack = Color(0xFF1E1E1E);

  bool _isCheckingEnergy = false;

  Future<void> _handlePlayButtonPressed() async {
    setState(() => _isCheckingEnergy = true);

    try {
      // Check if user has enough energy (10 energy required for Color Puzzle)
      bool hasEnergy = await EnergyManager.instance.hasEnoughEnergy(required: 10);

      if (!hasEnergy) {
        // Show "Not Enough Energy" dialog
        if (!mounted) return;
        _showNotEnoughEnergyDialog();
        setState(() => _isCheckingEnergy = false);
        return;
      }

      // Deduct 10 energy
      bool success = await EnergyManager.instance.useEnergy(amount: 10);

      if (success) {
        // Energy deducted successfully, start the game
        widget.onStart();
      } else {
        // Failed to deduct energy
        if (!mounted) return;
        _showErrorDialog();
        setState(() => _isCheckingEnergy = false);
      }
    } catch (e) {
      debugPrint('Error checking/using energy: $e');
      if (!mounted) return;
      _showErrorDialog();
      setState(() => _isCheckingEnergy = false);
    }
  }

  void _showNotEnoughEnergyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not Enough Energy'),
        content: const Text('You need 10 energy to play this game. Please wait for your energy to regenerate or come back later!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text('Something went wrong. Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = (screenWidth * 0.85).clamp(280.0, 400.0);

          return Container(
            width: dialogWidth,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: yaleBlue, width: 4),
              boxShadow: [
                BoxShadow(
                  color: yaleBlue.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with DOST-STII Blue background
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: yaleBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars,
                    color: white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Title - DOST-STII Blue
                const Text(
                  'GAME',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: yaleBlue,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'UNLOCKED!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: yaleBlue,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Game Name - Black text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    widget.gameName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: eerieBlack,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),

                // Energy Cost Display
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
                      Text(
                        'Costs 10 Energy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons Column for better spacing and no overflow
                Column(
                  children: [
                    // PLAY Button - DOST-STII Blue
                    _buildButton(
                      'PLAY',
                      yaleBlue,
                      Icons.play_arrow,
                      _isCheckingEnergy ? null : _handlePlayButtonPressed,
                      dialogWidth,
                      isLoading: _isCheckingEnergy,
                    ),
                    const SizedBox(height: 12),
                    // RESCAN Button - Red Pigment
                    _buildButton(
                      'RESCAN',
                      redPigment,
                      Icons.refresh,
                      _isCheckingEnergy ? null : widget.onRescan,
                      dialogWidth,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildButton(
      String text,
      Color color,
      IconData icon,
      VoidCallback? onTap,
      double dialogWidth, {
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
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(icon, color: white, size: 22),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: const TextStyle(
                    color: white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
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

// Game Route Model
class GameRoute {
  final String name;
  final Widget Function(BuildContext) route;

  GameRoute({required this.name, required this.route});
}