import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/pages/chat_list_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/chat_list_repository.dart';

import 'firebase_test_helper.dart';
import 'test_doubles.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan pesan login jika user null', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final auth = TestAuth();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatListPage(
          repository: ChatListRepositoryImpl(firestore: firestore, auth: auth),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Harus login'), findsOneWidget);
  });

  testWidgets('menampilkan empty state ketika tidak ada chat', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final auth = TestAuth(
      user: TestUser(uid: 'u1', displayName: 'Tester'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChatListPage(
          repository: ChatListRepositoryImpl(firestore: firestore, auth: auth),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.text('Belum ada chat'), findsOneWidget);
  });

  testWidgets('menampilkan item chat dari firestore', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final auth = TestAuth(
      user: TestUser(uid: 'u1', displayName: 'Tester'),
    );

    await firestore.collection('chats').doc('c1').set({
      'members': ['u1', 'u2'],
      'isGroup': false,
      'memberInfo': {
        'u2': {'name': 'Rekan', 'avatarUrl': ''},
      },
      'lastMessage': 'Halo',
      'lastMessageAt': Timestamp.now(),
      'unread': {'u1': 2},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatListPage(
          repository: ChatListRepositoryImpl(firestore: firestore, auth: auth),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Rekan'), findsOneWidget);
    expect(find.textContaining('Halo'), findsOneWidget);
  });
}
