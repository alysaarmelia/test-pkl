import 'package:cipta_vera_mandiri_digital/shared/models/document_record.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/document_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  test('DocumentRecord.fromSnapshot memetakan field umum', () async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime(2024, 7, 2, 9);
    final docRef = await firestore
        .collection(DocumentRepository.collectionName)
        .add({
          'uid': 'user-123',
          'title': 'KTP',
          'storagePath': 'pemberkasan/user-123/ktp.pdf',
          'downloadUrl': 'https://example.com/ktp.pdf',
          'createdAt': now.millisecondsSinceEpoch,
          'expiresAt': now.add(const Duration(days: 30)),
          'reminderIntervalDays': 90,
          'originalFileName': 'KTP.pdf',
        });

    final snapshot = await docRef.get();
    final record = DocumentRecord.fromSnapshot(snapshot);

    expect(record.id, snapshot.id);
    expect(record.uid, 'user-123');
    expect(record.title, 'KTP');
    expect(record.storagePath, 'pemberkasan/user-123/ktp.pdf');
    expect(record.downloadUrl, 'https://example.com/ktp.pdf');
    expect(record.createdAt.year, now.year);
    expect(record.expiresAt?.difference(now).inDays, greaterThan(25));
    expect(record.reminderIntervalDays, 90);
    expect(record.originalFileName, 'KTP.pdf');
  });
}
