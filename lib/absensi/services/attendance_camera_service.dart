import 'dart:io';

import 'package:camera/camera.dart';

class AttendanceCameraException implements Exception {
  const AttendanceCameraException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AttendanceCameraInitResult {
  const AttendanceCameraInitResult({
    required this.controller,
    required this.usingInfraredCamera,
  });

  final CameraController controller;
  final bool usingInfraredCamera;
}

class AttendanceCameraService {
  CameraController? _controller;
  bool _usingInfraredCamera = false;
  bool _isInitializingFaceCamera = false;
  bool _isImageStreamRunning = false;

  CameraController? get controller => _controller;
  bool get usingInfraredCamera => _usingInfraredCamera;

  Future<AttendanceCameraInitResult?> initializeFaceCamera({
    required List<CameraDescription> availableCameras,
  }) async {
    if (_isInitializingFaceCamera) return null;

    final existing = _controller;
    if (existing != null && existing.value.isInitialized) {
      return AttendanceCameraInitResult(
        controller: existing,
        usingInfraredCamera: _usingInfraredCamera,
      );
    }

    _isInitializingFaceCamera = true;
    try {
      CameraDescription? frontCamera;
      CameraDescription? trueDepthCamera;
      for (final camera in availableCameras) {
        if (camera.lensDirection != CameraLensDirection.front) continue;
        frontCamera ??= camera;
        if (Platform.isIOS) {
          final name = camera.name.toLowerCase();
          if (name.contains('truedepth') ||
              name.contains('true depth') ||
              name.contains('depth')) {
            trueDepthCamera ??= camera;
          }
        }
      }

      final CameraDescription? selectedCamera =
          trueDepthCamera ??
          frontCamera ??
          (availableCameras.isNotEmpty ? availableCameras.first : null);
      if (selectedCamera == null) {
        throw const AttendanceCameraException('Kamera depan tidak tersedia.');
      }

      final bool usingInfrared =
          Platform.isIOS &&
          trueDepthCamera != null &&
          selectedCamera == trueDepthCamera;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      try {
        await controller.initialize();
      } catch (e) {
        await controller.dispose();
        throw AttendanceCameraException('Gagal inisialisasi kamera: $e');
      }

      final previous = _controller;
      _controller = controller;
      _usingInfraredCamera = usingInfrared;
      if (previous != null && previous != controller) {
        try {
          await previous.dispose();
        } catch (_) {}
      }

      return AttendanceCameraInitResult(
        controller: controller,
        usingInfraredCamera: usingInfrared,
      );
    } finally {
      _isInitializingFaceCamera = false;
    }
  }

  Future<void> startImageStream(
    void Function(CameraImage image) onImage,
  ) async {
    final controller = _controller;
    if (controller == null || _isImageStreamRunning) return;
    try {
      await controller.startImageStream(onImage);
      _isImageStreamRunning = true;
    } catch (_) {
      _isImageStreamRunning = false;
    }
  }

  Future<void> stopImageStreamIfNeeded() async {
    final controller = _controller;
    if (controller == null || !_isImageStreamRunning) return;
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Stream may already be stopped.
    } finally {
      _isImageStreamRunning = false;
    }
  }

  Future<XFile> takeFacePicture({required bool useTorch}) async {
    final controller = _controller;
    if (controller == null) {
      throw const AttendanceCameraException('Kamera belum siap.');
    }

    bool torchActivated = false;
    try {
      if (useTorch) {
        try {
          await controller.setFlashMode(FlashMode.torch);
          torchActivated = true;
        } catch (_) {
          torchActivated = false;
        }
      }
      return await controller.takePicture();
    } finally {
      if (useTorch && torchActivated) {
        try {
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {}
      }
    }
  }

  Future<void> disposeFaceCamera() async {
    await stopImageStreamIfNeeded();
    final controller = _controller;
    _controller = null;
    _usingInfraredCamera = false;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }
}
