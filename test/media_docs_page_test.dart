import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/media_docs_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/media_docs_repository.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan dokumen pada tab Dokumen', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('chats')
        .doc('chat-1')
        .collection('messages')
        .doc('img-1')
        .set({'type': 'image', 'imageUrl': 'https://example.com/image.jpg'});
    await firestore
        .collection('chats')
        .doc('chat-1')
        .collection('messages')
        .doc('doc-1')
        .set({
          'type': 'file',
          'fileName': 'SOP.pdf',
          'fileUrl': 'https://example.com/sop.pdf',
        });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaDocsPage(
          chatId: 'chat-1',
          repository: MediaDocsRepositoryImpl(firestore: firestore),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('Dokumen'));
    await tester.pumpAndSettle();

    expect(find.text('SOP.pdf'), findsOneWidget);
  });
}
