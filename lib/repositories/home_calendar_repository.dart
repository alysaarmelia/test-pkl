import '../shared/models/calendar_event.dart';
import '../shared/services/calendar_event_repository.dart';

abstract class HomeCalendarRepository {
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime until,
  });

  Future<void> deleteEvent(String eventId);
}

class HomeCalendarRepositoryImpl implements HomeCalendarRepository {
  HomeCalendarRepositoryImpl({CalendarEventRepository? repository})
    : _repository = repository ?? CalendarEventRepository();

  final CalendarEventRepository _repository;

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime until,
  }) {
    return _repository.watchEvents(from: from, until: until);
  }

  @override
  Future<void> deleteEvent(String eventId) {
    return _repository.deleteEvent(eventId);
  }
}
