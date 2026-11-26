import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/models/material_request.dart';
import '../shared/services/material_request_repository.dart';

abstract class MaterialRequestTrackingRepository {
  String? get currentUserUid;
  String get currentUserDisplayName;

  Stream<List<MaterialRequest>> watchRequestsByRequester({
    required String requesterUid,
    int limit,
  });

  Future<void> markDelivered({
    required String requestId,
    required String receiverName,
    String? receiverUid,
  });

  Future<String?> fetchUserDisplayName(String uid);
}

class MaterialRequestTrackingRepositoryImpl
    implements MaterialRequestTrackingRepository {
  MaterialRequestTrackingRepositoryImpl({
    MaterialRequestRepository? materialRequestRepository,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _materialRequestRepository =
           materialRequestRepository ?? MaterialRequestRepository(),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final MaterialRequestRepository _materialRequestRepository;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  String get currentUserDisplayName {
    final user = _auth.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Pengorder';
  }

  @override
  Stream<List<MaterialRequest>> watchRequestsByRequester({
    required String requesterUid,
    int limit = 100,
  }) {
    return _materialRequestRepository.watchRequestsByRequester(
      requesterUid: requesterUid,
      limit: limit,
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
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }
}
