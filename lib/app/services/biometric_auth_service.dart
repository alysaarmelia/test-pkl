import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricCredentials {
  BiometricCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

/// Helper to gate login behind biometrics and keep the last credentials securely.
class BiometricAuthService {
  BiometricAuthService._();
  static final BiometricAuthService _instance = BiometricAuthService._();
  factory BiometricAuthService() => _instance;

  static const String _emailKey = 'biometric_email';
  static const String _passwordKey = 'biometric_password';
  static const String _optInKey = 'biometric_opt_in';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> canUseBiometricLogin() async {
    final optedIn = await isOptInEnabled();
    if (!optedIn) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;

      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      return await hasStoredCredentials();
    } on PlatformException catch (e) {
      debugPrint('Biometric check failed: $e');
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      debugPrint('Biometric check failed: $e');
      return false;
    }
  }

  Future<bool> hasStoredCredentials() async {
    final email = await _secureStorage.read(key: _emailKey);
    final password = await _secureStorage.read(key: _passwordKey);
    return (email != null && email.isNotEmpty) &&
        (password != null && password.isNotEmpty);
  }

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    final optedIn = await isOptInEnabled();
    if (!optedIn) {
      await clearCredentials();
      return;
    }
    await _secureStorage.write(key: _emailKey, value: email.trim());
    await _secureStorage.write(key: _passwordKey, value: password);
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _passwordKey);
  }

  Future<BiometricCredentials?> authenticateAndGetCredentials({
    String reason = 'Gunakan Face ID atau Touch ID untuk login',
  }) async {
    final optedIn = await isOptInEnabled();
    if (!optedIn) return null;
    try {
      final stored = await hasStoredCredentials();
      if (!stored) return null;

      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return null;

      final didAuth = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
      if (!didAuth) return null;

      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);
      if (email == null || password == null || email.isEmpty || password.isEmpty) {
        return null;
      }
      return BiometricCredentials(email: email, password: password);
    } on PlatformException catch (e) {
      debugPrint('Biometric auth failed: $e');
      return null;
    }
  }

  Future<bool> isOptInEnabled() async {
    final value = await _secureStorage.read(key: _optInKey);
    if (value == null) return true; // default: enabled
    return value == 'true';
  }

  Future<void> setOptIn(bool enable) async {
    await _secureStorage.write(key: _optInKey, value: enable.toString());
    if (!enable) {
      await clearCredentials();
    }
  }
}
