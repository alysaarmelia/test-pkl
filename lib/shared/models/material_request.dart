import 'package:cloud_firestore/cloud_firestore.dart';

class MaterialRequestItem {
  MaterialRequestItem({
    required this.no,
    required this.name,
    required this.quantity,
    this.status = MaterialRequestItemStatus.pending,
  });

  final int no;
  final String name;
  final String quantity;
  // pending/approved status for each material line
  final String status;

  MaterialRequestItem copyWith({
    int? no,
    String? name,
    String? quantity,
    String? status,
  }) {
    return MaterialRequestItem(
      no: no ?? this.no,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'no': no,
      'name': name,
      'quantity': quantity,
      'status': status,
    };
  }

  factory MaterialRequestItem.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return MaterialRequestItem(
        no: 0,
        name: '',
        quantity: '',
      );
    }
    return MaterialRequestItem(
      no: _asInt(data['no']) ?? 0,
      name: _asString(data['name']) ?? '',
      quantity: _asString(data['quantity']) ?? '',
      status: _asString(data['status']) ?? MaterialRequestItemStatus.pending,
    );
  }
}

class MaterialRequestDraft {
  MaterialRequestDraft({
    required this.companyName,
    required this.projectName,
    required this.requestDate,
    required this.requesterName,
    required this.requesterUid,
    required this.items,
    this.approverName,
  });

  final String companyName;
  final String projectName;
  final DateTime requestDate;
  final String requesterName;
  final String requesterUid;
  final String? approverName;
  final List<MaterialRequestItem> items;

  Map<String, dynamic> toFirestorePayload() {
    final now = Timestamp.now();
    return {
      'companyName': companyName,
      'projectName': projectName,
      'requestDate': Timestamp.fromDate(requestDate),
      'requesterName': requesterName,
      'requesterUid': requesterUid,
      'approverName': approverName ?? '',
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'createdAt': now,
      'updatedAt': now,
      'status': MaterialRequestStatus.pending,
      'approvedBy': null,
      'approvedByUid': null,
      'approvedAt': null,
      'receivedBy': null,
      'receivedByUid': null,
      'receivedAt': null,
    };
  }

  MaterialRequestDraft copyWith({
    String? companyName,
    String? projectName,
    DateTime? requestDate,
    String? requesterName,
    String? requesterUid,
    String? approverName,
    List<MaterialRequestItem>? items,
  }) {
    return MaterialRequestDraft(
      companyName: companyName ?? this.companyName,
      projectName: projectName ?? this.projectName,
      requestDate: requestDate ?? this.requestDate,
      requesterName: requesterName ?? this.requesterName,
      requesterUid: requesterUid ?? this.requesterUid,
      approverName: approverName ?? this.approverName,
      items: items ?? this.items,
    );
  }

  factory MaterialRequestDraft.fromRequest(MaterialRequest request) {
    return MaterialRequestDraft(
      companyName: request.companyName,
      projectName: request.projectName,
      requestDate: request.requestDate,
      requesterName: request.requesterName,
      requesterUid: request.requesterUid,
      approverName: request.approverName?.isNotEmpty == true
          ? request.approverName
          : null,
      items: request.items,
    );
  }
}

class MaterialRequest {
  MaterialRequest({
    required this.id,
    required this.companyName,
    required this.projectName,
    required this.requestDate,
    required this.requesterName,
    required this.requesterUid,
    required this.approverName,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.approvedByUid,
    this.receivedBy,
    this.receivedByUid,
    this.receivedAt,
    this.documentUrl,
    this.documentStoragePath,
    this.documentFileName,
    this.pdfUrl,
    this.pdfStoragePath,
    this.pdfFileName,
  });

  factory MaterialRequest.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return MaterialRequest(
      id: snapshot.id,
      companyName: _asString(data['companyName']) ?? '',
      projectName: _asString(data['projectName']) ?? '',
      requestDate: _asDate(data['requestDate']) ?? DateTime.now(),
      requesterName: _asString(data['requesterName']) ?? '',
      requesterUid: _asString(data['requesterUid']) ?? '',
      approverName: _asString(data['approverName']) ?? '',
      items: _itemsFromList(data['items']),
      status: _asString(data['status']) ?? MaterialRequestStatus.pending,
      createdAt: _asDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _asDate(data['updatedAt']) ?? DateTime.now(),
      approvedBy: _asString(data['approvedBy']),
      approvedAt: _asDate(data['approvedAt']),
      receivedBy: _asString(data['receivedBy']),
      approvedByUid: _asString(data['approvedByUid']),
      receivedByUid: _asString(data['receivedByUid']),
      receivedAt: _asDate(data['receivedAt']),
      documentUrl: _asString(data['documentUrl']),
      documentStoragePath: _asString(data['documentStoragePath']),
      documentFileName: _asString(data['documentFileName']),
      pdfUrl: _asString(data['pdfUrl']),
      pdfStoragePath: _asString(data['pdfStoragePath']),
      pdfFileName: _asString(data['pdfFileName']),
    );
  }

  final String id;
  final String companyName;
  final String projectName;
  final DateTime requestDate;
  final String requesterName;
  final String requesterUid;
  final String approverName;
  final List<MaterialRequestItem> items;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final String? approvedByUid;
  final DateTime? approvedAt;
  final String? receivedBy;
  final String? receivedByUid;
  final DateTime? receivedAt;
  final String? documentUrl;
  final String? documentStoragePath;
  final String? documentFileName;
  final String? pdfUrl;
  final String? pdfStoragePath;
  final String? pdfFileName;
}

class MaterialRequestStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const delivered = 'delivered';
}

class MaterialRequestItemStatus {
  static const pending = 'pending';
  static const approved = 'approved';
}

List<MaterialRequestItem> _itemsFromList(dynamic value) {
  if (value is List) {
    return value
        .map((item) =>
            MaterialRequestItem.fromMap(item as Map<String, dynamic>?))
        .toList(growable: false);
  }
  return const <MaterialRequestItem>[];
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
  if (value is String) return int.tryParse(value);
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
