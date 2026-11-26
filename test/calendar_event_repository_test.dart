import 'package:cipta_vera_mandiri_digital/shared/models/calendar_event.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/calendar_event_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  test('fetchEvents memfilter by range dan sort ascending', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CalendarEventRepository(firestore: firestore);
    final dates = [
      DateTime(2024, 7, 1),
      DateTime(2024, 7, 5),
      DateTime(2024, 7, 10),
    ];

    for (final d in dates) {
      await firestore.collection(CalendarEventRepository.collectionName).add({
        'title': 'Event ${d.day}',
        'date': Timestamp.fromDate(d),
        'createdAt': Timestamp.fromDate(d),
      });
    }

    final events = await repo.fetchEvents(
      from: DateTime(2024, 7, 2),
      until: DateTime(2024, 7, 8),
      limit: 10,
    );

    expect(events.length, 1);
    expect(events.first.title, 'Event 5');
    expect(events.first, isA<CalendarEvent>());
  });

  test('fetchEventById mengembalikan null jika tidak ada', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CalendarEventRepository(firestore: firestore);
    final event = await repo.fetchEventById('missing');
    expect(event, isNull);
  });
}
