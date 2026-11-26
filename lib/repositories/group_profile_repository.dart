import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;

class GroupProfileChatData {
  const GroupProfileChatData({
    this.groupName = 'Group',
    this.groupAvatarUrl = '',
    this.createdBy = '',
    this.admins = const <String>[],
    this.members = const <String>[],
    this.memberInfo = const <String, Map<String, dynamic>>{},
  });

  final String groupName;
  final String groupAvatarUrl;
  final String createdBy;
  final List<String> admins;
  final List<String> members;
  final Map<String, Map<String, dynamic>> memberInfo;
}

class GroupProfileMediaFilePreview {
  const GroupProfileMediaFilePreview({required this.url, required this.name});

  final String url;
  final String name;
}

class GroupProfileMediaDocsPreview {
  const GroupProfileMediaDocsPreview({
    this.images = const <String>[],
    this.files = const <GroupProfileMediaFilePreview>[],
  });

  final List<String> images;
  final List<GroupProfileMediaFilePreview> files;
}

abstract class GroupProfileRepository {
  String get currentUserUid;

  Stream<GroupProfileChatData> watchGroup(String chatId);

  Stream<GroupProfileMediaDocsPreview> watchMediaDocsPreview(
    String chatId, {
    int limit = 150,
  });

  Future<void> clearGroupChatHistory(String chatId);

  Future<void> leaveGroup({required String chatId, required String uid});

  Future<void> updateGroupName({required String chatId, required String name});

  Future<String> uploadGroupAvatar({
    required String chatId,
    required String filePath,
  });

  Future<void> setAdmin({
    required String chatId,
    required String uid,
    required bool value,
  });

  Future<void> removeMember({required String chatId, required String uid});
}

class GroupProfileRepositoryImpl implements GroupProfileRepository {
  GroupProfileRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    fb_storage.FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final fb_storage.FirebaseStorage? _storage;

  @override
  String get currentUserUid => _auth.currentUser?.uid ?? '';

  List<String> _asStringList(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, Map<String, dynamic>> _asMemberInfo(dynamic raw) {
    if (raw is! Map) return const <String, Map<String, dynamic>>{};
    final mapped = <String, Map<String, dynamic>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value is Map) {
        mapped[key] = Map<String, dynamic>.from(value);
      }
    }
    return mapped;
  }

  @override
  Stream<GroupProfileChatData> watchGroup(String chatId) {
    if (chatId.isEmpty) {
      return Stream.value(const GroupProfileChatData());
    }

    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      final members = _asStringList(data['members']);
      final memberInfo = _asMemberInfo(data['memberInfo']);
      if (memberInfo.isEmpty && members.isNotEmpty) {
        final fallback = <String, Map<String, dynamic>>{};
        for (final uid in members) {
          fallback[uid] = const <String, dynamic>{};
        }
        return GroupProfileChatData(
          groupName: (data['groupName'] ?? 'Group').toString(),
          groupAvatarUrl: (data['groupAvatarUrl'] ?? '').toString(),
          createdBy: (data['createdBy'] ?? '').toString(),
          admins: _asStringList(data['admins']),
          members: members,
          memberInfo: fallback,
        );
      }

      return GroupProfileChatData(
        groupName: (data['groupName'] ?? 'Group').toString(),
        groupAvatarUrl: (data['groupAvatarUrl'] ?? '').toString(),
        createdBy: (data['createdBy'] ?? '').toString(),
        admins: _asStringList(data['admins']),
        members: members,
        memberInfo: memberInfo,
      );
    });
  }

  @override
  Stream<GroupProfileMediaDocsPreview> watchMediaDocsPreview(
    String chatId, {
    int limit = 150,
  }) {
    if (chatId.isEmpty) {
      return Stream.value(const GroupProfileMediaDocsPreview());
    }

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('ts', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final images = <String>[];
          final files = <GroupProfileMediaFilePreview>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final type = (data['type'] ?? '').toString();
            final imageUrl = (data['imageUrl'] ?? data['photoUrl'] ?? '')
                .toString();
            final fileUrl = (data['fileUrl'] ?? '').toString();
            final fileName = (data['fileName'] ?? '').toString();

            if (imageUrl.isNotEmpty || type == 'image') {
              if (imageUrl.isNotEmpty) {
                images.add(imageUrl);
              }
            }

            if (fileUrl.isNotEmpty || type == 'file') {
              files.add(
                GroupProfileMediaFilePreview(
                  url: fileUrl,
                  name: fileName.isNotEmpty ? fileName : 'File',
                ),
              );
            }

            if (images.length >= 6 && files.length >= 6) {
              break;
            }
          }

          return GroupProfileMediaDocsPreview(images: images, files: files);
        });
  }

  @override
  Future<void> clearGroupChatHistory(String chatId) async {
    if (chatId.isEmpty) return;

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    const batchSize = 450;
    while (true) {
      final snapshot = await messagesRef.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < batchSize) break;
    }

    await chatRef.set({
      'lastMessage': 'Riwayat chat grup dibersihkan',
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> leaveGroup({required String chatId, required String uid}) {
    if (chatId.isEmpty || uid.isEmpty) return Future.value();
    return _firestore.collection('chats').doc(chatId).update({
      'members': FieldValue.arrayRemove([uid]),
      'memberInfo.$uid': FieldValue.delete(),
      'admins': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> updateGroupName({required String chatId, required String name}) {
    if (chatId.isEmpty || name.trim().isEmpty) return Future.value();
    return _firestore.collection('chats').doc(chatId).set({
      'groupName': name.trim(),
    }, SetOptions(merge: true));
  }

  @override
  Future<String> uploadGroupAvatar({
    required String chatId,
    required String filePath,
  }) async {
    if (chatId.isEmpty || filePath.isEmpty) {
      throw ArgumentError('chatId/filePath wajib diisi');
    }

    final storage = _storage ?? fb_storage.FirebaseStorage.instance;
    final ref = storage.ref().child('group_avatars/$chatId.jpg');
    await ref.putFile(File(filePath));
    final url = await ref.getDownloadURL();
    await _firestore.collection('chats').doc(chatId).set({
      'groupAvatarUrl': url,
    }, SetOptions(merge: true));
    return url;
  }

  @override
  Future<void> setAdmin({
    required String chatId,
    required String uid,
    required bool value,
  }) {
    if (chatId.isEmpty || uid.isEmpty) return Future.value();
    return _firestore.collection('chats').doc(chatId).update({
      'admins': value
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> removeMember({required String chatId, required String uid}) {
    if (chatId.isEmpty || uid.isEmpty) return Future.value();
    return _firestore.collection('chats').doc(chatId).update({
      'members': FieldValue.arrayRemove([uid]),
      'memberInfo.$uid': FieldValue.delete(),
      'admins': FieldValue.arrayRemove([uid]),
    });
  }
}
