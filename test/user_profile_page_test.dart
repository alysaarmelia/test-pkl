import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/user_profile_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/user_profile_repository.dart';

import 'firebase_test_helper.dart';
import 'test_doubles.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan nama dan PIN pengguna', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('peer').set({
      'name': 'Ayu Lestari',
      'pin': 'AYU001',
      'role': 'Staff',
    });

    final auth = TestAuth(
      user: TestUser(uid: 'me', displayName: 'Saya'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UserProfilePage(
          peerUid: 'peer',
          repository: UserProfileRepositoryImpl(
            firestore: firestore,
            auth: auth,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ayu Lestari'), findsOneWidget);
    expect(find.textContaining('AYU001'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });
}
