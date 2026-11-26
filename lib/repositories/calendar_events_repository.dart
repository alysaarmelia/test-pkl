import 'dart:async';
import 'dart:convert';

import 'package:cipta_vera_mandiri_digital/shared/models/calendar_event.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/calendar_event_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_page_event.dart';

abstract class CalendarEventsRepository {
  Stream<List<CalendarPageEvent>> watchEvents();
  Future<void> initialize();
  Future<void> dispose();
  Future<void> createEvent({
    required DateTime date,
    required String title,
    required String time,
    String location,
  });
  Future<void> deleteEvent(String eventId);
}

class CalendarEventsRepositoryImpl implements CalendarEventsRepository {
  CalendarEventsRepositoryImpl({
    CalendarEventRepository? calendarRepository,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _calendarRepository = calendarRepository ?? CalendarEventRepository(),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _localEventsPrefsKey = 'events';
  static const String _remoteEventsPrefsKey = 'events_remote_cache';

  final CalendarEventRepository _calendarRepository;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  final StreamController<List<CalendarPageEvent>> _eventsController =
      StreamController<List<CalendarPageEvent>>.broadcast();

  StreamSubscription<List<CalendarEvent>>? _calendarSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userProfileSubscription;

  final List<CalendarPageEvent> _localEvents = <CalendarPageEvent>[];
  List<CalendarPageEvent> _allRemoteEvents = const <CalendarPageEvent>[];
  List<CalendarPageEvent> _remoteEvents = const <CalendarPageEvent>[];
  Set<String> _userDivisionIds = <String>{};
  bool _initialized = false;

  @override
  Stream<List<CalendarPageEvent>> watchEvents() {
    return _eventsController.stream;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) {
      _emitCombinedEvents();
      return;
    }
    _initialized = true;

    await _loadLocalEventsFromPrefs();
    await _loadRemoteEventsFromCache();
    _subscribeToUserDivisionChanges();
    _subscribeToCalendarEvents();
    _emitCombinedEvents();
  }

  @override
  Future<void> dispose() async {
    await _calendarSubscription?.cancel();
    await _userProfileSubscription?.cancel();
    await _eventsController.close();
  }

  @override
  Future<void> createEvent({
    required DateTime date,
    required String title,
    required String time,
    String location = '',
  }) async {
    final firebaseUser = _auth.currentUser;
    final eventId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final newEvent = CalendarPageEvent(
      id: eventId,
      date: date,
      title: title.trim(),
      time: time.trim(),
      location: location.trim(),
      createdBy: firebaseUser?.uid,
      divisions: _userDivisionIds.isEmpty
          ? const [CalendarDivision.all]
          : _userDivisionIds.toList(growable: false),
    );

    final existingIndex = _localEvents.indexWhere(
      (item) => item.id == newEvent.id,
    );
    if (existingIndex >= 0) {
      _localEvents[existingIndex] = newEvent;
    } else {
      _localEvents.add(newEvent);
    }
    _localEvents.sort((a, b) => a.date.compareTo(b.date));

    _emitCombinedEvents();
    await _saveLocalEventsToPrefs();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    if (eventId.isEmpty) return;

    final isLocal =
        eventId.startsWith('local-') || eventId.startsWith('legacy-');

    if (isLocal) {
      _localEvents.removeWhere((event) => event.id == eventId);
      _emitCombinedEvents();
      await _saveLocalEventsToPrefs();
      return;
    }

    await _calendarRepository.deleteEvent(eventId);
    _allRemoteEvents =
        _allRemoteEvents.where((event) => event.id != eventId).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    _remoteEvents = _filterEventsForDivision(_allRemoteEvents);
    _emitCombinedEvents();
    await _saveRemoteEventsToCache(_allRemoteEvents);
  }

  void _subscribeToUserDivisionChanges() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _userProfileSubscription?.cancel();
      _userDivisionIds = <String>{};
      return;
    }

