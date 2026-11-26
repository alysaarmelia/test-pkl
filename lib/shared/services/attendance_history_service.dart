import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_record.dart';

class AttendanceHistory {
  static const _baseKey = 'attendance_history';
  static const Duration _retention = Duration(days: 30);

  static String _keyForUid(String uid) => '${_baseKey}_$uid';

  static Future<List<AttendanceRecord>> load({required String uid}) async {
    if (uid.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUid(uid));
    if (raw == null || raw.isEmpty) return [];

    final List list = jsonDecode(raw) as List;
    final items = list
        .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final now = DateTime.now();
    final filtered = items.where((r) {
      final diff = now
          .difference(DateTime(r.date.year, r.date.month, r.date.day))
          .inDays;
      return diff <= _retention.inDays;
    }).toList();

    if (filtered.length != items.length) {
      await saveAll(uid: uid, items: filtered);
    }

    filtered.sort(
      (a, b) => (b.checkInAt ?? b.date).compareTo(a.checkInAt ?? a.date),
    );
    return filtered;
  }

  static Future<void> saveAll({
    required String uid,
    required List<AttendanceRecord> items,
  }) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyForUid(uid),
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> saveRecord({
    required String uid,
    required DateTime date,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    double? lat,
    double? lon,
    String? project,
    String? note,
  }) async {
    if (uid.isEmpty) return;

    final items = await load(uid: uid);
    final keyDay = _dayKey(date);
    final idx = items.indexWhere((r) => _dayKey(r.date) == keyDay);

    if (idx >= 0) {
      final old = items[idx];
      items[idx] = AttendanceRecord(
        date: old.date,
        checkInAt: checkInAt ?? old.checkInAt,
        checkOutAt: checkOutAt ?? old.checkOutAt,
        lat: lat ?? old.lat,
        lon: lon ?? old.lon,
        project: project ?? old.project,
        note: note ?? old.note,
      );
    } else {
      items.add(
        AttendanceRecord(
          date: date,
          checkInAt: checkInAt,
          checkOutAt: checkOutAt,
          lat: lat,
          lon: lon,
          project: project,
          note: note,
        ),
      );
    }

    await saveAll(uid: uid, items: items);
  }

  static Future<void> clearAll({required String uid}) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyForUid(uid));
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
