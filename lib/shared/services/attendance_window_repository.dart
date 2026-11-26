import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_window.dart';

class AttendanceWindowRepository {
  AttendanceWindowRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'attendance_windows';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  static String docIdForDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  AttendanceWindow _buildAutoWindow(DateTime date) {
    return AttendanceWindow(
      date: DateTime(date.year, date.month, date.day),
      openAt: DateTime(date.year, date.month, date.day, 8, 0),
      closeAt: DateTime(date.year, date.month, date.day, 9, 30),
      lateGraceMinutes: 30,
      isDefault: true,
    );
  }

  Stream<AttendanceWindow?> watchWindow(DateTime date) {
    final docId = docIdForDate(date);
    return _collection.doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists) return _buildAutoWindow(date);
      return AttendanceWindow.fromSnapshot(snapshot);
    });
  }

  Future<AttendanceWindow?> fetchWindow(DateTime date) async {
    final docId = docIdForDate(date);
    final snapshot = await _collection.doc(docId).get();
    if (!snapshot.exists) return _buildAutoWindow(date);
    return AttendanceWindow.fromSnapshot(snapshot);
  }

  Future<void> setWindow({
    required DateTime date,
    required DateTime openAt,
    required DateTime closeAt,
    int lateGraceMinutes = 30,
  }) async {
    final docId = docIdForDate(date);
    final openDate = openAt.toLocal();
    final closeDate = closeAt.toLocal();
    await _collection.doc(docId).set({
      'openAt': Timestamp.fromDate(openDate.toUtc()),
      'closeAt': Timestamp.fromDate(closeDate.toUtc()),
      'lateGraceMinutes': lateGraceMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateTimes({
    required DateTime date,
    DateTime? openAt,
    DateTime? closeAt,
    int? lateGraceMinutes,
  }) async {
    final docId = docIdForDate(date);
    final payload = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (openAt != null) {
      payload['openAt'] = Timestamp.fromDate(openAt.toUtc());
    }
    if (closeAt != null) {
      payload['closeAt'] = Timestamp.fromDate(closeAt.toUtc());
    }
    if (lateGraceMinutes != null) {
      payload['lateGraceMinutes'] = lateGraceMinutes;
    }
    await _collection.doc(docId).set(payload, SetOptions(merge: true));
  }

  Future<void> deleteWindow(DateTime date) async {
    final docId = docIdForDate(date);
    await _collection.doc(docId).delete();
  }
}
