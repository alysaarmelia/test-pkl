import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:face_verification/face_verification.dart'; // Import the new package

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<void> init() async {
    await FaceVerification.instance.init();
  }

 
  Future<bool> registerFace({required String imagePath}) async {
    try {
      await FaceVerification.instance.registerFromImagePath(
        id: 'user_face',
        imagePath: imagePath,
        imageId: 'selfie_${DateTime.now().millisecondsSinceEpoch}',
      );
      return true;
    } catch (e) {
      print('Error registering face: $e');
      return false;
    }
  }

  Future<bool> verifyFace() async {
    try {

      final hasRecord = await hasRegisteredFace();
      if (!hasRecord) {
        print('No registered face found for verification.');
        return false;
      }

      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return false; // User cancelled

      final String? matchId = await FaceVerification.instance.verifyFromImagePath(
        imagePath: image.path,
        threshold: 0.70, 
        staffId: 'user_face', 
      );

      return matchId == 'user_face';
    } catch (e) {
      print('Error verifying face: $e');
      return false;
    }
  }

  /// Returns true if the special id `user_face` exists in local storage.
  Future<bool> hasRegisteredFace() async {
    try {
      final records = await FaceVerification.instance.listRegisteredAsync();
      // The API returns a list of records. Support both string ids and object with `id`.
      for (final r in records) {
        if (r is String && r == 'user_face') return true;
        try {
          final dynamic dyn = r;
          if (dyn != null && dyn.id == 'user_face') return true;
        } catch (_) {/* ignore and continue */}
      }
      return false;
    } catch (e) {
      print('Error checking registered faces: $e');
      return false;
    }
  }
}