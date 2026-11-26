import 'dart:convert';

import 'package:cipta_vera_mandiri_digital/shared/models/attendance_record.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/attendance_history_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AttendanceRecord toJson/fromJson roundtrip', () {
    final record = AttendanceRecord(
      date: DateTime(2024, 7, 2),
      checkInAt: DateTime(2024, 7, 2, 8, 30),
      checkOutAt: DateTime(2024, 7, 2, 17, 15),
      lat: -6.2,
      lon: 106.8,
      project: 'Site A',
      note: 'On time',
    );

    final encoded = jsonEncode(record.toJson());
    final decoded = AttendanceRecord.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );

    expect(decoded.date.year, 2024);
    expect(decoded.checkInAt?.hour, 8);
    expect(decoded.checkOutAt?.hour, 17);
    expect(decoded.project, 'Site A');
    expect(decoded.note, 'On time');
  });

  test('AttendanceHistory save/load/merge per hari', () async {
    SharedPreferences.setMockInitialValues({});
    const uid = 'user-xyz';

    final date = DateTime.now();
    await AttendanceHistory.saveRecord(
      uid: uid,
      date: date,
      checkInAt: DateTime(2024, 7, 3, 8, 0),
      lat: -6.2,
      lon: 106.8,
      project: 'Site B',
    );
    await AttendanceHistory.saveRecord(
      uid: uid,
      date: date,
      checkOutAt: DateTime(2024, 7, 3, 17, 0),
      note: 'Pulang tepat waktu',
    );

    final loaded = await AttendanceHistory.load(uid: uid);
    expect(loaded.length, 1);
    final rec = loaded.first;
    expect(rec.checkInAt?.hour, 8);
    expect(rec.checkOutAt?.hour, 17);
    expect(rec.project, 'Site B');
    expect(rec.note, 'Pulang tepat waktu');
  });
}
