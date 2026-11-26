import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company_profile.dart';

class CompanyProfileRepository {
  CompanyProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('company_profiles');

  Stream<List<CompanyProfileData>> watchPublishedProfiles() {
    return _collection
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(CompanyProfileData.fromSnapshot)
              .toList(growable: false);
          items.sort(_sortProfiles);
          return items;
        });
  }

  Stream<List<CompanyProfileData>> watchAllProfiles() {
    return _collection.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(CompanyProfileData.fromSnapshot)
          .toList(growable: false);
      items.sort(_sortProfiles);
      return items;
    });
  }

  Future<CompanyProfileData?> fetchProfileById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return CompanyProfileData.fromSnapshot(doc);
  }

  Future<void> saveProfile(CompanyProfileData data) async {
    final docRef = _collection.doc(data.id);
    final now = Timestamp.now();
    final createdAt = data.createdAt ?? now.toDate();
    await docRef.set(
      {
        ...data.toFirestorePayload(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteProfile(String id) {
    return _collection.doc(id).delete();
  }

  String generateId() => _collection.doc().id;

  static int _sortProfiles(
    CompanyProfileData a,
    CompanyProfileData b,
  ) {
    final orderCompare = a.sortOrder.compareTo(b.sortOrder);
    if (orderCompare != 0) return orderCompare;
    return a.displayName.compareTo(b.displayName);
  }
}
