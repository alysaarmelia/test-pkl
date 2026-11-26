// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:js_util' as js_util;

import 'web_authn_login_manager_interface.dart';
import 'web_authn_support.dart';

class WebAuthnLoginManagerWeb implements WebAuthnLoginManager {
  static const String _keyPasskeyId = 'admin_passkey_id';
  static const String _keyEmail = 'admin_passkey_email';
  static const String _keyPassword = 'admin_passkey_password';

  final WebAuthnSupport _support = createWebAuthnSupport();
  final html.Storage _storage = html.window.localStorage;

  @override
  Future<bool> isSupported() => _support.isSupported();

  @override
  Future<bool> hasPasskey() async {
    final supported = await isSupported();
    if (!supported) return false;
    return _storage[_keyPasskeyId] != null &&
        _storage[_keyEmail] != null &&
        _storage[_keyPassword] != null;
  }

  @override
  Future<void> clear() async {
    _storage.remove(_keyPasskeyId);
    _storage.remove(_keyEmail);
    _storage.remove(_keyPassword);
  }

  @override
  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    final supported = await isSupported();
    if (!supported) return;

    final passkeyId = await _registerPasskey(email);
    if (passkeyId == null) return;

    _storage[_keyPasskeyId] = passkeyId;
    _storage[_keyEmail] = email;
    _storage[_keyPassword] = password;
  }

  @override
  Future<WebAuthnStoredCredentials?> authenticate() async {
    final supported = await isSupported();
    if (!supported) return null;

    final id = _storage[_keyPasskeyId];
    final email = _storage[_keyEmail];
    final password = _storage[_keyPassword];
    if (id == null || email == null || password == null) return null;

    final credId = _decodeBase64(id);
    if (credId == null) return null;

    final ok = await _authenticateWithPasskey(credId);
    if (!ok) return null;

    return WebAuthnStoredCredentials(email: email, password: password);
  }

  Future<String?> _registerPasskey(String email) async {
    try {
      final challenge = _randomBytes(32);
      final userId = Uint8List.fromList(utf8.encode(email));
      final host = html.window.location.hostname;
      final rpId = (host != null && host.isNotEmpty) ? host : 'localhost';
      final options = {
        'publicKey': {
          'challenge': challenge,
          'rp': {'name': 'CVMD Admin Portal', 'id': rpId},
          'user': {'id': userId, 'name': email, 'displayName': email},
          'pubKeyCredParams': [
            {'type': 'public-key', 'alg': -7},
            {'type': 'public-key', 'alg': -257},
          ],
          'authenticatorSelection': {
            'authenticatorAttachment': 'platform',
            'residentKey': 'preferred',
            'userVerification': 'preferred',
          },
          'timeout': 60000,
        },
      };

      final credentials = js_util.getProperty(
        html.window.navigator,
        'credentials',
      );
      final credential = await js_util.promiseToFuture<Object?>(
        js_util.callMethod(credentials, 'create', [js_util.jsify(options)]),
      );
      if (credential == null) return null;

      final rawId = js_util.getProperty(credential, 'rawId');
      if (rawId is ByteBuffer) {
        return base64UrlEncode(Uint8List.view(rawId));
      }
      final id = js_util.getProperty(credential, 'id');
      if (id is String) return id;
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _authenticateWithPasskey(Uint8List credentialId) async {
    try {
      final challenge = _randomBytes(32);
      final host = html.window.location.hostname;
      final rpId = (host != null && host.isNotEmpty) ? host : 'localhost';
      final options = {
        'publicKey': {
          'challenge': challenge,
          'rpId': rpId,
          'allowCredentials': [
            {
              'type': 'public-key',
              'id': credentialId,
              'transports': ['internal'],
            },
          ],
          'userVerification': 'preferred',
          'timeout': 60000,
        },
      };
      final credentials = js_util.getProperty(
        html.window.navigator,
        'credentials',
      );
      final assertion = await js_util.promiseToFuture<Object?>(
        js_util.callMethod(credentials, 'get', [js_util.jsify(options)]),
      );
      return assertion != null;
    } catch (_) {
      return false;
    }
  }

  Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rand.nextInt(256)),
    );
  }

  Uint8List? _decodeBase64(String value) {
    try {
      return base64Url.decode(value);
    } catch (_) {
      return null;
    }
  }
}

WebAuthnLoginManager getWebAuthnLoginManager() => WebAuthnLoginManagerWeb();
