import 'package:cipta_vera_mandiri_digital/absensi/riwayat_absen.dart';
import 'package:cipta_vera_mandiri_digital/repositories/attendance_history_repository.dart';
import 'package:cipta_vera_mandiri_digital/repositories/leave_requests_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/attendance_history_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

class _MockLeaveRequestRepository extends Mock
    implements LeaveRequestsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'menampilkan empty state ketika tidak ada riwayat absen/cuti/izin',
    (tester) async {
      final mockRepo = _MockLeaveRequestRepository();
      when(
        () => mockRepo.watchUserRequests(
          uid: any(named: 'uid'),
          kind: any(named: 'kind'),
        ),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => mockRepo.fetchUserRequests(
          uid: any(named: 'uid'),
          kind: any(named: 'kind'),
          preferServer: any(named: 'preferServer'),
        ),
      ).thenAnswer((_) async => []);

      final auth = TestAuth(user: TestUser(uid: 'user-absen'));
      final viewModel = AttendanceHistoryViewModel(
        attendanceHistoryRepository: AttendanceHistoryRepositoryImpl(
          auth: auth,
        ),
        leaveRepository: mockRepo,
      );

      await tester.pumpWidget(
        MaterialApp(home: AttendanceHistoryPage(viewModel: viewModel)),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        find.text('Belum ada riwayat absen, cuti, atau izin.'),
        findsOneWidget,
      );
    },
  );
}
