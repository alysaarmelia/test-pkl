import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:shared_preferences/shared_preferences.dart';

class ChatPageUserProfile {
  const ChatPageUserProfile({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.online,
    required this.lastSeen,
  });

  final String uid;
  final String name;
  final String avatarUrl;
  final bool online;
  final DateTime? lastSeen;
}

class ChatPageMessageRecord {
  const ChatPageMessageRecord({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

class ChatPageForwardTarget {
  const ChatPageForwardTarget({
    required this.chatId,
    required this.peerUid,
    required this.chatData,
  });

  final String chatId;
  final String peerUid;
  final Map<String, dynamic> chatData;
}

class ChatPageSendResult {
  const ChatPageSendResult({this.resolvedPeerUid, this.messageId});

  final String? resolvedPeerUid;
  final String? messageId;
}

class ChatPageCreateMessageResult {
  const ChatPageCreateMessageResult({
    required this.messageId,
    this.resolvedPeerUid,
  });

  final String messageId;
  final String? resolvedPeerUid;
}

class _LocalChatListPreview {
  const _LocalChatListPreview({
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    required this.cachedAt,
  });

  final String lastMessage;
  final String lastSenderId;
  final DateTime lastMessageAt;
  final DateTime cachedAt;
}

abstract class ChatPageRepository {
  String get currentUserUid;

  Future<Map<String, dynamic>> fetchChatData(String chatId);

  Future<String?> getPeerUid({required String chatId, required String myUid});

  Future<String> fetchUserDisplayName(String uid);

  Future<ChatPageUserProfile> fetchUserProfile(String uid);

  Stream<ChatPageUserProfile> watchUserProfile(String uid);

  Future<void> setPresence({required String uid, required bool online});

  Future<void> markRead({required String chatId, required String myUid});

  Future<ChatPageSendResult> sendTextMessage({
    required String chatId,
    required String myUid,
    required String text,
    required bool isGroup,
    required List<dynamic> memberIds,
    String? peerUid,
    String? clientMessageId,
    String? replyToId,
    String? replyToText,
    bool? replyToFromMe,
  });

  Future<void> setTyping({
    required String chatId,
    required String myUid,
    required bool active,
  });

  Stream<Map<String, DateTime?>> watchTyping(String chatId);

  Future<ChatPageCreateMessageResult> createFilePlaceholder({
    required String chatId,
    required String myUid,
    required bool isGroup,
    required List<dynamic> memberIds,
    required String fileName,
    required int fileSize,
    String? peerUid,
  });

  Future<ChatPageCreateMessageResult> createImagePlaceholder({
    required String chatId,
    required String myUid,
    required bool isGroup,
    required List<dynamic> memberIds,
    String? peerUid,
  });

  Future<String> uploadChatFile({
    required String chatId,
    required String messageId,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  });

  Future<String> uploadChatImage({
    required String chatId,
    required String messageId,
    required String filePath,
    void Function(double progress)? onProgress,
  });

  Future<void> deleteChatImage({
    required String chatId,
    required String messageId,
  });

  Future<void> updateMessageFields({
    required String chatId,
    required String messageId,
    required Map<String, dynamic> data,
  });

  Stream<List<ChatPageMessageRecord>> watchMessages({
    required String chatId,
    int limit = 100,
  });

  List<ChatPageMessageRecord> getCachedMessages({
    required String chatId,
    int limit = 100,
  });

  Future<void> markMessageDelivered({
    required String chatId,
    required String messageId,
  });

  Future<void> markMessagesDelivered({
    required String chatId,
    required Iterable<String> messageIds,
  });

  Future<List<ChatPageForwardTarget>> getForwardTargets({
    required String myUid,
    String? excludeChatId,
    int limit = 30,
  });

  Future<void> forwardMessage({
    required String targetChatId,
    required String myUid,
    required String type,
    required String text,
    String? imageUrl,
  });

  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String myUid,
  });

  Future<void> deleteMessageForAll({
    required String chatId,
    required String messageId,
  });

  Future<Map<String, dynamic>> fetchMessage({
    required String chatId,
    required String messageId,
  });

  Future<void> clearMessageMedia({
    required String chatId,
    required String messageId,
  });

  Future<void> toggleStar({
    required String chatId,
    required String messageId,
    required bool value,
    required String myUid,
  });
}

class ChatPageRepositoryImpl implements ChatPageRepository {
  ChatPageRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    fb_storage.FirebaseStorage? storage,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? fb_storage.FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final fb_storage.FirebaseStorage _storage;
  static const String _messagesCachePrefix = 'chat_messages_cache_v1_';
  static const String _mediaPreviewCachePrefix = 'chatLocalMedia_';
  static const String _pendingTextCachePrefix = 'chatLocalPendingText_';
  static const Duration _localChatListPreviewTtl = Duration(minutes: 6);
  static final Map<String, List<ChatPageMessageRecord>> _messagesSessionCache =
      <String, List<ChatPageMessageRecord>>{};
  static final Map<String, _LocalChatListPreview> _localChatListPreviews =
      <String, _LocalChatListPreview>{};

