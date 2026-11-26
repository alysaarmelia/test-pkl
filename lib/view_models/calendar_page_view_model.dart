import 'dart:async';

import 'package:get/get.dart';

import '../repositories/calendar_events_repository.dart';
import '../repositories/calendar_holiday_repository.dart';
import '../repositories/calendar_page_event.dart';

class CalendarPageViewModel extends GetxController {
  CalendarPageViewModel({
    CalendarEventsRepository? eventsRepository,
    HolidayRepository? holidayRepository,
  }) : _eventsRepository = eventsRepository ?? CalendarEventsRepositoryImpl(),
       _holidayRepository = holidayRepository ?? ApiHolidayRepository();

  final CalendarEventsRepository _eventsRepository;
  final HolidayRepository _holidayRepository;

  final Rx<DateTime> selectedDay = DateTime.now().obs;
  final RxBool isSubmitting = false.obs;
  final RxList<CalendarPageEvent> events = <CalendarPageEvent>[].obs;
  final RxMap<DateTime, List<String>> holidays = <DateTime, List<String>>{}.obs;

  final Set<int> _loadedHolidayYears = <int>{};
  StreamSubscription<List<CalendarPageEvent>>? _eventsSubscription;

  @override
  void onInit() {
    super.onInit();
    _eventsSubscription = _eventsRepository.watchEvents().listen((items) {
      events.assignAll(items);
    });
    unawaited(_eventsRepository.initialize());
    unawaited(_prefetchHolidayWindow(DateTime.now().year));
  }

  @override
  void onClose() {
    _eventsSubscription?.cancel();
    unawaited(_eventsRepository.dispose());
    super.onClose();
  }

  DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void selectDay(DateTime day) {
    selectedDay.value = normalizeDate(day);
  }

  Future<void> onPageChanged(DateTime focusedDay) async {
    selectedDay.value = normalizeDate(focusedDay);
    await _prefetchHolidayWindow(focusedDay.year);
  }

  Map<DateTime, List<CalendarPageEvent>> groupEvents(
    List<CalendarPageEvent> items,
  ) {
    final map = <DateTime, List<CalendarPageEvent>>{};
    for (final event in items) {
      final day = normalizeDate(event.date);
      map.putIfAbsent(day, () => []).add(event);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) => a.date.compareTo(b.date));
    }
    return map;
  }

  Future<void> createEvent({
    required DateTime date,
    required String title,
    required String time,
    String location = '',
  }) async {
    if (isSubmitting.value) return;
    isSubmitting.value = true;
    try {
      await _eventsRepository.createEvent(
        date: date,
        title: title,
        time: time,
        location: location,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    if (isSubmitting.value) return;
    isSubmitting.value = true;
    try {
      await _eventsRepository.deleteEvent(eventId);
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _prefetchHolidayWindow(int centerYear) async {
    final yearsToLoad = <int>{
      centerYear - 1,
      centerYear,
      centerYear + 1,
    }.where((year) => !_loadedHolidayYears.contains(year)).toList()..sort();

    if (yearsToLoad.isEmpty) return;
    await _fetchHolidays(yearsToLoad);
  }

  Future<void> _fetchHolidays(List<int> years) async {
    final normalizedYears = years.toSet().toList()..sort();
    if (normalizedYears.isEmpty) return;

    final merged = <DateTime, List<String>>{};
    final fetchedYears = <int>{};

    for (final year in normalizedYears) {
      final data = await _holidayRepository.fetchHolidaysByYear(year);
      if (data.isNotEmpty) {
        fetchedYears.add(year);
      }
      for (final entry in data.entries) {
        merged.putIfAbsent(entry.key, () => <String>[]).addAll(entry.value);
      }
    }

    holidays.removeWhere((date, _) => normalizedYears.contains(date.year));
    for (final entry in merged.entries) {
      final deduped = entry.value.toSet().toList()..sort();
      holidays[entry.key] = deduped;
    }

    _loadedHolidayYears.addAll(fetchedYears);
  }
}
