import 'package:firebase_auth/firebase_auth.dart';

import '../shared/models/attendance_record.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/attendance_history_service.dart';

abstract class AttendanceHistoryRepository {
  String? get currentUserUid;

  Future<List<AttendanceRecord>> loadRecords();

  Future<void> saveCheckInRecord({
    required DateTime date,
    required double latitude,
    required double longitude,
    String? project,
    String? note,
  });
}

class AttendanceHistoryRepositoryImpl implements AttendanceHistoryRepository {
  AttendanceHistoryRepositoryImpl({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Future<List<AttendanceRecord>> loadRecords() async {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) {
      return const <AttendanceRecord>[];
    }
    return AttendanceHistory.load(uid: uid);
  }

  @override
  Future<void> saveCheckInRecord({
    required DateTime date,
    required double latitude,
    required double longitude,
    String? project,
    String? note,
  }) {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) {
      return Future<void>.value();
    }
    return AttendanceHistory.saveRecord(
      uid: uid,
      date: date,
      checkInAt: date,
      lat: latitude,
      lon: longitude,
      project: project,
      note: note,
    );
  }
}
