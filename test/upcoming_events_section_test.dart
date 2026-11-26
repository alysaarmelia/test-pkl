import 'package:cipta_vera_mandiri_digital/app/modules/home/controllers/home_controller.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/upcoming_events_section.dart';
import 'package:cipta_vera_mandiri_digital/repositories/home_calendar_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/calendar_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_test_helper.dart';

class _FakeHomeCalendarRepository implements HomeCalendarRepository {
  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime until,
  }) {
    return const Stream<List<CalendarEvent>>.empty();
  }
}

class _FakeHomeController extends HomeController {
  _FakeHomeController()
    : super(homeCalendarRepository: _FakeHomeCalendarRepository());
}

void main() {
  setUpAll(() async {
    Get.testMode = true;
    await setupFirebaseForTesting();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('menampilkan empty state ketika tidak ada acara', (tester) async {
    final controller = _FakeHomeController();
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: UpcomingEventsSection(onMenuSelected: (_) {})),
      ),
    );

    await tester.pump();

    expect(find.text('Tidak ada acara mendatang'), findsOneWidget);
  });

  testWidgets('menampilkan daftar acara mendatang', (tester) async {
    final controller = _FakeHomeController();
    final upcomingDate = DateTime.now().add(const Duration(days: 2));
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: UpcomingEventsSection(onMenuSelected: (_) {})),
      ),
    );
    await tester.pump();
    controller.events.assignAll([
      Event(
        id: 'e1',
        date: upcomingDate,
        title: 'Rapat Proyek',
        time: '10:00',
        location: 'Ruang Meeting',
      ),
    ]);
    await tester.pump();

    expect(find.text('Rapat Proyek'), findsOneWidget);
    expect(find.textContaining('Ruang Meeting'), findsOneWidget);
    expect(find.text('Lihat Kalender'), findsOneWidget);
  });
}
