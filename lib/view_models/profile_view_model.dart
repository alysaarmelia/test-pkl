import 'package:get/get.dart';

import 'profile_model.dart';
import '../repositories/profile_repository.dart';

enum ProfileFeedbackType { success, info, error, none }

class ProfileFeedback {
  const ProfileFeedback({required this.type, this.message = ''});

  final ProfileFeedbackType type;
  final String message;

  static const none = ProfileFeedback(type: ProfileFeedbackType.none);
}

class ProfileViewModel extends GetxController {
  ProfileViewModel({ProfileRepository? repository})
    : _repository = repository ?? ProfileRepositoryImpl();

  final ProfileRepository _repository;

  final RxBool uploadingPhoto = false.obs;

  String? get currentUid => _repository.currentUid;
  bool get hasActiveSession => currentUid != null;

  Stream<ProfileData?> watchProfile(String uid) {
    return _repository.watchProfile(uid);
  }

  Future<ProfileFeedback> updateProfilePicture() async {
    if (uploadingPhoto.value) {
      return const ProfileFeedback(
        type: ProfileFeedbackType.info,
        message: 'Sedang memproses foto sebelumnya, tunggu sebentar.',
      );
    }

    final uid = currentUid;
    if (uid == null || uid.isEmpty) {
      return const ProfileFeedback(
        type: ProfileFeedbackType.error,
        message: 'Sesi berakhir. Silakan login ulang.',
      );
    }

    uploadingPhoto.value = true;
    try {
      final result = await _repository.updateProfilePhoto(uid);
      return _mapRepositoryResult(result, removePhoto: false);
    } finally {
      uploadingPhoto.value = false;
    }
  }

  Future<ProfileFeedback> removeProfilePicture() async {
    if (uploadingPhoto.value) {
      return const ProfileFeedback(
        type: ProfileFeedbackType.info,
        message: 'Sedang memproses foto sebelumnya, tunggu sebentar.',
      );
    }

    final uid = currentUid;
    if (uid == null || uid.isEmpty) {
      return const ProfileFeedback(
        type: ProfileFeedbackType.error,
        message: 'Sesi berakhir. Silakan login ulang.',
      );
    }

    uploadingPhoto.value = true;
    try {
      final result = await _repository.removeProfilePhoto(uid);
      return _mapRepositoryResult(result, removePhoto: true);
    } finally {
      uploadingPhoto.value = false;
    }
  }

  ProfileFeedback _mapRepositoryResult(
    ProfileRepositoryResult result, {
    required bool removePhoto,
  }) {
    if (result.isCancelled) {
      return ProfileFeedback.none;
    }

    if (result.isSuccess) {
      return ProfileFeedback(
        type: ProfileFeedbackType.success,
        message: removePhoto
            ? 'Foto profil dihapus.'
            : 'Foto profil berhasil diperbarui.',
      );
    }

    return switch (result.failure) {
      ProfileRepositoryFailure.galleryPermissionDenied => const ProfileFeedback(
        type: ProfileFeedbackType.error,
        message:
            'Akses galeri ditolak. Aktifkan izin foto di pengaturan aplikasi.',
      ),
      ProfileRepositoryFailure.galleryOpenFailed => const ProfileFeedback(
        type: ProfileFeedbackType.error,
        message: 'Tidak bisa membuka galeri. Coba lagi.',
      ),
      ProfileRepositoryFailure.uploadFailed => const ProfileFeedback(
        type: ProfileFeedbackType.error,
        message: 'Gagal mengunggah foto profil. Coba lagi.',
      ),
      ProfileRepositoryFailure.deleteFailed => const ProfileFeedback(
        type: ProfileFeedbackType.error,
        message: 'Gagal menghapus foto profil. Coba lagi.',
      ),
      null => ProfileFeedback(
        type: ProfileFeedbackType.error,
        message: removePhoto
            ? 'Gagal menghapus foto profil.'
            : 'Gagal memperbarui foto profil.',
      ),
    };
  }
}
