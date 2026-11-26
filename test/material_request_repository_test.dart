import 'package:cipta_vera_mandiri_digital/shared/models/material_request.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/material_request_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  Map<String, dynamic> _baseRequest({
    required DateTime createdAt,
    String requesterUid = 'req-1',
    String status = MaterialRequestStatus.pending,
  }) {
    return {
      'companyName': 'PT CVM',
      'projectName': 'Proyek A',
      'requestDate': Timestamp.fromDate(createdAt),
      'requesterName': 'Andi',
      'requesterUid': requesterUid,
      'approverName': '',
      'items': [
        {'no': 1, 'name': 'Semen', 'quantity': '10', 'status': 'pending'},
      ],
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(createdAt),
    };
  }

  test('watchRequestsByRequester mengurutkan terbaru dahulu', () async {
    final firestore = FakeFirebaseFirestore();
    final storage = FirebaseStorage.instanceFor(bucket: 'test-bucket');
    final repo = MaterialRequestRepository(
      firestore: firestore,
      storage: storage,
    );
    await firestore
        .collection(MaterialRequestRepository.collectionName)
        .add(
          _baseRequest(
            createdAt: DateTime(2024, 7, 1),
            requesterUid: 'user-1',
            status: MaterialRequestStatus.pending,
          ),
        );
    await firestore
        .collection(MaterialRequestRepository.collectionName)
        .add(
          _baseRequest(
            createdAt: DateTime(2024, 7, 3),
            requesterUid: 'user-1',
            status: MaterialRequestStatus.approved,
          ),
        );

    final items = await repo
        .watchRequestsByRequester(requesterUid: 'user-1')
        .first
        .timeout(const Duration(seconds: 1));

    expect(items.map((e) => e.status).toList(), [
      MaterialRequestStatus.approved,
      MaterialRequestStatus.pending,
    ]);
    expect(items.first, isA<MaterialRequest>());
  });

  test('markDelivered memperbarui status dan receiver info', () async {
    final firestore = FakeFirebaseFirestore();
    final storage = FirebaseStorage.instanceFor(bucket: 'test-bucket');
    final repo = MaterialRequestRepository(
      firestore: firestore,
      storage: storage,
    );
    final docRef = await firestore
        .collection(MaterialRequestRepository.collectionName)
        .add(
          _baseRequest(createdAt: DateTime(2024, 7, 5), requesterUid: 'user-2'),
        );

    await repo.markDelivered(
      requestId: docRef.id,
      receiverName: 'Budi',
      receiverUid: 'receiver-1',
    );

    final updated = await docRef.get();
    expect(updated.get('status'), MaterialRequestStatus.delivered);
    expect(updated.get('receivedBy'), 'Budi');
    expect(updated.get('receivedByUid'), 'receiver-1');
    expect(updated.data()?.containsKey('receivedAt'), isTrue);
  });
}
