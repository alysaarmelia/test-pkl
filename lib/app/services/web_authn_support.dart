import 'web_authn_support_interface.dart';
import 'web_authn_support_stub.dart'
    if (dart.library.html) 'web_authn_support_web.dart';

export 'web_authn_support_interface.dart';

WebAuthnSupport createWebAuthnSupport() => getWebAuthnSupport();
