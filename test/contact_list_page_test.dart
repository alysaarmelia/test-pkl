import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/contact_list_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/contact_list_repository.dart';

import 'firebase_test_helper.dart';
import 'test_doubles.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan empty state ketika tidak ada kontak', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final auth = TestAuth(
      user: TestUser(uid: 'me', displayName: 'Saya'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ContactListPage(
          repository: ContactListRepositoryImpl(
            firestore: firestore,
            auth: auth,
          ),
          pinScanner: () async => null,
        ),
      ),
    );

    // initial pump for StreamBuilder
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('Belum ada kontak. Tambahkan lewat tombol di AppBar.'),
      findsOneWidget,
    );
  });

  testWidgets('pindai PIN menambah kontak ke daftar', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final auth = TestAuth(
      user: TestUser(uid: 'me', displayName: 'Saya'),
    );

    // Peer data + pin mapping
    await firestore.collection('users').doc('peer').set({
      'name': 'Budi',
      'pin': 'PIN123',
    });
    await firestore.collection('pins').doc('PIN123').set({
      'uid': 'peer',
      'collection': 'users',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ContactListPage(
          repository: ContactListRepositoryImpl(
            firestore: firestore,
            auth: auth,
          ),
          // Skip camera by injecting scanner result
          pinScanner: () async => 'PIN-123',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pindai QR PIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Budi'), findsOneWidget);

    // Ensure contact stored with resolved pin
    final contactDoc = await firestore
        .collection('users')
        .doc('me')
        .collection('contacts')
        .doc('peer')
        .get();
    expect(contactDoc.exists, isTrue);
    expect(contactDoc.data()?['pin'], 'PIN123');
  });
}
