import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactListUserProfile {
  const ContactListUserProfile({
    required this.uid,
    required this.name,
    required this.pin,
    required this.photoUrl,
    required this.online,
  });

  final String uid;
  final String name;
  final String pin;
  final String photoUrl;
  final bool online;
}

class ContactListContact {
  const ContactListContact({
    required this.peerUid,
    required this.displayName,
    required this.pin,
    required this.alias,
    required this.collection,
    this.photoUrl = '',
    this.online = false,
  });

  final String peerUid;
  final String displayName;
  final String pin;
  final String alias;
  final String collection;
  final String photoUrl;
  final bool online;
}

enum ContactListAddContactStatus {
  success,
  invalidPin,
  notFound,
  self,
  invalidPeerData,
  failure,
}

class ContactListAddContactResult {
  const ContactListAddContactResult({
    required this.status,
    this.message,
    this.contact,
  });

  final ContactListAddContactStatus status;
  final String? message;
  final ContactListContact? contact;
}

enum ContactListAddMemberStatus { added, alreadyMember, groupNotFound, failure }

class ContactListAddMemberResult {
  const ContactListAddMemberResult({
    required this.status,
    this.message,
    this.resolvedName,
  });

  final ContactListAddMemberStatus status;
  final String? message;
  final String? resolvedName;
}

abstract class ContactListRepository {
  String get currentUserUid;
  String? get currentUserDisplayName;
  String? get currentUserPhotoUrl;

  Stream<ContactListUserProfile?> watchCurrentUserProfile({
    required String uid,
  });

  Stream<List<ContactListContact>> watchContacts({required String uid});

  Future<ContactListUserProfile> fetchUserProfile(
    String uid, {
    String collection = 'users',
  });

  Future<ContactListAddContactResult> addContactByPin({
    required String myUid,
    required String pin,
    String alias,
  });

  Future<void> updateContactAlias({
    required String myUid,
    required String peerUid,
    required String alias,
  });

  Future<void> deleteContact({required String myUid, required String peerUid});

  Future<String?> ensureDmChat({
    required String myUid,
    required String peerUid,
    String? peerName,
    String? peerAvatarUrl,
    String? peerPin,
    String? myName,
    String? myAvatarUrl,
    String? myPin,
  });

  Future<ContactListAddMemberResult> addMemberToGroup({
    required String chatId,
    required String myUid,
    required String peerUid,
    required String displayName,
    required String alias,
    required String pin,
    required String avatarUrl,
  });
}

