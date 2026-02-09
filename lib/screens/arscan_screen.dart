import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'game1/main_trivia_screen.dart';

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
        _navigateToTrivia();
      }
    } catch (e) {
      debugPrint('Scan error: $e');
    } finally {
      _isBusy = false;
    }
  }

  void _navigateToTrivia() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainTriviaScreen()),
    );
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
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.cyan)));
    }

    final screenH = MediaQuery.of(context).size.height;
    const scanW = 280.0;
    const scanH = 280.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_cameraController!),

          // Simplified HUD with corner brackets only
          Center(
            child: SizedBox(
              width: scanW,
              height: scanH,
              child: Stack(
                children: [
                  _buildCorner(top: 0, left: 0, angle: 0),
                  _buildCorner(top: 0, right: 0, angle: 1.5708),
                  _buildCorner(bottom: 0, left: 0, angle: -1.5708),
                  _buildCorner(bottom: 0, right: 0, angle: 3.14159),

                  // Animated Scanning Line
                  AnimatedBuilder(
                    animation: _scanAnimationController,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanAnimationController.value * scanH,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                            color: Colors.cyan,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Cool Unique "Scan a marker" text in the bottom
          Positioned(
            bottom: screenH * 0.12,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _scanAnimationController,
                builder: (context, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _scanAnimationController.value,
                            child: const Icon(Icons.arrow_right, color: Colors.cyanAccent, size: 32),
                          ),
                          const SizedBox(width: 10),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: const [Colors.cyan, Colors.white, Colors.cyan],
                              stops: [0.0, _scanAnimationController.value, 1.0],
                            ).createShader(bounds),
                            child: const Text(
                              "SCAN A MARKER",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'LilitaOne',
                                letterSpacing: 6,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Opacity(
                            opacity: _scanAnimationController.value,
                            child: const Icon(Icons.arrow_left, color: Colors.cyanAccent, size: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 2,
                        width: 200 * _scanAnimationController.value,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.cyanAccent, Colors.transparent],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Clean Back Button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({double? top, double? left, double? right, double? bottom, required double angle}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.cyan, width: 4),
              left: BorderSide(color: Colors.cyan, width: 4),
            ),
          ),
        ),
      ),
    );
  }
}
