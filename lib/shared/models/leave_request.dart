import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveRequestStatus { pending, approved, rejected }

LeaveRequestStatus leaveRequestStatusFromString(String? value) {
  final normalized = value?.trim().toLowerCase();
  switch (normalized) {
    case 'approved':
    case 'approve':
    case 'accept':
    case 'accepted':
    case 'disetujui':
      return LeaveRequestStatus.approved;
    case 'rejected':
    case 'reject':
    case 'declined':
    case 'denied':
    case 'ditolak':
      return LeaveRequestStatus.rejected;
    case 'pending':
    case 'awaiting':
    case 'waiting':
    case 'menunggu':
    default:
      return LeaveRequestStatus.pending;
  }
}

String leaveRequestStatusToString(LeaveRequestStatus status) {
  switch (status) {
    case LeaveRequestStatus.approved:
      return 'approved';
    case LeaveRequestStatus.rejected:
      return 'rejected';
    case LeaveRequestStatus.pending:
      return 'pending';
  }
}

String leaveRequestStatusLabel(LeaveRequestStatus status) {
  switch (status) {
    case LeaveRequestStatus.approved:
      return 'Disetujui';
    case LeaveRequestStatus.rejected:
      return 'Ditolak';
    case LeaveRequestStatus.pending:
      return 'Menunggu';
  }
}

class LeaveRequest {
  LeaveRequest({
    required this.id,
    required this.uid,
    required this.kind,
    required this.reason,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    required this.status,
    this.attachments = const <LeaveAttachment>[],
    this.updatedAt,
    this.approverUid,
    this.approverEmail,
    this.decisionNote,
    this.requesterName,
    this.requesterEmail,
    this.approverName,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? raw,
  })  : extra = extra ?? const <String, dynamic>{},
        raw = raw ?? const <String, dynamic>{};

