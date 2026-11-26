import 'dart:async';

import 'package:cipta_vera_mandiri_digital/app/modules/home/controllers/home_controller.dart';
import 'package:cipta_vera_mandiri_digital/repositories/home_calendar_repository.dart';
import 'package:cipta_vera_mandiri_digital/repositories/home_controller_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHomeCalendarRepository implements HomeCalendarRepository {
  final List<String> deletedRemoteIds = <String>[];
  final StreamController<List<CalendarEvent>> _eventsController =
      StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime until,
  }) {
    return _eventsController.stream;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    deletedRemoteIds.add(eventId);
  }
}

class _FakeHomeControllerRepository implements HomeControllerRepository {
  _FakeHomeControllerRepository({this.uid});

  final String? uid;

  @override
  String? get currentUserUid => uid;

  @override
  Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    return const Stream<Map<String, dynamic>?>.empty();
  }
}

class _TestHomeController extends HomeController {
  _TestHomeController({
    required HomeCalendarRepository homeCalendarRepository,
    required HomeControllerRepository homeControllerRepository,
  }) : super(
         homeCalendarRepository: homeCalendarRepository,
         homeControllerRepository: homeControllerRepository,
       );

  @override
  Future<void> saveEventsToPrefs() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('createEvent memakai uid user jika createdBy tidak diisi', () async {
    final calendarRepository = _FakeHomeCalendarRepository();
    final homeRepository = _FakeHomeControllerRepository(uid: 'u-1');
    final controller = _TestHomeController(
      homeCalendarRepository: calendarRepository,
      homeControllerRepository: homeRepository,
    );

    final eventId = await controller.createEvent(
      date: DateTime(2026, 3, 25),
      title: 'Rapat Mingguan',
    );

    expect(eventId.startsWith('local-'), isTrue);
    expect(controller.events, hasLength(1));
    expect(controller.events.first.createdBy, 'u-1');
    expect(controller.events.first.divisions, const [CalendarDivision.all]);
  });

  test('createEvent mempertahankan createdBy bila dikirim manual', () async {
    final controller = _TestHomeController(
      homeCalendarRepository: _FakeHomeCalendarRepository(),
      homeControllerRepository: _FakeHomeControllerRepository(uid: 'u-1'),
    );

    await controller.createEvent(
      date: DateTime(2026, 3, 25),
      title: 'Review',
      createdBy: 'admin-1',
    );

    expect(controller.events.first.createdBy, 'admin-1');
  });

  test('deleteEvent local hanya hapus dari list lokal', () async {
    final calendarRepository = _FakeHomeCalendarRepository();
    final controller = _TestHomeController(
      homeCalendarRepository: calendarRepository,
      homeControllerRepository: _FakeHomeControllerRepository(uid: 'u-1'),
    );

    final localEventId = await controller.createEvent(
      date: DateTime(2026, 3, 25),
      title: 'Acara Local',
    );
    expect(controller.events, hasLength(1));

    await controller.deleteEvent(localEventId);

    expect(controller.events, isEmpty);
    expect(calendarRepository.deletedRemoteIds, isEmpty);
  });

  test('deleteEvent remote mendelegasikan ke repository', () async {
    final calendarRepository = _FakeHomeCalendarRepository();
    final controller = _TestHomeController(
      homeCalendarRepository: calendarRepository,
      homeControllerRepository: _FakeHomeControllerRepository(uid: 'u-1'),
    );

    await controller.deleteEvent('remote-123');

    expect(calendarRepository.deletedRemoteIds, ['remote-123']);
  });
}
