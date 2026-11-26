import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/starred_messages_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/starred_messages_repository.dart';

import 'firebase_test_helper.dart';
import 'test_doubles.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan pesan berbintang dan bisa unstar', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final auth = TestAuth(
      user: TestUser(uid: 'me', displayName: 'Saya'),
    );

    await firestore.collection('chats').doc('c1').set({
      'members': ['me', 'peer'],
      'type': 'dm',
    });
    await firestore.collection('chats').doc('c1').collection('messages').add({
      'text': 'Halo berbintang',
      'type': 'text',
      'starredBy': ['me'],
      'createdAt': DateTime.now(),
      'isDeleted': false,
      'deletedFor': const <String>[],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StarredMessagesPage(
          chatId: 'c1',
          repository: StarredMessagesRepositoryImpl(
            firestore: firestore,
            auth: auth,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Halo berbintang'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star).first);
    await tester.pumpAndSettle();

    expect(find.text('Belum ada pesan berbintang'), findsOneWidget);
  });
}
