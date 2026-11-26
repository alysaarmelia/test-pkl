class AttendanceRecord {
  final DateTime date;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final double? lat;
  final double? lon;
  final String? project;
  final String? note;

  AttendanceRecord({
    required this.date,
    this.checkInAt,
    this.checkOutAt,
    this.lat,
    this.lon,
    this.project,
    this.note,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
    checkInAt: j['checkInAt'] != null
        ? DateTime.tryParse(j['checkInAt'])
        : null,
    checkOutAt: j['checkOutAt'] != null
        ? DateTime.tryParse(j['checkOutAt'])
        : null,
    lat: (j['lat'] is num) ? (j['lat'] as num).toDouble() : null,
    lon: (j['lon'] is num) ? (j['lon'] as num).toDouble() : null,
    project: j['project'],
    note: j['note'],
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'checkInAt': checkInAt?.toIso8601String(),
    'checkOutAt': checkOutAt?.toIso8601String(),
    'lat': lat,
    'lon': lon,
    'project': project,
    'note': note,
  };
}
