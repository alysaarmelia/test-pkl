import '../../shared/models/document_record.dart';
import 'notification_service.dart';

class DocumentReminderManager {
  DocumentReminderManager._();

  static final DocumentReminderManager _instance = DocumentReminderManager._();
  factory DocumentReminderManager() => _instance;

  final NotificationService _notificationService = NotificationService();

  static const int _maxReminders = 480;

  final Set<String> _scheduledReminderKeys = <String>{};
  final Set<String> _scheduledReminderDocIds = <String>{};
  bool _isSyncing = false;

  Future<void> scheduleForDocument({
    required String documentId,
    required String title,
    required DateTime? expiresAt,
    required Duration? reminderInterval,
  }) async {
    if (expiresAt == null || reminderInterval == null) {
      return;
    }

    final key = _reminderKey(
      documentId: documentId,
      expiresAt: expiresAt,
      interval: reminderInterval,
    );
    _scheduledReminderDocIds.add(documentId);
    _scheduledReminderKeys.add(key);

    await _notificationService.cancelDocumentReminder(documentId: documentId);
    await _scheduleReminders(
      documentId: documentId,
      title: title,
      expiresAt: expiresAt,
      reminderInterval: reminderInterval,
    );
  }

  Future<void> syncDocuments(List<DocumentRecord> documents) async {
    if (_isSyncing) return;
    _isSyncing = true;

    final currentDocIds = <String>{};
    final currentKeys = <String>{};

    try {
      for (final doc in documents) {
        final expiresAt = doc.expiresAt;
        final interval = doc.reminderInterval;
        if (expiresAt == null || interval == null) continue;

        final key = _reminderKey(
          documentId: doc.id,
          expiresAt: expiresAt,
          interval: interval,
        );
        currentDocIds.add(doc.id);
        currentKeys.add(key);

        if (_scheduledReminderKeys.contains(key)) {
          continue;
        }

        await _notificationService.cancelDocumentReminder(documentId: doc.id);
        await _scheduleReminders(
          documentId: doc.id,
          title: doc.title,
          expiresAt: expiresAt,
          reminderInterval: interval,
        );
      }

      for (final id in _scheduledReminderDocIds) {
        if (!currentDocIds.contains(id)) {
          await _notificationService.cancelDocumentReminder(documentId: id);
        }
      }

      _scheduledReminderDocIds
        ..clear()
        ..addAll(currentDocIds);
      _scheduledReminderKeys
        ..clear()
        ..addAll(currentKeys);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _scheduleReminders({
    required String documentId,
    required String title,
    required DateTime expiresAt,
    required Duration reminderInterval,
  }) async {
    final reminders = _buildReminderSchedule(
      expiresAt: expiresAt,
      interval: reminderInterval,
    );
    if (reminders.isEmpty) {
      return;
    }

    for (var i = 0; i < reminders.length; i++) {
      await _notificationService.scheduleDocumentReminder(
        documentId: documentId,
        sequence: i,
        title: 'Pengingat dokumen: $title',
        body: 'Dokumen akan kedaluwarsa pada ${_formatDate(expiresAt)}',
        scheduledAt: reminders[i],
        payload: documentId,
      );
    }
  }

  List<DateTime> previewUpcoming({
    required DateTime expiresAt,
    required Duration interval,
    DateTime? now,
    Duration window = const Duration(hours: 26),
    int max = 4,
  }) {
    final current = now ?? DateTime.now();
    final upperBound = current.add(window);
    final schedule = _buildReminderSchedule(
      expiresAt: expiresAt,
      interval: interval,
    );
    return schedule
        .where(
          (time) => time.isAfter(current) && time.isBefore(upperBound),
        )
        .take(max)
        .toList(growable: false);
  }

  List<DateTime> _buildReminderSchedule({
    required DateTime expiresAt,
    required Duration interval,
  }) {
    // Schedule notifikasi SETIAP HARI jam 00:00 dan 12:00 sampai kedaluwarsa.
    // Parameter 'interval' menentukan kapan mulai mengingatkan
    // (mis. 90 hari sebelum kedaluwarsa).
    final now = DateTime.now();
    final dates = <DateTime>[];

    if (expiresAt.isBefore(now)) {
      return dates;
    }

    final reminderStartDate = expiresAt.subtract(interval);
    final startDate = reminderStartDate.isAfter(now) ? reminderStartDate : now;
    final expiryDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);

    DateTime slot(DateTime date, int hour) =>
        DateTime(date.year, date.month, date.day, hour, 0);

    var dayCursor = DateTime(startDate.year, startDate.month, startDate.day);

    while (!dayCursor.isAfter(expiryDate)) {
      final midnight = slot(dayCursor, 0);
      final noon = slot(dayCursor, 12);

      if (!midnight.isBefore(now)) {
        dates.add(midnight);
      }
      if (!noon.isBefore(now)) {
        dates.add(noon);
      }

      if (dates.length >= _maxReminders) break;

      dayCursor = dayCursor.add(const Duration(days: 1));
    }

    final expiryMidnight = slot(expiryDate, 0);
    final expiryNoon = slot(expiryDate, 12);
    if (!dates.contains(expiryMidnight) && !expiryMidnight.isBefore(now)) {
      dates.add(expiryMidnight);
    }
    if (!dates.contains(expiryNoon) && !expiryNoon.isBefore(now)) {
      dates.add(expiryNoon);
    }

    dates.sort((a, b) => a.compareTo(b));
    return dates;
  }

  String _reminderKey({
    required String documentId,
    required DateTime expiresAt,
    required Duration interval,
  }) {
    final expiresAtMillis = expiresAt.millisecondsSinceEpoch;
    return '$documentId|$expiresAtMillis|${interval.inDays}';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final month = months[(local.month - 1).clamp(0, months.length - 1)];
    return '${local.day} $month ${local.year}';
  }
}