  static Future<void> clearLocalChatCaches(String chatId) async {
    final normalized = chatId.trim();
    if (normalized.isEmpty) return;
    _messagesSessionCache.remove(normalized);
    _localChatListPreviews.remove(normalized);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_messagesCachePrefix$normalized');
      await prefs.remove('$_mediaPreviewCachePrefix$normalized');
      await prefs.remove('$_pendingTextCachePrefix$normalized');
    } catch (_) {}
  }

  static void cacheLocalChatListPreview({
    required String chatId,
    required String lastMessage,
    required String lastSenderId,
    DateTime? lastMessageAt,
  }) {
    final normalizedChatId = chatId.trim();
    final normalizedMessage = lastMessage.trim();
    if (normalizedChatId.isEmpty || normalizedMessage.isEmpty) return;
    _pruneLocalChatListPreviews();
    _localChatListPreviews[normalizedChatId] = _LocalChatListPreview(
      lastMessage: normalizedMessage,
      lastSenderId: lastSenderId.trim(),
      lastMessageAt: lastMessageAt ?? DateTime.now(),
      cachedAt: DateTime.now(),
    );
  }

  static Map<String, dynamic>? getLocalChatListPreview(String chatId) {
    final normalized = chatId.trim();
    if (normalized.isEmpty) return null;
    _pruneLocalChatListPreviews();
    final preview = _localChatListPreviews[normalized];
    if (preview == null) return null;
    return <String, dynamic>{
      'lastMessage': preview.lastMessage,
      'lastSenderId': preview.lastSenderId,
      'lastMessageAt': preview.lastMessageAt,
    };
  }

  static Set<String> getLocalChatListPreviewChatIds() {
    _pruneLocalChatListPreviews();
    return Set<String>.unmodifiable(_localChatListPreviews.keys);
  }

  static void clearLocalChatListPreview(String chatId) {
    final normalized = chatId.trim();
    if (normalized.isEmpty) return;
    _localChatListPreviews.remove(normalized);
  }

  static void _pruneLocalChatListPreviews() {
    if (_localChatListPreviews.isEmpty) return;
    final now = DateTime.now();
    _localChatListPreviews.removeWhere(
      (_, preview) =>
          now.difference(preview.cachedAt) > _localChatListPreviewTtl,
    );
  }

