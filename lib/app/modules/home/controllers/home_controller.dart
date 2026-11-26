import 'dart:async';
import 'dart:convert';

import 'package:cipta_vera_mandiri_digital/repositories/home_calendar_repository.dart';
import 'package:cipta_vera_mandiri_digital/repositories/home_controller_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/calendar_event.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Event {
  Event({
    required this.id,
    required this.date,
    required this.title,
    this.time = '',
    this.location = '',
    this.description,
    this.category,
    this.createdBy,
    this.divisions = const [CalendarDivision.all],
  });

  factory Event.fromCalendarEvent(CalendarEvent value) {
    return Event(
      id: value.id,
      date: value.date,
      title: value.title,
      time: value.timeText ?? '',
      location: value.location ?? '',
      description: value.description,
      category: value.category,
      createdBy: value.createdBy,
      divisions: value.divisions,
    );
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    DateTime parsedDate;
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }
    final idValue = (json['id'] as String?)?.trim();
    final titleValue = (json['title'] as String?)?.trim();
    return Event(
      id: (idValue != null && idValue.isNotEmpty)
          ? idValue
          : 'local-${parsedDate.microsecondsSinceEpoch}',
      date: parsedDate,
      title: titleValue != null && titleValue.isNotEmpty ? titleValue : 'Acara',
      time: (json['time'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      createdBy: json['createdBy'] as String?,
      divisions: CalendarDivision.sanitizeList(json['divisions']),
    );
  }

  final String id;
  final DateTime date;
  final String title;
  final String time;
  final String location;
  final String? description;
  final String? category;
  final String? createdBy;
  final List<String> divisions;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'time': time,
      'location': location,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (createdBy != null) 'createdBy': createdBy,
      'divisions': divisions,
    };
  }

  Event copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? time,
    String? location,
    String? description,
    String? category,
    String? createdBy,
    List<String>? divisions,
  }) {
    return Event(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      time: time ?? this.time,
      location: location ?? this.location,
      description: description ?? this.description,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
      divisions: CalendarDivision.sanitizeList(divisions ?? this.divisions),
    );
  }
}

Map<DateTime, List<Event>> calendarEvents = {};

class HomeController extends GetxController {
  HomeController({
    HomeCalendarRepository? homeCalendarRepository,
    HomeControllerRepository? homeControllerRepository,
  }) : _homeCalendarRepository =
           homeCalendarRepository ?? HomeCalendarRepositoryImpl(),
       _homeControllerRepository =
           homeControllerRepository ?? HomeControllerRepositoryImpl();

  final HomeCalendarRepository _homeCalendarRepository;
  final HomeControllerRepository _homeControllerRepository;
  StreamSubscription<List<CalendarEvent>>? _calendarSubscription;
  StreamSubscription<Map<String, dynamic>?>? _userProfileSubscription;
  Set<String> _userDivisionIds = <String>{};

  var currentIndex = 2.obs;
  var events = <Event>[].obs;
  var isLoading = true.obs;
  final List<Event> _localEvents = <Event>[];
  List<Event> _allRemoteEvents = const <Event>[];
  List<Event> _remoteEvents = const <Event>[];
  static const String _localEventsPrefsKey = 'events';
  static const String _remoteEventsPrefsKey = 'events_remote_cache';

  @override
  void onInit() {
    super.onInit();
    _initialise();
  }

  Future<void> _initialise() async {
    await loadEventsFromPrefs();
    _subscribeToUserDivisionChanges();
    await _loadRemoteEventsFromCache();
    _subscribeToCalendarEvents();
  }

  void _subscribeToUserDivisionChanges() {
    final uid = _homeControllerRepository.currentUserUid;
    if (uid == null) {
      _userProfileSubscription?.cancel();
      _userDivisionIds = <String>{};
      return;
    }
    _userProfileSubscription?.cancel();
    _userProfileSubscription = _homeControllerRepository
        .watchUserProfile(uid)
        .listen((data) {
          final next = CalendarDivision.divisionsFromUserData(data);
          if (_updateUserDivisions(next)) {
            _applyDivisionFilter();
          }
        }, onError: (_) {});
  }

