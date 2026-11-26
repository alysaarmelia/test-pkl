import 'dart:io';

import 'package:get/get.dart';

import '../repositories/complete_profile_repository.dart';

enum CompleteProfileFeedbackType { success, info, warning, error, none }

class CompleteProfileFeedback {
  const CompleteProfileFeedback({required this.type, this.message = ''});

  final CompleteProfileFeedbackType type;
  final String message;

  static const none = CompleteProfileFeedback(
    type: CompleteProfileFeedbackType.none,
  );
}

class CompleteProfileViewModel extends GetxController {
  CompleteProfileViewModel({CompleteProfileRepository? repository})
    : _repository = repository ?? CompleteProfileRepositoryImpl();

  final CompleteProfileRepository _repository;

  String? get currentUserUid => _repository.currentUserUid;
  String? get currentUserEmail => _repository.currentUserEmail;

  Future<CompleteProfilePinResult> loadOrGeneratePin() {
    return _repository.ensureUserPin();
  }

  Future<CompleteProfileFeedback> saveProfile({
    required String name,
    required String division,
    required String pin,
    File? imageFile,
  }) async {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) {
      return const CompleteProfileFeedback(
        type: CompleteProfileFeedbackType.warning,
        message: 'Sesi pengguna tidak ditemukan. Silakan login ulang.',
      );
    }

    final normalizedDivision = division.trim();
    if (normalizedDivision.isEmpty) {
      return const CompleteProfileFeedback(
        type: CompleteProfileFeedbackType.warning,
        message: 'Divisi wajib dipilih',
      );
    }

    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _repository.uploadProfilePicture(
          image: imageFile,
          uid: uid,
        );
      }

      await _repository.saveProfile(
        CompleteProfileSaveRequest(
          uid: uid,
          name: name.trim(),
          division: normalizedDivision,
          pin: pin.trim(),
          imageUrl: imageUrl,
          email: currentUserEmail,
        ),
      );

      return const CompleteProfileFeedback(
        type: CompleteProfileFeedbackType.success,
      );
    } on CompleteProfileRepositoryException catch (error) {
      return CompleteProfileFeedback(
        type: CompleteProfileFeedbackType.error,
        message: error.message,
      );
    } catch (error) {
      return CompleteProfileFeedback(
        type: CompleteProfileFeedbackType.error,
        message: 'Terjadi kesalahan: $error',
      );
    }
  }
}
