import 'dart:developer' as developer;
import 'dart:io';
// import 'dart:ui'; // Unnecessary
import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart'; // Unnecessary
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CameraHelper {
  static const String _logName = 'CameraHelper';

  static InputImage? inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
  }) {
    try {
      if (Platform.isIOS) {
        return _processIOSImage(image, sensorOrientation, deviceOrientation);
      } else if (Platform.isAndroid) {
        return _processAndroidImage(
          image,
          camera,
          sensorOrientation,
          deviceOrientation,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error converting CameraImage to InputImage',
        error: e,
        stackTrace: stackTrace,
        name: _logName,
      );
    }
    return null;
  }

  static InputImage? _processIOSImage(
    CameraImage image,
    int sensorOrientation,
    DeviceOrientation deviceOrientation,
  ) {
    try {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format != InputImageFormat.bgra8888) return null;

      final bytes = image.planes[0].bytes;

      final size = Size(image.width.toDouble(), image.height.toDouble());

      final rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;

      final inputImageMetadata = InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format!,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error processing iOS image',
        error: e,
        stackTrace: stackTrace,
        name: _logName,
      );
      return null;
    }
  }

  static InputImage? _processAndroidImage(
    CameraImage image,
    CameraDescription camera,
    int sensorOrientation,
    DeviceOrientation deviceOrientation,
  ) {
    try {
      // Determine rotation
      var rotationCompensation = sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      final rotation =
          InputImageRotationValue.fromRawValue(rotationCompensation) ??
          InputImageRotation.rotation0deg;

      // YUV420 to NV21 conversion
      // YUV_420_888 has 3 planes:
      // Plane 0: Y
      // Plane 1: U
      // Plane 2: V
      // NV21 expects: All Y bytes, followed by interleaved V and U bytes (VUVUVU...)

      if (image.planes.length != 3) {
        developer.log(
          '❌ Invalid plane count: ${image.planes.length}',
          name: _logName,
        );
        return null;
      }

      final plane0 = image.planes[0];
      final plane1 = image.planes[1];
      final plane2 = image.planes[2]; // V plane

      final int width = image.width;
      final int height = image.height;

      // Check if we need to perform conversion or if we can use bytes directly
      // Ideally we want to avoid copying if possible, but YUV_420_888 is often flexible.
      // For specific CameraX implementations, planes might be separate.

      // We construct a byte buffer for NV21
      // Total size = width * height * 1.5 (Y + UV)
      // However, strides might add padding.

      // Note: This conversion in Dart is expensive.
      // We only support the standard semi-planar structure efficiently.

      final Uint8List yBuffer = plane0.bytes;
      final Uint8List uBuffer = plane1.bytes;
      final Uint8List vBuffer = plane2.bytes;

      final int numPixels = width * height;

      // NV21 requires Y + VU interleaved.
      // The V buffer generally contains the VU data in semi-planar formats if pixelStride == 2

      final Uint8List nv21Bytes = Uint8List(numPixels + (numPixels >> 1));

      // Copy Y
      // If stride matches width, fast copy. Else row by row.
      // Assuming packed Y for strict performance now, or row-by-row for correctness.
      // To be safe and reasonably fast:

      int idUV = numPixels;

      // Helper to allow simple copy of Y
      if (plane0.bytesPerRow == width) {
        nv21Bytes.setRange(0, numPixels, yBuffer);
      } else {
        for (int i = 0; i < height; i++) {
          nv21Bytes.setRange(
            i * width,
            i * width + width,
            yBuffer.sublist(
              i * plane0.bytesPerRow,
              i * plane0.bytesPerRow + width,
            ),
          );
        }
      }

      // Interleave V and U
      // NV21 is Y...Y + V U V U...
      // In Android YUV_420_888:
      // If pixelStride is 2, and rowStride is same for U and V, and they overlap:
      // We can extract.
      // But safely:

      final int uvRowStride = plane2.bytesPerRow;
      final int uvPixelStride = plane2.bytesPerPixel ?? 1;
      final int uvWidth = width ~/ 2;
      final int uvHeight = height ~/ 2;

      for (int y = 0; y < uvHeight; y++) {
        for (int x = 0; x < uvWidth; x++) {
          final int uvIndex = y * uvRowStride + (x * uvPixelStride);

          if (uvIndex < vBuffer.length && uvIndex < uBuffer.length) {
            // V value
            nv21Bytes[idUV++] = vBuffer[uvIndex];

            // U value (often same buffer logic applies to plane1)
            nv21Bytes[idUV++] = uBuffer[uvIndex];
          }
        }
      }

      final inputImageMetadata = InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow:
            0, // Not used for NV21 in this constructor usually, or implied
      );

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: inputImageMetadata,
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error processing Android image',
        error: e,
        stackTrace: stackTrace,
        name: _logName,
      );
      return null;
    }
  }
}