  bool _updateUserDivisions(Set<String> next) {
    final sanitized = next;
    final changed = _hasDivisionChanged(sanitized);
    if (changed) {
      _userDivisionIds = sanitized;
    }
    return changed;
  }

  bool _hasDivisionChanged(Set<String> next) {
    if (next.length != _userDivisionIds.length) return true;
    for (final value in next) {
      if (!_userDivisionIds.contains(value)) return true;
    }
    return false;
  }

  void _applyDivisionFilter() {
    _remoteEvents = _filterEventsForDivision(_allRemoteEvents);
    _publishCombinedEvents();
  }

  void _subscribeToCalendarEvents() {
    _calendarSubscription?.cancel();
    final now = DateTime.now();
    final from = DateTime(now.year - 1, 1, 1);
    final until = DateTime(now.year + 2, 12, 31, 23, 59, 59, 999);
    _calendarSubscription = _homeCalendarRepository
        .watchEvents(from: from, until: until)
        .listen(
          (items) async {
            final mapped = items.map(Event.fromCalendarEvent).toList()
              ..sort((a, b) => a.date.compareTo(b.date));
            _allRemoteEvents = mapped;
            _remoteEvents = _filterEventsForDivision(mapped);
            _publishCombinedEvents();
            await _saveRemoteEventsToCache(mapped);
            isLoading.value = false;
          },
          onError: (error) {
            print('Failed to load calendar events: $error');
            isLoading.value = false;
          },
        );
  }

  @override
  void onClose() {
    _calendarSubscription?.cancel();
    _userProfileSubscription?.cancel();
    super.onClose();
  }

  Future<void> refreshEvents() async {
    await loadEventsFromPrefs();
    _subscribeToUserDivisionChanges();
    _subscribeToCalendarEvents();
  }

