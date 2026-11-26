class WebAuthnStoredCredentials {
  WebAuthnStoredCredentials({required this.email, required this.password});
  final String email;
  final String password;
}

abstract class WebAuthnLoginManager {
  Future<bool> isSupported();
  Future<bool> hasPasskey();
  Future<void> saveCredentials({
    required String email,
    required String password,
  });
  Future<WebAuthnStoredCredentials?> authenticate();
  Future<void> clear();
}
