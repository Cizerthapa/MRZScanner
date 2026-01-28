import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mrzreader/main.dart';
import 'package:mrzreader/model/passport_data.dart';
import 'package:mrzreader/service/mrz_parser.dart';
import 'package:mrzreader/screen/passport_form_screen.dart';
import 'package:mrzreader/util/camera_helper.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';

enum ScanMode { live, photo }

class MRZScannerScreen extends StatefulWidget {
  final ScanMode scanMode;

  const MRZScannerScreen({super.key, this.scanMode = ScanMode.live});

  @override
  State<MRZScannerScreen> createState() => _MRZScannerScreenState();
}

class _MRZScannerScreenState extends State<MRZScannerScreen>
    with WidgetsBindingObserver {
  static const String _logName = 'mrzreader.scanner';
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  bool _isInitialized = false;
  String _statusMessage = 'Initializing camera...';
  int _frameCount = 0;
  int _lastLoggedFrame = 0;
  DateTime? _lastProcessingTime;
  List<String> _lastMRZAttempts = [];
  // ignore: unused_field
  String? _lastRawText;

  @override
  void initState() {
    super.initState();
    developer.log('MRZScannerScreen initState called', name: _logName);
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    developer.log('Starting camera initialization...', name: _logName);

    try {
      if (cameras.isEmpty) {
        developer.log(
          '⚠️ No cameras available in camera list',
          name: _logName,
          level: 900,
        );
        setState(() {
          _statusMessage = 'No cameras available';
        });
        return;
      }

      developer.log('Found ${cameras.length} camera(s)', name: _logName);
      for (var i = 0; i < cameras.length; i++) {
        developer.log(
          'Camera $i: ${cameras[i].name} (${cameras[i].lensDirection.name}) - ',
          name: _logName,
        );
      }

      final selectedCamera = cameras[0];
      developer.log(
        'Selected camera: ${selectedCamera.name} (${selectedCamera.lensDirection.name})',
        name: _logName,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      developer.log(
        'CameraController created, starting initialization...',
        name: _logName,
      );

      await _cameraController!
          .initialize()
          .then((_) {
            developer.log(
              '✅ Camera controller initialized successfully',
              name: _logName,
            );

            return _cameraController!.setExposureMode(ExposureMode.auto);
          })
          .then((_) {
            developer.log('✅ Exposure mode set to auto', name: _logName);

            return _cameraController!.setFocusMode(FocusMode.auto);
          })
          .then((_) {
            developer.log('✅ Focus mode set to auto', name: _logName);
          });

      final cameraValue = _cameraController!.value;
      developer.log(
        'Camera properties:\n'
        '  - Resolution: ${cameraValue.previewSize?.width}x${cameraValue.previewSize?.height}\n'
        '  - Is streaming: ${cameraValue.isStreamingImages}\n'
        '  - Exposure mode: ${cameraValue.exposureMode.name}\n'
        '  - Focus mode: ${cameraValue.focusMode.name}\n'
        '  - Sensor orientation: ${cameraValue.deviceOrientation}',
        name: _logName,
      );

      developer.log('✅ Camera fully initialized', name: _logName);

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Tap "START SCAN" to read passport';
      });

      // _startScanning(); // Don't start automatically
      if (widget.scanMode == ScanMode.live) {
        _startScanning();
      }
    } on CameraException catch (e) {
      developer.log(
        '❌ CameraException during initialization:',
        error: e,
        name: _logName,
        level: 1000,
      );
      developer.log('  Code: ${e.code}', name: _logName);
      developer.log('  Description: ${e.description}', name: _logName);
      setState(() {
        _statusMessage = 'Camera error: ${e.code}';
      });
    } catch (e, stackTrace) {
      developer.log(
        '❌ Unexpected error during camera initialization:',
        error: e,
        name: _logName,
        level: 1000,
      );
      developer.log('Stack trace: $stackTrace', name: _logName);
      setState(() {
        _statusMessage = 'Initialization failed: ${e.toString()}';
      });
    }
  }

  void _startScanning() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      developer.log(
        'Cannot start scanning: Camera not initialized',
        name: _logName,
      );
      return;
    }

    if (_cameraController!.value.isStreamingImages) {
      developer.log('Camera already streaming', name: _logName);
      return;
    }

    try {
      developer.log('🚀 Starting camera image stream...', name: _logName);
      _cameraController!.startImageStream(_processFrame);
      _frameCount = 0;
      _lastLoggedFrame = 0;
      developer.log('✅ Camera stream started successfully', name: _logName);

      // Auto-stop after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _cameraController!.value.isStreamingImages) {
          developer.log(
            '⏰ Scan timeout reached (3s) - stopping scan',
            name: _logName,
          );
          _stopScanning();
          setState(() {
            _statusMessage = 'Scan timed out. Tap to try again.';
          });
        }
      });
    } on CameraException catch (e) {
      developer.log(
        '❌ CameraException starting image stream:',
        error: e,
        name: _logName,
        level: 1000,
      );
      setState(() {
        _statusMessage = 'Stream error: ${e.code}';
      });
    } catch (e, stackTrace) {
      developer.log(
        '❌ Unexpected error starting image stream:',
        error: e,
        name: _logName,
        level: 1000,
      );
      developer.log('Stack trace: $stackTrace', name: _logName);
    }
  }

  Future<void> _stopScanning() async {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      developer.log('🛑 Stopping camera image stream...', name: _logName);
      await _cameraController!.stopImageStream();
      developer.log('✅ Camera stream stopped', name: _logName);

      // Log scanning statistics
      developer.log(
        '📊 Scanning Statistics:\n'
        '  - Total frames processed: $_frameCount\n'
        '  - Last processing time: ${_lastProcessingTime?.toIso8601String() ?? "N/A"}\n'
        '  - Last MRZ attempts: ${_lastMRZAttempts.length}\n'
        '  - Is processing flag: $_isProcessing',
        name: _logName,
      );
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    _frameCount++;

    // Log frame count every 30 frames
    if (_frameCount - _lastLoggedFrame >= 30) {
      developer.log(
        '📸 Processing frame $_frameCount '
        '(Image format: ${image.format.group.name}, '
        'Size: ${image.width}x${image.height}, '
        'Planes: ${image.planes.length})',
        name: _logName,
      );
      _lastLoggedFrame = _frameCount;
    }

    if (_isProcessing) {
      if (_frameCount % 10 == 0) {
        developer.log(
          '⏳ Skipping frame $_frameCount - still processing previous frame',
          name: _logName,
        );
      }
      return;
    }

    if (!mounted) {
      developer.log('⚠️ Skipping frame - widget not mounted', name: _logName);
      return;
    }

    // Double check mode
    if (widget.scanMode == ScanMode.photo) {
      return;
    }

    _isProcessing = true;
    final startTime = DateTime.now();
    _lastProcessingTime = startTime;

    try {
      developer.log('🔄 Frame $_frameCount processing started', name: _logName);

      // Convert CameraImage to InputImage
      final inputImage = CameraHelper.inputImageFromCameraImage(
        image: image,
        camera: cameras[0],
        sensorOrientation: cameras[0].sensorOrientation,
        deviceOrientation: DeviceOrientation.portraitUp,
      );

      if (inputImage == null) {
        developer.log(
          '⚠️ InputImage conversion failed for frame $_frameCount',
          name: _logName,
        );
        _isProcessing = false;
        return;
      }

      developer.log(
        '✅ InputImage created: ',
        //${inputImage.bitmapData}x',
        // 'type: ${inputImage.type}'
        // 'rotation: ${inputImage.rotation}'
        // 'bytes: ${inputImage.bytes}'
        // 'metadata: ${inputImage.metadata}',
        name: _logName,
      );

      // Perform text recognition
      developer.log('🔍 Starting text recognition...', name: _logName);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      final processingTime = DateTime.now().difference(startTime);
      developer.log(
        '✅ Text recognition completed in ${processingTime.inMilliseconds}ms\n'
        '   Blocks: ${recognizedText.blocks.length}\n'
        '   Text length: ${recognizedText.text.length}',
        name: _logName,
      );

      // Store raw text for debugging
      _lastRawText = recognizedText.text;
      if (recognizedText.text.isNotEmpty && _frameCount % 20 == 0) {
        developer.log(
          '📝 Raw recognized text (sample):\n'
          '${recognizedText.text.substring(0, min(200, recognizedText.text.length))}${recognizedText.text.length > 200 ? '...' : ''}',
          name: _logName,
        );
      }

      // Extract potential MRZ lines
      List<String> mrzLines = _extractMRZLines(recognizedText.text);
      _lastMRZAttempts = mrzLines;

      if (mrzLines.isNotEmpty) {
        developer.log(
          '🎯 Found ${mrzLines.length} potential MRZ line(s):',
          name: _logName,
        );
        for (var i = 0; i < mrzLines.length; i++) {
          developer.log(
            '  Line $i (${mrzLines[i].length} chars): ${mrzLines[i]}',
            name: _logName,
          );
        }

        if (mrzLines.length >= 2) {
          developer.log('📋 Attempting to parse MRZ lines...', name: _logName);
          PassportData? passportData = MRZParser.parse(mrzLines);

          if (passportData != null) {
            final totalTime = DateTime.now().difference(startTime);
            developer.log(
              '✅✅✅ MRZ PARSED SUCCESSFULLY! 🎉\n'
              '   Total processing time: ${totalTime.inMilliseconds}ms\n'
              '   Document number: ${passportData.passportNumber}\n'
              '   Name: ${passportData.givenNames}\n'
              '   Nationality: ${passportData.nationality}\n'
              '   Date of birth: ${passportData.dateOfBirth}\n'
              '   Gender: ${passportData.sex}',
              name: _logName,
            );

            _stopScanning();

            if (mounted) {
              developer.log(
                '🚀 Navigating to PassportFormScreen',
                name: _logName,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PassportFormScreen(passportData: passportData),
                ),
              ).then((_) {
                developer.log(
                  '↩️ Returned from PassportFormScreen',
                  name: _logName,
                );
                if (mounted) {
                  _isProcessing = false;
                  _startScanning();
                }
              });
            }
            return;
          } else {
            developer.log(
              '❌ MRZ parsing failed - invalid format',
              name: _logName,
            );
            if (widget.scanMode == ScanMode.photo) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No valid MRZ data found in photo'),
                  ),
                );
              }
            }
          }
        } else {
          if (widget.scanMode == ScanMode.photo) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No MRZ lines detected in photo')),
              );
            }
          }
          if (_frameCount % 25 == 0) {
            developer.log(
              '🔍 Need at least 2 MRZ lines, found ${mrzLines.length}',
              name: _logName,
            );
          }
        }
      } else {
        if (_frameCount % 50 == 0) {
          developer.log(
            '🔍 No MRZ lines detected in frame $_frameCount',
            name: _logName,
          );
        }
      }

      // Add throttling delay between frames
      final delay = const Duration(milliseconds: 300);
      developer.log(
        '⏱️ Adding ${delay.inMilliseconds}ms delay before next frame',
        name: _logName,
      );
      await Future.delayed(delay);
    } on PlatformException catch (e) {
      developer.log(
        '❌ PlatformException during frame processing:',
        error: e,
        name: _logName,
        level: 1000,
      );
      developer.log('Code: ${e.code}', name: _logName);
      developer.log('Message: ${e.message}', name: _logName);
      developer.log('Details: ${e.details}', name: _logName);
    } catch (e, stackTrace) {
      developer.log(
        '❌ Unexpected error during frame processing:',
        error: e,
        name: _logName,
        level: 1000,
      );
      developer.log('Stack trace: $stackTrace', name: _logName);

      // Add error recovery delay
      await Future.delayed(const Duration(seconds: 1));
    } finally {
      if (mounted) {
        _isProcessing = false;
        final totalTime = DateTime.now().difference(startTime);
        if (_frameCount % 15 == 0) {
          developer.log(
            '🏁 Frame $_frameCount processing completed in ${totalTime.inMilliseconds}ms',
            name: _logName,
          );
        }
      } else {
        developer.log(
          '⚠️ Frame processing completed but widget not mounted',
          name: _logName,
        );
      }
    }
  }

  Future<void> _takePictureAndScan() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing photo...';
    });

    try {
      final XFile file = await _cameraController!.takePicture();

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Cropping photo...';
      });

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop MRZ Zone',
            toolbarColor: Colors.blueAccent,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop MRZ Zone',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) {
        developer.log('Cropping cancelled', name: _logName);
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Capture cancelled';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Processing photo...';
      });

      final inputImage = InputImage.fromFilePath(croppedFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Reuse the existing extraction and parsing logic
      _processRecognizedText(recognizedText);
    } catch (e) {
      developer.log('Error taking picture', error: e, name: _logName);
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          // Restore default message
          if (_cameraController != null &&
              _cameraController!.value.isInitialized) {
            _statusMessage = widget.scanMode == ScanMode.live
                ? 'Tap "START SCAN" to read'
                : 'Tap "CAPTURE" to take photo';
          }
        });
      }
    }
  }

  // Extracted from original _processFrame to be reused
  Future<void> _processRecognizedText(RecognizedText recognizedText) async {
    // Extract potential MRZ lines
    List<String> mrzLines = _extractMRZLines(recognizedText.text);
    _lastMRZAttempts = mrzLines;

    if (mrzLines.isNotEmpty) {
      if (mrzLines.length >= 2) {
        PassportData? passportData = MRZParser.parse(mrzLines);

        if (passportData != null) {
          _stopScanning();

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PassportFormScreen(passportData: passportData),
              ),
            ).then((_) {
              if (mounted && widget.scanMode == ScanMode.live) {
                _isProcessing = false;
                _startScanning();
              }
            });
          }
          return;
        } else {
          // ... parsing failed
          if (widget.scanMode == ScanMode.photo && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('No valid MRZ found')));
          }
        }
      }
    } else {
      if (widget.scanMode == ScanMode.photo && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No text detected')));
      }
    }
  }

  List<String> _extractMRZLines(String text) {
    try {
      final lines = text.split('\n');
      final mrzLines = <String>[];

      developer.log(
        '📄 Extracting MRZ lines from ${lines.length} text lines',
        name: _logName,
      );

      for (var i = 0; i < lines.length; i++) {
        final originalLine = lines[i];
        try {
          final cleaned = originalLine
              .replaceAll(' ', '')
              .replaceAll('.', '')
              .replaceAll(',', '')
              .replaceAll(';', '')
              .toUpperCase()
              .trim();

          if (cleaned.isEmpty) continue;

          final length = cleaned.length;
          final looksLikeMRZ = _looksLikeMRZ(cleaned);

          // Relaxed length requirements - allow ±3 characters for OCR errors
          if (looksLikeMRZ && length >= 27) {
            // Changed from strict 30/36/44
            developer.log(
              '✅ Line $i qualifies as MRZ: $cleaned (Length: $length)',
              name: _logName,
            );
            mrzLines.add(cleaned);
          } else {
            if (length >= 25 && _frameCount % 40 == 0) {
              developer.log(
                '❌ Line $i rejected as MRZ:\n'
                '   Original: "$originalLine"\n'
                '   Cleaned: "$cleaned"\n'
                '   Length: $length, LooksLikeMRZ: $looksLikeMRZ',
                name: _logName,
              );
            }
          }
        } catch (e) {
          developer.log(
            '⚠️ Error processing line $i',
            error: e,
            name: _logName,
          );
          continue;
        }
      }

      return mrzLines;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error extracting MRZ lines',
        error: e,
        stackTrace: stackTrace,
        name: _logName,
      );
      return [];
    }
  }

  bool _looksLikeMRZ(String line) {
    try {
      if (line.isEmpty) return false;

      // MRZ contains A-Z, 0-9, and < characters
      final mrzPattern = RegExp(r'^[A-Z0-9<]+$');
      if (!mrzPattern.hasMatch(line)) {
        return false;
      }

      // Count specific characters
      final angleCount = '<'.allMatches(line).length;
      final digitCount = RegExp(r'[0-9]').allMatches(line).length;
      final letterCount = RegExp(r'[A-Z]').allMatches(line).length;

      // Calculate ratios
      final totalChars = line.length;
      final digitRatio = digitCount / totalChars;
      final letterRatio = letterCount / totalChars;

      // Typical MRZ characteristics - RELAXED RULES:
      final hasAngles = angleCount >= 1; // Changed from 2 to 1
      final hasReasonableMix =
          digitRatio > 0.05 && letterRatio > 0.2; // More lenient
      final startsWithDocType =
          line.startsWith('P<') ||
          line.startsWith('PB') || // Added - your passport shows "PB"
          line.startsWith('V<') ||
          line.startsWith('I<') ||
          line.startsWith('A<');

      // Accept if EITHER has document type OR has good characteristics
      final isLikelyMRZ =
          hasAngles &&
          (hasReasonableMix || startsWithDocType || angleCount >= 3);

      if (_frameCount % 50 == 0 && line.length >= 25) {
        developer.log(
          '🔬 MRZ analysis for "$line":\n'
          '   Length: $totalChars\n'
          '   Angle chars: $angleCount\n'
          '   Digits: $digitCount (${(digitRatio * 100).toStringAsFixed(1)}%)\n'
          '   Letters: $letterCount (${(letterRatio * 100).toStringAsFixed(1)}%)\n'
          '   Starts with doc type: $startsWithDocType\n'
          '   Has angles: $hasAngles\n'
          '   Has reasonable mix: $hasReasonableMix\n'
          '   Final verdict: $isLikelyMRZ',
          name: _logName,
        );
      }

      return isLikelyMRZ;
    } catch (e) {
      developer.log('⚠️ Error analyzing MRZ pattern', error: e, name: _logName);
      return false;
    }
  }

  @override
  void dispose() {
    developer.log('🧹 MRZScannerScreen dispose() called', name: _logName);

    WidgetsBinding.instance.removeObserver(this);

    _stopScanning();

    if (_cameraController != null) {
      developer.log('Disposing camera controller...', name: _logName);
      _cameraController!.dispose();
    }

    developer.log('Closing text recognizer...', name: _logName);
    _textRecognizer.close();

    // Log final statistics
    developer.log(
      '📊 FINAL STATISTICS:\n'
      '  - Total frames processed: $_frameCount\n'
      '  - Is initialized: $_isInitialized\n'
      '  - Is processing: $_isProcessing\n'
      '  - Last status: $_statusMessage',
      name: _logName,
    );

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('📱 App lifecycle state changed: $state', name: _logName);

    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      developer.log(
        '⚠️ Lifecycle change ignored - camera not initialized',
        name: _logName,
      );
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
        developer.log('🔄 App inactive - disposing camera', name: _logName);
        _stopScanning();
        cameraController.dispose();
        setState(() {
          _isInitialized = false;
          _statusMessage = 'Camera inactive';
        });
        break;

      case AppLifecycleState.resumed:
        developer.log('🔄 App resumed - reinitializing camera', name: _logName);
        setState(() {
          _statusMessage = 'Reinitializing camera...';
        });
        _initializeCamera();
        break;

      case AppLifecycleState.paused:
        developer.log('🔄 App paused - stopping scanning', name: _logName);
        _stopScanning();
        break;

      case AppLifecycleState.detached:
        developer.log('🔄 App detached', name: _logName);
        break;

      case AppLifecycleState.hidden:
        developer.log('🔄 App hidden', name: _logName);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    developer.log('🏗️ Building MRZScannerScreen UI', name: _logName);

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
                        child: Column(
                          children: [
                            Text(
                              _statusMessage.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Frame: $_frameCount | Processing: $_isProcessing',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
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
                            onPressed: () async {
                              developer.log(
                                'Manual scan button pressed',
                                name: _logName,
                              );
                              if (!_isProcessing) {
                                if (widget.scanMode == ScanMode.live) {
                                  await _stopScanning();
                                  _startScanning();
                                } else {
                                  _takePictureAndScan();
                                }
                              }
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent.withAlpha(63),
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
                                : const Icon(Icons.camera_alt, size: 20),
                            label: Text(
                              _isProcessing
                                  ? 'PROCESSING...'
                                  : (widget.scanMode == ScanMode.live
                                        ? 'START SCAN'
                                        : 'CAPTURE'),
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
                    const SizedBox(height: 16),
                    if (_frameCount > 0)
                      Text(
                        'Frames processed: $_frameCount',
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTechOverlay() {
    return const ScannerOverlay();
  }
}

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
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
                  height: 320,
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
            height: 320,
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
