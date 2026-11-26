import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class MenuGridRepository {
  String? get currentUserUid;

  Stream<String?> watchAuthUserIds();

  Stream<Map<String, dynamic>?> watchUserProfile(String uid);
}

class MenuGridRepositoryImpl implements MenuGridRepository {
  MenuGridRepositoryImpl({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Stream<String?> watchAuthUserIds() {
    return _auth.userChanges().map((user) => user?.uid);
  }

  @override
  Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return const Stream<Map<String, dynamic>?>.empty();
    }
    return _firestore
        .collection('users')
        .doc(trimmedUid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }
}
