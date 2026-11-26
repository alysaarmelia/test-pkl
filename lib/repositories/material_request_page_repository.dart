import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/models/material_request.dart';
import '../shared/services/material_request_repository.dart'
    as shared_repository;
import '../shared/utils/material_request_document_service.dart';

abstract class MaterialRequestPageRepository {
  String? get currentUserUid;

  Future<String> resolveRequesterName();

  Future<void> submitDraft(MaterialRequestDraft draft);
}

class MaterialRequestPageRepositoryImpl
    implements MaterialRequestPageRepository {
  MaterialRequestPageRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    shared_repository.MaterialRequestRepository? requestRepository,
    MaterialRequestDocumentService? documentService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _requestRepository =
           requestRepository ?? shared_repository.MaterialRequestRepository(),
       _documentService = documentService ?? MaterialRequestDocumentService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final shared_repository.MaterialRequestRepository _requestRepository;
  final MaterialRequestDocumentService _documentService;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Future<String> resolveRequesterName() async {
    final user = _auth.currentUser;
    if (user == null) return 'Pengorder';

    var resolved = _normalizeName(user.displayName);
    if (resolved.isEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final candidates = [
              data['name'],
              data['fullName'],
              data['displayName'],
            ];
            for (final candidate in candidates) {
              if (candidate is! String) continue;
              final normalized = _normalizeName(candidate);
              if (normalized.isEmpty) continue;
              resolved = normalized;
              break;
            }
          }
        }
      } catch (_) {
        // Ignore profile lookup failures; fallback below.
      }
    }

    if (resolved.isEmpty) {
      resolved = _normalizeName(user.email);
    }

    return resolved.isEmpty ? 'Pengorder' : resolved;
  }

  @override
  Future<void> submitDraft(MaterialRequestDraft draft) async {
    final documents = await _documentService.generate(draft);
    await _requestRepository.createRequest(
      draft: draft,
      docxBytes: documents.docxBytes,
      docxFileName: documents.docFileName,
      pdfBytes: documents.pdfBytes,
      pdfFileName: documents.pdfFileName,
    );
  }

  String _normalizeName(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return '';

    final localPart = value.contains('@') ? value.split('@').first : value;
    final sanitized = localPart.replaceAll(RegExp(r'[_\.\-]+'), ' ').trim();
    final words = sanitized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return localPart;

    final cased = words
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');

    return cased.isEmpty ? localPart : cased;
  }
}
