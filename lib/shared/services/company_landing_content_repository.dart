import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company_landing_content.dart';

class CompanyLandingContentRepository {
  CompanyLandingContentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.collection('company_landing_content').doc('primary');

  Stream<CompanyLandingContent> watchContent() {
    return _docRef.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return CompanyLandingContent.defaults();
      }
      return CompanyLandingContent.fromSnapshot(snapshot);
    });
  }

  Future<CompanyLandingContent> fetchContent() async {
    final snapshot = await _docRef.get();
    if (!snapshot.exists) {
      return CompanyLandingContent.defaults();
    }
    return CompanyLandingContent.fromSnapshot(snapshot);
  }

  Future<void> saveContent(CompanyLandingContent content) async {
    await _docRef.set(
      {
        ...content.toMap(),
        'updatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }
}
