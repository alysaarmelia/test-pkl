

import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _kCheckInAt = 'absen_checkInAt';

  static SharedPreferences? _prefs;

  static String _checkInKey(String? uid) {
    if (uid == null || uid.trim().isEmpty) return _kCheckInAt;
    return '$_kCheckInAt:$uid';
  }

  /// Panggil sekali waktu app start (misal di main.dart)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static DateTime? getCheckInAt({String? uid}) {
    final inMillis = _prefs?.getInt(_checkInKey(uid));
    return inMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(inMillis)
        : null;
  }

  static Future<void> setCheckIn(DateTime? dt, {String? uid}) async {
    if (dt != null) {
      await _prefs?.setInt(_checkInKey(uid), dt.millisecondsSinceEpoch);
    } else {
      await _prefs?.remove(_checkInKey(uid));
    }
  }

  static Future<void> clearLegacyCheckIn() async {
    await _prefs?.remove(_kCheckInAt);
  }

  // Deprecated: gunakan getCheckInAt/setCheckIn dengan uid.
  static DateTime? get checkInAt => getCheckInAt();

  static const _kIsFirstTimeRun = 'app_is_first_time_run';

  /// Returns true if it is the very first time the app is run.
  /// Defaults to true.
  static bool isFirstTimeRun() {
    return _prefs?.getBool(_kIsFirstTimeRun) ?? true;
  }

  /// Sets the first time run flag to false after onboarding is completed.
  static Future<void> setFirstTimeCompleted() async {
    await _prefs?.setBool(_kIsFirstTimeRun, false);
  }
}
