import 'package:cipta_vera_mandiri_digital/shared/models/leave_request.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/leave_request_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  test('submitLeave menyimpan kind cuti dan metadata span hari', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = LeaveRequestRepository(firestore: firestore);
    final start = DateTime(2024, 7, 1);
    final end = DateTime(2024, 7, 3);

    final id = await repo.submitLeave(
      uid: 'user-1',
      startDate: start,
      endDate: end,
      reason: 'Liburan',
      requesterName: 'Andi',
    );

    final doc = await firestore
        .collection(LeaveRequestRepository.collectionName)
        .doc(id)
        .get();

    expect(doc.get('uid'), 'user-1');
    expect(doc.get('kind'), 'cuti');
    expect(doc.get('daySpan'), 3);
    expect(doc.get('requesterName'), 'Andi');
    expect(doc.get('reason'), 'Liburan');
  });

  test('watchUserRequests mengurutkan createdAt desc', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = LeaveRequestRepository(firestore: firestore);
    final now = DateTime(2024, 7, 10);

    await firestore.collection(LeaveRequestRepository.collectionName).add({
      'uid': 'user-2',
      'kind': 'izin',
      'reason': 'Ke dokter',
      'startAt': Timestamp.fromDate(now),
      'endAt': Timestamp.fromDate(now),
      'status': leaveRequestStatusToString(LeaveRequestStatus.pending),
      'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      'updatedAt': Timestamp.fromDate(now),
    });
    await firestore.collection(LeaveRequestRepository.collectionName).add({
      'uid': 'user-2',
      'kind': 'cuti',
      'reason': 'Liburan',
      'startAt': Timestamp.fromDate(now),
      'endAt': Timestamp.fromDate(now.add(const Duration(days: 2))),
      'status': leaveRequestStatusToString(LeaveRequestStatus.approved),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    final items = await repo
        .watchUserRequests(uid: 'user-2')
        .first
        .timeout(const Duration(seconds: 1));

    expect(items.map((e) => e.kind).toList(), ['cuti', 'izin']);
    expect(items.first.status, LeaveRequestStatus.approved);
  });

  test('updateStatus memperbarui status dan decision metadata', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = LeaveRequestRepository(firestore: firestore);
    final docRef = await firestore
        .collection(LeaveRequestRepository.collectionName)
        .add({
          'uid': 'user-3',
          'kind': 'izin',
          'reason': 'Urusan keluarga',
          'startAt': Timestamp.now(),
          'endAt': Timestamp.now(),
          'status': leaveRequestStatusToString(LeaveRequestStatus.pending),
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

    await repo.updateStatus(
      requestId: docRef.id,
      status: LeaveRequestStatus.approved,
      decidedByUid: 'admin-1',
      decidedByName: 'Admin',
      decisionNote: 'Disetujui',
    );

    final updated = await docRef.get();
    expect(
      updated.get('status'),
      leaveRequestStatusToString(LeaveRequestStatus.approved),
    );
    expect(updated.get('decisionBy'), 'admin-1');
    expect(updated.get('decisionByName'), 'Admin');
    expect(updated.get('decisionNote'), 'Disetujui');
  });
}
