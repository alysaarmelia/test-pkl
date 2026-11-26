import 'package:cipta_vera_mandiri_digital/shared/models/attendance_window.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/attendance_window_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  test('setWindow + fetchWindow menyimpan jadwal absensi', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = AttendanceWindowRepository(firestore: firestore);
    final date = DateTime(2024, 7, 10);
    final open = DateTime(2024, 7, 10, 8, 0);
    final close = DateTime(2024, 7, 10, 17, 0);

    await repo.setWindow(
      date: date,
      openAt: open,
      closeAt: close,
      lateGraceMinutes: 15,
    );

    final fetched = await repo.fetchWindow(date);
    expect(fetched, isNotNull);
    expect(fetched!.date.year, 2024);
    expect(fetched.openAt.hour, 8);
    expect(fetched.closeAt.hour, 17);
    expect(fetched.lateGraceMinutes, 15);
  });

  test('watchWindow memetakan snapshot menjadi AttendanceWindow', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = AttendanceWindowRepository(firestore: firestore);
    final date = DateTime(2024, 8, 1);
    final docId = AttendanceWindowRepository.docIdForDate(date);

    await firestore
        .collection(AttendanceWindowRepository.collectionName)
        .doc(docId)
        .set({
          'openAt': Timestamp.fromDate(DateTime(2024, 8, 1, 7, 0)),
          'closeAt': Timestamp.fromDate(DateTime(2024, 8, 1, 15, 0)),
          'lateGraceMinutes': 10,
        });

    final window = await repo
        .watchWindow(date)
        .first
        .timeout(const Duration(seconds: 1));

    expect(window, isNotNull);
    expect(window!.openAt.hour, 7);
    expect(window.closeAt.hour, 15);
    expect(window.lateGraceMinutes, 10);
    expect(window.isConfigured, isTrue);
  });

  test('updateTimes memperbarui jam buka/tutup dan grace period', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = AttendanceWindowRepository(firestore: firestore);
    final date = DateTime(2024, 9, 5);
    final docId = AttendanceWindowRepository.docIdForDate(date);
    await firestore
        .collection(AttendanceWindowRepository.collectionName)
        .doc(docId)
        .set({
          'openAt': Timestamp.fromDate(DateTime(2024, 9, 5, 9, 0)),
          'closeAt': Timestamp.fromDate(DateTime(2024, 9, 5, 18, 0)),
          'lateGraceMinutes': 20,
        });

    await repo.updateTimes(
      date: date,
      openAt: DateTime(2024, 9, 5, 8, 30),
      closeAt: DateTime(2024, 9, 5, 17, 30),
      lateGraceMinutes: 5,
    );

    final snapshot = await firestore
        .collection(AttendanceWindowRepository.collectionName)
        .doc(docId)
        .get();
    final window = AttendanceWindow.fromSnapshot(snapshot);
    expect(window.openAt.hour, 8);
    expect(window.openAt.minute, 30);
    expect(window.closeAt.hour, 17);
    expect(window.closeAt.minute, 30);
    expect(window.lateGraceMinutes, 5);
  });

  test(
    'model AttendanceWindow isWithinWindow/isLate bekerja sesuai jadwal',
    () {
      final date = DateTime(2024, 10, 1);
      final window = AttendanceWindow(
        date: date,
        openAt: DateTime(2024, 10, 1, 8, 0),
        closeAt: DateTime(2024, 10, 1, 17, 0),
        lateGraceMinutes: 15,
      );

      expect(window.isBeforeOpen(DateTime(2024, 10, 1, 7, 59)), isTrue);
      expect(window.isWithinWindow(DateTime(2024, 10, 1, 8, 0)), isTrue);
      expect(window.isWithinWindow(DateTime(2024, 10, 1, 17, 10)), isTrue);
      expect(window.isLate(DateTime(2024, 10, 1, 17, 5)), isTrue);
      expect(window.isAfterClose(DateTime(2024, 10, 1, 17, 20)), isTrue);
      expect(window.isWithinWindow(DateTime(2024, 10, 1, 18, 0)), isFalse);
    },
  );
}
