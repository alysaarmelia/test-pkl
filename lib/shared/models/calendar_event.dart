import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarDivisionOption {
  const CalendarDivisionOption({required this.id, required this.label});

  final String id;
  final String label;
}

class CalendarDivision {
  CalendarDivision._();

  static const String purchasingLogistik = 'purchasing_logistik';
  static const String administrations = 'administrations';
  static const String finance = 'finance';
  static const String projectOfficer = 'project_officer';
  static const String headOfficer = 'head_officer';
  static const String all = 'all';

  static const List<CalendarDivisionOption> options = [
    CalendarDivisionOption(
      id: all,
      label: 'Semua Divisi',
    ),
    CalendarDivisionOption(
      id: administrations,
      label: 'Administrations',
    ),
    CalendarDivisionOption(
      id: finance,
      label: 'Finance',
    ),
    CalendarDivisionOption(
      id: projectOfficer,
      label: 'Project Officer',
    ),
    CalendarDivisionOption(
      id: headOfficer,
      label: 'Head Officer',
    ),
    CalendarDivisionOption(
      id: purchasingLogistik,
      label: 'Purchasing & Logistik',
    ),
  ];

  static String? labelFor(String id) {
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return null;
  }

  static List<String> sanitizeList(dynamic raw) {
    final ids = <String>[];
    void addId(String value) {
      if (value.isEmpty) return;
      if (!ids.contains(value)) ids.add(value);
    }

    if (raw is Iterable) {
      for (final value in raw) {
        final normalized = _normalize(value);
        if (normalized.isNotEmpty) addId(normalized);
      }
    } else {
      final normalized = _normalize(raw);
      if (normalized.isNotEmpty) addId(normalized);
    }

    if (ids.isEmpty) return const [all];
    return List<String>.unmodifiable(ids);
  }

  static Set<String> divisionsFromUserData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return <String>{};
    final ids = <String>{};
    for (final key in const [
      'division',
      'divisi',
      'divisions',
      'department',
      'team',
      'role',
      'section',
      'unit',
      'position',
      'jabatan',
    ]) {
      final normalized = _normalize(data[key]);
      if (normalized.isNotEmpty) ids.add(normalized);
    }
    return ids;
  }

  static String _normalize(dynamic value) {
    if (value == null) return '';
    if (value is Iterable) {
      for (final item in value) {
        final normalized = _normalize(item);
        if (normalized.isNotEmpty) return normalized;
      }
      return '';
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower == all ||
        lower.contains('semua') ||
        lower.contains('all')) return all;
    if (lower.contains('purchasing') ||
        lower.contains('logistik') ||
        lower.contains('logistic')) {
      return purchasingLogistik;
    }
    if (lower.contains('admin')) return administrations;
    if (lower.contains('finance') || lower.contains('finans')) return finance;
    if (lower.contains('project')) return projectOfficer;
    if (lower.contains('head')) return headOfficer;
    return '';
  }
}

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.divisions,
    this.category,
    this.description,
    this.location,
    this.timeText,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    Map<String, dynamic>? raw,
  }) : raw = raw ?? const <String, dynamic>{};

  factory CalendarEvent.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawDate = _asDate(data['date']) ?? DateTime.now();
    return CalendarEvent(
      id: snapshot.id,
      title: _asString(data['title']) ?? 'Acara Tidak Bernama',
      date: rawDate.toLocal(),
      divisions: CalendarDivision.sanitizeList(data['divisions']),
      category: _asString(data['category']),
      description: _asString(data['description'] ?? data['note']),
      location: _asString(data['location'] ?? data['place']),
      timeText: _asString(data['time'] ?? data['timeText']),
      createdBy: _asString(data['createdBy']),
      createdAt: _asDate(data['createdAt'])?.toLocal(),
      updatedAt: _asDate(data['updatedAt'])?.toLocal(),
      raw: data,
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? date,
    List<String>? divisions,
    String? category,
    String? description,
    String? location,
    String? timeText,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? raw,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      divisions: CalendarDivision.sanitizeList(
        divisions ?? this.divisions,
      ),
      category: category ?? this.category,
      description: description ?? this.description,
      location: location ?? this.location,
      timeText: timeText ?? this.timeText,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      raw: raw ?? this.raw,
    );
  }

  final String id;
  final String title;
  final DateTime date;
  final List<String> divisions;
  final String? category;
  final String? description;
  final String? location;
  final String? timeText;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': Timestamp.fromDate(date),
      'divisions': CalendarDivision.sanitizeList(divisions),
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (timeText != null) 'time': timeText,
      if (createdBy != null) 'createdBy': createdBy,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (raw.isNotEmpty) 'raw': raw,
    };
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  bool isVisibleFor(Set<String> userDivisions) {
    if (divisions.isEmpty || divisions.contains(CalendarDivision.all)) {
      return true;
    }
    if (userDivisions.isEmpty || userDivisions.contains(CalendarDivision.all)) {
      // Fall back to showing the event if we don't know the user's division.
      return true;
    }
    for (final division in divisions) {
      if (userDivisions.contains(division)) return true;
    }
    return false;
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      if ('$value'.length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }
}

class CalendarEventPayload {
  CalendarEventPayload({
    required this.title,
    required this.date,
    this.divisions = const [CalendarDivision.all],
    this.category,
    this.description,
    this.location,
    this.timeText,
    this.createdBy,
  });

  final String title;
  final DateTime date;
  final List<String> divisions;
  final String? category;
  final String? description;
  final String? location;
  final String? timeText;
  final String? createdBy;

  Map<String, dynamic> toFirestoreData() {
    return {
      'title': title.trim(),
      'date': Timestamp.fromDate(date),
      'divisions': CalendarDivision.sanitizeList(divisions),
      if (category != null && category!.trim().isNotEmpty)
        'category': category!.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (location != null && location!.trim().isNotEmpty)
        'location': location!.trim(),
      if (timeText != null && timeText!.trim().isNotEmpty)
        'time': timeText!.trim(),
      if (createdBy != null && createdBy!.trim().isNotEmpty)
        'createdBy': createdBy!.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateData() {
    return {
      if (title.trim().isNotEmpty) 'title': title.trim(),
      'date': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
      'divisions': CalendarDivision.sanitizeList(divisions),
      if (category != null)
        'category': category!.trim(),
      if (description != null)
        'description': description!.trim(),
      if (location != null)
        'location': location!.trim(),
      if (timeText != null)
        'time': timeText!.trim(),
      if (createdBy != null)
        'createdBy': createdBy!.trim(),
    };
  }
}
