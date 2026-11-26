import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page_repository.dart';

class UserProfilePeerProfile {
  const UserProfilePeerProfile({
    required this.uid,
    required this.name,
    required this.role,
    required this.pin,
    required this.photoUrl,
  });

  final String uid;
  final String name;
  final String role;
  final String pin;
  final String photoUrl;
}

class UserProfileFilePreview {
  const UserProfileFilePreview({required this.url, required this.name});

  final String url;
  final String name;
}

class UserProfileMediaDocsPreview {
  const UserProfileMediaDocsPreview({
    this.images = const <String>[],
    this.files = const <UserProfileFilePreview>[],
  });

  final List<String> images;
  final List<UserProfileFilePreview> files;
}

class UserProfileStarredSummary {
  const UserProfileStarredSummary({required this.text, this.timestamp});

  final String text;
  final DateTime? timestamp;
}

enum UserProfileAddContactStatus {
  success,
  partial,
  notLoggedIn,
  self,
  failure,
}

class UserProfileAddContactResult {
  const UserProfileAddContactResult({
    required this.status,
    required this.message,
  });

  final UserProfileAddContactStatus status;
  final String message;
}

class UserProfileClearChatResult {
  const UserProfileClearChatResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

abstract class UserProfileRepository {
  String get currentUserUid;
  String? get currentUserDisplayName;
  String? get currentUserPhotoUrl;

  Future<String?> resolveChatId({
    required String myUid,
    required String peerUid,
  });

  Stream<UserProfilePeerProfile> watchPeerProfile(String peerUid);

  Stream<bool> watchIsInMyContacts({
    required String myUid,
    required String peerUid,
  });

  Future<UserProfileAddContactResult> addContactForBoth({
    required String myUid,
    required String peerUid,
    required UserProfilePeerProfile peerProfile,
  });

  Future<UserProfileClearChatResult> clearChatHistory(String chatId);

  Stream<UserProfileMediaDocsPreview> watchMediaDocsPreview(String chatId);

  Stream<UserProfileStarredSummary?> watchStarredSummary({
    required String chatId,
    required String myUid,
  });
}

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  String get currentUserUid => _auth.currentUser?.uid ?? '';

  @override
  String? get currentUserDisplayName => _auth.currentUser?.displayName;

  @override
  String? get currentUserPhotoUrl => _auth.currentUser?.photoURL;

