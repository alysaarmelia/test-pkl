import 'package:cloud_firestore/cloud_firestore.dart';

import 'calendar_event.dart';

class DocumentRecord {
  DocumentRecord({
    required this.id,
    required this.uid,
    required this.title,
    required this.storagePath,
    required this.downloadUrl,
    required this.createdAt,
    this.originalFileName,
    this.expiresAt,
    this.reminderIntervalDays,
    this.createdBy,
    this.divisions = const [CalendarDivision.all],
    Map<String, dynamic>? extra,
    Map<String, dynamic>? raw,
  })  : extra = extra ?? const <String, dynamic>{},
        raw = raw ?? const <String, dynamic>{};

  factory DocumentRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DocumentRecord(
      id: doc.id,
      uid: _asString(data['uid']) ?? '',
      title: _asString(data['title']) ?? _asString(data['name']) ?? '',
      storagePath: _asString(data['storagePath']) ?? '',
      downloadUrl: _asString(data['downloadUrl']) ??
          _asString(data['fileUrl']) ??
          '',
      createdAt: _asDate(data['createdAt']) ?? DateTime.now(),
      createdBy: _asString(data['createdBy']) ?? _asString(data['creatorId']),
      expiresAt: _asDate(data['expiresAt']) ?? _asDate(data['expiryAt']),
      reminderIntervalDays: _asInt(data['reminderIntervalDays']) ??
          _asInt(data['reminderEveryDays']),
      originalFileName: _asString(data['originalFileName']) ??
          _asString(data['fileName']),
      divisions: CalendarDivision.sanitizeList(data['divisions']),
      extra: _asMap(data['extra']) ?? const <String, dynamic>{},
      raw: Map<String, dynamic>.from(data),
    );
  }

  final String id;
  final String uid;
  final String title;
  final String storagePath;
  final String downloadUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? reminderIntervalDays;
  final String? originalFileName;
  final String? createdBy;
  final List<String> divisions;
  final Map<String, dynamic> extra;
  final Map<String, dynamic> raw;

  Duration? get reminderInterval =>
      reminderIntervalDays != null && reminderIntervalDays! > 0
          ? Duration(days: reminderIntervalDays!)
          : null;

  DocumentRecord copyWith({
    String? id,
    String? uid,
    String? title,
    String? storagePath,
    String? downloadUrl,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? reminderIntervalDays,
    String? originalFileName,
    String? createdBy,
    List<String>? divisions,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? raw,
  }) {
    return DocumentRecord(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      reminderIntervalDays: reminderIntervalDays ?? this.reminderIntervalDays,
      originalFileName: originalFileName ?? this.originalFileName,
      createdBy: createdBy ?? this.createdBy,
      divisions: divisions ?? this.divisions,
      extra: extra ?? this.extra,
      raw: raw ?? this.raw,
    );
  }
}

String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
        .toLocal();
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
