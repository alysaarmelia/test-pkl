import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class ChatNotificationService {
  ChatNotificationService._();

  static final ChatNotificationService _instance = ChatNotificationService._();
  factory ChatNotificationService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notifications = NotificationService();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSub;

  bool _initialSnapshotLoaded = false;
  String? _activeChatId;

  final Map<String, Timestamp?> _lastSeenAt = <String, Timestamp?>{};

  void start() {
    _authSub ??= _auth.authStateChanges().listen((user) {
      _chatSub?.cancel();
      _chatSub = null;
      _initialSnapshotLoaded = false;
      _lastSeenAt.clear();
      if (user != null) {
        _subscribeToChats(user.uid);
      }
    });
  }

  void dispose() {
    _authSub?.cancel();
    _chatSub?.cancel();
  }

  void setActiveChat(String? chatId) {
    _activeChatId = chatId;
  }

  void _subscribeToChats(String uid) {
    _chatSub = _db
        .collection('chats')
        .where('members', arrayContains: uid)
        .snapshots()
        .listen((snapshot) async {
          if (!_initialSnapshotLoaded) {
            for (final doc in snapshot.docs) {
              _lastSeenAt[doc.id] = _extractTimestamp(
                doc.data()['lastMessageAt'],
              );
            }
            _initialSnapshotLoaded = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.removed) continue;
            final data = change.doc.data();
            if (data == null) continue;

            final Timestamp? timestamp = _extractTimestamp(
              data['lastMessageAt'],
            );
            final Timestamp? previous = _lastSeenAt[change.doc.id];

            final bool isNewer =
                timestamp != null &&
                (previous == null || timestamp.compareTo(previous) > 0);
            if (!isNewer) {
              continue;
            }

            final String senderId =
                (data['lastMessageSenderId'] ?? data['lastSenderId'] ?? '')
                    .toString();
            if (senderId == uid) {
              continue;
            }

            if (_activeChatId != null && _activeChatId == change.doc.id) {
              continue;
            }

            final bool isGroup = data['isGroup'] == true;
            String body = (data['lastMessage'] ?? '').toString().trim();
            if (body.isEmpty) {
              continue;
            }

            final String title = _resolveChatTitle(data, uid);
            if (isGroup) {
              final String? senderName = _resolveSenderName(data, senderId);
              if (senderName != null && senderName.isNotEmpty) {
                body = '$senderName: $body';
              }
            }
            final String displayTitle = title.isNotEmpty
                ? title
                : (isGroup ? 'Pesan grup baru' : 'Pesan baru');
            await _notifications.showChatNotification(
              chatId: change.doc.id,
              title: displayTitle,
              body: body,
              isGroup: isGroup,
            );

            _lastSeenAt[change.doc.id] = timestamp;
          }

          for (final doc in snapshot.docs) {
            _lastSeenAt[doc.id] = _extractTimestamp(
              doc.data()['lastMessageAt'],
            );
          }
        });
  }

  Timestamp? _extractTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    }
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (value is num) {
      return Timestamp.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return null;
  }

  String _resolveChatTitle(Map<String, dynamic> data, String uid) {
    if (data['isGroup'] == true) {
      final title = (data['groupName'] ?? data['name'] ?? data['title'] ?? '')
          .toString();
      return title.isNotEmpty ? title : 'Pesan grup baru';
    }

    final memberInfoRaw = data['memberInfo'];
    if (memberInfoRaw is Map) {
      final members = Map<dynamic, dynamic>.from(memberInfoRaw);
      for (final entry in members.entries) {
        final key = entry.key.toString();
        if (key == uid) continue;
        final value = entry.value;
        if (value is Map) {
          final name = (value['name'] ?? value['displayName'] ?? '').toString();
          if (name.trim().isNotEmpty) {
            return name.trim();
          }
        } else if (value != null) {
          final name = value.toString();
          if (name.trim().isNotEmpty) {
            return name.trim();
          }
        }
      }
    }

    final directName = (data['name'] ?? data['title'] ?? '').toString();
    return directName.isNotEmpty ? directName : 'Pesan baru';
  }

  String? _resolveSenderName(Map<String, dynamic> data, String senderId) {
    final memberInfoRaw = data['memberInfo'];
    if (memberInfoRaw is Map) {
      final members = Map<dynamic, dynamic>.from(memberInfoRaw);
      final value = members[senderId] ?? members[senderId.toString()];
      if (value is Map) {
        final name = (value['name'] ?? value['displayName'] ?? '').toString();
        if (name.trim().isNotEmpty) {
          return name.trim();
        }
      } else if (value != null) {
        final name = value.toString();
        if (name.trim().isNotEmpty) {
          return name.trim();
        }
      }
    }
    return null;
  }
}
