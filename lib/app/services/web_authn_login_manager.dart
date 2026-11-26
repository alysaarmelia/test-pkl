import 'web_authn_login_manager_interface.dart';
import 'web_authn_login_manager_stub.dart'
    if (dart.library.html) 'web_authn_login_manager_web.dart';

export 'web_authn_login_manager_interface.dart';

WebAuthnLoginManager createWebAuthnLoginManager() => getWebAuthnLoginManager();
