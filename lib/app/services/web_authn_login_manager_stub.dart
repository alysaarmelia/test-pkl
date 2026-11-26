import 'web_authn_login_manager_interface.dart';

class WebAuthnLoginManagerStub implements WebAuthnLoginManager {
  @override
  Future<WebAuthnStoredCredentials?> authenticate() async => null;

  @override
  Future<void> clear() async {}

  @override
  Future<bool> hasPasskey() async => false;

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {}
}

WebAuthnLoginManager getWebAuthnLoginManager() => WebAuthnLoginManagerStub();
