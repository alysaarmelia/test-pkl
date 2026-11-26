import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PinChatResult {
  PinChatResult({
    required this.chatId,
    required this.peerUid,
    required this.displayName,
    this.avatarUrl,
  });

  final String chatId;
  final String peerUid;
  final String displayName;
  final String? avatarUrl;

  Map<String, dynamic> toChatSummary() {
    return <String, dynamic>{
      'chatId': chatId,
      'name': displayName,
      'avatarUrl': avatarUrl ?? '',
      'isGroup': false,
    };
  }
}

class PinChatHelper {
  const PinChatHelper._();

  static Future<PinChatResult?> ensureChat({
    required BuildContext context,
    required String rawPin,
  }) async {
    final pin = _normalizePin(rawPin);
    if (pin.isEmpty) {
      showGlassSnackBar(
        context,
        message: 'PIN tidak boleh kosong',
        tone: GlassSnackTone.warning,
      );
      return null;
    }

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      showGlassSnackBar(
        context,
        message: 'Harus login terlebih dahulu',
        tone: GlassSnackTone.warning,
      );
      return null;
    }

    final db = FirebaseFirestore.instance;

    // Cegah memakai PIN sendiri
    try {
      final myDoc = await db.collection('users').doc(user.uid).get();
      final data = myDoc.data() ?? <String, dynamic>{};
      final myPins = <String>{
        for (final entry in [data['pin'], data['userPin'], data['chatPin']])
          if (entry != null)
            entry
                .toString()
                .replaceAll(RegExp(r'\s+'), '')
                .toUpperCase(),
      };
      if (myPins.contains(pin)) {
        showGlassSnackBar(
          context,
          message: 'Itu adalah PIN Anda sendiri',
          tone: GlassSnackTone.warning,
        );
        return null;
      }
    } catch (_) {}

    final peerDoc = await _findUserByPin(db, pin);
    if (peerDoc == null) {
      showGlassSnackBar(
        context,
        message: 'PIN tidak ditemukan',
        tone: GlassSnackTone.warning,
      );
      return null;
    }

    final peerUid = peerDoc.id;
    if (peerUid == user.uid) {
      showGlassSnackBar(
        context,
        message: 'Itu adalah PIN Anda sendiri',
        tone: GlassSnackTone.warning,
      );
      return null;
    }

    final myUid = user.uid;
    final memberIds = <String>[myUid, peerUid]..sort();
    final chatId = memberIds.join('_');
    final chatRef = db.collection('chats').doc(chatId);
    final existingChat = await chatRef.get();
    final timestamp = FieldValue.serverTimestamp();

    try {
      final myProfileSnap =
          await db.collection('users').doc(myUid).get().catchError((_) => null);
      final peerData = peerDoc.data() ?? <String, dynamic>{};
      final myProfile = myProfileSnap?.data() ?? <String, dynamic>{};

      final myName =
          (myProfile['name'] ?? user.displayName ?? 'Teman').toString();
      final peerName = (peerData['name'] ??
              peerData['displayName'] ??
              peerData['username'] ??
              peerData['fullName'] ??
              'Teman')
          .toString();
      final myAvatar = _pickAvatar(myProfile);
      final peerAvatar = _pickAvatar(peerData);

      final unread = <String, int>{myUid: 0, peerUid: 0};

      if (existingChat.exists) {
        await chatRef.set({
          'members': memberIds,
          'memberInfo': {
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
          },
          'unread': unread,
        }, SetOptions(merge: true));
      } else {
        await chatRef.set({
          'type': 'dm',
          'members': memberIds,
          'createdAt': timestamp,
          'lastMessage': '',
          'lastMessageAt': timestamp,
          'lastSenderId': myUid,
          'memberInfo': {
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
          },
          'unread': unread,
        });
      }

      return PinChatResult(
        chatId: chatId,
        peerUid: peerUid,
        displayName: peerName,
        avatarUrl: peerAvatar,
      );
    } catch (e) {
      showGlassSnackBar(
        context,
        message: 'Gagal membuat chat: $e',
        tone: GlassSnackTone.error,
      );
      return null;
    }
  }

  static String _normalizePin(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  static String _pickAvatar(Map<String, dynamic> source) {
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

  static Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByPin(
    FirebaseFirestore db,
    String pin,
  ) async {
    try {
      var snap = await db
          .collection('users')
          .where('pin', isEqualTo: pin)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;

      snap = await db
          .collection('users')
          .where('userPin', isEqualTo: pin)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;

      snap = await db
          .collection('users')
          .where('chatPin', isEqualTo: pin)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;

      if (await _collectionExists(db, 'profiles')) {
        snap = await db
            .collection('profiles')
            .where('pin', isEqualTo: pin)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return snap.docs.first;

        snap = await db
            .collection('profiles')
            .where('userPin', isEqualTo: pin)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return snap.docs.first;

        snap = await db
            .collection('profiles')
            .where('chatPin', isEqualTo: pin)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return snap.docs.first;
      }
    } catch (_) {}

    try {
      final pinDoc = await db.collection('pins').doc(pin).get();
      if (pinDoc.exists) {
        final data = pinDoc.data();
        final uid = (data?['uid'] ?? '').toString();
        if (uid.isNotEmpty) {
          final userDoc = await db.collection('users').doc(uid).get();
          if (userDoc.exists) return userDoc;
        }
      }
    } catch (_) {}

    Future<DocumentSnapshot<Map<String, dynamic>>?> scan(String coll) async {
      try {
        final snap = await db.collection(coll).limit(500).get();
        for (final doc in snap.docs) {
          if (_pinEquals(doc.data(), pin)) return doc;
        }
      } catch (_) {}
      return null;
    }

    final usersScan = await scan('users');
    if (usersScan != null) return usersScan;

    if (await _collectionExists(db, 'profiles')) {
      final profilesScan = await scan('profiles');
      if (profilesScan != null) return profilesScan;
    }

    return null;
  }

  static Future<bool> _collectionExists(
    FirebaseFirestore db,
    String name,
  ) async {
    try {
      await db.collection(name).limit(1).get();
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _pinEquals(Map<String, dynamic> data, String target) {
    String normalize(dynamic value) => value == null
        ? ''
        : value
            .toString()
            .replaceAll(RegExp(r'\s+'), '')
            .toUpperCase();

    final candidates = [
      data['pin'],
      data['userPin'],
      data['chatPin'],
      data['PIN'],
      data['Pin'],
    ];
    final normalizedTarget = normalize(target);
    if (normalizedTarget.isEmpty) return false;

    for (final candidate in candidates) {
      if (normalize(candidate) == normalizedTarget) return true;
    }
    return false;
  }
}
