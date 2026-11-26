import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/pages/profile_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/profile_repository.dart';

import 'firebase_test_helper.dart';
import 'test_doubles.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan pesan ketika tidak ada user', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          repository: ProfileRepositoryImpl(
            auth: TestAuth(),
            firestore: FakeFirebaseFirestore(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.text('Tidak menemukan sesi pengguna. Silakan login ulang.'),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan data profil dari firestore', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set({
      'name': 'Jane Doe',
      'role': 'Engineer',
      'pin': 'PIN123',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          repository: ProfileRepositoryImpl(
            auth: TestAuth(user: TestUser(uid: 'u1')),
            firestore: firestore,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Jane Doe'), findsWidgets);
    expect(find.textContaining('PIN123'), findsOneWidget);
    expect(find.text('Engineer'), findsWidgets);
  });

  testWidgets('menampilkan fallback ketika data profil kosong', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set({});

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          repository: ProfileRepositoryImpl(
            auth: TestAuth(user: TestUser(uid: 'u1')),
            firestore: firestore,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Nama Tidak Ditemukan'), findsWidgets);
    expect(find.text('- BELUM ADA PIN -'), findsOneWidget);
    expect(find.text('- Belum ada role -'), findsWidgets);
  });
}
