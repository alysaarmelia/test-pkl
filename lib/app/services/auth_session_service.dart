import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Simple session helper to persist and validate the last successful login time.
class AuthSessionService {
  AuthSessionService._();
  static final AuthSessionService _instance = AuthSessionService._();
  factory AuthSessionService() => _instance;

  static const Duration sessionDuration = Duration(days: 30);
  static const String _loginTimestampKey = 'auth_last_login_ms';

  Future<void> recordLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _loginTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> hasActiveSession() async {
    final expiresAt = await _calculateExpiry();
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt);
  }

  Future<Duration?> remainingTime() async {
    final expiresAt = await _calculateExpiry();
    if (expiresAt == null) return null;
    return expiresAt.difference(DateTime.now());
  }

  Future<DateTime?> _calculateExpiry() async {
    final timestamp = await _readTimestamp();
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp).add(sessionDuration);
  }

  Future<int?> _readTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_loginTimestampKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginTimestampKey);
  }
}
