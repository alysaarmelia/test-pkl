import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leave_request.dart';

class LeaveRequestRepository {
  LeaveRequestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionName = 'leave_requests';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Future<String> submitLeave({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    Map<String, dynamic>? metadata,
    List<LeaveAttachment> attachments = const <LeaveAttachment>[],
  }) {
    final startAt = DateTime(startDate.year, startDate.month, startDate.day);
    final endAt = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );
    final daySpan = endAt.difference(startAt).inDays + 1;
    return _submit(
      uid: uid,
      kind: 'cuti',
      startAt: startAt,
      endAt: endAt,
      reason: reason,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      attachments: attachments,
      extra: {
        'startDateText': _formatDate(startDate),
        'endDateText': _formatDate(endDate),
        'daySpan': daySpan,
        if (metadata != null) ...metadata,
      },
    );
  }

  Future<String> submitPermission({
    required String uid,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    Map<String, dynamic>? metadata,
    List<LeaveAttachment> attachments = const <LeaveAttachment>[],
  }) {
    return _submit(
      uid: uid,
      kind: 'izin',
      startAt: startAt,
      endAt: endAt,
      reason: reason,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      attachments: attachments,
      extra: metadata,
    );
  }

  Future<String> _submit({
    required String uid,
    required String kind,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    List<LeaveAttachment> attachments = const <LeaveAttachment>[],
    Map<String, dynamic>? extra,
  }) async {
    final now = Timestamp.now();
    final doc = await _collection.add({
      'uid': uid,
      'kind': kind,
      'reason': reason,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'status': leaveRequestStatusToString(LeaveRequestStatus.pending),
      'createdAt': now,
      'updatedAt': now,
      if (requesterName != null) 'requesterName': requesterName,
      if (requesterEmail != null) 'requesterEmail': requesterEmail,
      if (attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toMap()).toList(),
      if (extra != null) ...extra,
    });
    return doc.id;
  }

  Stream<List<LeaveRequest>> watchUserRequests({
    required String uid,
    String? kind,
    int limit = 60,
  }) {
    Query<Map<String, dynamic>> query = _collection.where(
      'uid',
      isEqualTo: uid,
    );
    if (kind != null && kind.isNotEmpty) {
      query = query.where('kind', isEqualTo: kind);
    }
    return query.snapshots(includeMetadataChanges: true).asyncMap((
      snapshot,
    ) async {
      try {
        final serverSnapshot = await query.get(
          const GetOptions(source: Source.server),
        );
        return _limit(_mapDocs(serverSnapshot.docs), limit);
      } catch (_) {
        return _limit(_mapDocs(snapshot.docs), limit);
      }
    });
  }

  Stream<LeaveRequest?> watchRequestById(String requestId) {
    return _collection
        .doc(requestId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return LeaveRequest.fromSnapshot(snapshot);
        });
  }

  Future<String> fetchUserNameByUid(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return '';
    try {
      final doc = await _firestore.collection('users').doc(trimmed).get();
      if (!doc.exists) return '';
      final data = doc.data();
      final picked = data?['name'];
      if (picked is! String) return '';
      final value = picked.trim();
      return value.isEmpty ? '' : value;
    } catch (_) {
      return '';
    }
  }

  Future<List<LeaveRequest>> fetchUserRequests({
    required String uid,
    String? kind,
    int limit = 60,
    bool preferServer = false,
  }) async {
    Query<Map<String, dynamic>> query = _collection.where(
      'uid',
      isEqualTo: uid,
    );
    if (kind != null && kind.isNotEmpty) {
      query = query.where('kind', isEqualTo: kind);
    }

    final getOptions = preferServer
        ? const GetOptions(source: Source.server)
        : null;

    final snapshot = getOptions != null
        ? await query.get(getOptions)
        : await query.get();
    final items = _mapDocs(snapshot.docs);
    return _limit(items, limit);
  }

  Stream<List<LeaveRequest>> watchRequests({
    String? kind,
    LeaveRequestStatus? status,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> query = _collection;
    if (kind != null && kind.isNotEmpty) {
      query = query.where('kind', isEqualTo: kind);
    }
    if (status != null) {
      query = query.where(
        'status',
        isEqualTo: leaveRequestStatusToString(status),
      );
    }
    return query.snapshots().map((snapshot) {
      final items = _mapDocs(snapshot.docs);
      return _limit(items, limit);
    });
  }

  Future<void> updateStatus({
    required String requestId,
    required LeaveRequestStatus status,
    String? decidedByUid,
    String? decidedByEmail,
    String? decidedByName,
    String? decisionNote,
  }) async {
    final docRef = _collection.doc(requestId);
    await docRef.update({
      'status': leaveRequestStatusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
      'decisionAt': FieldValue.serverTimestamp(),
      if (decidedByUid != null) 'decisionBy': decidedByUid,
      if (decidedByEmail != null) 'decisionByEmail': decidedByEmail,
      if (decidedByName != null) 'decisionByName': decidedByName,
      if (decidedByName != null) 'approverName': decidedByName,
      if (decisionNote != null && decisionNote.trim().isNotEmpty)
        'decisionNote': decisionNote.trim(),
    });
  }

  Future<void> deleteRequest(String requestId) {
    return _collection.doc(requestId).delete();
  }

  Future<void> addAttachments({
    required String requestId,
    required List<LeaveAttachment> attachments,
  }) async {
    await _collection.doc(requestId).update({
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<LeaveRequest> _mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map(LeaveRequest.fromSnapshot).toList(growable: false)
      ..sort((a, b) => _compareDate(b.createdAt, a.createdAt));
  }

  List<LeaveRequest> _limit(List<LeaveRequest> items, int limit) {
    if (items.length > limit) {
      return items.sublist(0, limit);
    }
    return items;
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static int _compareDate(DateTime? a, DateTime? b) {
    final left = a ?? b ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b ?? a ?? DateTime.fromMillisecondsSinceEpoch(0);
    return left.compareTo(right);
  }
}
