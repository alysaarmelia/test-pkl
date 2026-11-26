import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';

class CalendarEventRepository {
  CalendarEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionName = 'calendar_events';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Stream<List<CalendarEvent>> watchEvents({
    DateTime? from,
    DateTime? until,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _collection.orderBy('date');
    if (from != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (until != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(until),
      );
    }
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) => _mapDocs(snapshot.docs));
  }

  Future<List<CalendarEvent>> fetchEvents({
    DateTime? from,
    DateTime? until,
    int? limit,
    bool preferServer = false,
  }) async {
    Query<Map<String, dynamic>> query = _collection.orderBy('date');
    if (from != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (until != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(until),
      );
    }
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }
    final options = preferServer
        ? const GetOptions(source: Source.server)
        : const GetOptions(source: Source.serverAndCache);
    final snapshot = await query.get(options);
    return _mapDocs(snapshot.docs);
  }

  Future<CalendarEvent?> fetchEventById(String eventId) async {
    if (eventId.isEmpty) return null;
    final doc = await _collection.doc(eventId).get();
    if (!doc.exists) return null;
    return CalendarEvent.fromSnapshot(doc);
  }

  Future<String> createEvent(CalendarEventPayload payload) async {
    final docRef = await _collection.add(payload.toFirestoreData());
    return docRef.id;
  }

  Future<void> updateEvent({
    required String eventId,
    required CalendarEventPayload payload,
  }) {
    return _collection.doc(eventId).update(payload.toUpdateData());
  }

  Future<void> deleteEvent(String eventId) {
    return _collection.doc(eventId).delete();
  }

  List<CalendarEvent> _mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = docs
        .map(CalendarEvent.fromSnapshot)
        .toList(growable: false);
    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }
}
