import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mrzreader/screen/mrz_scanner_app.dart';
import 'dart:developer' as developer;

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
