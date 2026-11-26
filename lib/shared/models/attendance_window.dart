import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceWindow {
  const AttendanceWindow({
    required this.date,
    required this.openAt,
    required this.closeAt,
    required this.lateGraceMinutes,
    this.isDefault = false,
  });

  factory AttendanceWindow.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final docId = snapshot.id;
    final date =
        _parseDocIdAsDate(docId) ??
        DateTime.now(); // fallback to avoid invalid state

    DateTime? _parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final openAt =
        _parseTimestamp(data['openAt']) ??
        DateTime(date.year, date.month, date.day);
    final closeAt =
        _parseTimestamp(data['closeAt']) ??
        openAt.add(const Duration(hours: 8));
    final grace = data['lateGraceMinutes'] is num
        ? (data['lateGraceMinutes'] as num).toInt()
        : 30;

    return AttendanceWindow(
      date: DateTime(date.year, date.month, date.day),
      openAt: openAt.toLocal(),
      closeAt: closeAt.toLocal(),
      lateGraceMinutes: grace,
      isDefault: false,
    );
  }

  final DateTime date;
  final DateTime openAt;
  final DateTime closeAt;
  final int lateGraceMinutes;
  final bool isDefault;

  bool get isConfigured => openAt.isBefore(closeAt);

  bool isWithinWindow(DateTime moment) {
    final localMoment = moment.toLocal();
    return !localMoment.isBefore(openAt) &&
        !localMoment.isAfter(closeGraceDeadline());
  }

  bool isBeforeOpen(DateTime moment) => moment.toLocal().isBefore(openAt);

  bool isAfterClose(DateTime moment) =>
      moment.toLocal().isAfter(closeGraceDeadline());

  bool isLate(DateTime moment) {
    final localMoment = moment.toLocal();
    if (localMoment.isBefore(closeAt)) return false;
    if (localMoment.isAfter(closeGraceDeadline())) return false;
    return true;
  }

  Duration minutesLate(DateTime moment) {
    if (!isLate(moment)) return Duration.zero;
    return Duration(minutes: lateGraceMinutes);
  }

  DateTime lateThreshold() => closeAt;

  DateTime closeGraceDeadline() =>
      closeAt.add(Duration(minutes: lateGraceMinutes));

  Map<String, dynamic> toMap() {
    return {
      'openAt': Timestamp.fromDate(openAt.toUtc()),
      'closeAt': Timestamp.fromDate(closeAt.toUtc()),
      'lateGraceMinutes': lateGraceMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _parseDocIdAsDate(String id) {
    final parts = id.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}
