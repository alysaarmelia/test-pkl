import 'web_authn_support_interface.dart';

class WebAuthnSupportStub implements WebAuthnSupport {
  @override
  Future<bool> isSupported() async => false;
}

WebAuthnSupport getWebAuthnSupport() => WebAuthnSupportStub();
