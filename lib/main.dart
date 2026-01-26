import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:developer' as developer;
import 'mrz_parser.dart';
import 'passport_form_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
    developer.log(
      'Available cameras: ${cameras.length}',
      name: 'mrzreader.main',
    );
  } catch (e) {
    developer.log(
      'Failed to get available cameras',
      error: e,
      name: 'mrzreader.main',
    );
  }
  runApp(const MRZScannerApp());
}

class MRZScannerApp extends StatelessWidget {
  const MRZScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MRZ Passport Scanner',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MRZScannerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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
      appBar: AppBar(
        title: const Text('Passport MRZ Scanner'),
        centerTitle: true,
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Camera Preview
                SizedBox.expand(child: CameraPreview(_cameraController!)),

                // MRZ Frame Guide
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Align MRZ here',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),

                // Status Message
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),

                // Capture Button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.extended(
                      onPressed: _isProcessing ? null : _captureAndProcess,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.camera),
                      label: Text(
                        _isProcessing ? 'Processing...' : 'Scan Passport',
                      ),
                      backgroundColor: _isProcessing
                          ? Colors.grey
                          : Colors.blue,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_statusMessage),
                ],
              ),
            ),
    );
  }
}
