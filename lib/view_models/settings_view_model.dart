import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../repositories/settings_repository.dart';

enum SettingsFeedbackType { success, info, warning, error, none }

class SettingsFeedback {
  const SettingsFeedback({
    required this.type,
    this.message = '',
    this.openSystemSettings = false,
  });

  final SettingsFeedbackType type;
  final String message;
  final bool openSystemSettings;

  static const none = SettingsFeedback(type: SettingsFeedbackType.none);
}

class SettingsViewModel extends GetxController {
  SettingsViewModel({
    required bool enableBiometric,
    SettingsRepository? repository,
  }) : _enableBiometric = enableBiometric,
       _repository = repository ?? SettingsRepositoryImpl();

  final bool _enableBiometric;
  final SettingsRepository _repository;

  final RxnString currentUserUid = RxnString();
  final Rxn<SettingsProfileData> profileData = Rxn<SettingsProfileData>();
  final Rxn<Object> profileError = Rxn<Object>();
  final RxnString profilePin = RxnString();
  final RxBool profileLoading = false.obs;

  final RxBool requestingNotifications = false.obs;
  final RxBool signingOut = false.obs;
  final RxBool biometricSupported = false.obs;
  final RxBool biometricOptIn = false.obs;
  final RxBool biometricBusy = false.obs;
  final RxBool biometricHasCreds = false.obs;

  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<SettingsProfileData?>? _profileSubscription;

  bool get biometricPlatformSupported {
    if (!_enableBiometric || kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  void onInit() {
    super.onInit();
    currentUserUid.value = _repository.currentUserUid;

    _authSubscription = _repository.watchAuthUserIds().listen((uid) {
      _handleAuthUserChange(uid);
    });

    _handleAuthUserChange(currentUserUid.value);

    if (biometricPlatformSupported) {
      unawaited(loadBiometricSetting());
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.onClose();
  }

  Future<SettingsFeedback> loadBiometricSetting() async {
    if (!biometricPlatformSupported) return SettingsFeedback.none;

    biometricBusy.value = true;
    try {
      final snapshot = await _repository.loadBiometricSnapshot();
      biometricSupported.value = snapshot.supported;
      biometricOptIn.value = snapshot.optIn;
      biometricHasCreds.value = snapshot.hasCredentials;
      return SettingsFeedback.none;
    } catch (_) {
      biometricSupported.value = false;
      biometricOptIn.value = false;
      biometricHasCreds.value = false;
      return const SettingsFeedback(
        type: SettingsFeedbackType.error,
        message: 'Gagal memuat status biometric.',
      );
    } finally {
      biometricBusy.value = false;
    }
  }

  Future<SettingsFeedback> toggleBiometric(bool enable) async {
    if (!biometricPlatformSupported || biometricBusy.value) {
      return SettingsFeedback.none;
    }

    biometricBusy.value = true;
    try {
      await _repository.setBiometricOptIn(enable);
      final snapshot = await _repository.loadBiometricSnapshot();
      biometricSupported.value = snapshot.supported;
      biometricOptIn.value = snapshot.optIn;
      biometricHasCreds.value = snapshot.hasCredentials;

      if (enable) {
        if (!snapshot.hasCredentials) {
          return const SettingsFeedback(
            type: SettingsFeedbackType.info,
            message:
                'Face ID aktif. Login manual sekali untuk menyimpan akses.',
          );
        }
        return const SettingsFeedback(
          type: SettingsFeedbackType.success,
          message: 'Face ID siap digunakan.',
        );
      }

      return const SettingsFeedback(
        type: SettingsFeedbackType.info,
        message: 'Face ID dinonaktifkan untuk login.',
      );
    } catch (error) {
      return SettingsFeedback(
        type: SettingsFeedbackType.error,
        message: 'Gagal memperbarui Face ID: $error',
      );
    } finally {
      biometricBusy.value = false;
    }
  }

  Future<SettingsFeedback> requestNotificationAccess() async {
    if (requestingNotifications.value) return SettingsFeedback.none;

    requestingNotifications.value = true;
    try {
      final snapshot = await _repository.requestNotificationAccess();
      if (snapshot.enabled) {
        return const SettingsFeedback(
          type: SettingsFeedbackType.success,
          message: 'Notifikasi berhasil diaktifkan.',
        );
      }

      if (snapshot.permanentlyDenied) {
        return const SettingsFeedback(
          type: SettingsFeedbackType.warning,
          message:
              'Izin notifikasi masih dinonaktifkan. Aktifkan melalui pengaturan aplikasi.',
          openSystemSettings: true,
        );
      }

      return const SettingsFeedback(
        type: SettingsFeedbackType.warning,
        message:
            'Notifikasi belum aktif. Periksa pengaturan notifikasi aplikasi.',
      );
    } catch (error) {
      return SettingsFeedback(
        type: SettingsFeedbackType.error,
        message: 'Gagal mengaktifkan notifikasi: $error',
      );
    } finally {
      requestingNotifications.value = false;
    }
  }

  Future<SettingsFeedback> logout() async {
    if (signingOut.value) return SettingsFeedback.none;

    signingOut.value = true;
    try {
      await _repository.logout();
      return const SettingsFeedback(type: SettingsFeedbackType.success);
    } catch (error) {
      return SettingsFeedback(
        type: SettingsFeedbackType.error,
        message: 'Gagal logout: $error',
      );
    } finally {
      signingOut.value = false;
    }
  }

  void _handleAuthUserChange(String? uid) {
    currentUserUid.value = uid;

    if (uid == null || uid.isEmpty) {
      _profileSubscription?.cancel();
      profileData.value = null;
      profilePin.value = null;
      profileLoading.value = false;
      profileError.value = null;
      return;
    }

    _startProfileListener(uid);
  }

  void _startProfileListener(String userId) {
    _profileSubscription?.cancel();
    profileLoading.value = true;
    profileError.value = null;

    _profileSubscription = _repository
        .watchUserProfile(userId)
        .listen(
          (data) {
            profileData.value = data;
            profilePin.value = data?.pin ?? '';
            profileLoading.value = false;
          },
          onError: (error) {
            profileError.value = error;
            profilePin.value = null;
            profileLoading.value = false;
          },
        );
  }
}
