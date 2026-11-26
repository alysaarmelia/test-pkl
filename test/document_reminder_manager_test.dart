import 'package:cipta_vera_mandiri_digital/app/services/document_reminder_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previewUpcoming hanya mengembalikan jadwal dalam window', () {
    final manager = DocumentReminderManager();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 3));
    final upcoming = manager.previewUpcoming(
      expiresAt: expiresAt,
      interval: const Duration(days: 3),
      now: now,
      window: const Duration(hours: 48),
    );

    expect(upcoming, isNotEmpty);
    expect(upcoming.length, lessThanOrEqualTo(4));
    expect(upcoming.every((d) => d.isAfter(now)), isTrue);
    expect(
      upcoming.every((d) => d.isBefore(now.add(const Duration(hours: 48)))),
      isTrue,
    );
  });
}
