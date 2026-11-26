import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../repositories/chat_list_repository.dart';

enum ChatListPinAction { pin, unpin }

enum ChatListFavoriteAction { add, remove }

enum ChatListFeedbackType { success, info, warning, error, none }

class ChatListFeedback {
  const ChatListFeedback({
    required this.type,
    this.message = '',
    this.clearedType,
  });

  final ChatListFeedbackType type;
  final String message;
  final ChatListClearChatResultType? clearedType;

  static const none = ChatListFeedback(type: ChatListFeedbackType.none);
}

class ChatListSections {
  const ChatListSections({required this.visible, required this.archived});

  final List<Map<String, dynamic>> visible;
  final List<Map<String, dynamic>> archived;
}

class ChatListViewModel extends GetxController {
  ChatListViewModel({ChatListRepository? repository})
    : _repository = repository ?? ChatListRepositoryImpl();

  final ChatListRepository _repository;
  static const int _initialChatsLimit = 80;

  Stream<ChatListChatsSnapshot>? _chatStream;
  StreamSubscription<String?>? _authSub;
  StreamSubscription<ChatListUserStateSnapshot>? _userStateSub;

  bool _firstLoadDone = false;
  bool _isAdmin = false;
  int _tabIndex = 0;
  String _searchQuery = '';

  final Map<String, String?> _avatarCache = <String, String?>{};
  final Map<String, Map<String, String?>> _userProfileCache =
      <String, Map<String, String?>>{};
  Map<String, DateTime> _pinnedChatOrder = <String, DateTime>{};
  Set<String> _hiddenChatIds = <String>{};
  Map<String, ChatListPinAction> _pendingPinOps = <String, ChatListPinAction>{};
  Set<String> _favoriteChatIds = <String>{};
  Map<String, ChatListFavoriteAction> _pendingFavoriteOps =
      <String, ChatListFavoriteAction>{};
  Map<String, DateTime> _locallyRemovedChats = <String, DateTime>{};

  Stream<ChatListChatsSnapshot>? get chatStream => _chatStream;
  String? get currentUserUid => _repository.currentUserUid;
  bool get firstLoadDone => _firstLoadDone;
  bool get isAdmin => _isAdmin;
  int get tabIndex => _tabIndex;
  String get searchQuery => _searchQuery;
  Map<String, String?> get avatarCache => _avatarCache;
  Map<String, Map<String, String?>> get userProfileCache => _userProfileCache;
  Map<String, DateTime> get pinnedChatOrder => _pinnedChatOrder;
  Set<String> get hiddenChatIds => _hiddenChatIds;
  Set<String> get favoriteChatIds => _favoriteChatIds;

  void setTabIndex(int value) {
    final next = value < 0 ? 0 : (value > 3 ? 3 : value);
    if (_tabIndex == next) return;
    _tabIndex = next;
    _notify();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    _notify();
  }

