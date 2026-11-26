// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'web_authn_support_interface.dart';

class WebAuthnSupportWeb implements WebAuthnSupport {
  @override
  Future<bool> isSupported() async {
    try {
      final hasNavigator = js_util.hasProperty(html.window, 'navigator');
      if (!hasNavigator) return false;
      final navigator = html.window.navigator;
      final hasCredentials =
          js_util.hasProperty(navigator, 'credentials') &&
              navigator.credentials != null;
      return hasCredentials;
    } catch (_) {
      return false;
    }
  }
}

WebAuthnSupport getWebAuthnSupport() => WebAuthnSupportWeb();
