import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/chat_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/chat_page_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/chat_page_view_model.dart';

class _NoopChatPageRepository implements ChatPageRepository {
  @override
  String get currentUserUid => '';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Unexpected call: $invocation');
  }
}

void main() {
  testWidgets('mode lokal tetap bisa kirim pesan setelah migrasi', (
    tester,
  ) async {
    final viewModel = ChatPageViewModel(repository: _NoopChatPageRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          chatId: null,
          peerName: 'Dummy',
          viewModel: viewModel,
          setActiveChat: (_) {},
        ),
      ),
    );

    expect(find.text('Selamat datang di chat.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Tes chat lokal');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Tes chat lokal'), findsOneWidget);
  });
}
