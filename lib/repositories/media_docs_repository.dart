import 'package:cloud_firestore/cloud_firestore.dart';

class MediaDocsMessageRecord {
  const MediaDocsMessageRecord({
    required this.id,
    required this.type,
    required this.imageUrl,
    required this.fileUrl,
    required this.fileName,
  });

  final String id;
  final String type;
  final String imageUrl;
  final String fileUrl;
  final String fileName;
}

abstract class MediaDocsRepository {
  Stream<List<MediaDocsMessageRecord>> watchMediaMessages(String chatId);

  Stream<List<MediaDocsMessageRecord>> watchFileMessages(String chatId);

  Future<void> deleteMessages({
    required String chatId,
    required List<String> messageIds,
  });

  Future<List<String>> fetchMessageIdsByType({
    required String chatId,
    required String type,
  });
}

class MediaDocsRepositoryImpl implements MediaDocsRepository {
  MediaDocsRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  MediaDocsMessageRecord _mapDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final type = (data['type'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? data['photoUrl'] ?? data['url'] ?? '')
        .toString();
    final fileUrl = (data['fileUrl'] ?? data['url'] ?? '').toString();
    final fileName = (data['fileName'] ?? 'Dokumen').toString();
    return MediaDocsMessageRecord(
      id: doc.id,
      type: type,
      imageUrl: imageUrl,
      fileUrl: fileUrl,
      fileName: fileName,
    );
  }

  @override
  Stream<List<MediaDocsMessageRecord>> watchMediaMessages(String chatId) {
    if (chatId.isEmpty) return Stream.value(const <MediaDocsMessageRecord>[]);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('type', isEqualTo: 'image')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(_mapDoc).toList(growable: false);
        });
  }

  @override
  Stream<List<MediaDocsMessageRecord>> watchFileMessages(String chatId) {
    if (chatId.isEmpty) return Stream.value(const <MediaDocsMessageRecord>[]);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('type', isEqualTo: 'file')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(_mapDoc).toList(growable: false);
        });
  }

  @override
  Future<void> deleteMessages({
    required String chatId,
    required List<String> messageIds,
  }) async {
    if (chatId.isEmpty || messageIds.isEmpty) return;

    final col = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages');
    final batch = _firestore.batch();
    for (final id in messageIds) {
      if (id.isEmpty) continue;
      batch.delete(col.doc(id));
    }
    await batch.commit();
  }

  @override
  Future<List<String>> fetchMessageIdsByType({
    required String chatId,
    required String type,
  }) async {
    if (chatId.isEmpty || type.isEmpty) return const <String>[];

    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('type', isEqualTo: type)
        .get();
    return snapshot.docs.map((doc) => doc.id).toList(growable: false);
  }
}