class ContactListRepositoryImpl implements ContactListRepository {
  ContactListRepositoryImpl({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const String _contactsCachePrefix = 'contact_list_cache_v1_';
  static final Map<String, List<ContactListContact>> _contactsSessionCache =
      <String, List<ContactListContact>>{};

  static const List<String> _candidateUserCollections = [
    'users',
    'profiles',
    'user_profiles',
    'members',
  ];

  @override
  String get currentUserUid => _auth.currentUser?.uid ?? '';

  @override
  String? get currentUserDisplayName => _auth.currentUser?.displayName;

  @override
  String? get currentUserPhotoUrl => _auth.currentUser?.photoURL;

  String _normPin(String s) {
    return s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  bool _isPermissionDenied(FirebaseException error) {
    final code = error.code.trim().toLowerCase();
    return code == 'permission-denied' || code == 'unauthenticated';
  }

  @override
  Stream<ContactListUserProfile?> watchCurrentUserProfile({
    required String uid,
  }) {
    if (uid.isEmpty) return const Stream<ContactListUserProfile?>.empty();
    return (() async* {
      try {
        await for (final snapshot
            in _db.collection('users').doc(uid).snapshots()) {
          final data = snapshot.data();
          if (data == null) {
            yield null;
            continue;
          }
          yield ContactListUserProfile(
            uid: uid,
            name: (data['name'] ?? '').toString(),
            pin: (data['pin'] ?? '').toString(),
            photoUrl: (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString(),
            online: (data['online'] ?? false) == true,
          );
        }
      } on FirebaseException catch (error) {
        if (_isPermissionDenied(error)) {
          yield null;
          return;
        }
        rethrow;
      }
    })();
  }

  @override
  Stream<List<ContactListContact>> watchContacts({required String uid}) {
    if (uid.isEmpty) return const Stream<List<ContactListContact>>.empty();

    Stream<List<ContactListContact>> stream() async* {
      final query = _db
          .collection('users')
          .doc(uid)
          .collection('contacts')
          .orderBy('displayName', descending: false);

      String? lastSignature;
      bool shouldEmit(List<ContactListContact> items) {
        final signature = _contactsSignature(items);
        if (signature == lastSignature) return false;
        lastSignature = signature;
        return true;
      }

      final sessionCached = _readContactsSessionCache(uid);
      if (sessionCached.isNotEmpty && shouldEmit(sessionCached)) {
        yield sessionCached;
      }

      final prefsCached = await _readContactsCache(uid);
      if (prefsCached.isNotEmpty && shouldEmit(prefsCached)) {
        _writeContactsSessionCache(uid: uid, contacts: prefsCached);
        yield prefsCached;
      }

      try {
        final localSnapshot = await query.get(
          const GetOptions(source: Source.cache),
        );
        final localContacts = _mapContactDocs(localSnapshot.docs);
        if (localContacts.isNotEmpty && shouldEmit(localContacts)) {
          _writeContactsSessionCache(uid: uid, contacts: localContacts);
          yield localContacts;
        }
      } catch (_) {}

      try {
        await for (final snapshot in query.snapshots()) {
          final contacts = _mapContactDocs(snapshot.docs);
          _writeContactsSessionCache(uid: uid, contacts: contacts);
          await _writeContactsCache(uid: uid, contacts: contacts);
          if (shouldEmit(contacts)) {
            yield contacts;
          }
        }
      } on FirebaseException catch (error) {
        if (_isPermissionDenied(error)) {
          if (shouldEmit(const <ContactListContact>[])) {
            yield const <ContactListContact>[];
          }
          return;
        }
        rethrow;
      }
    }

    return stream();
  }

  @override
  Future<ContactListUserProfile> fetchUserProfile(
    String uid, {
    String collection = 'users',
  }) async {
    if (uid.isEmpty) {
      return const ContactListUserProfile(
        uid: '',
        name: '',
        pin: '',
        photoUrl: '',
        online: false,
      );
    }

    try {
      final d = await _db.collection(collection).doc(uid).get();
      final data = d.data() ?? <String, dynamic>{};
      return ContactListUserProfile(
        uid: uid,
        name:
            (data['name'] ??
                    data['displayName'] ??
                    data['username'] ??
                    data['fullName'] ??
                    '')
                .toString(),
        pin:
            (data['pin'] ??
                    data['userPin'] ??
                    data['PIN'] ??
                    data['pinUpper'] ??
                    '')
                .toString(),
        photoUrl: (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString(),
        online: (data['online'] ?? false) == true,
      );
    } catch (_) {
      try {
        final d2 = await _db.collection('users').doc(uid).get();
        final data = d2.data() ?? <String, dynamic>{};
        return ContactListUserProfile(
          uid: uid,
          name:
              (data['name'] ??
                      data['displayName'] ??
                      data['username'] ??
                      data['fullName'] ??
                      '')
                  .toString(),
          pin:
              (data['pin'] ??
                      data['userPin'] ??
                      data['PIN'] ??
                      data['pinUpper'] ??
                      '')
                  .toString(),
          photoUrl: (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString(),
          online: (data['online'] ?? false) == true,
        );
      } catch (_) {
        return ContactListUserProfile(
          uid: uid,
          name: '',
          pin: '',
          photoUrl: '',
          online: false,
        );
      }
    }
  }

  Future<MapEntry<String, DocumentSnapshot<Map<String, dynamic>>>?>
  _findByPinsCollection(String normalizedPin) async {
    try {
      final doc = await _db.collection('pins').doc(normalizedPin).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final uid = (data['uid'] ?? data['userId'] ?? '').toString();
      if (uid.isEmpty) return null;
      final coll = (data['collection'] ?? 'users').toString();
      final userDoc = await _db.collection(coll).doc(uid).get();
      if (!userDoc.exists) return null;
      return MapEntry(coll, userDoc);
    } catch (_) {
      return null;
    }
  }

  Future<MapEntry<String, DocumentSnapshot<Map<String, dynamic>>>?>
  _findUserByPin(String pinUpperNoSpace) async {
    for (final coll in _candidateUserCollections) {
      final tries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _db
            .collection(coll)
            .where('pin', isEqualTo: pinUpperNoSpace)
            .limit(1)
            .get(),
        _db
            .collection(coll)
            .where('userPin', isEqualTo: pinUpperNoSpace)
            .limit(1)
            .get(),
        _db
            .collection(coll)
            .where('PIN', isEqualTo: pinUpperNoSpace)
            .limit(1)
            .get(),
        _db
            .collection(coll)
            .where('pinUpper', isEqualTo: pinUpperNoSpace)
            .limit(1)
            .get(),
      ];
      for (final fut in tries) {
        try {
          final q = await fut;
          if (q.docs.isNotEmpty) {
            return MapEntry(coll, q.docs.first);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<MapEntry<String, DocumentSnapshot<Map<String, dynamic>>>?>
  _fallbackScanByPin(String normalizedPin) async {
    try {
      for (final coll in _candidateUserCollections) {
        final snap = await _db.collection(coll).limit(500).get();
        for (final d in snap.docs) {
          final data = d.data();
          final candidates = [
            data['pin'],
            data['userPin'],
            data['PIN'],
            data['pinUpper'],
          ];
          for (final c in candidates) {
            if (c == null) continue;
            final norm = _normPin(c.toString());
            if (norm == normalizedPin) {
              return MapEntry(coll, d);
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<ContactListAddContactResult> addContactByPin({
    required String myUid,
    required String pin,
    String alias = '',
  }) async {
    final normalizedPin = _normPin(pin);
    if (normalizedPin.isEmpty) {
      return const ContactListAddContactResult(
        status: ContactListAddContactStatus.invalidPin,
        message: 'PIN wajib diisi',
      );
    }
    if (myUid.isEmpty) {
      return const ContactListAddContactResult(
        status: ContactListAddContactStatus.failure,
        message: 'Harus login terlebih dahulu',
      );
    }

    MapEntry<String, DocumentSnapshot<Map<String, dynamic>>>? found;
    try {
      found = await _findByPinsCollection(normalizedPin);
      found ??= await _findUserByPin(normalizedPin);
      found ??= await _fallbackScanByPin(normalizedPin);
      if (found == null || !found.value.exists) {
        return const ContactListAddContactResult(
          status: ContactListAddContactStatus.notFound,
          message: 'PIN tidak ditemukan',
        );
      }

      final peerUid = found.value.id;
      if (peerUid == myUid) {
        return const ContactListAddContactResult(
          status: ContactListAddContactStatus.self,
          message: 'Tidak bisa menambahkan diri sendiri',
        );
      }

      final peerData = found.value.data();
      if (peerData == null) {
        return const ContactListAddContactResult(
          status: ContactListAddContactStatus.invalidPeerData,
          message: 'Data kontak tidak lengkap',
        );
      }

      final contact = ContactListContact(
        peerUid: peerUid,
        displayName:
            (peerData['name'] ??
                    peerData['displayName'] ??
                    peerData['username'] ??
                    peerData['fullName'] ??
                    '')
                .toString(),
        pin:
            (peerData['pin'] ??
                    peerData['userPin'] ??
                    peerData['PIN'] ??
                    peerData['pinUpper'] ??
                    normalizedPin)
                .toString(),
        alias: alias,
        collection: found.key,
        photoUrl: (peerData['photoUrl'] ?? peerData['avatarUrl'] ?? '')
            .toString(),
        online: (peerData['online'] ?? false) == true,
      );

      await _db
          .collection('users')
          .doc(myUid)
          .collection('contacts')
          .doc(contact.peerUid)
          .set({
            'displayName': contact.displayName,
            'pin': contact.pin,
            'alias': contact.alias,
            'collection': contact.collection,
            'photoUrl': contact.photoUrl,
            'online': contact.online,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await _upsertCachedContact(uid: myUid, contact: contact);

      return ContactListAddContactResult(
        status: ContactListAddContactStatus.success,
        message: 'Kontak ditambahkan',
        contact: contact,
      );
    } catch (e) {
      return ContactListAddContactResult(
        status: ContactListAddContactStatus.failure,
        message: 'Gagal menambah kontak: $e',
      );
    }
  }

  @override
  Future<void> updateContactAlias({
    required String myUid,
    required String peerUid,
    required String alias,
  }) async {
    await _db
        .collection('users')
        .doc(myUid)
        .collection('contacts')
        .doc(peerUid)
        .set({'alias': alias}, SetOptions(merge: true));

    final cached = await _readMergedCachedContacts(myUid);
    final index = cached.indexWhere((contact) => contact.peerUid == peerUid);
    if (index < 0) return;
    final previous = cached[index];
    cached[index] = ContactListContact(
      peerUid: previous.peerUid,
      displayName: previous.displayName,
      pin: previous.pin,
      alias: alias,
      collection: previous.collection,
      photoUrl: previous.photoUrl,
      online: previous.online,
    );
    cached.sort((a, b) => a.displayName.compareTo(b.displayName));
    _writeContactsSessionCache(uid: myUid, contacts: cached);
    await _writeContactsCache(uid: myUid, contacts: cached);
  }

  @override
  Future<void> deleteContact({
    required String myUid,
    required String peerUid,
  }) async {
    final before = await _readMergedCachedContacts(myUid);
    await _removeCachedContact(uid: myUid, peerUid: peerUid);
    try {
      await _db
          .collection('users')
          .doc(myUid)
          .collection('contacts')
          .doc(peerUid)
          .delete();
    } catch (_) {
      _writeContactsSessionCache(uid: myUid, contacts: before);
      await _writeContactsCache(uid: myUid, contacts: before);
      rethrow;
    }
  }

  @override
  Future<String?> ensureDmChat({
    required String myUid,
    required String peerUid,
    String? peerName,
    String? peerAvatarUrl,
    String? peerPin,
    String? myName,
    String? myAvatarUrl,
    String? myPin,
  }) async {
    if (myUid.isEmpty || peerUid.isEmpty) return null;

    try {
      final ids = [myUid, peerUid]..sort();
      final chatId = ids.join('_');
      final chatRef = _db.collection('chats').doc(chatId);

      String resolvedMyName = (myName?.trim().isNotEmpty == true)
          ? myName!.trim()
          : (_auth.currentUser?.displayName?.trim() ?? '');
      String resolvedMyAvatar = (myAvatarUrl?.trim().isNotEmpty == true)
          ? myAvatarUrl!.trim()
          : (_auth.currentUser?.photoURL ?? '');
      String resolvedMyPin = (myPin ?? '').trim();

      String resolvedPeerName = (peerName?.trim().isNotEmpty == true)
          ? peerName!.trim()
          : '';
      String resolvedPeerAvatar = (peerAvatarUrl ?? '').trim();
      String resolvedPeerPin = (peerPin ?? '').trim();

      final existing = await chatRef.get();
      if (existing.exists) {
        final existingData = existing.data() ?? <String, dynamic>{};
        final existingMembers = <String>{
          for (final m in (existingData['members'] as List? ?? const []))
            m.toString(),
        };
        final Map<String, dynamic> existingMemberInfo =
            Map<String, dynamic>.from(
              (existingData['memberInfo'] as Map? ?? const {}),
            );
        final Map<String, dynamic> existingUnread = Map<String, dynamic>.from(
          (existingData['unread'] as Map? ?? const {}),
        );

        final updates = <String, dynamic>{};
        if (!existingMembers.contains(myUid) ||
            !existingMembers.contains(peerUid)) {
          updates['members'] = FieldValue.arrayUnion([myUid, peerUid]);
        }
        updates['memberInfo.$myUid'] = {
          'name': resolvedMyName.isNotEmpty ? resolvedMyName : 'Teman',
          'avatarUrl': resolvedMyAvatar,
          'pin': resolvedMyPin,
          'role': (existingMemberInfo[myUid]?['role'] ?? 'member').toString(),
        };
        updates['memberInfo.$peerUid'] = {
          'name': resolvedPeerName.isNotEmpty ? resolvedPeerName : 'Teman',
          'avatarUrl': resolvedPeerAvatar,
          'pin': resolvedPeerPin,
          'role': (existingMemberInfo[peerUid]?['role'] ?? 'member').toString(),
        };
        if (!existingUnread.containsKey(myUid) ||
            existingUnread[myUid] is! int) {
          updates['unread.$myUid'] = 0;
        }
        if (!existingUnread.containsKey(peerUid) ||
            existingUnread[peerUid] is! int) {
          updates['unread.$peerUid'] = 0;
        }
        if (updates.isNotEmpty) {
          await chatRef.set(updates, SetOptions(merge: true));
        }
        return chatId;
      }

      if (resolvedMyName.trim().isEmpty ||
          resolvedMyAvatar.trim().isEmpty ||
          resolvedMyPin.trim().isEmpty) {
        try {
          final myDoc = await _db.collection('users').doc(myUid).get();
          final myData = myDoc.data() ?? <String, dynamic>{};
          if (resolvedMyName.trim().isEmpty) {
            resolvedMyName =
                (myData['name'] ??
                        myData['displayName'] ??
                        myData['fullName'] ??
                        _auth.currentUser?.displayName ??
                        'Teman')
                    .toString()
                    .trim();
          }
          if (resolvedMyAvatar.trim().isEmpty) {
            resolvedMyAvatar =
                (myData['avatarUrl'] ??
                        myData['photoUrl'] ??
                        myData['profilePhoto'] ??
                        _auth.currentUser?.photoURL ??
                        '')
                    .toString()
                    .trim();
          }
          if (resolvedMyPin.trim().isEmpty) {
            resolvedMyPin =
                (myData['pin'] ?? myData['userPin'] ?? myData['chatPin'] ?? '')
                    .toString()
                    .trim();
          }
        } catch (_) {}
      }

      if (resolvedPeerName.trim().isEmpty ||
          resolvedPeerAvatar.trim().isEmpty ||
          resolvedPeerPin.trim().isEmpty) {
        try {
          final peerDoc = await _db.collection('users').doc(peerUid).get();
          final peerData = peerDoc.data() ?? <String, dynamic>{};
          if (resolvedPeerName.trim().isEmpty) {
            resolvedPeerName =
                (peerData['name'] ??
                        peerData['displayName'] ??
                        peerData['fullName'] ??
                        'Teman')
                    .toString()
                    .trim();
          }
          if (resolvedPeerAvatar.trim().isEmpty) {
            resolvedPeerAvatar =
                (peerData['avatarUrl'] ??
                        peerData['photoUrl'] ??
                        peerData['profilePhoto'] ??
                        '')
                    .toString()
                    .trim();
          }
          if (resolvedPeerPin.trim().isEmpty) {
            resolvedPeerPin =
                (peerData['pin'] ??
                        peerData['userPin'] ??
                        peerData['chatPin'] ??
                        '')
                    .toString()
                    .trim();
          }
        } catch (_) {}
      }

      if (resolvedMyName.trim().isEmpty) resolvedMyName = 'Teman';
      if (resolvedPeerName.trim().isEmpty) resolvedPeerName = 'Teman';

      final timestamp = FieldValue.serverTimestamp();
      await chatRef.set({
        'type': 'dm',
        'members': ids,
        'createdBy': myUid,
        'createdAt': timestamp,
      }, SetOptions(merge: true));

      try {
        await chatRef.set({
          'admins': [myUid],
          'lastMessage': '',
          'lastMessageAt': timestamp,
          'lastSenderId': myUid,
          'unread': {peerUid: 0, myUid: 0},
          'memberInfo': {
            myUid: {
              'name': resolvedMyName,
              'avatarUrl': resolvedMyAvatar,
              'pin': resolvedMyPin,
              'joinedAt': timestamp,
              'role': 'member',
            },
            peerUid: {
              'name': resolvedPeerName,
              'avatarUrl': resolvedPeerAvatar,
              'pin': resolvedPeerPin,
              'joinedAt': timestamp,
              'role': 'member',
            },
          },
        }, SetOptions(merge: true));
      } catch (_) {}

      return chatId;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ContactListAddMemberResult> addMemberToGroup({
    required String chatId,
    required String myUid,
    required String peerUid,
    required String displayName,
    required String alias,
    required String pin,
    required String avatarUrl,
  }) async {
    if (chatId.isEmpty) {
      return const ContactListAddMemberResult(
        status: ContactListAddMemberStatus.groupNotFound,
        message: 'Grup tidak ditemukan',
      );
    }
    try {
      final chatRef = _db.collection('chats').doc(chatId);
      final chatSnap = await chatRef.get();
      final chatData = chatSnap.data() ?? <String, dynamic>{};
      final rawMembers = chatData['members'];
      final currentMembers = rawMembers is List
          ? rawMembers.map((e) => e.toString()).toList()
          : <String>[];
      if (currentMembers.contains(peerUid)) {
        return const ContactListAddMemberResult(
          status: ContactListAddMemberStatus.alreadyMember,
          message: 'Pengguna sudah tergabung dalam grup',
        );
      }

      final resolvedName = alias.isNotEmpty
          ? alias
          : displayName.isNotEmpty
          ? displayName
          : 'Tanpa Nama';

      await chatRef.set({
        'members': FieldValue.arrayUnion([peerUid]),
        'memberInfo': {
          peerUid: {
            'name': resolvedName,
            'pin': pin,
            'avatarUrl': avatarUrl,
            'addedAt': FieldValue.serverTimestamp(),
            'addedBy': myUid,
          },
        },
        'unread.$peerUid': 0,
      }, SetOptions(merge: true));

      return ContactListAddMemberResult(
        status: ContactListAddMemberStatus.added,
        resolvedName: resolvedName,
      );
    } catch (e) {
      return ContactListAddMemberResult(
        status: ContactListAddMemberStatus.failure,
        message: 'Gagal menambah anggota: $e',
      );
    }
  }

  List<ContactListContact> _mapContactDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final contacts = docs
        .map((doc) {
          final data = doc.data();
          return ContactListContact(
            peerUid: doc.id,
            displayName: (data['displayName'] ?? '').toString(),
            pin: (data['pin'] ?? '').toString(),
            alias: (data['alias'] ?? '').toString(),
            collection: (data['collection'] ?? 'users').toString(),
            photoUrl: (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString(),
            online: (data['online'] ?? false) == true,
          );
        })
        .toList(growable: false);
    contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    return contacts;
  }

  String _contactsCacheKey(String uid) => '$_contactsCachePrefix$uid';

  String _contactsSignature(List<ContactListContact> contacts) {
    if (contacts.isEmpty) return '__empty__';
    final buffer = StringBuffer();
    for (final contact in contacts) {
      buffer.write(contact.peerUid);
      buffer.write('|');
      buffer.write(contact.displayName);
      buffer.write('|');
      buffer.write(contact.pin);
      buffer.write('|');
      buffer.write(contact.alias);
      buffer.write('|');
      buffer.write(contact.collection);
      buffer.write('|');
      buffer.write(contact.photoUrl);
      buffer.write('|');
      buffer.write(contact.online ? '1' : '0');
      buffer.write(';');
    }
    return buffer.toString();
  }

  ContactListContact _decodeContact(Map<dynamic, dynamic> raw) {
    return ContactListContact(
      peerUid: (raw['peerUid'] ?? '').toString(),
      displayName: (raw['displayName'] ?? '').toString(),
      pin: (raw['pin'] ?? '').toString(),
      alias: (raw['alias'] ?? '').toString(),
      collection: (raw['collection'] ?? 'users').toString(),
      photoUrl: (raw['photoUrl'] ?? '').toString(),
      online: (raw['online'] ?? false) == true,
    );
  }

  Map<String, dynamic> _encodeContact(ContactListContact contact) {
    return <String, dynamic>{
      'peerUid': contact.peerUid,
      'displayName': contact.displayName,
      'pin': contact.pin,
      'alias': contact.alias,
      'collection': contact.collection,
      'photoUrl': contact.photoUrl,
      'online': contact.online,
    };
  }

  List<ContactListContact> _readContactsSessionCache(String uid) {
    final cached = _contactsSessionCache[uid];
    if (cached == null || cached.isEmpty) return const <ContactListContact>[];
    return List<ContactListContact>.from(cached, growable: false);
  }

  void _writeContactsSessionCache({
    required String uid,
    required List<ContactListContact> contacts,
  }) {
    _contactsSessionCache[uid] = List<ContactListContact>.from(
      contacts,
      growable: false,
    );
  }

  Future<List<ContactListContact>> _readContactsCache(String uid) async {
    if (uid.isEmpty) return const <ContactListContact>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_contactsCacheKey(uid));
      if (raw == null || raw.isEmpty) return const <ContactListContact>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ContactListContact>[];
      final contacts = <ContactListContact>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final contact = _decodeContact(item);
        if (contact.peerUid.isEmpty) continue;
        contacts.add(contact);
      }
      contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
      return contacts;
    } catch (_) {
      return const <ContactListContact>[];
    }
  }

  Future<void> _writeContactsCache({
    required String uid,
    required List<ContactListContact> contacts,
  }) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = contacts
          .map((contact) => _encodeContact(contact))
          .toList(growable: false);
      await prefs.setString(_contactsCacheKey(uid), jsonEncode(payload));
    } catch (_) {}
  }

  Future<List<ContactListContact>> _readMergedCachedContacts(String uid) async {
    if (uid.isEmpty) return const <ContactListContact>[];
    final session = _readContactsSessionCache(uid);
    if (session.isNotEmpty) return session;
    final persisted = await _readContactsCache(uid);
    if (persisted.isNotEmpty) {
      _writeContactsSessionCache(uid: uid, contacts: persisted);
    }
    return persisted;
  }

  Future<void> _upsertCachedContact({
    required String uid,
    required ContactListContact contact,
  }) async {
    if (uid.isEmpty || contact.peerUid.isEmpty) return;
    final existing = await _readMergedCachedContacts(uid);
    final contacts = <ContactListContact>[...existing];
    final index = contacts.indexWhere(
      (item) => item.peerUid == contact.peerUid,
    );
    if (index >= 0) {
      contacts[index] = contact;
    } else {
      contacts.add(contact);
    }
    contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    _writeContactsSessionCache(uid: uid, contacts: contacts);
    await _writeContactsCache(uid: uid, contacts: contacts);
  }

  Future<void> _removeCachedContact({
    required String uid,
    required String peerUid,
  }) async {
    if (uid.isEmpty || peerUid.isEmpty) return;
    final existing = await _readMergedCachedContacts(uid);
    if (existing.isEmpty) return;
    final filtered = existing
        .where((contact) => contact.peerUid != peerUid)
        .toList(growable: false);
    _writeContactsSessionCache(uid: uid, contacts: filtered);
    await _writeContactsCache(uid: uid, contacts: filtered);
  }
}
