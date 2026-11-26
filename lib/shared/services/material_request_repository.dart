import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/material_request.dart';

class MaterialRequestRepository {
  MaterialRequestRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String collectionName = 'material_requests';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Future<String> createRequest({
    required MaterialRequestDraft draft,
    required Uint8List docxBytes,
    required String docxFileName,
    required Uint8List pdfBytes,
    required String pdfFileName,
  }) async {
    final initialData = draft.toFirestorePayload()
      ..addAll({
        'documentFileName': docxFileName,
        'pdfFileName': pdfFileName,
      });
    final docRef = await _collection.add(initialData);
    final docStoragePath =
        'material_requests/${docRef.id}/$docxFileName'.replaceAll(' ', '_');
    final pdfStoragePath =
        'material_requests/${docRef.id}/$pdfFileName'.replaceAll(' ', '_');

    try {
      final docUrl = await _uploadFile(
        bytes: docxBytes,
        storagePath: docStoragePath,
        contentType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      final pdfUrl = await _uploadFile(
        bytes: pdfBytes,
        storagePath: pdfStoragePath,
        contentType: 'application/pdf',
      );
      await docRef.update({
        'documentUrl': docUrl,
        'documentStoragePath': docStoragePath,
        'pdfUrl': pdfUrl,
        'pdfStoragePath': pdfStoragePath,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      await docRef.delete();
      rethrow;
    }
  }

  Future<void> approveRequest({
    required MaterialRequest request,
    required String approverName,
    String? approverUid,
    required Uint8List docxBytes,
    required String docxFileName,
    required Uint8List pdfBytes,
    required String pdfFileName,
  }) async {
    final docRef = _collection.doc(request.id);
    final updatedItems = request.items
        .map(
          (item) => item.copyWith(status: MaterialRequestItemStatus.approved),
        )
        .toList(growable: false);

    await _saveRequestWithDocuments(
      docRef: docRef,
      request: request,
      items: updatedItems,
      approverName: approverName,
      approverUid: approverUid,
      docxBytes: docxBytes,
      docxFileName: docxFileName,
      pdfBytes: pdfBytes,
      pdfFileName: pdfFileName,
      forceApproved: true,
    );
  }

  Future<void> markDelivered({
    required String requestId,
    required String receiverName,
    String? receiverUid,
  }) {
    return _collection.doc(requestId).update({
      'status': MaterialRequestStatus.delivered,
      'receivedBy': receiverName,
      'receivedByUid': receiverUid,
      'receivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<MaterialRequest>> watchRequests({int limit = 100}) {
    Query<Map<String, dynamic>> query =
        _collection.orderBy('createdAt', descending: true);
    if (limit > 0) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(MaterialRequest.fromSnapshot)
          .toList(growable: false);
    });
  }

  Future<List<MaterialRequest>> fetchRequests({int limit = 100}) async {
    Query<Map<String, dynamic>> query =
        _collection.orderBy('createdAt', descending: true);
    if (limit > 0) {
      query = query.limit(limit);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map(MaterialRequest.fromSnapshot)
        .toList(growable: false);
  }

  Stream<List<MaterialRequest>> watchRequestsByRequester({
    required String requesterUid,
    int limit = 100,
  }) {
    final query =
        _collection.where('requesterUid', isEqualTo: requesterUid);
    return query.snapshots().map((snapshot) {
      final requests =
          snapshot.docs.map(MaterialRequest.fromSnapshot).toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit > 0 && requests.length > limit) {
        return requests.sublist(0, limit);
      }
      return requests;
    });
  }

  Future<List<MaterialRequest>> fetchRequestsByRequester({
    required String requesterUid,
    int limit = 100,
  }) async {
    final snapshot = await _collection
        .where('requesterUid', isEqualTo: requesterUid)
        .get();
    final requests =
        snapshot.docs.map(MaterialRequest.fromSnapshot).toList();
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit > 0 && requests.length > limit) {
      return requests.sublist(0, limit);
    }
    return requests;
  }

  Future<void> updateItemsWithDocuments({
    required MaterialRequest request,
    required List<MaterialRequestItem> items,
    required Uint8List docxBytes,
    required String docxFileName,
    required Uint8List pdfBytes,
    required String pdfFileName,
    String? approverName,
    String? approverUid,
  }) async {
    final docRef = _collection.doc(request.id);
    await _saveRequestWithDocuments(
      docRef: docRef,
      request: request,
      items: items,
      approverName: approverName,
      approverUid: approverUid,
      docxBytes: docxBytes,
      docxFileName: docxFileName,
      pdfBytes: pdfBytes,
      pdfFileName: pdfFileName,
    );
  }

  Future<String> _uploadFile({
    required Uint8List bytes,
    required String storagePath,
    required String contentType,
  }) async {
    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(contentType: contentType);
    final task = ref.putData(bytes, metadata);
    await task.whenComplete(() {});
    return ref.getDownloadURL();
  }

  Future<void> _saveRequestWithDocuments({
    required DocumentReference<Map<String, dynamic>> docRef,
    required MaterialRequest request,
    required List<MaterialRequestItem> items,
    required Uint8List docxBytes,
    required String docxFileName,
    required Uint8List pdfBytes,
    required String pdfFileName,
    String? approverName,
    String? approverUid,
    bool forceApproved = false,
  }) async {
    final docStoragePath = request.documentStoragePath ??
        'material_requests/${request.id}/$docxFileName'.replaceAll(' ', '_');
    final pdfStoragePath = request.pdfStoragePath ??
        'material_requests/${request.id}/$pdfFileName'.replaceAll(' ', '_');

    final docUrl = await _uploadFile(
      bytes: docxBytes,
      storagePath: docStoragePath,
      contentType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final pdfUrl = await _uploadFile(
      bytes: pdfBytes,
      storagePath: pdfStoragePath,
      contentType: 'application/pdf',
    );

    var nextStatus = request.status;
    if (request.status != MaterialRequestStatus.delivered) {
      if (forceApproved || _allItemsApproved(items)) {
        nextStatus = MaterialRequestStatus.approved;
      } else {
        nextStatus = MaterialRequestStatus.pending;
      }
    }

    final normalizedApproverName = approverName?.trim() ?? '';
    final resolvedApproverName = normalizedApproverName.isNotEmpty
        ? normalizedApproverName
        : request.approverName;
    final resolvedApprovedByUid = approverUid ?? request.approvedByUid;
    String? resolvedApprovedBy;
    if (approverUid != null) {
      resolvedApprovedBy = approverUid;
    } else if (normalizedApproverName.isNotEmpty) {
      resolvedApprovedBy = normalizedApproverName;
    } else if (request.approvedBy?.isNotEmpty == true) {
      resolvedApprovedBy = request.approvedBy;
    } else if (request.approverName.isNotEmpty) {
      resolvedApprovedBy = request.approverName;
    }

    final payload = <String, dynamic>{
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'status': nextStatus,
      'documentUrl': docUrl,
      'documentStoragePath': docStoragePath,
      'documentFileName': docxFileName,
      'pdfUrl': pdfUrl,
      'pdfStoragePath': pdfStoragePath,
      'pdfFileName': pdfFileName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (nextStatus == MaterialRequestStatus.approved) {
      payload.addAll({
        'approverName': resolvedApproverName,
        'approvedBy': resolvedApprovedBy,
        'approvedByUid': resolvedApprovedByUid,
        'approvedAt': FieldValue.serverTimestamp(),
      });
    } else if (nextStatus == MaterialRequestStatus.pending) {
      payload.addAll({
        'approverName': resolvedApproverName,
        'approvedBy': resolvedApprovedBy,
        'approvedByUid': resolvedApprovedByUid,
        'approvedAt': null,
      });
    }

    await docRef.update(payload);
  }

  bool _allItemsApproved(List<MaterialRequestItem> items) {
    return items.isNotEmpty &&
        items.every(
          (item) => item.status == MaterialRequestItemStatus.approved,
        );
  }
}
