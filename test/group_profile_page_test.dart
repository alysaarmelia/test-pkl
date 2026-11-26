import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/group_profile_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/group_profile_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';
import 'test_doubles.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan info grup dan aksi admin', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('chats').doc('chat-1').set({
      'groupName': 'Team A',
      'createdBy': 'admin-1',
      'admins': ['admin-1'],
      'members': ['admin-1', 'user-2'],
      'memberInfo': {
        'admin-1': {'name': 'Admin Satu'},
        'user-2': {'name': 'User Dua'},
      },
    });

    final auth = TestAuth(user: TestUser(uid: 'admin-1'));

    await tester.pumpWidget(
      MaterialApp(
        home: GroupProfilePage(
          chatId: 'chat-1',
          repository: GroupProfileRepositoryImpl(
            firestore: firestore,
            auth: auth,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Team A'), findsOneWidget);
    expect(find.textContaining('2 anggota'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget); // tombol admin
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('non-admin tidak melihat kontrol manajemen anggota', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('chats').doc('chat-2').set({
      'groupName': 'Team B',
      'createdBy': 'creator-1',
      'admins': ['creator-1'],
      'members': ['creator-1', 'member-1'],
      'memberInfo': {
        'creator-1': {'name': 'Owner'},
        'member-1': {'name': 'Member Biasa'},
      },
    });

    final auth = TestAuth(user: TestUser(uid: 'member-1'));

    await tester.pumpWidget(
      MaterialApp(
        home: GroupProfilePage(
          chatId: 'chat-2',
          repository: GroupProfileRepositoryImpl(
            firestore: firestore,
            auth: auth,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Team B'), findsOneWidget);
    expect(find.text('Tambah'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
}
