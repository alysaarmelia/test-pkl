import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AttendanceCameraInputConverter {
  const AttendanceCameraInputConverter._();

  static const Map<DeviceOrientation, int> _orientations =
      <DeviceOrientation, int>{
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };

  static InputImage? fromCameraImage({
    required CameraImage image,
    required CameraController controller,
  }) {
    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final DeviceOrientation deviceOrientation =
          controller.value.deviceOrientation;
      final int? rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;
      int adjusted;
      if (camera.lensDirection == CameraLensDirection.front) {
        adjusted = (sensorOrientation + rotationCompensation) % 360;
      } else {
        adjusted = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(adjusted);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null ||
        (Platform.isAndroid &&
            format != InputImageFormat.nv21 &&
            format != InputImageFormat.yuv_420_888) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      debugPrint('Unsupported image format ${image.format.raw}');
      return null;
    }

    if (Platform.isIOS) {
      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    Uint8List bytes;
    int bytesPerRow;
    InputImageFormat effectiveFormat = format;
    if (format == InputImageFormat.nv21 && image.planes.length == 1) {
      final Plane plane = image.planes.first;
      bytes = plane.bytes;
      bytesPerRow = plane.bytesPerRow;
    } else if (format == InputImageFormat.yuv_420_888 &&
        image.planes.length == 3) {
      bytes = _convertYuv420ToNv21(image);
      bytesPerRow = image.width;
      effectiveFormat = InputImageFormat.nv21;
    } else {
      debugPrint('Unsupported planes configuration for format ${image.format.raw}');
      return null;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: effectiveFormat,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  static Uint8List _convertYuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    final int ySize = width * height;
    final Uint8List nv21 = Uint8List(ySize + (width * height ~/ 2));

    int offset = 0;
    for (int row = 0; row < height; row++) {
      final int rowStart = row * planeY.bytesPerRow;
      for (int col = 0; col < width; col++) {
        nv21[offset++] = planeY.bytes[rowStart + col];
      }
    }

    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;
    final int uRowStride = planeU.bytesPerRow;
    final int vRowStride = planeV.bytesPerRow;
    final int uPixelStride = planeU.bytesPerPixel ?? 1;
    final int vPixelStride = planeV.bytesPerPixel ?? 1;

    for (int row = 0; row < uvHeight; row++) {
      final int uRowStart = row * uRowStride;
      final int vRowStart = row * vRowStride;
      for (int col = 0; col < uvWidth; col++) {
        final int uIndex = uRowStart + col * uPixelStride;
        final int vIndex = vRowStart + col * vPixelStride;
        nv21[offset++] = planeV.bytes[vIndex];
        nv21[offset++] = planeU.bytes[uIndex];
      }
    }

    return nv21;
  }
}