  String _resolveName(Map<String, dynamic> data, {String fallback = 'Teman'}) {
    final candidates = [
      data['name'],
      data['displayName'],
      data['fullName'],
      data['username'],
      data['userName'],
      fallback,
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  String _resolvePin(Map<String, dynamic> data, {String fallback = ''}) {
    final candidates = [
      data['pin'],
      data['userPin'],
      data['PIN'],
      data['pinUpper'],
      data['chatPin'],
      fallback,
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty) return value.toUpperCase();
    }
    return fallback;
  }

  String _resolveAvatar(Map<String, dynamic> data, {String fallback = ''}) {
    final candidates = [
      data['avatarUrl'],
      data['photoUrl'],
      data['profilePhoto'],
      data['photoURL'],
      fallback,
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  DateTime? _resolveDate(dynamic rawTs) {
    if (rawTs is Timestamp) return rawTs.toDate();
    if (rawTs is DateTime) return rawTs;
    return null;
  }

  UserProfilePeerProfile _mapPeerProfile(
    String uid,
    Map<String, dynamic> data,
  ) {
    return UserProfilePeerProfile(
      uid: uid,
      name: _resolveName(data, fallback: 'Pengguna'),
      role: (data['role'] ?? '').toString(),
      pin: _resolvePin(data),
      photoUrl: _resolveAvatar(data),
    );
  }

  @override
  Future<String?> resolveChatId({
    required String myUid,
    required String peerUid,
  }) async {
    if (myUid.isEmpty || peerUid.isEmpty) return null;

    try {
      final qs = await _firestore
          .collection('chats')
          .where('members', arrayContains: myUid)
          .limit(50)
          .get();
      for (final doc in qs.docs) {
        final data = doc.data();
        final members = (data['members'] is List)
            ? List.from(data['members'])
            : <dynamic>[];
        final type = (data['type'] ?? 'dm').toString();
        if (type == 'dm' && members.contains(peerUid)) {
          return doc.id;
        }
      }
    } catch (_) {}

    final a = myUid.compareTo(peerUid) <= 0 ? myUid : peerUid;
    final b = myUid.compareTo(peerUid) <= 0 ? peerUid : myUid;
    final id1 = '${a}_$b';
    final id2 = '${b}_$a';
    final chats = _firestore.collection('chats');
    try {
      final d1 = await chats.doc(id1).get();
      if (d1.exists) return id1;
      final d2 = await chats.doc(id2).get();
      if (d2.exists) return id2;
    } catch (_) {}

    return null;
  }

  @override
  Stream<UserProfilePeerProfile> watchPeerProfile(String peerUid) {
    if (peerUid.isEmpty) {
      return Stream.value(
        const UserProfilePeerProfile(
          uid: '',
          name: 'Pengguna',
          role: '',
          pin: '',
          photoUrl: '',
        ),
      );
    }
    return _firestore.collection('users').doc(peerUid).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return _mapPeerProfile(peerUid, data);
    });
  }

  @override
  Stream<bool> watchIsInMyContacts({
    required String myUid,
    required String peerUid,
  }) {
    if (myUid.isEmpty || peerUid.isEmpty) return Stream.value(false);
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('contacts')
        .doc(peerUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  @override
  Future<UserProfileAddContactResult> addContactForBoth({
    required String myUid,
    required String peerUid,
    required UserProfilePeerProfile peerProfile,
  }) async {
    if (myUid.isEmpty) {
      return const UserProfileAddContactResult(
        status: UserProfileAddContactStatus.notLoggedIn,
        message: 'Harus login untuk menambahkan kontak',
      );
    }
    if (peerUid.isEmpty || peerUid == myUid) {
      return const UserProfileAddContactResult(
        status: UserProfileAddContactStatus.self,
        message: 'Tidak bisa menambahkan diri sendiri',
      );
    }

    try {
      final myDocSnap = await _firestore.collection('users').doc(myUid).get();
      final myData = myDocSnap.data() ?? <String, dynamic>{};

      final myName = _resolveName(
        myData,
        fallback: currentUserDisplayName ?? 'Teman',
      );
      final myPin = _resolvePin(myData);
      final myAvatar = _resolveAvatar(
        myData,
        fallback: currentUserPhotoUrl ?? '',
      );

      final myContactRef = _firestore
          .collection('users')
          .doc(myUid)
          .collection('contacts')
          .doc(peerUid);
      final peerContactRef = _firestore
          .collection('users')
          .doc(peerUid)
          .collection('contacts')
          .doc(myUid);

      final now = FieldValue.serverTimestamp();

      final myExisting = await myContactRef.get();
      final myPayload = <String, dynamic>{
        'displayName': peerProfile.name,
        'pin': peerProfile.pin,
        'collection': 'users',
        'avatarUrl': peerProfile.photoUrl,
        'updatedAt': now,
      };
      if (!myExisting.exists) {
        myPayload['createdAt'] = now;
      }
      await myContactRef.set(myPayload, SetOptions(merge: true));

      final peerPayload = <String, dynamic>{
        'displayName': myName,
        'pin': myPin,
        'collection': 'users',
        'avatarUrl': myAvatar,
        'updatedAt': now,
      };
      try {
        await peerContactRef.set({
          ...peerPayload,
          'createdAt': now,
        }, SetOptions(merge: true));
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          return const UserProfileAddContactResult(
            status: UserProfileAddContactStatus.partial,
            message:
                'Kontak ditambahkan ke daftar Anda. Pengguna lain mungkin perlu menambahkan Anda secara manual.',
          );
        }
        rethrow;
      }

      return const UserProfileAddContactResult(
        status: UserProfileAddContactStatus.success,
        message: 'Kontak berhasil ditambahkan',
      );
    } catch (e) {
      return UserProfileAddContactResult(
        status: UserProfileAddContactStatus.failure,
        message: 'Gagal menambahkan kontak: $e',
      );
    }
  }

  @override
  Future<UserProfileClearChatResult> clearChatHistory(String chatId) async {
    if (chatId.isEmpty) {
      return const UserProfileClearChatResult(
        success: false,
        message: 'Chat tidak ditemukan',
      );
    }
    try {
      final msgCollection = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages');
      const pageSize = 400;
      QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
      while (true) {
        Query<Map<String, dynamic>> query = msgCollection
            .orderBy(FieldPath.documentId)
            .limit(pageSize);
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }
        final snapshot = await query.get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < pageSize) break;
        lastDoc = snapshot.docs.last;
      }

      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': 'Riwayat chat dibersihkan',
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await ChatPageRepositoryImpl.clearLocalChatCaches(chatId);

      return const UserProfileClearChatResult(
        success: true,
        message: 'Riwayat chat telah dibersihkan',
      );
    } catch (e) {
      return UserProfileClearChatResult(
        success: false,
        message: 'Gagal membersihkan chat: $e',
      );
    }
  }

  @override
  Stream<UserProfileMediaDocsPreview> watchMediaDocsPreview(String chatId) {
    if (chatId.isEmpty) {
      return Stream.value(const UserProfileMediaDocsPreview());
    }
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('ts', descending: true)
        .limit(150)
        .snapshots()
        .map((snapshot) {
          final images = <String>[];
          final files = <UserProfileFilePreview>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final type = (data['type'] ?? '').toString();
            final imageUrl = (data['imageUrl'] ?? data['photoUrl'] ?? '')
                .toString()
                .trim();
            final fileUrl = (data['fileUrl'] ?? '').toString().trim();
            final fileName = (data['fileName'] ?? '').toString().trim();

            if ((imageUrl.isNotEmpty || type == 'image') &&
                imageUrl.isNotEmpty) {
              images.add(imageUrl);
            }
            if (fileUrl.isNotEmpty || type == 'file') {
              files.add(
                UserProfileFilePreview(
                  url: fileUrl,
                  name: fileName.isNotEmpty ? fileName : 'Dokumen',
                ),
              );
            }
            if (images.length >= 6 && files.length >= 6) break;
          }
          return UserProfileMediaDocsPreview(images: images, files: files);
        });
  }

  @override
  Stream<UserProfileStarredSummary?> watchStarredSummary({
    required String chatId,
    required String myUid,
  }) {
    if (chatId.isEmpty || myUid.isEmpty) return Stream.value(null);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('starredBy', arrayContains: myUid)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) return null;

          final sorted = [...docs];
          sorted.sort((a, b) {
            final am = a.data();
            final bm = b.data();
            final at =
                _resolveDate(am['starredAt'] ?? am['createdAt'] ?? am['ts']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bt =
                _resolveDate(bm['starredAt'] ?? bm['createdAt'] ?? bm['ts']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bt.compareTo(at);
          });

          final first = sorted.first.data();
          final text = (first['text'] ?? first['message'] ?? '[media]')
              .toString();
          final ts = _resolveDate(
            first['starredAt'] ?? first['createdAt'] ?? first['ts'],
          );
          return UserProfileStarredSummary(text: text, timestamp: ts);
        });
  }
}
