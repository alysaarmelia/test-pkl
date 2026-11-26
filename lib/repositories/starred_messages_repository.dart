import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StarredMessageRecord {
  const StarredMessageRecord({
    required this.id,
    required this.text,
    required this.type,
    required this.sortTime,
    required this.displayTime,
    required this.isDeleted,
    required this.deletedFor,
  });

  final String id;
  final String text;
  final String type;
  final DateTime? sortTime;
  final DateTime? displayTime;
  final bool isDeleted;
  final List<String> deletedFor;
}

abstract class StarredMessagesRepository {
  String get currentUserUid;

  Future<String?> resolveChatId({String? chatId, String? peerUid});

  Stream<List<StarredMessageRecord>> watchStarredBy({
    required String chatId,
    required String myUid,
  });

  Stream<List<StarredMessageRecord>> watchLegacyStarred({
    required String chatId,
  });

  Future<void> removeStar({
    required String chatId,
    required String messageId,
    required String myUid,
  });
}

class StarredMessagesRepositoryImpl implements StarredMessagesRepository {
  StarredMessagesRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  String get currentUserUid => _auth.currentUser?.uid ?? '';

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  StarredMessageRecord _mapMessageDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final text = (data['text'] ?? data['message'] ?? '').toString();
    final type =
        (data['type'] ??
                (data['imageUrl'] != null || data['photoUrl'] != null
                    ? 'image'
                    : (data['fileUrl'] != null || data['url'] != null
                          ? 'file'
                          : 'text')))
            .toString();

    final sortTime = _toDateTime(
      data['starredAt'] ?? data['createdAt'] ?? data['ts'],
    );
    final displayTime = _toDateTime(data['ts'] ?? data['createdAt']);
    final isDeleted = (data['isDeleted'] ?? false) == true;
    final deletedFor = List<String>.from(
      (data['deletedFor'] ?? const []) as List,
    );

    return StarredMessageRecord(
      id: doc.id,
      text: text,
      type: type,
      sortTime: sortTime,
      displayTime: displayTime,
      isDeleted: isDeleted,
      deletedFor: deletedFor,
    );
  }

  @override
  Future<String?> resolveChatId({String? chatId, String? peerUid}) async {
    if (chatId != null && chatId.isNotEmpty) return chatId;
    final myUid = currentUserUid;
    if (myUid.isEmpty || peerUid == null || peerUid.isEmpty) return null;

    final a = myUid.compareTo(peerUid) <= 0 ? myUid : peerUid;
    final b = myUid.compareTo(peerUid) <= 0 ? peerUid : myUid;
    final id1 = '${a}_$b';
    final id2 = '${b}_$a';
    final chats = _firestore.collection('chats');
    final d1 = await chats.doc(id1).get();
    if (d1.exists) return id1;
    final d2 = await chats.doc(id2).get();
    if (d2.exists) return id2;
    return id1;
  }

  @override
  Stream<List<StarredMessageRecord>> watchStarredBy({
    required String chatId,
    required String myUid,
  }) {
    if (chatId.isEmpty || myUid.isEmpty) return const Stream.empty();
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('starredBy', arrayContains: myUid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(_mapMessageDoc).toList(growable: false);
        });
  }

  @override
  Stream<List<StarredMessageRecord>> watchLegacyStarred({
    required String chatId,
  }) {
    if (chatId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('starred', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(_mapMessageDoc).toList(growable: false);
        });
  }

  @override
  Future<void> removeStar({
    required String chatId,
    required String messageId,
    required String myUid,
  }) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({
          'starredBy': FieldValue.arrayRemove([myUid]),
        }, SetOptions(merge: true));
  }
}