    _userProfileSubscription?.cancel();
    _userProfileSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          final next = CalendarDivision.divisionsFromUserData(snapshot.data());
          if (_hasDivisionChanged(next)) {
            _userDivisionIds = next;
            _remoteEvents = _filterEventsForDivision(_allRemoteEvents);
            _emitCombinedEvents();
          }
        }, onError: (_) {});
  }

  bool _hasDivisionChanged(Set<String> next) {
    if (next.length != _userDivisionIds.length) return true;
    for (final value in next) {
      if (!_userDivisionIds.contains(value)) return true;
    }
    return false;
  }

  void _subscribeToCalendarEvents() {
    _calendarSubscription?.cancel();

    final now = DateTime.now();
    final from = DateTime(now.year - 1, 1, 1);
    final until = DateTime(now.year + 2, 12, 31, 23, 59, 59, 999);

    _calendarSubscription = _calendarRepository
        .watchEvents(from: from, until: until)
        .listen((items) async {
          final mapped =
              items
                  .map(CalendarPageEvent.fromCalendarEvent)
                  .toList(growable: false)
                ..sort((a, b) => a.date.compareTo(b.date));
          _allRemoteEvents = mapped;
          _remoteEvents = _filterEventsForDivision(mapped);
          _emitCombinedEvents();
          await _saveRemoteEventsToCache(mapped);
        }, onError: (_) {});
  }

  List<CalendarPageEvent> _filterEventsForDivision(
    List<CalendarPageEvent> source,
  ) {
    final filtered = source.where(_isEventVisibleForUser).toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }

  bool _isEventVisibleForUser(CalendarPageEvent event) {
    final divisions = event.divisions.isEmpty
        ? const [CalendarDivision.all]
        : event.divisions;
    if (divisions.contains(CalendarDivision.all)) return true;
    if (_userDivisionIds.isEmpty ||
        _userDivisionIds.contains(CalendarDivision.all)) {
      return true;
    }
    for (final division in divisions) {
      if (_userDivisionIds.contains(division)) return true;
    }
    return false;
  }

  void _emitCombinedEvents() {
    if (_eventsController.isClosed) return;

    final merged = <CalendarPageEvent>[];
    final seen = <String>{};

    for (final event in _remoteEvents) {
      if (seen.add(event.id)) merged.add(event);
    }
    for (final event in _localEvents) {
      if (seen.add(event.id)) merged.add(event);
    }

    merged.sort((a, b) => a.date.compareTo(b.date));
    _eventsController.add(List<CalendarPageEvent>.unmodifiable(merged));
  }

  Future<void> _loadLocalEventsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final eventsString = prefs.getString(_localEventsPrefsKey);

    _localEvents.clear();
    if (eventsString == null || eventsString.isEmpty) return;

    try {
      final decoded = jsonDecode(eventsString);
      if (decoded is List) {
        final cachedEvents =
            decoded
                .whereType<Map<String, dynamic>>()
                .map(CalendarPageEvent.fromJson)
                .where(
                  (event) =>
                      event.id.startsWith('local-') ||
                      event.id.startsWith('legacy-'),
                )
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        _localEvents.addAll(cachedEvents);
      } else if (decoded is Map) {
        final cachedEvents = <CalendarPageEvent>[];
        decoded.forEach((key, value) {
          final date = DateTime.tryParse(key)?.toLocal();
          if (date == null || value is! List) return;
          for (final item in value) {
            if (item is! Map) continue;
            cachedEvents.add(
              CalendarPageEvent(
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
    } catch (_) {
      // Ignore malformed cache.
    }
  }

  Future<void> _saveLocalEventsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _localEvents.map((event) => event.toJson()).toList();
    await prefs.setString(_localEventsPrefsKey, jsonEncode(payload));
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
        final cachedEvents =
            decoded
                .whereType<Map<String, dynamic>>()
                .map(CalendarPageEvent.fromJson)
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        _allRemoteEvents = cachedEvents;
        _remoteEvents = _filterEventsForDivision(cachedEvents);
      }
    } catch (_) {
      // Ignore malformed cache.
    }
  }

  Future<void> _saveRemoteEventsToCache(List<CalendarPageEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = events.map((event) => event.toJson()).toList();
    await prefs.setString(_remoteEventsPrefsKey, jsonEncode(payload));
  }
}
