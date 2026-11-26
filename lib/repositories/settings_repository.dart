import 'package:cipta_vera_mandiri_digital/app/services/auth_session_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/biometric_auth_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsBiometricSnapshot {
  const SettingsBiometricSnapshot({
    required this.supported,
    required this.optIn,
    required this.hasCredentials,
  });

  final bool supported;
  final bool optIn;
  final bool hasCredentials;
}

class SettingsNotificationSnapshot {
  const SettingsNotificationSnapshot({
    required this.enabled,
    required this.permanentlyDenied,
  });

  final bool enabled;
  final bool permanentlyDenied;
}

class SettingsProfileData {
  const SettingsProfileData({
    required this.displayName,
    required this.role,
    required this.photoUrl,
    required this.pin,
  });

  final String displayName;
  final String role;
  final String photoUrl;
  final String pin;

  factory SettingsProfileData.fromMap(Map<String, dynamic> data) {
    final displayName = _firstNonEmpty([
      data['name'],
      data['displayName'],
      data['fullName'],
      data['username'],
    ], 'Nama Tidak Ditemukan');

    final role = _firstNonEmpty([
      data['role'],
      data['team'],
      data['department'],
    ], 'Role belum ditentukan');

    final pin = _firstNonEmpty([
      data['pin'],
      data['pinUpper'],
      data['userPin'],
      data['chatPin'],
      data['PIN'],
    ], '').toUpperCase();

    return SettingsProfileData(
      displayName: displayName,
      role: role,
      photoUrl: _valueToString(data['photoUrl']),
      pin: pin,
    );
  }
}

abstract class SettingsRepository {
  String? get currentUserUid;
  Stream<String?> watchAuthUserIds();
  Stream<SettingsProfileData?> watchUserProfile(String userId);
  Future<SettingsBiometricSnapshot> loadBiometricSnapshot();
  Future<void> setBiometricOptIn(bool enabled);
  Future<SettingsNotificationSnapshot> requestNotificationAccess();
  Future<void> logout();
}

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
    BiometricAuthService? biometricService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService = notificationService ?? NotificationService(),
       _biometricService = biometricService ?? BiometricAuthService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  final BiometricAuthService _biometricService;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Stream<String?> watchAuthUserIds() {
    return _auth.userChanges().map((user) => user?.uid);
  }

  @override
  Stream<SettingsProfileData?> watchUserProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return SettingsProfileData.fromMap(data);
    });
  }

  @override
  Future<SettingsBiometricSnapshot> loadBiometricSnapshot() async {
    final supported = await _biometricService.isDeviceSupported();
    final optIn = await _biometricService.isOptInEnabled();
    final hasCredentials = await _biometricService.hasStoredCredentials();
    return SettingsBiometricSnapshot(
      supported: supported,
      optIn: optIn,
      hasCredentials: hasCredentials,
    );
  }

  @override
  Future<void> setBiometricOptIn(bool enabled) {
    return _biometricService.setOptIn(enabled);
  }

  @override
  Future<SettingsNotificationSnapshot> requestNotificationAccess() async {
    var status = await Permission.notification.status;
    if (!_isNotificationAllowed(status)) {
      status = await Permission.notification.request();
    }

    await _notificationService.init();
    final enabled = await _notificationService.areNotificationsEnabled();

    return SettingsNotificationSnapshot(
      enabled: enabled,
      permanentlyDenied: status.isPermanentlyDenied,
    );
  }

  @override
  Future<void> logout() async {
    await AuthSessionService().clearSession();
    await _auth.signOut();
  }

  bool _isNotificationAllowed(PermissionStatus status) {
    return status.isGranted ||
        status.isLimited ||
        status == PermissionStatus.provisional;
  }
}

String _valueToString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  return value.toString().trim();
}

String _firstNonEmpty(Iterable<dynamic> values, String fallback) {
  for (final value in values) {
    final str = _valueToString(value);
    if (str.isNotEmpty) return str;
  }
  return fallback;
}
