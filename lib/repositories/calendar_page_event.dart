import 'package:cipta_vera_mandiri_digital/shared/models/calendar_event.dart';

class CalendarPageEvent {
  CalendarPageEvent({
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

  factory CalendarPageEvent.fromCalendarEvent(CalendarEvent value) {
    return CalendarPageEvent(
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

  factory CalendarPageEvent.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    DateTime parsedDate;
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }
    final idValue = (json['id'] as String?)?.trim();
    final titleValue = (json['title'] as String?)?.trim();
    return CalendarPageEvent(
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
}