  Future<void> saveEventsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _localEvents.map((event) => event.toJson()).toList();
    await prefs.setString(_localEventsPrefsKey, jsonEncode(payload));
  }

  Future<void> loadEventsFromPrefs() async {
    isLoading.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final eventsString = prefs.getString(_localEventsPrefsKey);
    _localEvents.clear();
    if (eventsString != null && eventsString.isNotEmpty) {
      try {
        final decoded = jsonDecode(eventsString);
        if (decoded is List) {
          final cachedEvents =
              decoded
                  .whereType<Map<String, dynamic>>()
                  .map(Event.fromJson)
                  .where(
                    (event) =>
                        event.id.startsWith('local-') ||
                        event.id.startsWith('legacy-'),
                  )
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));
          _localEvents.addAll(cachedEvents);
        } else if (decoded is Map) {
          final cachedEvents = <Event>[];
          decoded.forEach((key, value) {
            final date = DateTime.tryParse(key)?.toLocal();
            if (date == null || value is! List) return;
            for (final item in value) {
              if (item is! Map) continue;
              cachedEvents.add(
                Event(
                  id: 'legacy-${date.microsecondsSinceEpoch}-${cachedEvents.length}',
                  date: DateTime(date.year, date.month, date.day),
                  title: (item['title'] as String?) ?? 'Acara',
                  time: (item['time'] as String?) ?? '',
                  location:
                      (item['location'] as String?) ??
                      (item['room'] as String?) ??
                      '',
                ),
              );
            }
          });
          cachedEvents.sort((a, b) => a.date.compareTo(b.date));
          _localEvents.addAll(cachedEvents);
        }
      } catch (error) {
        print('Failed to parse cached events: $error');
      }
    }
    _publishCombinedEvents();
    isLoading.value = false;
  }

  Future<void> _loadRemoteEventsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheString = prefs.getString(_remoteEventsPrefsKey);
    if (cacheString == null || cacheString.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(cacheString);
      if (decoded is List) {
        final cachedEvents = decoded
            .whereType<Map<String, dynamic>>()
            .map(Event.fromJson)
            .toList();
        cachedEvents.sort((a, b) => a.date.compareTo(b.date));
        _allRemoteEvents = cachedEvents;
        _remoteEvents = _filterEventsForDivision(cachedEvents);
        _publishCombinedEvents();
      }
    } catch (error) {
      print('Failed to parse remote event cache: $error');
    }
  }

  Future<void> _saveRemoteEventsToCache(List<Event> events) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = events.map((event) => event.toJson()).toList();
    await prefs.setString(_remoteEventsPrefsKey, jsonEncode(payload));
  }

  List<Event> _filterEventsForDivision(List<Event> source) {
    final filtered = source.where(_isEventVisibleForUser).toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }

  bool _isEventVisibleForUser(Event event) {
    final divisions = event.divisions.isEmpty
        ? const [CalendarDivision.all]
        : event.divisions;
    if (divisions.contains(CalendarDivision.all)) return true;
    if (_userDivisionIds.isEmpty ||
        _userDivisionIds.contains(CalendarDivision.all)) {
      // If we don't know the user's division yet, show the event instead of hiding it.
      return true;
    }
    for (final division in divisions) {
      if (_userDivisionIds.contains(division)) return true;
    }
    return false;
  }

  void _publishCombinedEvents() {
    final merged = <Event>[];
    final seen = <String>{};
    for (final event in _remoteEvents) {
      if (seen.add(event.id)) {
        merged.add(event);
      }
    }
    for (final event in _localEvents) {
      if (seen.add(event.id)) {
        merged.add(event);
      }
    }
    merged.sort((a, b) => a.date.compareTo(b.date));
    events.assignAll(merged);
    _rebuildCalendarEvents(merged);
  }

  void _rebuildCalendarEvents(List<Event> source) {
    final grouped = <DateTime, List<Event>>{};
    for (final event in source) {
      final normalized = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      grouped.putIfAbsent(normalized, () => []).add(event);
    }
    calendarEvents = grouped;
  }

  List<Event> get upcomingEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final filtered =
        events.where((event) => !event.date.isBefore(today)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }

  Future<String> createEvent({
    required DateTime date,
    required String title,
    String? time,
    String? location,
    String? description,
    String? category,
    String? createdBy,
  }) async {
    final currentUid = _homeControllerRepository.currentUserUid;
    final createdByValue = (createdBy?.trim().isNotEmpty == true)
        ? createdBy!.trim()
        : currentUid;
    final eventId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final newEvent = Event(
      id: eventId,
      date: date,
      title: title.trim(),
      time: (time ?? '').trim(),
      location: (location ?? '').trim(),
      description: description,
      category: category,
      createdBy: createdByValue,
      divisions: _userDivisionIds.isEmpty
          ? const [CalendarDivision.all]
          : _userDivisionIds.toList(growable: false),
    );
    await _addOrUpdateLocalEvent(newEvent);
    return eventId;
  }

  Future<void> deleteEvent(String eventId) async {
    if (eventId.isEmpty) return;
    final isLocal =
        eventId.startsWith('local-') || eventId.startsWith('legacy-');
    if (isLocal) {
      _localEvents.removeWhere((event) => event.id == eventId);
      _publishCombinedEvents();
      await saveEventsToPrefs();
      return;
    }
    await _homeCalendarRepository.deleteEvent(eventId);
    _allRemoteEvents = _allRemoteEvents
        .where((event) => event.id != eventId)
        .toList();
    _allRemoteEvents.sort((a, b) => a.date.compareTo(b.date));
    _remoteEvents = _filterEventsForDivision(_allRemoteEvents);
    _publishCombinedEvents();
    await _saveRemoteEventsToCache(_allRemoteEvents);
  }

  Future<void> _addOrUpdateLocalEvent(Event event) async {
    final existingIndex = _localEvents.indexWhere(
      (item) => item.id == event.id,
    );
    if (existingIndex >= 0) {
      _localEvents[existingIndex] = event;
    } else {
      _localEvents.add(event);
    }
    _localEvents.sort((a, b) => a.date.compareTo(b.date));
    _publishCombinedEvents();
    await saveEventsToPrefs();
  }
}
