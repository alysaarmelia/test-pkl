import 'package:cipta_vera_mandiri_digital/app/modules/pages/pemberkasan_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/pemberkasan_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/document_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';
import 'test_doubles.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan notice login ketika user belum masuk', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PemberkasanPage())),
    );

    expect(
      find.text('Silakan masuk untuk mengakses fitur pemberkasan.'),
      findsOneWidget,
    );
    expect(find.text('Tambah Dokumen'), findsNothing);
  });

  testWidgets('menampilkan empty state ketika tidak ada dokumen', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final auth = TestAuth(user: TestUser(uid: 'user-1'));
    final repo = PemberkasanRepositoryImpl(
      documentRepository: DocumentRepository(firestore: firestore),
      auth: auth,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PemberkasanPage(repository: repo, enableReminders: false),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Belum ada dokumen pemberkasan.'), findsOneWidget);
    expect(find.text('Tambah Dokumen'), findsOneWidget);
  });

  testWidgets('menampilkan daftar dokumen dari firestore', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime(2024, 7, 1);
    await firestore.collection(DocumentRepository.collectionName).add({
      'uid': 'user-2',
      'title': 'Kontrak Kerja',
      'storagePath': 'pemberkasan/user-2/kontrak.pdf',
      'downloadUrl': 'https://example.com/kontrak.pdf',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    final auth = TestAuth(user: TestUser(uid: 'user-2'));
    final repo = PemberkasanRepositoryImpl(
      documentRepository: DocumentRepository(firestore: firestore),
      auth: auth,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PemberkasanPage(repository: repo, enableReminders: false),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Kontrak Kerja'), findsOneWidget);
    expect(find.textContaining('Diunggah'), findsOneWidget);
    expect(find.text('Tambah Dokumen'), findsOneWidget);
  });
}