  ChatListSections buildSections({
    required List<ChatListChatDoc> docs,
    required String? userId,
  }) {
    final generated = List.generate(docs.length, (index) {
      final doc = docs[index];
      final data = doc.data;

      final rawMembers = data['members'];
      final members = <String>[];
      if (rawMembers is List) {
        for (final member in rawMembers) {
          if (member == null) continue;
          final value = member.toString();
          if (value.isNotEmpty) {
            members.add(value);
          }
        }
      }

      final type = (data['type'] ?? '').toString();
      final isGroup =
          type == 'group' ||
          (data['groupName'] ?? '').toString().isNotEmpty ||
          members.length > 2;

      final memberInfoRaw = data['memberInfo'];
      final memberInfo = <String, Map<String, dynamic>>{};
      if (memberInfoRaw is Map) {
        memberInfoRaw.forEach((key, value) {
          if (value is Map) {
            memberInfo[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }

      String displayName = '';
      String avatarUrl = '';
      String? peerUid;
      bool needsFetchName = false;
      bool needsFetchAvatar = false;

      if (isGroup) {
        displayName = (data['groupName'] ?? '').toString();
        if (displayName.trim().isEmpty) {
          displayName = 'Grup';
        }
        avatarUrl = (data['groupAvatarUrl'] ?? '').toString();
      } else {
        final myUid = userId ?? '';
        for (final member in members) {
          if (member != myUid) {
            peerUid = member;
            break;
          }
        }
        if (peerUid == null && members.isNotEmpty) {
          peerUid = members.first;
        }
        if (peerUid != null && peerUid.isEmpty) {
          peerUid = null;
        }

        final info = peerUid != null ? memberInfo[peerUid] : null;
        displayName =
            (info?['alias'] ??
                    info?['name'] ??
                    info?['username'] ??
                    info?['displayName'] ??
                    '')
                .toString();
        avatarUrl = (info?['avatarUrl'] ?? info?['photoUrl'] ?? '').toString();
        needsFetchName =
            peerUid != null &&
            peerUid.isNotEmpty &&
            _isGenericName(displayName);
        needsFetchAvatar = avatarUrl.trim().isEmpty;
      }

      final sanitizedName = displayName.trim();
      final storedName = sanitizedName.isEmpty
          ? (isGroup ? 'Grup' : 'Teman')
          : sanitizedName;

      final unreadRaw =
          data['unread'] ?? data['unread_count'] ?? data['unreadCount'];
      final flatKey = 'unread_$userId';
      final flatUnread = data[flatKey];

      var unreadCount = _resolveUnreadCount(unreadRaw, userId);
      if (unreadCount <= 0 && flatUnread != null) {
        if (flatUnread is int)
          unreadCount = flatUnread;
        else if (flatUnread is num)
          unreadCount = flatUnread.toInt();
      }

      // Fallback universal: jika Firestore mengatakan 0 tapi kita tahu ada
      // pesan baru (berdasarkan perbandingan waktu atau pengirim),
      // set ke 1 agar dot hijau muncul. Jika Firestore > 0, gunakan angka asli.
      if (unreadCount <= 0 && userId != null && userId.isNotEmpty) {
        final lastSenderId = (data['lastSenderId'] ?? '').toString().trim();
        final lastMessage = (data['lastMessage'] ?? '').toString().trim();
        if (lastSenderId.isNotEmpty &&
            lastSenderId != userId &&
            lastMessage.isNotEmpty) {
          // Hanya set ke 1 sebagai indikator "ada pesan baru"
          // Jika increment Firestore masuk, ini akan otomatis terupdate ke > 1
          unreadCount = 1;
        }
      }

      // Validasi dengan waktu baca lokal (reliable fallback)
      if (unreadCount > 0) {
        final lastMsgAt = _normalizeToDateTime(data['lastMessageAt']);
        final localReadAt = ChatListRepositoryImpl.getLocalReadTime(doc.id);
        if (localReadAt != null && lastMsgAt != null) {
          if (localReadAt.isAfter(lastMsgAt)) {
            unreadCount = 0;
          }
        }
      }

      final lastMessageDeletedForRaw = data['lastMessageDeletedFor'];
      List<String> lastMessageDeletedFor = const [];
      if (lastMessageDeletedForRaw is Iterable) {
        lastMessageDeletedFor = lastMessageDeletedForRaw
            .map((entry) => entry.toString())
            .toList(growable: false);
      }

      return <String, dynamic>{
        'chatId': doc.id,
        'peerUid': peerUid,
        'name': storedName,
        'needsFetch': needsFetchName || needsFetchAvatar,
        'avatarUrl': avatarUrl,
        'lastMessage': (data['lastMessage'] ?? '').toString(),
        'lastMessageAt': data['lastMessageAt'],
        'lastSenderId': (data['lastSenderId'] ?? '').toString(),
        'lastMessageDeletedFor': lastMessageDeletedFor,
        'unread': unreadCount,
        'membersCount': members.length,
        'isGroup': isGroup,
        'members': List<String>.unmodifiable(members),
        'isFavorite': _favoriteChatIds.contains(doc.id),
        'index': index,
      };
    });

    var items = List<Map<String, dynamic>>.from(generated);

    final search = _searchQuery.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((chat) {
            final name = (chat['name'] ?? '').toString().toLowerCase();
            final message = (chat['lastMessage'] ?? '')
                .toString()
                .toLowerCase();
            return name.contains(search) || message.contains(search);
          })
          .toList(growable: false);
    }

    switch (_tabIndex) {
      case 1:
        items = items
            .where((chat) => (chat['unread'] ?? 0) > 0)
            .toList(growable: false);
        break;
      case 2:
        items = items
            .where((chat) => chat['isFavorite'] == true)
            .toList(growable: false);
        break;
      case 3:
        items = items
            .where((chat) => chat['isGroup'] == true)
            .toList(growable: false);
        break;
      default:
        break;
    }

    return _applyPinAndVisibility(items);
  }

  @override
  void onInit() {
    super.onInit();
    final uid = currentUserUid;
    if (uid != null && uid.isNotEmpty) {
      _chatStream = _repository.watchChats(uid, limit: _initialChatsLimit);
      _loadRole(uid);
      _listenUserState(uid);
      _userProfileCache.clear();
      _avatarCache.clear();
    }

    _authSub = _repository.watchAuthUserIds().listen((uid) {
      if (uid == null || uid.isEmpty) {
        _chatStream = null;
        _userStateSub?.cancel();
        _pinnedChatOrder = <String, DateTime>{};
        _hiddenChatIds = <String>{};
        _favoriteChatIds = <String>{};
        _pendingPinOps = <String, ChatListPinAction>{};
        _pendingFavoriteOps = <String, ChatListFavoriteAction>{};
        _locallyRemovedChats = <String, DateTime>{};
        _avatarCache.clear();
        _userProfileCache.clear();
        _notify();
        return;
      }

      _firstLoadDone = false;
      _pinnedChatOrder = <String, DateTime>{};
      _hiddenChatIds = <String>{};
      _favoriteChatIds = <String>{};
      _pendingPinOps = <String, ChatListPinAction>{};
      _pendingFavoriteOps = <String, ChatListFavoriteAction>{};
      _locallyRemovedChats = <String, DateTime>{};
      _chatStream = _repository.watchChats(uid, limit: _initialChatsLimit);
      _loadRole(uid);
      _listenUserState(uid);
      _avatarCache.clear();
      _userProfileCache.clear();
      _notify();
    });
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _userStateSub?.cancel();
    super.onClose();
  }

  void markFirstLoadDone() {
    if (_firstLoadDone) return;
    _firstLoadDone = true;
    _notify();
  }

  Future<void> resetUnread(String chatId) async {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) return;
    await _repository.resetUnread(chatId: chatId, uid: uid);
  }

  void refreshChats() {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) return;
    _chatStream = _repository.watchChats(uid, limit: _initialChatsLimit);
    _notify();
  }

  Future<ChatListFeedback> setPinned({
    required String chatId,
    required bool pin,
  }) async {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) return ChatListFeedback.none;

    final previousPinned = Map<String, DateTime>.from(_pinnedChatOrder);
    final previousPending = Map<String, ChatListPinAction>.from(_pendingPinOps);
    if (pin) {
      _pinnedChatOrder[chatId] = previousPinned[chatId] ?? DateTime.now();
      _pendingPinOps[chatId] = ChatListPinAction.pin;
    } else {
      _pinnedChatOrder.remove(chatId);
      _pendingPinOps[chatId] = ChatListPinAction.unpin;
    }
    _notify();

    try {
      await _repository.setPinned(uid: uid, chatId: chatId, pin: pin);
      return ChatListFeedback(
        type: pin ? ChatListFeedbackType.success : ChatListFeedbackType.info,
        message: pin ? 'Chat dipin ke atas' : 'Pin chat dilepas',
      );
    } catch (error) {
      _pinnedChatOrder = previousPinned;
      _pendingPinOps = previousPending;
      _notify();
      return ChatListFeedback(
        type: ChatListFeedbackType.error,
        message: 'Gagal memperbarui pin: $error',
      );
    }
  }