  @override
  String get currentUserUid => _auth.currentUser?.uid ?? '';

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    if (value is String) return DateTime.tryParse(value);
    try {
      final converted = (value as dynamic).toDate();
      if (converted is DateTime) return converted;
    } catch (_) {}
    return null;
  }

  bool _isAuthOrPermissionError(FirebaseException error) {
    final code = error.code.toLowerCase();
    if (code == 'unauthenticated') return true;
    if (code != 'permission-denied') return false;
    final currentUid = _auth.currentUser?.uid ?? '';
    return currentUid.isEmpty;
  }

  ChatPageUserProfile _mapUserProfile(String uid, Map<String, dynamic> data) {
    final name =
        (data['name'] ??
                data['displayName'] ??
                data['fullName'] ??
                data['username'] ??
                '')
            .toString()
            .trim();
    final avatar =
        (data['avatarUrl'] ??
                data['photoUrl'] ??
                data['profilePhoto'] ??
                data['photoURL'] ??
                '')
            .toString()
            .trim();
    return ChatPageUserProfile(
      uid: uid,
      name: name,
      avatarUrl: avatar,
      online: (data['online'] ?? false) == true,
      lastSeen: _toDateTime(data['lastSeen']),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchChatData(String chatId) async {
    final doc = await _db.collection('chats').doc(chatId).get();
    return doc.data() ?? <String, dynamic>{};
  }

  @override
  Future<String?> getPeerUid({
    required String chatId,
    required String myUid,
  }) async {
    try {
      final data = await fetchChatData(chatId);
      final members = List<String>.from((data['members'] ?? const []) as List);
      final peer = members.firstWhere((m) => m != myUid, orElse: () => '');
      if (peer.isNotEmpty) return peer;
    } catch (_) {}
    return _derivePeerUidFromChatId(chatId: chatId, myUid: myUid);
  }

  @override
  Future<String> fetchUserDisplayName(String uid) async {
    if (uid.isEmpty) return '';
    final data = (await _db.collection('users').doc(uid).get()).data() ?? {};
    return _mapUserProfile(uid, data).name;
  }

  @override
  Future<ChatPageUserProfile> fetchUserProfile(String uid) async {
    if (uid.isEmpty) {
      return const ChatPageUserProfile(
        uid: '',
        name: '',
        avatarUrl: '',
        online: false,
        lastSeen: null,
      );
    }
    final data = (await _db.collection('users').doc(uid).get()).data() ?? {};
    return _mapUserProfile(uid, data);
  }

  @override
  Stream<ChatPageUserProfile> watchUserProfile(String uid) {
    if (uid.isEmpty) {
      return const Stream<ChatPageUserProfile>.empty();
    }
    Stream<ChatPageUserProfile> stream() async* {
      try {
        await for (final doc in _db.collection('users').doc(uid).snapshots()) {
          final data = doc.data() ?? <String, dynamic>{};
          yield _mapUserProfile(uid, data);
        }
      } on FirebaseException catch (error) {
        if (_isAuthOrPermissionError(error)) return;
        rethrow;
      }
    }

    return stream();
  }

  @override
  Future<void> setPresence({required String uid, required bool online}) async {
    if (uid.isEmpty) return Future.value();
    try {
      await _db.collection('users').doc(uid).set({
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (_isAuthOrPermissionError(error)) return;
      rethrow;
    }
  }

  @override
  Future<void> markRead({required String chatId, required String myUid}) async {
    if (chatId.isEmpty || myUid.isEmpty) return;
    final chatRef = _db.collection('chats').doc(chatId);
    await chatRef.set({
      'unread.$myUid': 0,
      'unread_$myUid': 0,
    }, SetOptions(merge: true));

    final snap = await chatRef
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(80)
        .get();
    final batch = _db.batch();
    for (final msgDoc in snap.docs) {
      final data = msgDoc.data();
      if (data['senderId'] == myUid) continue;
      final readBy = List<dynamic>.from((data['readBy'] ?? const []) as List);
      if (!readBy.contains(myUid)) {
        batch.set(msgDoc.reference, {
          'readBy': FieldValue.arrayUnion([myUid]),
        }, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  Map<String, dynamic> _buildChatUpdateUnread({
    required bool isGroup,
    required String myUid,
    required Iterable<dynamic> memberIds,
    String? peerUid,
  }) {
    final updateMap = <String, dynamic>{};
    if (isGroup) {
      for (final memberId in memberIds) {
        final id = memberId.toString();
        if (id.isEmpty || id == myUid) continue;
        updateMap['unread.$id'] = FieldValue.increment(1);
        updateMap['unread_$id'] = FieldValue.increment(1);
      }
      return updateMap;
    }
    final String peerId = (peerUid ?? '').trim();
    if (peerId.isNotEmpty) {
      updateMap['unread.$peerId'] = FieldValue.increment(1);
      // Fallback: juga sediakan di root jika unread bukan Map
      updateMap['unread_$peerId'] = FieldValue.increment(1);
    }

    if (!isGroup && memberIds.isNotEmpty) {
      for (final memberId in memberIds) {
        final id = memberId.toString().trim();
        if (id.isNotEmpty && id != myUid && id != peerId) {
          updateMap['unread.$id'] = FieldValue.increment(1);
          updateMap['unread_$id'] = FieldValue.increment(1);
        }
      }
    }
    return updateMap;
  }

  String? _derivePeerUidFromMembers({
    required String myUid,
    required Iterable<dynamic> memberIds,
  }) {
    for (final member in memberIds) {
      final id = member.toString();
      if (id.isEmpty || id == myUid) continue;
      return id;
    }
    return null;
  }

  String? _derivePeerUidFromChatId({
    required String chatId,
    required String myUid,
  }) {
    final normalizedChatId = chatId.trim();
    final normalizedMyUid = myUid.trim();
    if (normalizedChatId.isEmpty || normalizedMyUid.isEmpty) return null;
    final prefix = '${normalizedMyUid}_';
    if (normalizedChatId.startsWith(prefix)) {
      final candidate = normalizedChatId.substring(prefix.length).trim();
      if (candidate.isNotEmpty) return candidate;
    }
    final suffix = '_$normalizedMyUid';
    if (normalizedChatId.endsWith(suffix)) {
      final candidate = normalizedChatId
          .substring(0, normalizedChatId.length - suffix.length)
          .trim();
      if (candidate.isNotEmpty) return candidate;
    }
    final parts = normalizedChatId.split('_');
    if (parts.length == 2) {
      if (parts[0] == normalizedMyUid && parts[1].trim().isNotEmpty) {
        return parts[1].trim();
      }
      if (parts[1] == normalizedMyUid && parts[0].trim().isNotEmpty) {
        return parts[0].trim();
      }
    }
    return null;
  }

  Map<String, dynamic> _buildDmRecoveryUpdate({
    required String myUid,
    String? peerUid,
  }) {
    final updateMap = <String, dynamic>{};
    if (myUid.trim().isNotEmpty) {
      updateMap['unread.$myUid'] = 0;
    }
    final normalizedPeerUid = (peerUid ?? '').trim();
    if (normalizedPeerUid.isNotEmpty) {
      updateMap['type'] = 'dm';
      updateMap['members'] = FieldValue.arrayUnion([myUid, normalizedPeerUid]);
    }
    return updateMap;
  }

  @override
  Future<ChatPageSendResult> sendTextMessage({
    required String chatId,
    required String myUid,
    required String text,
    required bool isGroup,
    required List<dynamic> memberIds,
    String? peerUid,
    String? clientMessageId,
    String? replyToId,
    String? replyToText,
    bool? replyToFromMe,
  }) async {
    if (chatId.isEmpty || myUid.isEmpty || text.trim().isEmpty) {
      return const ChatPageSendResult();
    }

    var resolvedPeerUid = peerUid;
    if (!isGroup && (resolvedPeerUid == null || resolvedPeerUid.isEmpty)) {
      resolvedPeerUid = _derivePeerUidFromMembers(
        myUid: myUid,
        memberIds: memberIds,
      );
    }
    if (!isGroup && (resolvedPeerUid == null || resolvedPeerUid.isEmpty)) {
      resolvedPeerUid = _derivePeerUidFromChatId(chatId: chatId, myUid: myUid);
    }
    Future<String?>? deferredPeerUidLookup;
    if (!isGroup && (resolvedPeerUid == null || resolvedPeerUid.isEmpty)) {
      deferredPeerUidLookup = getPeerUid(chatId: chatId, myUid: myUid);
    }

    final now = DateTime.now();
    cacheLocalChatListPreview(
      chatId: chatId,
      lastMessage: text,
      lastSenderId: myUid,
      lastMessageAt: now,
    );

    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    final chatRef = _db.collection('chats').doc(chatId);
    final batch = _db.batch();

    final payload = <String, dynamic>{
      'text': text,
      'senderId': myUid,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [myUid],
      'delivered': false,
    };
    if (replyToId != null) payload['replyToId'] = replyToId;
    if (replyToText != null) payload['replyToText'] = replyToText;
    if (replyToFromMe != null) payload['replyToFromMe'] = replyToFromMe;
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      payload['clientMessageId'] = clientMessageId;
    }
    batch.set(msgRef, payload);

    final updateMap = <String, dynamic>{
      'lastMessage': text,
      'lastMessageAt': now,
      'lastSenderId': myUid,
      'lastMessageDeletedFor': FieldValue.delete(),
    };
    if (!isGroup) {
      updateMap.addAll(
        _buildDmRecoveryUpdate(myUid: myUid, peerUid: resolvedPeerUid),
      );
    }
    updateMap.addAll(
      _buildChatUpdateUnread(
        isGroup: isGroup,
        myUid: myUid,
        memberIds: memberIds,
        peerUid: resolvedPeerUid,
      ),
    );

    batch.set(chatRef, updateMap, SetOptions(merge: true));
    await batch.commit();

    if (deferredPeerUidLookup != null) {
      try {
        final fetched = await deferredPeerUidLookup;
        if (fetched != null && fetched.isNotEmpty) {
          resolvedPeerUid = fetched;
          await chatRef.set({
            ..._buildDmRecoveryUpdate(myUid: myUid, peerUid: fetched),
            'unread.$fetched': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      } catch (_) {}
    }

    return ChatPageSendResult(
      resolvedPeerUid: resolvedPeerUid,
      messageId: msgRef.id,
    );
  }

  @override
  Future<void> setTyping({
    required String chatId,
    required String myUid,
    required bool active,
  }) async {
    if (chatId.isEmpty || myUid.isEmpty) return Future.value();
    final ref = _db.collection('chats').doc(chatId);
    try {
      if (active) {
        await ref.set({
          'typing.$myUid': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }
      await ref.set({
        'typing.$myUid': FieldValue.delete(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (_isAuthOrPermissionError(error)) return;
      rethrow;
    }
  }

  @override
  Stream<Map<String, DateTime?>> watchTyping(String chatId) {
    if (chatId.isEmpty) return const Stream<Map<String, DateTime?>>.empty();
    Stream<Map<String, DateTime?>> stream() async* {
      try {
        await for (final doc
            in _db.collection('chats').doc(chatId).snapshots()) {
          final data = doc.data() ?? <String, dynamic>{};
          final rawTyping = data['typing'];
          final typingMap = rawTyping is Map<String, dynamic>
              ? rawTyping
              : <String, dynamic>{};
          final normalized = <String, DateTime?>{};
          for (final entry in typingMap.entries) {
            final dt = _toDateTime(entry.value);
            if (dt != null) {
              normalized[entry.key] = dt;
            } else if (entry.value == true) {
              normalized[entry.key] = null;
            }
          }
          yield normalized;
        }
      } on FirebaseException catch (error) {
        if (_isAuthOrPermissionError(error)) return;
        rethrow;
      }
    }

    return stream();
  }

  Future<ChatPageCreateMessageResult> _createMediaPlaceholder({
    required String chatId,
    required String myUid,
    required bool isGroup,
    required List<dynamic> memberIds,
    required Map<String, dynamic> messagePayload,
    required String lastMessage,
    String? peerUid,
  }) async {
    var resolvedPeerUid = peerUid;
    if (!isGroup && (resolvedPeerUid == null || resolvedPeerUid.isEmpty)) {
      resolvedPeerUid = _derivePeerUidFromMembers(
        myUid: myUid,
        memberIds: memberIds,
      );
    }
    if (!isGroup && (resolvedPeerUid == null || resolvedPeerUid.isEmpty)) {
      resolvedPeerUid = _derivePeerUidFromChatId(chatId: chatId, myUid: myUid);
    }
    Future<String?>? deferredPeerUidLookup;
    if (!isGroup && (resolvedPeerUid == null || resolvedPeerUid.isEmpty)) {
      deferredPeerUidLookup = getPeerUid(chatId: chatId, myUid: myUid);
    }

    final now = DateTime.now();
    cacheLocalChatListPreview(
      chatId: chatId,
      lastMessage: lastMessage,
      lastSenderId: myUid,
      lastMessageAt: now,
    );

    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    final chatRef = _db.collection('chats').doc(chatId);

    await msgRef.set(messagePayload);

    final updateMap = <String, dynamic>{
      'lastMessage': lastMessage,
      'lastMessageAt': now,
      'lastSenderId': myUid,
      'lastMessageDeletedFor': FieldValue.delete(),
    };
    if (!isGroup) {
      updateMap.addAll(
        _buildDmRecoveryUpdate(myUid: myUid, peerUid: resolvedPeerUid),
      );
    }
    updateMap.addAll(
      _buildChatUpdateUnread(
        isGroup: isGroup,
        myUid: myUid,
        memberIds: memberIds,
        peerUid: resolvedPeerUid,
      ),
    );
    await chatRef.set(updateMap, SetOptions(merge: true));

    if (deferredPeerUidLookup != null) {
      try {
        final fetched = await deferredPeerUidLookup;
        if (fetched != null && fetched.isNotEmpty) {
          resolvedPeerUid = fetched;
          await chatRef.set({
            ..._buildDmRecoveryUpdate(myUid: myUid, peerUid: fetched),
            'unread.$fetched': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      } catch (_) {}
    }

    return ChatPageCreateMessageResult(
      messageId: msgRef.id,
      resolvedPeerUid: resolvedPeerUid,
    );
  }

  @override
  Future<ChatPageCreateMessageResult> createFilePlaceholder({
    required String chatId,
    required String myUid,
    required bool isGroup,
    required List<dynamic> memberIds,
    required String fileName,
    required int fileSize,
    String? peerUid,
  }) {
    return _createMediaPlaceholder(
      chatId: chatId,
      myUid: myUid,
      isGroup: isGroup,
      memberIds: memberIds,
      peerUid: peerUid,
      messagePayload: {
        'type': 'file',
        'fileName': fileName,
        'fileSize': fileSize,
        'fileUrl': null,
        'senderId': myUid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': myUid.isNotEmpty ? [myUid] : [],
        'delivered': false,
      },
      lastMessage: fileName,
    );
  }

  @override
  Future<ChatPageCreateMessageResult> createImagePlaceholder({
    required String chatId,
    required String myUid,
    required bool isGroup,
    required List<dynamic> memberIds,
    String? peerUid,
  }) {
    return _createMediaPlaceholder(
      chatId: chatId,
      myUid: myUid,
      isGroup: isGroup,
      memberIds: memberIds,
      peerUid: peerUid,
      messagePayload: {
        'type': 'image',
        'imageUrl': null,
        'text': 'Foto',
        'senderId': myUid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': myUid.isNotEmpty ? [myUid] : [],
        'delivered': false,
      },
      lastMessage: '[Foto]',
    );
  }

  Future<String> _uploadToStorage({
    required String chatId,
    required String storageFileName,
    required String filePath,
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    final storageRef = _storage
        .ref()
        .child('chat_media')
        .child(chatId)
        .child(storageFileName);
    final uploadTask = storageRef.putFile(file);
    var lastReportedProgress = 0.0;
    var lastReportedAt = DateTime.fromMillisecondsSinceEpoch(0);
    await for (final evt in uploadTask.snapshotEvents) {
      final total = evt.totalBytes;
      if (total <= 0) continue;
      final progress = evt.bytesTransferred / total;
      final now = DateTime.now();
      final shouldReport =
          progress >= 1.0 ||
          (progress - lastReportedProgress) >= 0.03 ||
          now.difference(lastReportedAt).inMilliseconds >= 250;
      if (shouldReport) {
        lastReportedProgress = progress;
        lastReportedAt = now;
        onProgress?.call(progress);
      }
    }
    await uploadTask;
    return storageRef.getDownloadURL();
  }

  @override
  Future<String> uploadChatFile({
    required String chatId,
    required String messageId,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) {
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return _uploadToStorage(
      chatId: chatId,
      storageFileName: '${messageId}_$sanitizedFileName',
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  @override
  Future<String> uploadChatImage({
    required String chatId,
    required String messageId,
    required String filePath,
    void Function(double progress)? onProgress,
  }) {
    return _uploadToStorage(
      chatId: chatId,
      storageFileName: '$messageId.jpg',
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> deleteChatImage({
    required String chatId,
    required String messageId,
  }) {
    return _storage
        .ref()
        .child('chat_media')
        .child(chatId)
        .child('$messageId.jpg')
        .delete();
  }

  @override
  Future<void> updateMessageFields({
    required String chatId,
    required String messageId,
    required Map<String, dynamic> data,
  }) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(data, SetOptions(merge: true));
  }

  @override
  List<ChatPageMessageRecord> getCachedMessages({
    required String chatId,
    int limit = 100,
  }) {
    return _readMessagesSessionCache(chatId: chatId, limit: limit);
  }

  @override
  Stream<List<ChatPageMessageRecord>> watchMessages({
    required String chatId,
    int limit = 100,
  }) async* {
    if (chatId.isEmpty) {
      return;
    }

    final query = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    final seenSignatures = <String>{};
    bool shouldEmit(List<ChatPageMessageRecord> items) {
      final signature = _messageRecordsSignature(items);
      if (signature.isEmpty) return false;
      return seenSignatures.add(signature);
    }

    final sessionCached = _readMessagesSessionCache(
      chatId: chatId,
      limit: limit,
    );
    if (sessionCached.isNotEmpty && shouldEmit(sessionCached)) {
      yield sessionCached;
    }

    final prefsCached = await _readMessagesCache(chatId: chatId, limit: limit);
    if (prefsCached.isNotEmpty && shouldEmit(prefsCached)) {
      _writeMessagesSessionCache(chatId: chatId, messages: prefsCached);
      yield prefsCached;
    }

    try {
      final localCache = await query.get(
        const GetOptions(source: Source.cache),
      );
      final cachedDocs = _mapMessageDocs(localCache.docs);
      if (cachedDocs.isNotEmpty && shouldEmit(cachedDocs)) {
        _writeMessagesSessionCache(chatId: chatId, messages: cachedDocs);
        yield cachedDocs;
      }
    } catch (_) {}

    try {
      await for (final snapshot in query.snapshots(
        includeMetadataChanges: true,
      )) {
        final docs = _mapMessageDocs(snapshot.docs);
        unawaited(_writeMessagesCache(chatId: chatId, messages: docs));
        if (shouldEmit(docs)) {
          yield docs;
        }
      }
    } on FirebaseException catch (error) {
      if (_isAuthOrPermissionError(error)) return;
      rethrow;
    }
  }

  @override
  Future<void> markMessageDelivered({
    required String chatId,
    required String messageId,
  }) {
    return updateMessageFields(
      chatId: chatId,
      messageId: messageId,
      data: {'delivered': true},
    );
  }

  @override
  Future<void> markMessagesDelivered({
    required String chatId,
    required Iterable<String> messageIds,
  }) async {
    if (chatId.isEmpty) return;

    final uniqueIds = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniqueIds.isEmpty) return;

    const chunkSize = 400;
    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final end = (i + chunkSize < uniqueIds.length)
          ? i + chunkSize
          : uniqueIds.length;
      final batch = _db.batch();
      for (final messageId in uniqueIds.sublist(i, end)) {
        final ref = _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId);
        batch.set(ref, {'delivered': true}, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  @override
  Future<List<ChatPageForwardTarget>> getForwardTargets({
    required String myUid,
    String? excludeChatId,
    int limit = 30,
  }) async {
    if (myUid.isEmpty) return const [];
    final qs = await _db
        .collection('chats')
        .where('members', arrayContains: myUid)
        .limit(limit)
        .get();
    final targets = <ChatPageForwardTarget>[];
    for (final doc in qs.docs) {
      if (excludeChatId != null && doc.id == excludeChatId) continue;
      final data = doc.data();
      final members = List<String>.from((data['members'] ?? const []) as List);
      final peerUid = members.firstWhere((m) => m != myUid, orElse: () => '');
      targets.add(
        ChatPageForwardTarget(
          chatId: doc.id,
          peerUid: peerUid,
          chatData: Map<String, dynamic>.from(data),
        ),
      );
    }
    return targets;
  }

  @override
  Future<void> forwardMessage({
    required String targetChatId,
    required String myUid,
    required String type,
    required String text,
    String? imageUrl,
  }) async {
    final now = DateTime.now();
    final forwardedLastMessage = type == 'image' ? '[Foto]' : text;
    cacheLocalChatListPreview(
      chatId: targetChatId,
      lastMessage: forwardedLastMessage,
      lastSenderId: myUid,
      lastMessageAt: now,
    );

    final msgRef = _db
        .collection('chats')
        .doc(targetChatId)
        .collection('messages')
        .doc();
    final chatRef = _db.collection('chats').doc(targetChatId);

    final payload = <String, dynamic>{
      'senderId': myUid,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': myUid.isNotEmpty ? [myUid] : [],
      'delivered': false,
    };
    if (type == 'image') {
      payload['type'] = 'image';
      payload['imageUrl'] = imageUrl;
      payload['text'] = 'Foto';
    } else {
      payload['type'] = 'text';
      payload['text'] = text;
    }

    final batch = _db.batch();
    batch.set(msgRef, payload);
    batch.set(chatRef, {
      'lastMessage': forwardedLastMessage,
      'lastMessageAt': now,
      'lastSenderId': myUid,
      'lastMessageDeletedFor': FieldValue.delete(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String myUid,
  }) {
    return updateMessageFields(
      chatId: chatId,
      messageId: messageId,
      data: {
        'deletedFor': FieldValue.arrayUnion([myUid]),
      },
    );
  }

  @override
  Future<void> deleteMessageForAll({
    required String chatId,
    required String messageId,
  }) async {
    final now = DateTime.now();
    cacheLocalChatListPreview(
      chatId: chatId,
      lastMessage: 'Pesan ini telah dihapus',
      lastSenderId: currentUserUid,
      lastMessageAt: now,
    );

    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc(messageId);
    final batch = _db.batch();
    batch.set(msgRef, {'isDeleted': true}, SetOptions(merge: true));
    batch.set(chatRef, {
      'lastMessage': 'Pesan ini telah dihapus',
      'lastMessageAt': now,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<Map<String, dynamic>> fetchMessage({
    required String chatId,
    required String messageId,
  }) async {
    final snap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .get();
    return snap.data() ?? <String, dynamic>{};
  }

  @override
  Future<void> clearMessageMedia({
    required String chatId,
    required String messageId,
  }) {
    return updateMessageFields(
      chatId: chatId,
      messageId: messageId,
      data: {
        'imageUrl': FieldValue.delete(),
        'localPath': FieldValue.delete(),
        'isDeleted': true,
        'text': 'Pesan ini telah dihapus',
      },
    );
  }

  @override
  Future<void> toggleStar({
    required String chatId,
    required String messageId,
    required bool value,
    required String myUid,
  }) {
    final data = <String, dynamic>{
      'starred': value,
      'starredAt': FieldValue.serverTimestamp(),
    };
    if (myUid.isNotEmpty) {
      data['starredBy'] = value
          ? FieldValue.arrayUnion([myUid])
          : FieldValue.arrayRemove([myUid]);
    }
    return updateMessageFields(
      chatId: chatId,
      messageId: messageId,
      data: data,
    );
  }

  List<ChatPageMessageRecord> _mapMessageDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          final createdAt = _toDateTime(data['createdAt']);
          if (createdAt != null) {
            data['createdAt'] = createdAt;
          }
          return ChatPageMessageRecord(id: doc.id, data: data);
        })
        .toList(growable: false);
  }

  String _messagesCacheKey(String chatId) => '$_messagesCachePrefix$chatId';

  Future<List<ChatPageMessageRecord>> _readMessagesCache({
    required String chatId,
    required int limit,
  }) async {
    if (chatId.isEmpty) return const <ChatPageMessageRecord>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_messagesCacheKey(chatId));
      if (raw == null || raw.isEmpty) return const <ChatPageMessageRecord>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ChatPageMessageRecord>[];
      final records = <ChatPageMessageRecord>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final id = (item['id'] ?? '').toString();
        final data = item['data'];
        if (id.isEmpty || data is! Map) continue;
        records.add(
          ChatPageMessageRecord(
            id: id,
            data: _normalizeCachedMessageData(data),
          ),
        );
      }
      if (limit > 0 && records.length > limit) {
        return records.sublist(0, limit);
      }
      return records;
    } catch (_) {
      return const <ChatPageMessageRecord>[];
    }
  }

  Future<void> _writeMessagesCache({
    required String chatId,
    required List<ChatPageMessageRecord> messages,
  }) async {
    if (chatId.isEmpty) return;
    _writeMessagesSessionCache(chatId: chatId, messages: messages);
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = messages
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'data': _encodeMap(item.data),
            },
          )
          .toList(growable: false);
      await prefs.setString(_messagesCacheKey(chatId), jsonEncode(payload));
    } catch (_) {}
  }

  Map<String, dynamic> _normalizeCachedMessageData(dynamic source) {
    final data = source is Map
        ? Map<String, dynamic>.from(source)
        : <String, dynamic>{};
    final createdAt = _toDateTime(data['createdAt']);
    if (createdAt != null) {
      data['createdAt'] = createdAt;
    }
    return data;
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

  String _messageRecordsSignature(List<ChatPageMessageRecord> records) {
    if (records.isEmpty) return '__empty__';
    final buffer = StringBuffer();
    for (final record in records) {
      final data = record.data;
      buffer.write(record.id);
      buffer.write('|');
      final createdAt = _toDateTime(data['createdAt']);
      if (createdAt != null) {
        buffer.write(createdAt.millisecondsSinceEpoch);
      }
      buffer.write('|');
      buffer.write((data['delivered'] ?? false) == true ? '1' : '0');
      buffer.write('|');
      buffer.write((data['isDeleted'] ?? false) == true ? '1' : '0');
      buffer.write('|');
      final readBy = data['readBy'];
      if (readBy is List) {
        buffer.write(readBy.length);
      } else {
        buffer.write('0');
      }
      buffer.write(';');
    }
    return buffer.toString();
  }

  List<ChatPageMessageRecord> _cloneMessageRecords(
    List<ChatPageMessageRecord> records,
  ) {
    return records
        .map(
          (record) => ChatPageMessageRecord(
            id: record.id,
            data: Map<String, dynamic>.from(record.data),
          ),
        )
        .toList(growable: false);
  }

  List<ChatPageMessageRecord> _readMessagesSessionCache({
    required String chatId,
    required int limit,
  }) {
    if (chatId.isEmpty) return const <ChatPageMessageRecord>[];
    final cached = _messagesSessionCache[chatId];
    if (cached == null || cached.isEmpty) {
      return const <ChatPageMessageRecord>[];
    }
    final sliced = (limit > 0 && cached.length > limit)
        ? cached.sublist(0, limit)
        : cached;
    return _cloneMessageRecords(sliced);
  }

  void _writeMessagesSessionCache({
    required String chatId,
    required List<ChatPageMessageRecord> messages,
  }) {
    if (chatId.isEmpty) return;
    final cloned = _cloneMessageRecords(messages);
    _messagesSessionCache[chatId] = cloned;
  }
}