  factory LeaveRequest.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LeaveRequest(
      id: doc.id,
      uid: _asString(data['uid']) ?? '',
      kind: _asString(data['kind']) ?? _asString(data['type']) ?? '',
      reason: _asString(data['reason']) ?? '',
      startAt: _asDate(data['startAt']) ??
          _asDate(data['startDate']) ??
          DateTime.fromMillisecondsSinceEpoch(
            _asInt(data['startEpoch']) ?? 0,
            isUtc: true,
          ),
      endAt: _asDate(data['endAt']) ??
          _asDate(data['endDate']) ??
          DateTime.fromMillisecondsSinceEpoch(
            _asInt(data['endEpoch']) ?? 0,
            isUtc: true,
          ),
      createdAt: _asDate(data['createdAt']) ??
          _asDate(data['date']) ??
          DateTime.now(),
      attachments: _attachmentsFromList(data['attachments']),
      updatedAt: _asDate(data['updatedAt']),
      status: leaveRequestStatusFromString(
        _asString(data['status']) ?? _asString(data['state']),
      ),
      approverUid: _asString(data['decisionBy']) ??
          _asString(data['approverUid']) ??
          _asString(data['approvedBy']),
      approverEmail: _asString(data['decisionByEmail']) ??
          _asString(data['approverEmail']),
      decisionNote: _asString(data['decisionNote']) ?? _asString(data['note']),
      requesterName: _asString(data['requesterName']) ??
          _asString(data['applicantName']) ??
          _asString(data['userName']) ??
          _asString(data['username']) ??
          _asString(data['fullName']) ??
          _asString(data['displayName']) ??
          _asString(data['name']) ??
          _asString(data['employeeName']),
      requesterEmail: _asString(data['requesterEmail']) ??
          _asString(data['applicantEmail']) ??
          _asString(data['userEmail']) ??
          _asString(data['email']) ??
          _asString(data['contactEmail']),
      approverName: _asString(data['approverName']) ??
          _asString(data['approverDisplayName']) ??
          _asString(data['approverFullName']) ??
          _asString(data['approverUsername']) ??
          _asString(data['decisionByName']) ??
          _asString(data['decisionByDisplayName']) ??
          _asString(data['decisionByFullName']) ??
          _asString(data['name']) ??
          _asString(data['displayName']) ??
          _asString(data['fullName']),
      extra: _asMap(data['extra']) ??
          _pickKnownExtras(data, const [
            'startTimeText',
            'endTimeText',
            'startMinutes',
            'endMinutes',
            'daySpan',
            'requestDate',
            'startDateText',
            'endDateText',
          ]),
      raw: Map<String, dynamic>.from(data),
    );
  }

  final String id;
  final String uid;
  final String kind; // 'cuti' atau 'izin'
  final String reason;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime createdAt;
  final LeaveRequestStatus status;
  final List<LeaveAttachment> attachments;
  final DateTime? updatedAt;
  final String? approverUid;
  final String? approverEmail;
  final String? decisionNote;
  final String? requesterName;
  final String? requesterEmail;
  final String? approverName;
  final Map<String, dynamic> extra;
  final Map<String, dynamic> raw;

  bool get isLeave => kind.toLowerCase() == 'cuti' || kind == 'leave';
  bool get isPermission => kind.toLowerCase() == 'izin' || kind == 'permission';
  bool get isPending => status == LeaveRequestStatus.pending;
  bool get isApproved => status == LeaveRequestStatus.approved;
  bool get isRejected => status == LeaveRequestStatus.rejected;

  LeaveRequest copyWith({
    String? id,
    String? uid,
    String? kind,
    String? reason,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? createdAt,
    LeaveRequestStatus? status,
    List<LeaveAttachment>? attachments,
    DateTime? updatedAt,
    String? approverUid,
    String? approverEmail,
    String? decisionNote,
    String? requesterName,
    String? requesterEmail,
    String? approverName,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? raw,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      kind: kind ?? this.kind,
      reason: reason ?? this.reason,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      updatedAt: updatedAt ?? this.updatedAt,
      approverUid: approverUid ?? this.approverUid,
      approverEmail: approverEmail ?? this.approverEmail,
      decisionNote: decisionNote ?? this.decisionNote,
      requesterName: requesterName ?? this.requesterName,
      requesterEmail: requesterEmail ?? this.requesterEmail,
      approverName: approverName ?? this.approverName,
      extra: extra ?? this.extra,
      raw: raw ?? this.raw,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'kind': kind,
      'reason': reason,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': leaveRequestStatusToString(status),
      if (approverUid != null) 'approverUid': approverUid,
      if (approverEmail != null) 'approverEmail': approverEmail,
      if (approverName != null && approverName!.trim().isNotEmpty)
        'approverName': approverName!.trim(),
      if (requesterName != null && requesterName!.trim().isNotEmpty)
        'requesterName': requesterName!.trim(),
      if (requesterEmail != null && requesterEmail!.trim().isNotEmpty)
        'requesterEmail': requesterEmail!.trim(),
      if (decisionNote != null) 'decisionNote': decisionNote,
      if (attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toMap()).toList(),
      if (extra.isNotEmpty) 'extra': extra,
    }..removeWhere((key, value) => value == null);
  }

  static Map<String, dynamic> _pickKnownExtras(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    return {
      for (final key in keys)
        if (source.containsKey(key)) key: source[key],
    };
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is int) {
      if ('$value'.length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }
}

class LeaveAttachment {
  LeaveAttachment({
    required this.name,
    required this.url,
    required this.storagePath,
    this.contentType,
    this.size,
  });

  final String name;
  final String url;
  final String storagePath;
  final String? contentType;
  final int? size;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'storagePath': storagePath,
      if (contentType != null) 'contentType': contentType,
      if (size != null) 'size': size,
    };
  }

  factory LeaveAttachment.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return LeaveAttachment(name: '', url: '', storagePath: '');
    }
    return LeaveAttachment(
      name: LeaveRequest._asString(data['name']) ?? '',
      url: LeaveRequest._asString(data['url']) ?? '',
      storagePath: LeaveRequest._asString(data['storagePath']) ?? '',
      contentType: LeaveRequest._asString(data['contentType']),
      size: LeaveRequest._asInt(data['size']),
    );
  }
}

List<LeaveAttachment> _attachmentsFromList(dynamic value) {
  if (value is List) {
    return value
        .map(
          (entry) => LeaveAttachment.fromMap(
            entry is Map<String, dynamic>
                ? entry
                : (entry is Map
                    ? entry.map((key, value) => MapEntry('$key', value))
                    : null),
          ),
        )
        .where((att) => att.url.isNotEmpty)
        .toList(growable: false);
  }
  return const <LeaveAttachment>[];
}
