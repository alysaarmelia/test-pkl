import 'dart:io';

import 'package:face_verification/face_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class AttendanceFaceVerificationService {
  bool _initialized = false;
  bool? _hasStoredFaceProfile;

  bool get isReady => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    await FaceVerification.instance.init();
    _initialized = true;
  }

  Future<bool> hasStoredFaceProfile({
    required String? userId,
    bool force = false,
  }) async {
    if (!force && _hasStoredFaceProfile != null) {
      return _hasStoredFaceProfile!;
    }
    if (!_initialized || userId == null || userId.isEmpty) {
      return false;
    }

    try {
      final List<dynamic> records =
          (await FaceVerification.instance.listRegisteredAsync())
              .cast<dynamic>();
      final exists = records.any((record) {
        if (record == null) return false;
        if (record is String) return record == userId;
        try {
          return record.id == userId;
        } catch (_) {
          return false;
        }
      });
      _hasStoredFaceProfile = exists;
      return exists;
    } catch (e, st) {
      debugPrint('Failed to check registered face profile: $e');
      debugPrintStack(stackTrace: st);
      return _hasStoredFaceProfile ?? false;
    }
  }

  Future<bool> verifyRegisteredProfile({
    required String userId,
    required String imagePath,
    double threshold = 0.70,
  }) async {
    final String? matchId = await FaceVerification.instance.verifyFromImagePath(
      imagePath: imagePath,
      threshold: threshold,
      staffId: userId,
    );
    return matchId == userId;
  }

  Future<void> registerNewProfile({
    required String userId,
    required String imagePath,
  }) async {
    await FaceVerification.instance.registerFromImagePath(
      id: userId,
      imagePath: imagePath,
      imageId: 'selfie_${DateTime.now().millisecondsSinceEpoch}',
    );
    _hasStoredFaceProfile = true;
  }

  Future<File?> normalizeCapturedFaceFile(XFile source) async {
    try {
      final bytes = await source.readAsBytes();
      final normalizedBytes = await compute(_normalizeFaceCaptureBytes, bytes);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_face.jpg',
      );
      await file.writeAsBytes(normalizedBytes, flush: true);
      return file;
    } catch (e, st) {
      debugPrint('Failed to normalize captured face: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }
}

Uint8List _normalizeFaceCaptureBytes(Uint8List bytes) {
  final img.Image? originalImage = img.decodeImage(bytes);
  if (originalImage == null) {
    throw Exception('Failed to decode captured face');
  }
  final normalized = img.encodeJpg(originalImage, quality: 95);
  return Uint8List.fromList(normalized);
}
