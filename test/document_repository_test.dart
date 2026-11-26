import 'package:cipta_vera_mandiri_digital/shared/models/document_record.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/document_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  test('addDocument menyimpan field wajib', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = DocumentRepository(firestore: firestore);

    final id = await repo.addDocument(
      uid: 'user-1',
      title: 'KTP',
      storagePath: 'pemberkasan/user-1/ktp.pdf',
      downloadUrl: 'https://example.com/ktp.pdf',
      createdBy: 'user-1',
    );

    final snapshot = await firestore
        .collection(DocumentRepository.collectionName)
        .doc(id)
        .get();

    expect(snapshot.exists, isTrue);
    expect(snapshot.get('uid'), 'user-1');
    expect(snapshot.get('title'), 'KTP');
    expect(snapshot.get('storagePath'), 'pemberkasan/user-1/ktp.pdf');
    expect(snapshot.get('downloadUrl'), 'https://example.com/ktp.pdf');
    expect(snapshot.get('createdBy'), 'user-1');
  });

  test('watchDocuments mengurutkan createdAt desc', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = DocumentRepository(firestore: firestore);
    final now = DateTime(2024, 1, 2);

    await firestore.collection(DocumentRepository.collectionName).add({
      'uid': 'user-2',
      'title': 'Old Doc',
      'storagePath': 'path/old',
      'downloadUrl': 'old',
      'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      'updatedAt': Timestamp.fromDate(now),
    });
    await firestore.collection(DocumentRepository.collectionName).add({
      'uid': 'user-2',
      'title': 'New Doc',
      'storagePath': 'path/new',
      'downloadUrl': 'new',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    final items = await repo
        .watchDocuments(uid: 'user-2')
        .first
        .timeout(const Duration(seconds: 1));

    expect(items.map((e) => e.title).toList(growable: false), [
      'New Doc',
      'Old Doc',
    ]);
    expect(items.first, isA<DocumentRecord>());
  });
}
