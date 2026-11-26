import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CreateGroupMyProfile {
  const CreateGroupMyProfile({
    required this.name,
    required this.pin,
    required this.avatarUrl,
  });

  final String name;
  final String pin;
  final String avatarUrl;
}

class CreateGroupContact {
  const CreateGroupContact({
    required this.uid,
    required this.displayName,
    required this.alias,
    required this.name,
    required this.fullName,
    required this.pin,
    required this.userPin,
    required this.chatPin,
    required this.photoUrl,
    required this.avatarUrl,
    required this.profilePhoto,
    required this.collection,
  });

  final String uid;
  final String displayName;
  final String alias;
  final String name;
  final String fullName;
  final String pin;
  final String userPin;
  final String chatPin;
  final String photoUrl;
  final String avatarUrl;
  final String profilePhoto;
  final String collection;

  factory CreateGroupContact.fromMap(String uid, Map<String, dynamic> data) {
    return CreateGroupContact(
      uid: uid,
      displayName: (data['displayName'] ?? '').toString(),
      alias: (data['alias'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      fullName: (data['fullName'] ?? '').toString(),
      pin: (data['pin'] ?? '').toString(),
      userPin: (data['userPin'] ?? '').toString(),
      chatPin: (data['chatPin'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      avatarUrl: (data['avatarUrl'] ?? '').toString(),
      profilePhoto: (data['profilePhoto'] ?? '').toString(),
      collection: (data['collection'] ?? 'users').toString(),
    );
  }

  String get displayLabel {
    if (alias.trim().isNotEmpty) return alias.trim();
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (name.trim().isNotEmpty) return name.trim();
    if (fullName.trim().isNotEmpty) return fullName.trim();
    return 'Tanpa Nama';
  }

  String get resolvedPin {
    final value = _firstNonEmpty([pin, chatPin, userPin]);
    return value.toUpperCase();
  }

  String get resolvedAvatar {
    return _firstNonEmpty([photoUrl, avatarUrl, profilePhoto]);
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final fields = <String>[
      displayName,
      alias,
      name,
      fullName,
      pin,
      userPin,
      chatPin,
    ];
    return fields.any((value) => value.toLowerCase().contains(normalized));
  }
}

class CreateGroupSelectedMember {
  const CreateGroupSelectedMember({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.pin,
  });

  final String uid;
  final String name;
  final String avatarUrl;
  final String pin;
}

class CreateGroupCreateResponse {
  const CreateGroupCreateResponse({
    required this.chatId,
    required this.groupName,
    this.avatarUploadWarning,
  });

  final String chatId;
  final String groupName;
  final String? avatarUploadWarning;
}

abstract class CreateGroupRepository {
  String? get currentUserUid;

  Stream<String?> watchAuthUserIds();

  Future<CreateGroupMyProfile?> fetchMyProfile(String uid);

  Stream<List<CreateGroupContact>> watchContacts(String uid);

  Future<CreateGroupSelectedMember?> resolveSelectedMember(
    CreateGroupContact contact,
  );

  Future<CreateGroupCreateResponse> createGroup({
    required String groupName,
    required String groupDescription,
    required Map<String, CreateGroupSelectedMember> selectedMembers,
    String? imagePath,
  });
}

class CreateGroupRepositoryImpl implements CreateGroupRepository {
  CreateGroupRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Stream<String?> watchAuthUserIds() {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  @override
  Future<CreateGroupMyProfile?> fetchMyProfile(String uid) async {
    if (uid.isEmpty) return null;

    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data() ?? <String, dynamic>{};
    final current = _auth.currentUser;
    final name = _firstNonEmpty([
      data['name']?.toString(),
      data['displayName']?.toString(),
      data['fullName']?.toString(),
      current?.displayName,
      'Teman',
    ]);
    final pin = _firstNonEmpty([
      data['pin']?.toString(),
      data['userPin']?.toString(),
      data['chatPin']?.toString(),
    ]).toUpperCase();
    final avatar = _resolveAvatar(data);

    return CreateGroupMyProfile(name: name, pin: pin, avatarUrl: avatar);
  }

  @override
  Stream<List<CreateGroupContact>> watchContacts(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .orderBy('displayName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CreateGroupContact.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  @override
  Future<CreateGroupSelectedMember?> resolveSelectedMember(
    CreateGroupContact contact,
  ) async {
    final uid = contact.uid;
    if (uid.isEmpty) return null;

    final collection = contact.collection.trim().isEmpty
        ? 'users'
        : contact.collection.trim();
    final profileSnap = await _firestore.collection(collection).doc(uid).get();
    final profile = profileSnap.data() ?? <String, dynamic>{};

    final displayName = contact.alias.trim().isNotEmpty
        ? contact.alias.trim()
        : _firstNonEmpty([
            profile['name']?.toString(),
            profile['displayName']?.toString(),
            profile['username']?.toString(),
            profile['fullName']?.toString(),
            contact.displayName,
            contact.name,
            contact.fullName,
            'Anggota',
          ]);
    final avatar = _resolveAvatar(profile);
    final pin = _firstNonEmpty([
      profile['pin']?.toString(),
      profile['userPin']?.toString(),
      profile['chatPin']?.toString(),
      contact.pin,
      contact.userPin,
      contact.chatPin,
    ]).toUpperCase();

    return CreateGroupSelectedMember(
      uid: uid,
      name: displayName,
      avatarUrl: avatar,
      pin: pin,
    );
  }

  @override
  Future<CreateGroupCreateResponse> createGroup({
    required String groupName,
    required String groupDescription,
    required Map<String, CreateGroupSelectedMember> selectedMembers,
    String? imagePath,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Harus login untuk membuat grup');
    }

    final docRef = _firestore.collection('chats').doc();
    final profileSnap = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final profile = profileSnap.data() ?? <String, dynamic>{};

    final displayName = _firstNonEmpty([
      profile['name']?.toString(),
      profile['displayName']?.toString(),
      profile['fullName']?.toString(),
      user.displayName,
      'Teman',
    ]);
    final avatarUrl = _resolveAvatar(profile);
    final pin = _firstNonEmpty([
      profile['pin']?.toString(),
      profile['userPin']?.toString(),
      profile['chatPin']?.toString(),
    ]).toUpperCase();

    final now = FieldValue.serverTimestamp();
    final members = <String>{user.uid, ...selectedMembers.keys};
    final memberInfo = <String, dynamic>{
      user.uid: {
        'name': displayName,
        'avatarUrl': avatarUrl,
        'pin': pin,
        'joinedAt': now,
        'role': 'admin',
      },
    };

    final unread = <String, int>{for (final id in members) id: 0};
    for (final entry in selectedMembers.entries) {
      final member = entry.value;
      memberInfo[entry.key] = {
        'name': member.name,
        'avatarUrl': member.avatarUrl,
        'pin': member.pin,
        'joinedAt': now,
        'role': 'member',
      };
    }

    final payload = <String, dynamic>{
      'type': 'group',
      'groupName': groupName,
      'groupNameLower': groupName.toLowerCase(),
      if (groupDescription.trim().isNotEmpty)
        'groupDescription': groupDescription,
      'groupAvatarUrl': '',
      'createdAt': now,
      'createdBy': user.uid,
      'members': members.toList(growable: false),
      'admins': <String>[user.uid],
      'memberInfo': memberInfo,
      'unread': unread,
      'lastMessage': '',
      'lastSenderId': user.uid,
      'lastMessageAt': now,
    };

    await docRef.set(payload, SetOptions(merge: true));

    String? avatarUploadWarning;
    final normalizedImagePath = imagePath?.trim() ?? '';
    if (normalizedImagePath.isNotEmpty) {
      try {
        final file = File(normalizedImagePath);
        if (file.existsSync()) {
          final storageRef = _storage.ref().child(
            'group_avatars/${docRef.id}.jpg',
          );
          await storageRef.putFile(file);
          final url = await storageRef.getDownloadURL();
          await docRef.set({'groupAvatarUrl': url}, SetOptions(merge: true));
        }
      } catch (error) {
        avatarUploadWarning = 'Foto grup gagal diunggah: $error';
      }
    }

    return CreateGroupCreateResponse(
      chatId: docRef.id,
      groupName: groupName,
      avatarUploadWarning: avatarUploadWarning,
    );
  }

  String _resolveAvatar(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['avatarUrl']?.toString(),
      data['photoUrl']?.toString(),
      data['profilePhoto']?.toString(),
      data['photoURL']?.toString(),
    ]);
  }
}

String _firstNonEmpty(List<String?> candidates) {
  for (final candidate in candidates) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}
