import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class HomeControllerRepository {
  String? get currentUserUid;

  Stream<Map<String, dynamic>?> watchUserProfile(String uid);
}

class HomeControllerRepositoryImpl implements HomeControllerRepository {
  HomeControllerRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    if (uid.isEmpty) {
      return const Stream<Map<String, dynamic>?>.empty();
    }
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      return snapshot.data();
    });
  }
}
