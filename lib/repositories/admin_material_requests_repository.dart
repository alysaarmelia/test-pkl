import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/models/material_request.dart';
import '../shared/services/material_request_repository.dart';
import '../shared/utils/material_request_document_service.dart';

abstract class AdminMaterialRequestsRepository {
  String? get currentUserUid;
  String? get currentUserDisplayName;
  String? get currentUserEmail;

  Stream<List<MaterialRequest>> watchRequests({int limit = 200});

  Future<String?> fetchUserDisplayName(String uid);

  Future<MaterialRequestDocumentBundle> generateDocuments(
    MaterialRequestDraft draft, {
    String? baseFileName,
  });

  Future<void> approveRequest({
    required MaterialRequest request,
    required String approverName,
    String? approverUid,
    required MaterialRequestDocumentBundle documents,
  });

  Future<void> updateItemsWithDocuments({
    required MaterialRequest request,
    required List<MaterialRequestItem> items,
    String? approverName,
    String? approverUid,
    required MaterialRequestDocumentBundle documents,
  });

  Future<void> markDelivered({
    required String requestId,
    required String receiverName,
    String? receiverUid,
  });
}

class AdminMaterialRequestsRepositoryImpl
    implements AdminMaterialRequestsRepository {
  AdminMaterialRequestsRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    MaterialRequestRepository? materialRequestRepository,
    MaterialRequestDocumentService? documentService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _materialRequestRepository =
           materialRequestRepository ?? MaterialRequestRepository(),
       _documentService = documentService ?? MaterialRequestDocumentService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final MaterialRequestRepository _materialRequestRepository;
  final MaterialRequestDocumentService _documentService;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  String? get currentUserDisplayName => _auth.currentUser?.displayName;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  Stream<List<MaterialRequest>> watchRequests({int limit = 200}) {
    return _materialRequestRepository.watchRequests(limit: limit);
  }

  @override
  Future<String?> fetchUserDisplayName(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return null;

    final doc = await _firestore.collection('users').doc(trimmed).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final candidates = [data['name'], data['fullName'], data['displayName']];

    for (final candidate in candidates) {
      if (candidate is String) {
        final value = candidate.trim();
        if (value.isNotEmpty) return value;
      }
    }

    return null;
  }

  @override
  Future<MaterialRequestDocumentBundle> generateDocuments(
    MaterialRequestDraft draft, {
    String? baseFileName,
  }) {
    return _documentService.generate(draft, baseFileName: baseFileName);
  }

  @override
  Future<void> approveRequest({
    required MaterialRequest request,
    required String approverName,
    String? approverUid,
    required MaterialRequestDocumentBundle documents,
  }) {
    return _materialRequestRepository.approveRequest(
      request: request,
      approverName: approverName,
      approverUid: approverUid,
      docxBytes: documents.docxBytes,
      docxFileName: documents.docFileName,
      pdfBytes: documents.pdfBytes,
      pdfFileName: documents.pdfFileName,
    );
  }

  @override
  Future<void> updateItemsWithDocuments({
    required MaterialRequest request,
    required List<MaterialRequestItem> items,
    String? approverName,
    String? approverUid,
    required MaterialRequestDocumentBundle documents,
  }) {
    return _materialRequestRepository.updateItemsWithDocuments(
      request: request,
      items: items,
      approverName: approverName,
      approverUid: approverUid,
      docxBytes: documents.docxBytes,
      docxFileName: documents.docFileName,
      pdfBytes: documents.pdfBytes,
      pdfFileName: documents.pdfFileName,
    );
  }

  @override
  Future<void> markDelivered({
    required String requestId,
    required String receiverName,
    String? receiverUid,
  }) {
    return _materialRequestRepository.markDelivered(
      requestId: requestId,
      receiverName: receiverName,
      receiverUid: receiverUid,
    );
  }
}