  Future<ChatListFeedback> setFavorite({
    required String chatId,
    required bool favorite,
  }) async {
    if (chatId.isEmpty) return ChatListFeedback.none;
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) return ChatListFeedback.none;

    final previousFavorites = Set<String>.from(_favoriteChatIds);
    final previousPending = Map<String, ChatListFavoriteAction>.from(
      _pendingFavoriteOps,
    );
    if (favorite) {
      _favoriteChatIds = <String>{..._favoriteChatIds, chatId};
      _pendingFavoriteOps[chatId] = ChatListFavoriteAction.add;
    } else {
      final updated = Set<String>.from(_favoriteChatIds)..remove(chatId);
      _favoriteChatIds = updated;
      _pendingFavoriteOps[chatId] = ChatListFavoriteAction.remove;
    }
    _notify();

    try {
      await _repository.setFavorite(
        uid: uid,
        chatId: chatId,
        favorite: favorite,
      );
      return ChatListFeedback(
        type: favorite
            ? ChatListFeedbackType.success
            : ChatListFeedbackType.info,
        message: favorite ? 'Ditambahkan ke favorit' : 'Dihapus dari favorit',
      );
    } catch (error) {
      _favoriteChatIds = previousFavorites;
      _pendingFavoriteOps = previousPending;
      _notify();
      return ChatListFeedback(
        type: ChatListFeedbackType.error,
        message: 'Gagal memperbarui favorit: $error',
      );
    }
  }

  Future<ChatListFeedback> hideChat(String chatId) async {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) return ChatListFeedback.none;

    final previousHidden = _hiddenChatIds;
    final previousPinned = _pinnedChatOrder;
    final previousPending = _pendingPinOps;
    _hiddenChatIds = <String>{..._hiddenChatIds, chatId};
    final updated = Map<String, DateTime>.from(_pinnedChatOrder)
      ..remove(chatId);
    _pinnedChatOrder = updated;
    if (_pendingPinOps.containsKey(chatId)) {
      _pendingPinOps = Map<String, ChatListPinAction>.from(_pendingPinOps)
        ..remove(chatId);
    }
    _notify();

    try {
      await _repository.hideChat(uid: uid, chatId: chatId);
      return const ChatListFeedback(
        type: ChatListFeedbackType.success,
        message: 'Chat disembunyikan dari daftar Anda',
      );
    } catch (error) {
      _hiddenChatIds = previousHidden;
      _pinnedChatOrder = previousPinned;
      _pendingPinOps = previousPending;
      _notify();
      return ChatListFeedback(
        type: ChatListFeedbackType.error,
        message: 'Gagal menyembunyikan chat: $error',
      );
    }
  }

  Future<ChatListFeedback> unhideChat(String chatId) async {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) return ChatListFeedback.none;
    if (!_hiddenChatIds.contains(chatId)) return ChatListFeedback.none;

    final previousHidden = _hiddenChatIds;
    _hiddenChatIds = Set<String>.from(_hiddenChatIds)..remove(chatId);
    _notify();

    try {
      await _repository.unhideChat(uid: uid, chatId: chatId);
      return const ChatListFeedback(
        type: ChatListFeedbackType.success,
        message: 'Chat dikembalikan ke daftar',
      );
    } catch (error) {
      _hiddenChatIds = previousHidden;
      _notify();
      return ChatListFeedback(
        type: ChatListFeedbackType.error,
        message: 'Gagal memulihkan chat: $error',
      );
    }
  }

  Future<ChatListFeedback> clearChatForCurrentUser(String chatId) async {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) return ChatListFeedback.none;

    final previousRemoved = Map<String, DateTime>.from(_locallyRemovedChats);
    _locallyRemovedChats = Map<String, DateTime>.from(_locallyRemovedChats)
      ..[chatId] = DateTime.now();
    _notify();

    try {
      final result = await _repository.clearChatForCurrentUser(
        uid: uid,
        chatId: chatId,
      );

      if (result.type == ChatListClearChatResultType.removedFromList) {
        final hidden = Set<String>.from(_hiddenChatIds)..remove(chatId);
        _hiddenChatIds = hidden;
        final pinned = Map<String, DateTime>.from(_pinnedChatOrder)
          ..remove(chatId);
        _pinnedChatOrder = pinned;
        final favorites = Set<String>.from(_favoriteChatIds)..remove(chatId);
        _favoriteChatIds = favorites;
        final pendingFav = Map<String, ChatListFavoriteAction>.from(
          _pendingFavoriteOps,
        )..remove(chatId);
        _pendingFavoriteOps = pendingFav;
        _notify();
        return ChatListFeedback(
          type: ChatListFeedbackType.success,
          message: 'Chat dihapus dari daftar Anda.',
          clearedType: result.type,
        );
      }

      final nextRemoved = Map<String, DateTime>.from(_locallyRemovedChats)
        ..remove(chatId);
      _locallyRemovedChats = nextRemoved;
      _notify();
      return ChatListFeedback(
        type: ChatListFeedbackType.success,
        message: 'Riwayat chat dibersihkan dan dipindahkan ke arsip.',
        clearedType: result.type,
      );
    } catch (error) {
      _locallyRemovedChats = previousRemoved;
      _notify();
      return ChatListFeedback(
        type: ChatListFeedbackType.error,
        message: 'Gagal membersihkan chat: $error',
      );
    }
  }

  Future<ChatListFeedback> startChatByPin(String pin) async {
    final result = await _repository.startDirectChatByPin(pin);
    if (result.status == ChatListStartChatStatus.success &&
        (result.chatId?.isNotEmpty ?? false)) {
      final nextRemoved = Map<String, DateTime>.from(_locallyRemovedChats)
        ..remove(result.chatId);
      _locallyRemovedChats = nextRemoved;
      _notify();
    }
    return switch (result.status) {
      ChatListStartChatStatus.success => ChatListFeedback.none,
      ChatListStartChatStatus.notLoggedIn => const ChatListFeedback(
        type: ChatListFeedbackType.warning,
        message: 'Harus login terlebih dahulu',
      ),
      ChatListStartChatStatus.selfPin => const ChatListFeedback(
        type: ChatListFeedbackType.warning,
        message: 'Itu adalah PIN Anda sendiri',
      ),
      ChatListStartChatStatus.notFound => const ChatListFeedback(
        type: ChatListFeedbackType.warning,
        message: 'PIN tidak ditemukan',
      ),
      ChatListStartChatStatus.failure => ChatListFeedback(
        type: ChatListFeedbackType.error,
        message: 'Gagal memulai chat: ${result.message ?? 'unknown error'}',
      ),
    };
  }

  Future<ChatListStartChatResult> startChatByPinRaw(String pin) {
    return _repository.startDirectChatByPin(pin);
  }

  Future<void> clearChatMessages(String chatId) {
    return _repository.clearChatMessages(chatId);
  }

  Future<void> deleteChat(String chatId) {
    return _repository.deleteChat(chatId);
  }

  Future<ChatListUserProfile?> fetchUserProfile(String uid) {
    return _repository.fetchUserProfile(uid);
  }

  Stream<ChatListUserProfile?> watchUserProfile(String uid) {
    return _repository.watchUserProfile(uid);
  }

  Future<void> updateMemberInfo({
    required String chatId,
    required String peerUid,
    required String name,
    required String avatarUrl,
  }) {
    return _repository.updateMemberInfo(
      chatId: chatId,
      peerUid: peerUid,
      name: name,
      avatarUrl: avatarUrl,
    );
  }

  Future<String?> resolveAvatarUrl(String avatar) {
    return _repository.resolveAvatarUrl(avatar);
  }

  void updateProfileCache(String uid, {String? name, String? avatarUrl}) {
    if (uid.isEmpty) return;
    final normalizedName = name?.trim();
    final normalizedAvatar = avatarUrl?.trim();
    if ((normalizedName == null || normalizedName.isEmpty) &&
        (normalizedAvatar == null || normalizedAvatar.isEmpty)) {
      return;
    }
    final previous = _userProfileCache[uid];
    final next = Map<String, String?>.from(previous ?? {});
    if (normalizedName != null && normalizedName.isNotEmpty) {
      next['name'] = normalizedName;
    }
    if (normalizedAvatar != null && normalizedAvatar.isNotEmpty) {
      next['avatarUrl'] = normalizedAvatar;
    }
    if (mapEquals(previous, next)) {
      return;
    }
    _userProfileCache[uid] = next;
  }

  void cacheAvatar(String key, String? resolvedUrl) {
    if (_avatarCache[key] == resolvedUrl) {
      return;
    }
    _avatarCache[key] = resolvedUrl;
  }

  void _listenUserState(String uid) {
    _userStateSub?.cancel();
    _userStateSub = _repository.watchUserState(uid).listen((snapshot) {
      final hasPendingWrites = snapshot.hasPendingWrites;
      final previousPinned = _pinnedChatOrder;
      final previousPending = _pendingPinOps;
      final previousFavorites = _favoriteChatIds;
      final previousFavoritePending = _pendingFavoriteOps;

      final serverPinned = <String, DateTime>{...snapshot.pinnedChats};
      Map<String, DateTime> pinned = hasPendingWrites
          ? <String, DateTime>{...previousPinned, ...serverPinned}
          : <String, DateTime>{...serverPinned};

      final nextPending = Map<String, ChatListPinAction>.from(previousPending);
      if (!hasPendingWrites) {
        nextPending.removeWhere((chatId, action) {
          final serverHas = serverPinned.containsKey(chatId);
          if (action == ChatListPinAction.pin && serverHas) return true;
          if (action == ChatListPinAction.unpin && !serverHas) return true;
          return false;
        });
      }

      nextPending.forEach((chatId, action) {
        if (action == ChatListPinAction.pin) {
          pinned.putIfAbsent(
            chatId,
            () => previousPinned[chatId] ?? DateTime.now(),
          );
        } else {
          pinned.remove(chatId);
        }
      });

      final nextPendingFavorites = Map<String, ChatListFavoriteAction>.from(
        previousFavoritePending,
      );
      final favoritesFromServer = <String>{...snapshot.favoriteChatIds};
      Set<String> favorites = hasPendingWrites
          ? <String>{...previousFavorites, ...favoritesFromServer}
          : <String>{...favoritesFromServer};

      if (!hasPendingWrites) {
        nextPendingFavorites.removeWhere((chatId, action) {
          final serverHas = favoritesFromServer.contains(chatId);
          if (action == ChatListFavoriteAction.add && serverHas) return true;
          if (action == ChatListFavoriteAction.remove && !serverHas) {
            return true;
          }
          return false;
        });
      }

      nextPendingFavorites.forEach((chatId, action) {
        if (action == ChatListFavoriteAction.add) {
          favorites.add(chatId);
        } else {
          favorites.remove(chatId);
        }
      });

      final hidden = <String>{...snapshot.hiddenChatIds};
      final pinnedChanged = !mapEquals(_pinnedChatOrder, pinned);
      final hiddenChanged = !setEquals(_hiddenChatIds, hidden);
      final pendingChanged = !mapEquals(_pendingPinOps, nextPending);
      final favoriteChanged = !setEquals(_favoriteChatIds, favorites);
      final favoritePendingChanged = !mapEquals(
        _pendingFavoriteOps,
        nextPendingFavorites,
      );

      if (pinnedChanged ||
          hiddenChanged ||
          pendingChanged ||
          favoriteChanged ||
          favoritePendingChanged) {
        _pinnedChatOrder = pinned;
        _hiddenChatIds = hidden;
        _pendingPinOps = nextPending;
        _favoriteChatIds = favorites;
        _pendingFavoriteOps = nextPendingFavorites;
        _notify();
      }
    }, onError: (_) {});
  }

  Future<void> _loadRole(String uid) async {
    try {
      final next = await _repository.isAdmin(uid);
      if (_isAdmin != next) {
        _isAdmin = next;
        _notify();
      }
    } catch (_) {}
  }

  void _notify() {
    if (isClosed) return;
    update();
  }

  ChatListSections _applyPinAndVisibility(List<Map<String, dynamic>> items) {
    final pinned = <Map<String, dynamic>>[];
    final others = <Map<String, dynamic>>[];
    final archived = <Map<String, dynamic>>[];
    final expiredRemoved = <String>[];

    for (final item in items) {
      final chatId = (item['chatId'] ?? '').toString();
      if (chatId.isEmpty) continue;
      final removedAt = _locallyRemovedChats[chatId];
      if (removedAt != null) {
        final lastMessageAt = _normalizeToDateTime(item['lastMessageAt']);
        final hasNewActivityAfterRemoval =
            lastMessageAt != null && lastMessageAt.isAfter(removedAt);
        if (hasNewActivityAfterRemoval) {
          expiredRemoved.add(chatId);
        } else {
          continue;
        }
      }

      final entry = Map<String, dynamic>.from(item);
      final pinnedAt = _pinnedChatOrder[chatId];
      entry['isPinned'] = pinnedAt != null;
      entry['pinnedAt'] = pinnedAt;

      if (_hiddenChatIds.contains(chatId)) {
        entry['isArchived'] = true;
        archived.add(entry);
        continue;
      }

      entry['isArchived'] = false;
      if (pinnedAt != null) {
        pinned.add(entry);
      } else {
        others.add(entry);
      }
    }
    if (expiredRemoved.isNotEmpty) {
      final nextRemoved = Map<String, DateTime>.from(_locallyRemovedChats);
      for (final chatId in expiredRemoved) {
        nextRemoved.remove(chatId);
      }
      _locallyRemovedChats = nextRemoved;
    }

    int comparePinned(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aTime = a['pinnedAt'] as DateTime?;
      final bTime = b['pinnedAt'] as DateTime?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    }

    pinned.sort(comparePinned);
    archived.sort(comparePinned);

    int originalIndex(Map<String, dynamic> item) {
      final index = item['index'];
      if (index is int) return index;
      return 0;
    }

    others.sort((a, b) => originalIndex(a).compareTo(originalIndex(b)));

    return ChatListSections(
      visible: [...pinned, ...others],
      archived: archived,
    );
  }

  bool _isGenericName(String name) {
    final normalized = name.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'unknown' ||
        normalized == 'teman' ||
        normalized == 'saya';
  }

  int _resolveUnreadCount(dynamic unreadRaw, String? userId) {
    if (unreadRaw is int) return unreadRaw;
    if (unreadRaw is num) return unreadRaw.toInt();
    if (unreadRaw is String) return int.tryParse(unreadRaw.trim()) ?? 0;

    final normalizedUserId = (userId ?? '').trim();
    if (normalizedUserId.isEmpty) return 0;

    // 1. Cek unread_UID (flat field fallback)
    final flatKey = 'unread_$normalizedUserId';
    for (final key in [
      'unread_$normalizedUserId',
      'unreadCount_$normalizedUserId',
    ]) {
      if (unreadRaw is Map && unreadRaw.containsKey(key)) {
        final v = unreadRaw[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
      }
    }

    // 2. Cek unread Map (standard)
    if (unreadRaw is Map) {
      // Direct access first
      final direct = unreadRaw[normalizedUserId];
      if (direct is int) return direct;
      if (direct is num) return direct.toInt();
      if (direct is String) return int.tryParse(direct.trim()) ?? 0;

      // Fuzzy iteration as fallback
      for (final entry in unreadRaw.entries) {
        final k = entry.key.toString().trim();
        if (k == normalizedUserId || k == 'unread_$normalizedUserId') {
          final value = entry.value;
          if (value is int) return value;
          if (value is num) return value.toInt();
          if (value is String) return int.tryParse(value.trim()) ?? 0;
        }
      }
    }
    return 0;
  }

  bool _hasUnreadEntryForUser(dynamic unreadRaw, String? userId) {
    final normalizedUserId = (userId ?? '').trim();
    if (normalizedUserId.isEmpty || unreadRaw is! Map) {
      return false;
    }
    for (final key in unreadRaw.keys) {
      if (key.toString().trim() == normalizedUserId) {
        return true;
      }
    }
    return false;
  }

  DateTime? _normalizeToDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value != null) {
      try {
        final dynamic candidate = value;
        final converted = candidate.toDate();
        if (converted is DateTime) return converted;
      } catch (_) {}
    }
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
}
