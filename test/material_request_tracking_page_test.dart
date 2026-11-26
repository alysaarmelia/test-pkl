import 'package:cipta_vera_mandiri_digital/app/modules/pages/material_request_tracking_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/material_request_tracking_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/material_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMaterialRequestTrackingRepository extends Mock
    implements MaterialRequestTrackingRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetMocktailState();
  });

  testWidgets('menampilkan pesan login saat user null', (tester) async {
    final repo = _MockMaterialRequestTrackingRepository();
    when(() => repo.currentUserUid).thenReturn(null);
    when(() => repo.currentUserDisplayName).thenReturn('Pengorder');
    when(
      () => repo.watchRequestsByRequester(
        requesterUid: any(named: 'requesterUid'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => const Stream<List<MaterialRequest>>.empty());
    when(() => repo.fetchUserDisplayName(any())).thenAnswer((_) async => null);
    when(
      () => repo.markDelivered(
        requestId: any(named: 'requestId'),
        receiverName: any(named: 'receiverName'),
        receiverUid: any(named: 'receiverUid'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(home: MaterialRequestTrackingPage(repository: repo)),
    );

    await tester.pump();

    expect(find.textContaining('Sesi Anda telah berakhir'), findsOneWidget);
  });

  testWidgets('menampilkan empty state saat tidak ada permintaan', (
    tester,
  ) async {
    final repo = _MockMaterialRequestTrackingRepository();
    when(() => repo.currentUserUid).thenReturn('user-req');
    when(() => repo.currentUserDisplayName).thenReturn('Requester');
    when(
      () => repo.watchRequestsByRequester(
        requesterUid: any(named: 'requesterUid'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream.value(const <MaterialRequest>[]));
    when(() => repo.fetchUserDisplayName(any())).thenAnswer((_) async => null);
    when(
      () => repo.markDelivered(
        requestId: any(named: 'requestId'),
        receiverName: any(named: 'receiverName'),
        receiverUid: any(named: 'receiverUid'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(home: MaterialRequestTrackingPage(repository: repo)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Belum ada permintaan'), findsOneWidget);
  });
}
