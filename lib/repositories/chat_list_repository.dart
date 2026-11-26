import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page_repository.dart';

class ChatListChatDoc {
  const ChatListChatDoc({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

class ChatListChatsSnapshot {
  const ChatListChatsSnapshot({
    required this.docs,
    this.permissionDenied = false,
  });

  final List<ChatListChatDoc> docs;
  final bool permissionDenied;
}

class ChatListUserStateSnapshot {
  const ChatListUserStateSnapshot({
    required this.hasPendingWrites,
    required this.pinnedChats,
    required this.hiddenChatIds,
    required this.favoriteChatIds,
  });

  final bool hasPendingWrites;
  final Map<String, DateTime> pinnedChats;
  final Set<String> hiddenChatIds;
  final Set<String> favoriteChatIds;
}

class ChatListUserProfile {
  const ChatListUserProfile({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;
}

enum ChatListClearChatResultType { removedFromList, archived }

class ChatListClearChatResult {
  const ChatListClearChatResult({required this.type});

  final ChatListClearChatResultType type;
}

enum ChatListStartChatStatus {
  success,
  notLoggedIn,
  selfPin,
  notFound,
  failure,
}

class ChatListStartChatResult {
  const ChatListStartChatResult({
    required this.status,
    this.chatId,
    this.peerName,
    this.peerAvatarUrl,
    this.message,
  });

  final ChatListStartChatStatus status;
  final String? chatId;
  final String? peerName;
  final String? peerAvatarUrl;
  final String? message;
}

abstract class ChatListRepository {
  String? get currentUserUid;

  Stream<String?> watchAuthUserIds();

  Stream<ChatListChatsSnapshot> watchChats(String uid, {int limit});

  Stream<ChatListUserStateSnapshot> watchUserState(String uid);

  Future<void> resetUnread({required String chatId, required String uid});

  Future<bool> isAdmin(String uid);

  Future<ChatListUserProfile?> fetchUserProfile(String uid);

  Stream<ChatListUserProfile?> watchUserProfile(String uid);

  Future<void> setPinned({
    required String uid,
    required String chatId,
    required bool pin,
  });

  Future<void> setFavorite({
    required String uid,
    required String chatId,
    required bool favorite,
  });

  Future<void> hideChat({required String uid, required String chatId});

  Future<void> unhideChat({required String uid, required String chatId});

  Future<ChatListClearChatResult> clearChatForCurrentUser({
    required String uid,
    required String chatId,
  });

  Future<void> removeChatMetaForUser({
    required String uid,
    required String chatId,
  });

  Future<void> updateMemberInfo({
    required String chatId,
    required String peerUid,
    required String name,
    required String avatarUrl,
  });

  Future<String?> resolveAvatarUrl(String avatar);

  Future<ChatListStartChatResult> startDirectChatByPin(String inputPin);

  Future<void> clearChatMessages(String chatId);

  Future<void> deleteChat(String chatId);
}

class ChatListRepositoryImpl implements ChatListRepository {
  ChatListRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  FirebaseStorage? _storage;
  static const String _chatCachePrefix = 'chat_list_cache_v1_';

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Stream<String?> watchAuthUserIds() {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  Query<Map<String, dynamic>> _chatQueryFor(
    String uid, {
    bool orderByLastMessage = false,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('chats')
        .where('members', arrayContains: uid);
    if (orderByLastMessage) {
      query = query.orderBy('lastMessageAt', descending: true);
    }
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }
    return query;
  }

  @override
  Stream<ChatListChatsSnapshot> watchChats(
    String uid, {
    int limit = 200,
  }) async* {
    final orderedQuery = _chatQueryFor(
      uid,
      orderByLastMessage: true,
      limit: limit,
    );
    String? lastEmittedSignature;
    var emittedAny = false;
    bool shouldEmit(List<ChatListChatDoc> docs) {
      final signature = _docsSignature(docs);
      if (signature == lastEmittedSignature) return false;
      lastEmittedSignature = signature;
      return true;
    }

    final cachedFallbackDocs = await _readCachedChats(uid: uid, limit: limit);
    final fallbackDocsPool = <String, ChatListChatDoc>{};
    _upsertFallbackDocs(pool: fallbackDocsPool, docs: cachedFallbackDocs);

    try {
      final localCache = await orderedQuery.get(
        const GetOptions(source: Source.cache),
      );
      final cacheDocs = _mergeMissingLocalPreviewChats(
        baseDocs: _mapChatDocs(localCache.docs),
        fallbackPool: fallbackDocsPool,
        uid: uid,
        limit: limit,
      );
      if (shouldEmit(cacheDocs)) {
        await loadLocalReadTimes(cacheDocs.map((d) => d.id).toList());
        emittedAny = true;
        yield ChatListChatsSnapshot(docs: cacheDocs);
      }
    } catch (_) {}

    if (!emittedAny) {
      final cachedDocs = _mergeMissingLocalPreviewChats(
        baseDocs: cachedFallbackDocs,
        fallbackPool: fallbackDocsPool,
        uid: uid,
        limit: limit,
      );
      if (shouldEmit(cachedDocs)) {
        await loadLocalReadTimes(cachedDocs.map((d) => d.id).toList());
        emittedAny = true;
        yield ChatListChatsSnapshot(docs: cachedDocs);
      }
    }

    try {
      await for (final snapshot in orderedQuery.snapshots(
        includeMetadataChanges: true,
      )) {
        final mapped = _mapChatDocs(snapshot.docs);
        _upsertFallbackDocs(pool: fallbackDocsPool, docs: mapped);
        final docs = _mergeMissingLocalPreviewChats(
          baseDocs: mapped,
          fallbackPool: fallbackDocsPool,
          uid: uid,
          limit: limit,
        );
        unawaited(_writeCachedChats(uid: uid, docs: docs));
        if (shouldEmit(docs)) {
          await loadLocalReadTimes(docs.map((d) => d.id).toList());
          emittedAny = true;
          yield ChatListChatsSnapshot(docs: docs);
        }
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        yield const ChatListChatsSnapshot(docs: [], permissionDenied: true);
        return;
      }
      if (_isMissingIndex(error)) {
        final fallbackQuery = _chatQueryFor(uid);
        try {
          await for (final snapshot in fallbackQuery.snapshots()) {
            final mapped = _mapChatDocs(snapshot.docs);
            _upsertFallbackDocs(pool: fallbackDocsPool, docs: mapped);
            final docs = _mergeMissingLocalPreviewChats(
              baseDocs: mapped,
              fallbackPool: fallbackDocsPool,
              uid: uid,
              limit: limit,
            );
            unawaited(_writeCachedChats(uid: uid, docs: docs));
            final limited = docs.length > limit ? docs.sublist(0, limit) : docs;
            if (shouldEmit(limited)) {
              emittedAny = true;
              yield ChatListChatsSnapshot(docs: limited);
            }
          }
          return;
        } on FirebaseException catch (fallbackError) {
          if (fallbackError.code == 'permission-denied') {
            yield const ChatListChatsSnapshot(docs: [], permissionDenied: true);
            return;
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  void _upsertFallbackDocs({
    required Map<String, ChatListChatDoc> pool,
    required List<ChatListChatDoc> docs,
  }) {
    for (final doc in docs) {
      final chatId = doc.id.trim();
      if (chatId.isEmpty) continue;
      pool[chatId] = ChatListChatDoc(
        id: chatId,
        data: Map<String, dynamic>.from(doc.data),
      );
    }
  }

  List<ChatListChatDoc> _mergeMissingLocalPreviewChats({
    required List<ChatListChatDoc> baseDocs,
    required Map<String, ChatListChatDoc> fallbackPool,
    required String uid,
    required int limit,
  }) {
    final merged = <ChatListChatDoc>[
      for (final doc in baseDocs)
        ChatListChatDoc(id: doc.id, data: Map<String, dynamic>.from(doc.data)),
    ];
    final existingIds = merged.map((doc) => doc.id).toSet();
    final localPreviewChatIds =
        ChatPageRepositoryImpl.getLocalChatListPreviewChatIds();
    for (final chatId in localPreviewChatIds) {
      if (existingIds.contains(chatId)) continue;
      final fallbackDoc = fallbackPool[chatId];
      if (fallbackDoc != null) {
        merged.add(
          ChatListChatDoc(
            id: fallbackDoc.id,
            data: Map<String, dynamic>.from(fallbackDoc.data),
          ),
        );
        existingIds.add(chatId);
        continue;
      }

      final preview = ChatPageRepositoryImpl.getLocalChatListPreview(chatId);
      final synthetic = _buildSyntheticDocFromLocalPreview(
        chatId: chatId,
        uid: uid,
        preview: preview,
      );
      if (synthetic == null) continue;
      merged.add(
        ChatListChatDoc(
          id: synthetic.id,
          data: Map<String, dynamic>.from(synthetic.data),
        ),
      );
      fallbackPool[chatId] = synthetic;
      existingIds.add(chatId);
    }
    final patched = _applyLocalChatListPreviews(merged);
    if (limit > 0 && patched.length > limit) {
      return patched.sublist(0, limit);
    }
    return patched;
  }

  ChatListChatDoc? _buildSyntheticDocFromLocalPreview({
    required String chatId,
    required String uid,
    required Map<String, dynamic>? preview,
  }) {
    if (preview == null) return null;
    final previewMessage = (preview['lastMessage'] ?? '').toString().trim();
    final previewAt = _normalizeToDateTime(preview['lastMessageAt']);
    final previewSender = (preview['lastSenderId'] ?? '').toString().trim();
    if (previewMessage.isEmpty || previewAt == null) return null;

    final members = _guessMembersFromChatId(chatId: chatId, uid: uid);
    final data = <String, dynamic>{
      'lastMessage': previewMessage,
      'lastMessageAt': previewAt,
      'lastSenderId': previewSender,
      'lastMessageDeletedFor': const <String>[],
      'members': members,
      'memberInfo': const <String, dynamic>{},
      'unread': uid.isNotEmpty
          ? <String, dynamic>{uid: 0}
          : <String, dynamic>{},
    };
    if (members.length == 2) {
      data['type'] = 'dm';
    }
    return ChatListChatDoc(id: chatId, data: data);
  }

  List<String> _guessMembersFromChatId({
    required String chatId,
    required String uid,
  }) {
    final parts = chatId
        .split('_')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (parts.length == 2 && uid.isNotEmpty && parts.contains(uid)) {
      return parts;
    }
    if (parts.length == 2 && uid.isNotEmpty) {
      return <String>[uid, ...parts.where((entry) => entry != uid)];
    }
    if (uid.isNotEmpty) {
      return <String>[uid];
    }
    return const <String>[];
  }

  List<ChatListChatDoc> _applyLocalChatListPreviews(
    List<ChatListChatDoc> docs,
  ) {
    if (docs.isEmpty) return docs;
    final patched = <ChatListChatDoc>[];
    for (final doc in docs) {
      final preview = ChatPageRepositoryImpl.getLocalChatListPreview(doc.id);
      if (preview == null) {
        patched.add(doc);
        continue;
      }

      final previewMessage = (preview['lastMessage'] ?? '').toString().trim();
      final previewSender = (preview['lastSenderId'] ?? '').toString().trim();
      final previewAt = _normalizeToDateTime(preview['lastMessageAt']);
      if (previewMessage.isEmpty || previewAt == null) {
        patched.add(doc);
        continue;
      }

      final data = Map<String, dynamic>.from(doc.data);
      final currentAt = _normalizeToDateTime(data['lastMessageAt']);
      final currentMessage = (data['lastMessage'] ?? '').toString().trim();
      final usePreview =
          currentAt == null ||
          previewAt.isAfter(currentAt) ||
          (previewAt.isAtSameMomentAs(currentAt) &&
              currentMessage != previewMessage);

      if (usePreview) {
        data['lastMessage'] = previewMessage;
        data['lastMessageAt'] = previewAt;
        if (previewSender.isNotEmpty) {
          data['lastSenderId'] = previewSender;
        }
        data['lastMessageDeletedFor'] = const <String>[];
        patched.add(ChatListChatDoc(id: doc.id, data: data));
        continue;
      }

      if (!currentAt.isBefore(previewAt)) {
        ChatPageRepositoryImpl.clearLocalChatListPreview(doc.id);
      }
      patched.add(doc);
    }

    patched.sort(
      (a, b) => _compareLastMessageAt(
        b.data['lastMessageAt'],
        a.data['lastMessageAt'],
      ),
    );
    return patched;
  }

  List<ChatListChatDoc> _mapChatDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map(
          (doc) => ChatListChatDoc(
            id: doc.id,
            data: Map<String, dynamic>.from(doc.data()),
          ),
        )
        .toList(growable: false);
  }

  @override
  Stream<ChatListUserStateSnapshot> watchUserState(String uid) {
    Stream<ChatListUserStateSnapshot> stream() async* {
      try {
        await for (final snapshot
            in _firestore.collection('users').doc(uid).snapshots()) {
          final hasPendingWrites = snapshot.metadata.hasPendingWrites;
          final data = snapshot.data() ?? const <String, dynamic>{};

          final pinnedChats = <String, DateTime>{};
          final rawPinned = data['pinnedChats'];
          if (rawPinned is Map) {
            rawPinned.forEach((key, value) {
              final resolved = _normalizeToDateTime(value);
              if (resolved != null) {
                pinnedChats[key.toString()] = resolved;
              }
            });
          }

          final hiddenChatIds = <String>{};
          final rawHidden = data['hiddenChats'];
          if (rawHidden is List) {
            for (final entry in rawHidden) {
              if (entry == null) continue;
              hiddenChatIds.add(entry.toString());
            }
          }

          final favoriteChatIds = <String>{};
          final rawFavorite = data['favoriteChats'];
          if (rawFavorite is List) {
            for (final entry in rawFavorite) {
              if (entry == null) continue;
              favoriteChatIds.add(entry.toString());
            }
          } else if (rawFavorite is Map) {
            for (final entry in rawFavorite.keys) {
              favoriteChatIds.add(entry.toString());
            }
          }

          yield ChatListUserStateSnapshot(
            hasPendingWrites: hasPendingWrites,
            pinnedChats: pinnedChats,
            hiddenChatIds: hiddenChatIds,
            favoriteChatIds: favoriteChatIds,
          );
        }
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied' ||
            error.code == 'unauthenticated') {
          yield const ChatListUserStateSnapshot(
            hasPendingWrites: false,
            pinnedChats: <String, DateTime>{},
            hiddenChatIds: <String>{},
            favoriteChatIds: <String>{},
          );
          return;
        }
        rethrow;
      }
    }

    return stream();
  }

  @override
  Future<void> resetUnread({required String chatId, required String uid}) {
    saveLocalReadTime(chatId);
    return _firestore.collection('chats').doc(chatId).set({
      'unread.$uid': 0,
      'unread_$uid': 0,
    }, SetOptions(merge: true));
  }

  // ── Local read-time cache ─────────────────────────────────────────────────
  // Menyimpan kapan user terakhir membaca tiap chat secara lokal.
  // Ini memberi fallback yang reliable untuk dot hijau bahkan jika
  // Firestore unread field tidak terupdate dengan benar.

  static final Map<String, DateTime> _localReadTimeCache =
      <String, DateTime>{};
  static const String _localReadTimePrefixKey = 'chat_local_read_v1_';

  static void saveLocalReadTime(String chatId) {
    final normalized = chatId.trim();
    if (normalized.isEmpty) return;
    final now = DateTime.now();
    _localReadTimeCache[normalized] = now;
    // Simpan ke SharedPreferences secara async (fire and forget)
    SharedPreferences.getInstance()
        .then(
          (prefs) => prefs.setString(
            '$_localReadTimePrefixKey$normalized',
            now.toIso8601String(),
          ),
        )
        .catchError((_) {});
  }

  static DateTime? getLocalReadTime(String chatId) {
    final normalized = chatId.trim();
    if (normalized.isEmpty) return null;
    return _localReadTimeCache[normalized];
  }

  static Future<void> loadLocalReadTimes(List<String> chatIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final chatId in chatIds) {
        if (_localReadTimeCache.containsKey(chatId)) continue;
        final raw = prefs.getString('$_localReadTimePrefixKey$chatId');
        if (raw == null) continue;
        final dt = DateTime.tryParse(raw);
        if (dt != null) _localReadTimeCache[chatId] = dt;
      }
    } catch (_) {}
  }
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<bool> isAdmin(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    final role = (snap.data()?['role'] ?? '').toString().toLowerCase();
    return role == 'admin';
  }

  @override
  Future<ChatListUserProfile?> fetchUserProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return _profileFromMap(data);
  }

  @override
  Stream<ChatListUserProfile?> watchUserProfile(String uid) {
    Stream<ChatListUserProfile?> stream() async* {
      try {
        await for (final snapshot
            in _firestore.collection('users').doc(uid).snapshots()) {
          final data = snapshot.data();
          if (data == null) {
            yield null;
            continue;
          }
          yield _profileFromMap(data);
        }
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied' ||
            error.code == 'unauthenticated') {
          yield null;
          return;
        }
        rethrow;
      }
    }

    return stream();
  }

  ChatListUserProfile _profileFromMap(Map<String, dynamic> data) {
    final name =
        (data['name'] ??
                data['displayName'] ??
                data['username'] ??
                data['fullName'] ??
                'Teman')
            .toString();
    final avatar =
        (data['avatarUrl'] ?? data['photoUrl'] ?? data['profilePhoto'] ?? '')
            .toString();
    return ChatListUserProfile(name: name, avatarUrl: avatar);
  }

  @override
  Future<void> setPinned({
    required String uid,
    required String chatId,
    required bool pin,
  }) {
    final data = pin
        ? <String, dynamic>{'pinnedChats.$chatId': FieldValue.serverTimestamp()}
        : <String, dynamic>{'pinnedChats.$chatId': FieldValue.delete()};
    return _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<void> setFavorite({
    required String uid,
    required String chatId,
    required bool favorite,
  }) {
    return _firestore.collection('users').doc(uid).set({
      'favoriteChats': favorite
          ? FieldValue.arrayUnion([chatId])
          : FieldValue.arrayRemove([chatId]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> hideChat({required String uid, required String chatId}) {
    return _firestore.collection('users').doc(uid).set({
      'hiddenChats': FieldValue.arrayUnion([chatId]),
      'pinnedChats.$chatId': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> unhideChat({required String uid, required String chatId}) {
    return _firestore.collection('users').doc(uid).set({
      'hiddenChats': FieldValue.arrayRemove([chatId]),
    }, SetOptions(merge: true));
  }

  @override
  Future<ChatListClearChatResult> clearChatForCurrentUser({
    required String uid,
    required String chatId,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatSnap = await chatRef.get();
    final chatData = chatSnap.data() ?? <String, dynamic>{};
    final isGroup =
        chatData['isGroup'] == true ||
        ((chatData['members'] is List) &&
            (chatData['members'] as List).length > 2);

    const pageSize = 200;
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
    while (true) {
      Query<Map<String, dynamic>> query = chatRef
          .collection('messages')
          .orderBy(FieldPath.documentId)
          .limit(pageSize);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final chunk = await query.get();
      if (chunk.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final messageDoc in chunk.docs) {
        batch.set(messageDoc.reference, {
          'deletedFor': FieldValue.arrayUnion([uid]),
        }, SetOptions(merge: true));
      }
      await batch.commit();

      if (chunk.docs.length < pageSize) break;
      lastDoc = chunk.docs.last;
    }

    if (!isGroup) {
      await chatRef.set({
        'members': FieldValue.arrayRemove([uid]),
        'admins': FieldValue.arrayRemove([uid]),
        'memberInfo': {uid: FieldValue.delete()},
        'unread': {uid: FieldValue.delete()},
        'typing.$uid': FieldValue.delete(),
        'lastMessageDeletedFor': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));

      await removeChatMetaForUser(uid: uid, chatId: chatId);
      await ChatPageRepositoryImpl.clearLocalChatCaches(chatId);
      return const ChatListClearChatResult(
        type: ChatListClearChatResultType.removedFromList,
      );
    }

    await chatRef.set({
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unread': {uid: 0},
      'lastMessageDeletedFor': FieldValue.arrayUnion([uid]),
    }, SetOptions(merge: true));
    await ChatPageRepositoryImpl.clearLocalChatCaches(chatId);

    return const ChatListClearChatResult(
      type: ChatListClearChatResultType.archived,
    );
  }

  @override
  Future<void> removeChatMetaForUser({
    required String uid,
    required String chatId,
  }) {
    return _firestore.collection('users').doc(uid).set({
      'hiddenChats': FieldValue.arrayRemove([chatId]),
      'pinnedChats.$chatId': FieldValue.delete(),
      'favoriteChats': FieldValue.arrayRemove([chatId]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateMemberInfo({
    required String chatId,
    required String peerUid,
    required String name,
    required String avatarUrl,
  }) {
    final payload = <String, dynamic>{};
    if (name.trim().isNotEmpty) {
      payload['name'] = name;
    }
    if (avatarUrl.trim().isNotEmpty) {
      payload['avatarUrl'] = avatarUrl;
    }
    if (payload.isEmpty) return Future<void>.value();

    return _firestore.collection('chats').doc(chatId).set({
      'memberInfo': {peerUid: payload},
    }, SetOptions(merge: true));
  }

  @override
  Future<String?> resolveAvatarUrl(String avatar) async {
    if (avatar.isEmpty) return null;

    final storage = _storage ??= FirebaseStorage.instance;
    try {
      if (avatar.startsWith('gs://')) {
        return await storage.refFromURL(avatar).getDownloadURL();
      }
      if (avatar.startsWith('http')) {
        return avatar;
      }
      return await storage.ref(avatar).getDownloadURL();
    } on FirebaseException catch (error) {
      if (_isStorageObjectMissing(error)) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<ChatListStartChatResult> startDirectChatByPin(String inputPin) async {
    final normalizedPin = inputPin.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (normalizedPin.isEmpty) {
      return const ChatListStartChatResult(
        status: ChatListStartChatStatus.notFound,
        message: 'PIN tidak ditemukan',
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      return const ChatListStartChatResult(
        status: ChatListStartChatStatus.notLoggedIn,
      );
    }

    try {
      final myDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = myDoc.data() ?? const <String, dynamic>{};
      final mine = [data['pin'], data['userPin'], data['chatPin']]
          .where((v) => v != null)
          .map((v) => v.toString().replaceAll(RegExp(r'\s+'), '').toUpperCase())
          .toSet();
      if (mine.contains(normalizedPin)) {
        return const ChatListStartChatResult(
          status: ChatListStartChatStatus.selfPin,
        );
      }
    } catch (_) {}

    final peer = await _findUserByPin(normalizedPin);
    if (peer == null) {
      return const ChatListStartChatResult(
        status: ChatListStartChatStatus.notFound,
      );
    }

    final peerUid = peer.id;
    if (peerUid == user.uid) {
      return const ChatListStartChatResult(
        status: ChatListStartChatStatus.selfPin,
      );
    }

    try {
      final myUid = user.uid;
      final ids = [myUid, peerUid]..sort();
      final chatId = ids.join('_');

      final myProfileSnap = await _firestore
          .collection('users')
          .doc(myUid)
          .get();
      final myProfile = myProfileSnap.data() ?? <String, dynamic>{};
      final peerData = peer.data() ?? <String, dynamic>{};

      final chatRef = _firestore.collection('chats').doc(chatId);
      final existingChat = await chatRef.get();

      final timestamp = FieldValue.serverTimestamp();
      final myAvatar = _pickAvatar(myProfile);
      final peerAvatar = _pickAvatar(peerData);
      final myName = (myProfile['name'] ?? user.displayName ?? 'Teman')
          .toString();
      final peerName = (peerData['name'] ?? peerData['displayName'] ?? 'Teman')
          .toString();

      final createMemberInfo = {
        myUid: {
          'pin': (myProfile['pin'] ?? '').toString(),
          'name': myName,
          'avatarUrl': myAvatar,
          'joinedAt': timestamp,
          'role': 'member',
        },
        peerUid: {
          'pin': (peerData['pin'] ?? peerData['userPin'] ?? '').toString(),
          'name': peerName,
          'avatarUrl': peerAvatar,
          'joinedAt': timestamp,
          'role': 'member',
        },
      };

      final updateMemberInfo = {
        myUid: {
          'pin': (myProfile['pin'] ?? '').toString(),
          'name': myName,
          'avatarUrl': myAvatar,
        },
        peerUid: {
          'pin': (peerData['pin'] ?? peerData['userPin'] ?? '').toString(),
          'name': peerName,
          'avatarUrl': peerAvatar,
        },
      };

      final unread = {myUid: 0, peerUid: 0};

      if (existingChat.exists) {
        await chatRef.set({
          'members': ids,
          'memberInfo': updateMemberInfo,
          'unread': unread,
        }, SetOptions(merge: true));
      } else {
        await chatRef.set({
          'type': 'dm',
          'members': ids,
          'createdAt': timestamp,
          'lastMessage': '',
          'lastMessageAt': timestamp,
          'lastSenderId': myUid,
          'memberInfo': createMemberInfo,
          'unread': unread,
        });
      }

      return ChatListStartChatResult(
        status: ChatListStartChatStatus.success,
        chatId: chatId,
        peerName: peerName,
        peerAvatarUrl: peerAvatar,
      );
    } catch (error) {
      return ChatListStartChatResult(
        status: ChatListStartChatStatus.failure,
        message: error.toString(),
      );
    }
  }

  @override
  Future<void> clearChatMessages(String chatId) async {
    const int page = 400;
    while (true) {
      final snap = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .limit(page)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < page) break;
    }

    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': FieldValue.delete(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await ChatPageRepositoryImpl.clearLocalChatCaches(chatId);
  }

  @override
  Future<void> deleteChat(String chatId) async {
    await clearChatMessages(chatId);
    await _firestore.collection('chats').doc(chatId).delete();
    await ChatPageRepositoryImpl.clearLocalChatCaches(chatId);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByPin(
    String pin,
  ) async {
    try {
      var snap = await _firestore
          .collection('users')
          .where('pin', isEqualTo: pin)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;

      snap = await _firestore
          .collection('users')
          .where('userPin', isEqualTo: pin)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;

      snap = await _firestore
          .collection('users')
          .where('chatPin', isEqualTo: pin)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;

      if (await _collectionExists('profiles')) {
        snap = await _firestore
            .collection('profiles')
            .where('pin', isEqualTo: pin)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return snap.docs.first;

        snap = await _firestore
            .collection('profiles')
            .where('userPin', isEqualTo: pin)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return snap.docs.first;

        snap = await _firestore
            .collection('profiles')
            .where('chatPin', isEqualTo: pin)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return snap.docs.first;
      }
    } catch (_) {}

    try {
      final pinDoc = await _firestore.collection('pins').doc(pin).get();
      if (pinDoc.exists) {
        final data = pinDoc.data();
        final uid = (data?['uid'] ?? '').toString();
        if (uid.isNotEmpty) {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists) return userDoc;
        }
      }
    } catch (_) {}

    Future<DocumentSnapshot<Map<String, dynamic>>?> scan(String coll) async {
      try {
        final snap = await _firestore.collection(coll).limit(500).get();
        for (final doc in snap.docs) {
          if (_pinEquals(doc.data(), pin)) return doc;
        }
      } catch (_) {}
      return null;
    }

    final userDoc = await scan('users');
    if (userDoc != null) return userDoc;

    if (await _collectionExists('profiles')) {
      final profileDoc = await scan('profiles');
      if (profileDoc != null) return profileDoc;
    }

    return null;
  }

  Future<bool> _collectionExists(String name) async {
    try {
      await _firestore.collection(name).limit(1).get();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _pinEquals(Map<String, dynamic> data, String target) {
    String norm(dynamic value) => value == null
        ? ''
        : value.toString().replaceAll(RegExp(r'\s+'), '').toUpperCase();

    final normalizedTarget = norm(target);
    if (normalizedTarget.isEmpty) return false;
    final candidates = [
      data['pin'],
      data['userPin'],
      data['chatPin'],
      data['PIN'],
      data['Pin'],
    ];
    for (final candidate in candidates) {
      if (norm(candidate) == normalizedTarget) {
        return true;
      }
    }
    return false;
  }

  String _pickAvatar(Map<String, dynamic> source) {
    final candidates = [
      source['avatarUrl'],
      source['photoUrl'],
      source['profilePhoto'],
      source['photoURL'],
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  DateTime? _normalizeToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      } catch (_) {
        return null;
      }
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  int _compareLastMessageAt(dynamic a, dynamic b) {
    final da = _normalizeToDateTime(a);
    final db = _normalizeToDateTime(b);
    if (da == null && db == null) return 0;
    if (da == null) return -1;
    if (db == null) return 1;
    return da.compareTo(db);
  }

  bool _isStorageObjectMissing(FirebaseException error) {
    final code = error.code.trim().toLowerCase();
    if (code == 'object-not-found' ||
        code == 'storage/object-not-found' ||
        code == 'not-found') {
      return true;
    }
    return error.message?.toLowerCase().contains('object does not exist') ==
        true;
  }

  bool _isMissingIndex(FirebaseException error) {
    if (error.code == 'failed-precondition') return true;
    final message = error.message?.toLowerCase() ?? '';
    return message.contains('index') && message.contains('create');
  }

  String _chatCacheKey(String uid) => '$_chatCachePrefix$uid';

  Future<List<ChatListChatDoc>> _readCachedChats({
    required String uid,
    required int limit,
  }) async {
    if (uid.isEmpty) return const <ChatListChatDoc>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatCacheKey(uid));
      if (raw == null || raw.isEmpty) return const <ChatListChatDoc>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ChatListChatDoc>[];
      final docs = <ChatListChatDoc>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final id = (entry['id'] ?? '').toString();
        final data = entry['data'];
        if (id.isEmpty || data is! Map) continue;
        docs.add(
          ChatListChatDoc(id: id, data: Map<String, dynamic>.from(data)),
        );
      }
      if (limit > 0 && docs.length > limit) {
        return docs.sublist(0, limit);
      }
      return docs;
    } catch (_) {
      return const <ChatListChatDoc>[];
    }
  }

  Future<void> _writeCachedChats({
    required String uid,
    required List<ChatListChatDoc> docs,
  }) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = docs
          .map(
            (doc) => <String, dynamic>{
              'id': doc.id,
              'data': _encodeMap(doc.data),
            },
          )
          .toList(growable: false);
      await prefs.setString(_chatCacheKey(uid), jsonEncode(payload));
    } catch (_) {}
  }

  Map<String, dynamic> _encodeMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    source.forEach((key, value) {
      final encoded = _encodeValue(value);
      if (encoded != null) {
        result[key] = encoded;
      }
    });
    return result;
  }

  dynamic _encodeValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is Iterable) {
      return value.map(_encodeValue).toList(growable: false);
    }
    if (value is Map) {
      final mapValue = <String, dynamic>{};
      value.forEach((key, innerValue) {
        final encoded = _encodeValue(innerValue);
        if (encoded != null) {
          mapValue[key.toString()] = encoded;
        }
      });
      return mapValue;
    }
    return value.toString();
  }

  String _docsSignature(List<ChatListChatDoc> docs) {
    if (docs.isEmpty) return '__empty__';
    final buffer = StringBuffer();
    for (final doc in docs) {
      final data = doc.data;
      buffer.write(doc.id);
      buffer.write('|');
      final lastMessageAt = data['lastMessageAt'];
      final normalizedDate = _normalizeToDateTime(lastMessageAt);
      if (normalizedDate != null) {
        buffer.write(normalizedDate.millisecondsSinceEpoch);
      } else if (lastMessageAt != null) {
        buffer.write(lastMessageAt.toString());
      }
      buffer.write('|');
      buffer.write((data['lastMessage'] ?? '').toString());
      buffer.write('|');
      buffer.write((data['lastSenderId'] ?? '').toString());
      buffer.write('|');
      final unread = data['unread'];
      if (unread is Map) {
        final keys = unread.keys.map((entry) => entry.toString()).toList()
          ..sort();
        for (final key in keys) {
          final value = unread[key];
          buffer.write(key);
          buffer.write(':');
          buffer.write(value?.toString() ?? '');
          buffer.write(',');
        }
      }
      buffer.write('|');
      final deletedFor = data['lastMessageDeletedFor'];
      if (deletedFor is Iterable) {
        final values = deletedFor.map((entry) => entry.toString()).toList()
          ..sort();
        for (final value in values) {
          buffer.write(value);
          buffer.write(',');
        }
      }
      buffer.write(';');
    }
    return buffer.toString();
  }
}
