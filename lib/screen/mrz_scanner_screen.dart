import 'dart:developer' as developer;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mrzreader/main.dart';
import 'package:mrzreader/model/passport_data.dart';
import 'package:mrzreader/service/mrz_parser.dart';
import 'package:mrzreader/screen/passport_form_screen.dart';

class MRZScannerScreen extends StatefulWidget {
  const MRZScannerScreen({super.key});

  @override
  State<MRZScannerScreen> createState() => _MRZScannerScreenState();
}

class _MRZScannerScreenState extends State<MRZScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  bool _isInitialized = false;
  String _statusMessage = 'Initializing camera...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    developer.log('Initializing camera...', name: 'mrzreader.camera');
    if (cameras.isEmpty) {
      developer.log(
        'No cameras available',
        name: 'mrzreader.camera',
        level: 900,
      );
      setState(() {
        _statusMessage = 'No cameras available';
      });
      return;
    }

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      developer.log(
        'Camera initialized successfully',
        name: 'mrzreader.camera',
      );
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Position passport MRZ area in frame';
      });
    } catch (e) {
      developer.log(
        'Camera initialization failed',
        error: e,
        name: 'mrzreader.camera',
        level: 1000,
      );
      setState(() {
        _statusMessage = 'Camera initialization failed: $e';
      });
    }
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      developer.log(
        'Capture skipped: isProcessing=$_isProcessing, cameraReady=${_cameraController?.value.isInitialized}',
        name: 'mrzreader.scanner',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing...';
    });

    developer.log('Capturing picture...', name: 'mrzreader.scanner');

    try {
      final XFile image = await _cameraController!.takePicture();
      developer.log(
        'Picture captured: ${image.path}',
        name: 'mrzreader.scanner',
      );

      final InputImage inputImage = InputImage.fromFilePath(image.path);
      developer.log(
        'Processing image with ML Kit...',
        name: 'mrzreader.scanner',
      );

      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      developer.log(
        'Text recognition completed. Length: ${recognizedText.text.length}',
        name: 'mrzreader.scanner',
      );

      // Extract potential MRZ lines
      List<String> mrzLines = _extractMRZLines(recognizedText.text);
      developer.log(
        'Found ${mrzLines.length} potential MRZ lines',
        name: 'mrzreader.scanner',
      );

      if (mrzLines.length >= 2) {
        // Parse MRZ
        developer.log(
          'Attempting to parse MRZ lines...',
          name: 'mrzreader.scanner',
        );
        PassportData? passportData = MRZParser.parse(mrzLines);

        if (passportData != null) {
          developer.log('MRZ parsed successfully', name: 'mrzreader.scanner');
          // Navigate to form screen
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PassportFormScreen(passportData: passportData),
              ),
            );
          }
        } else {
          developer.log(
            'Failed to parse MRZ data',
            name: 'mrzreader.scanner',
            level: 900,
          );
          setState(() {
            _statusMessage = 'Failed to parse MRZ. Try again.';
          });
        }
      } else {
        developer.log(
          'Insufficient MRZ lines detected',
          name: 'mrzreader.scanner',
        );
        setState(() {
          _statusMessage = 'MRZ not detected. Please align passport properly.';
        });
      }
    } catch (e) {
      developer.log(
        'Error during capture/process',
        error: e,
        name: 'mrzreader.scanner',
        level: 1000,
      );
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });

      // Reset status message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isProcessing) {
          setState(() {
            _statusMessage = 'Position passport MRZ area in frame';
          });
        }
      });
    }
  }

  List<String> _extractMRZLines(String text) {
    List<String> lines = text.split('\n');
    List<String> mrzLines = [];

    for (String line in lines) {
      // Clean and filter lines that look like MRZ
      String cleaned = line
          .replaceAll(' ', '')
          .replaceAll('.', '')
          .toUpperCase();

      // MRZ lines are typically 30, 36, or 44 characters long
      // and contain mostly uppercase letters, numbers, and '<' characters
      if (cleaned.length >= 30 && _looksLikeMRZ(cleaned)) {
        mrzLines.add(cleaned);
      }
    }

    return mrzLines;
  }

  bool _looksLikeMRZ(String line) {
    // MRZ contains A-Z, 0-9, and < characters
    RegExp mrzPattern = RegExp(r'^[A-Z0-9<]+$');
    if (!mrzPattern.hasMatch(line)) return false;

    // Should have some '<' characters (used as fillers)
    int angleCount = '<'.allMatches(line).length;
    return angleCount >= 2;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'SCANNER',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Camera Preview
                SizedBox.expand(child: CameraPreview(_cameraController!)),

                // Technical Overlay
                _buildTechOverlay(),

                // Status Message Glass
                Positioned(
                  top: 120,
                  left: 24,
                  right: 24,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withAlpha(38)),
                        ),
                        child: Text(
                          _statusMessage.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Capture Button
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withAlpha(63),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : _captureAndProcess,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isProcessing
                                  ? Colors.grey.withAlpha(63)
                                  : Colors.blueAccent.withAlpha(63),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                            label: Text(
                              _isProcessing ? 'SCANNING...' : 'SCAN PASSPORT',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.blueAccent),
                    const SizedBox(height: 32),
                    Text(
                      _statusMessage.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTechOverlay() {
    return Stack(
      children: [
        // Mask with a hole
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withAlpha(153),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Decorative frame
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 160,
            child: Stack(
              children: [
                // Animated Frame Corners
                _buildFrameCorner(topLeft: true),
                _buildFrameCorner(topRight: true),
                _buildFrameCorner(bottomLeft: true),
                _buildFrameCorner(bottomRight: true),

                // Scanning Line Animation placeholder (visual only)
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 1,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withAlpha(127),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrameCorner({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return Positioned(
      top: (topLeft || topRight) ? 0 : null,
      bottom: (bottomLeft || bottomRight) ? 0 : null,
      left: (topLeft || bottomLeft) ? 0 : null,
      right: (topRight || bottomRight) ? 0 : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: (topLeft || topRight)
                ? const BorderSide(color: Colors.blueAccent, width: 4)
                : BorderSide.none,
            bottom: (bottomLeft || bottomRight)
                ? const BorderSide(color: Colors.blueAccent, width: 4)
                : BorderSide.none,
            left: (topLeft || bottomLeft)
                ? const BorderSide(color: Colors.blueAccent, width: 4)
                : BorderSide.none,
            right: (topRight || bottomRight)
                ? const BorderSide(color: Colors.blueAccent, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
