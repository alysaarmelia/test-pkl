import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/chat_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/contact_list_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/archived_chats_page.dart';
import 'package:cipta_vera_mandiri_digital/app/services/avatar_thumbnail_cache_service.dart';
import 'package:cipta_vera_mandiri_digital/repositories/chat_list_repository.dart';
import 'package:cipta_vera_mandiri_digital/repositories/chat_page_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/chat_list_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/create_group_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

const List<Color> pinnedGradientColors = [Color(0xFF3D54F7), Color(0xFF7C8CFF)];

const List<Color> _backgroundGradient = <Color>[
  Color(0xFF101529),
  Color(0xFF1C2844),
];

const Color _surfaceStrong = Color.fromRGBO(255, 255, 255, 0.18);
const Color _surfaceSoft = Color.fromRGBO(255, 255, 255, 0.12);
const Color _surfaceBorder = Color.fromRGBO(255, 255, 255, 0.35);

class ChatListPage extends StatefulWidget {
  final ChatListRepository? repository;

  const ChatListPage({super.key, this.repository});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final ChatListViewModel _viewModel;
  late final String _viewModelTag;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Map<String, Future<ChatListUserProfile?>> _profileFetchCache =
      <String, Future<ChatListUserProfile?>>{};
  final Map<String, Future<String?>> _avatarResolveCache =
      <String, Future<String?>>{};
  final Map<String, String?> _avatarThumbPathCache = <String, String?>{};
  final Map<String, Future<String?>> _avatarThumbFutureCache =
      <String, Future<String?>>{};
  final Set<String> _removingChatIds = <String>{};
  final Set<String> _memberInfoUpdateQueue = <String>{};

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'chat-list-${identityHashCode(this)}';
    _viewModel = Get.put(
      ChatListViewModel(repository: widget.repository),
      tag: _viewModelTag,
    );
  }

  void _openChat(
    Map<String, dynamic> chat,
    BuildContext context, {
    bool unarchive = true,
  }) {
    final String chatId = (chat['chatId'] ?? '').toString();
    if (chatId.isEmpty) return;

    if (unarchive) {
      unawaited(_unhideChat(chatId, context: context, showMessage: false));
    }

    final String avatar = (chat['avatarUrl'] ?? '').toString();
    final uid = _viewModel.currentUserUid;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          peerName: (chat['name'] ?? '').toString(),
          peerAvatarUrl: avatar.isEmpty ? null : avatar,
          isGroup: chat['isGroup'] == true,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      // Reset unread SETELAH user keluar dari ChatPage — dot hijau tetap
      // terlihat selama user berada di dalam chat (ChatPage sendiri sudah
      // memanggil markRead). Di sini hanya sebagai fallback clean-up.
      if (uid != null && uid.isNotEmpty) {
        unawaited(_viewModel.resetUnread(chatId).catchError((_) {}));
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<ChatListViewModel>(tag: _viewModelTag)) {
      Get.delete<ChatListViewModel>(tag: _viewModelTag, force: true);
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime? _normalizeToDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value != null) {
      try {
        final dynamic candidate = value;
        final converted = candidate.toDate();
        if (converted is DateTime) {
          return converted;
        }
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

  List<ChatListChatDoc> _applyLocalPreviews(List<ChatListChatDoc> docs) {
    if (docs.isEmpty) return docs;
    var changed = false;
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
      if (!usePreview) {
        patched.add(doc);
        continue;
      }

      changed = true;
      data['lastMessage'] = previewMessage;
      data['lastMessageAt'] = previewAt;
      if (previewSender.isNotEmpty) {
        data['lastSenderId'] = previewSender;
      }
      data['lastMessageDeletedFor'] = const <String>[];
      patched.add(ChatListChatDoc(id: doc.id, data: data));
    }
    if (!changed) return docs;
    patched.sort((a, b) {
      final aTime = _normalizeToDateTime(a.data['lastMessageAt']);
      final bTime = _normalizeToDateTime(b.data['lastMessageAt']);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return patched;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChatListViewModel>(
      tag: _viewModelTag,
      builder: (_) => Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: 63,
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'Chat',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 28,
              height: 1,
            ),
          ),
          actions: [
            _glassIconButton(
              icon: Icons.group_add,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupPage()),
                );
              },
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              icon: Icons.contacts,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactListPage()),
                );
              },
            ),
            const SizedBox(width: 12),
          ],
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: _surfaceSoft,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color.fromRGBO(255, 255, 255, 0.25),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: _backgroundGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                _searchBar(),
                const SizedBox(height: 10),
                _filterChips(),
                const SizedBox(height: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (_viewModel.chatStream == null) {
                        return const Center(
                          child: Text(
                            'Harus login',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }
                      final userId = _viewModel.currentUserUid;
                      return StreamBuilder<ChatListChatsSnapshot>(
                        stream: _viewModel.chatStream,
                        builder: (ctx, snap) {
                          final chatSnapshot = snap.data;
                          if (chatSnapshot?.permissionDenied == true) {
                            return _permissionDeniedView();
                          }
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                'Gagal memuat chat: ${snap.error}',
                                style: const TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          final waiting =
                              snap.connectionState == ConnectionState.waiting &&
                              !(chatSnapshot != null &&
                                  chatSnapshot.docs.isNotEmpty);
                          if (waiting && !_viewModel.firstLoadDone) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snap.hasData && !_viewModel.firstLoadDone) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              _viewModel.markFirstLoadDone();
                            });
                          }
                          final docs = _applyLocalPreviews(
                            chatSnapshot?.docs ?? const <ChatListChatDoc>[],
                          );
                          final sections = _viewModel.buildSections(
                            docs: docs,
                            userId: userId,
                          );
                          final visibleItems = sections.visible;
                          final archivedItems = sections.archived;
                          final hasArchived = archivedItems.isNotEmpty;
                          final hasUnreadArchived = archivedItems.any(
                            (c) => (c['unread'] ?? 0) > 0,
                          );

                          final totalCount =
                              visibleItems.length + (hasArchived ? 1 : 0);

                          if (totalCount == 0) {
                            return const Center(
                              child: Text(
                                'Belum ada chat',
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
                            itemBuilder: (context, index) {
                              if (hasArchived && index == 0) {
                                return _archivedBanner(
                                  count: archivedItems.length,
                                  hasUnread: hasUnreadArchived,
                                  onTap: () =>
                                      _showArchivedList(context, archivedItems),
                                );
                              }
                              final visibleIndex = hasArchived
                                  ? index - 1
                                  : index;
                              if (visibleIndex < visibleItems.length) {
                                return _buildChatTile(
                                  context: context,
                                  chat: visibleItems[visibleIndex],
                                  isArchivedSection: false,
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            separatorBuilder: (_, index) {
                              if (index >= totalCount - 1) {
                                return const SizedBox(height: 10);
                              }
                              if (hasArchived && index == 0) {
                                return const SizedBox(height: 10);
                              }
                              return const SizedBox(height: 10);
                            },
                            itemCount: totalCount,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required BuildContext context,
    required Map<String, dynamic> chat,
    required bool isArchivedSection,
  }) {
    final bool isGroup = chat['isGroup'] == true;
    final String? peerUid = chat['peerUid'] as String?;
    final cachedProfile = (peerUid != null && peerUid.isNotEmpty)
        ? _viewModel.userProfileCache[peerUid]
        : null;
    final bool needFetch =
        !isGroup && chat['needsFetch'] == true && cachedProfile == null;
    final Map<String, dynamic> baseChat = {
      ...chat,
      if (cachedProfile != null &&
          (cachedProfile['name'] ?? '').toString().trim().isNotEmpty)
        'name': cachedProfile['name'],
      if (cachedProfile != null &&
          (cachedProfile['avatarUrl'] ?? '').toString().trim().isNotEmpty)
        'avatarUrl': cachedProfile['avatarUrl'],
    };

    Widget buildTile(Map<String, dynamic> data) {
      final chatId = (data['chatId'] ?? '').toString();
      final bool isArchived = data['isArchived'] == true || isArchivedSection;

      Widget buildTileContent() {
        return GestureDetector(
          onTap: () => _openChat(data, context, unarchive: !isArchived),
          onLongPress: () => _showChatOptions(context, data),
          child: _chatTileDynamic(data, context),
        );
      }

      final isPinned = data['isPinned'] == true;
      final isRemoving = _removingChatIds.contains(chatId);
      return TweenAnimationBuilder<double>(
        key: ValueKey<String>('chat-remove-$chatId'),
        tween: Tween<double>(begin: 1, end: isRemoving ? 0 : 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) {
          final double clamped = value.clamp(0.0, 1.0).toDouble();
          return Opacity(
            opacity: clamped,
            child: Transform.translate(
              offset: Offset((1 - clamped) * 34, 0),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: clamped,
                  child: IgnorePointer(ignoring: isRemoving, child: child),
                ),
              ),
            ),
          );
        },
        child: Dismissible(
          key: ValueKey<String>('$chatId-$isPinned'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          confirmDismiss: (direction) async {
            if (isArchived) {
              await _unhideChat(chatId, context: context, showMessage: true);
            } else {
              await _setPinned(chatId, pin: !isPinned, context: context);
            }
            return false;
          },
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: pinnedGradientColors),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isArchived
                  ? Icons.unarchive_outlined
                  : (isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              color: Colors.white,
            ),
          ),
          child: buildTileContent(),
        ),
      );
    }

    if (needFetch && peerUid != null && peerUid.isNotEmpty) {
      return FutureBuilder<ChatListUserProfile?>(
        future: _profileFutureFor(peerUid),
        builder: (context, snap) {
          var updatedChat = Map<String, dynamic>.from(baseChat);
          if (snap.connectionState == ConnectionState.done &&
              snap.hasData &&
              snap.data != null) {
            final profile = snap.data!;
            final name = profile.name;
            final avatar = profile.avatarUrl;
            updatedChat['name'] = name;
            updatedChat['avatarUrl'] = avatar;
            updatedChat['needsFetch'] = false;
            _updateProfileCache(peerUid, name: name, avatarUrl: avatar);
            _prefetchAvatar(avatar);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _maybeUpdateMemberInfo(
                  chatId: updatedChat['chatId'] as String,
                  peerUid: peerUid,
                  name: name,
                  avatarUrl: avatar,
                  members: updatedChat['members'] as List<String>? ?? const [],
                );
              }
            });
          }
          return buildTile(updatedChat);
        },
      );
    }

    return buildTile(baseChat);
  }

  Future<void> _setPinned(
    String chatId, {
    required bool pin,
    required BuildContext context,
    bool showMessage = true,
  }) async {
    final feedback = await _viewModel.setPinned(chatId: chatId, pin: pin);
    if (!mounted || !showMessage || feedback.message.isEmpty) return;
    _showFeedback(context, feedback);
  }

  Future<void> _setFavorite(
    String chatId, {
    required bool favorite,
    required BuildContext context,
    bool showMessage = true,
  }) async {
    final feedback = await _viewModel.setFavorite(
      chatId: chatId,
      favorite: favorite,
    );
    if (!mounted || !showMessage || feedback.message.isEmpty) return;
    _showFeedback(context, feedback);
  }

  Future<void> _hideChat(
    String chatId,
    BuildContext context, {
    bool showMessage = true,
  }) async {
    final feedback = await _viewModel.hideChat(chatId);
    if (!mounted || !showMessage || feedback.message.isEmpty) return;
    _showFeedback(context, feedback);
  }

  Future<void> _unhideChat(
    String chatId, {
    BuildContext? context,
    bool showMessage = false,
  }) async {
    final feedback = await _viewModel.unhideChat(chatId);
    if (!mounted ||
        !showMessage ||
        context == null ||
        feedback.message.isEmpty) {
      return;
    }
    _showFeedback(context, feedback);
  }

  Future<void> _confirmClearChat(BuildContext context, String chatId) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.white,
                      size: 42,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Hapus semua pesan?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Semua pesan di chat ini akan dihapus. Tindakan tidak dapat dibatalkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Hapus'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirm != true || !mounted) return;
    await _animateChatRemoval(chatId);
    try {
      final feedback = await _viewModel.clearChatForCurrentUser(chatId);
      if (!mounted) return;
      if (feedback.type == ChatListFeedbackType.error) {
        _restoreRemovedChat(chatId);
        _showFeedback(context, feedback);
        return;
      }

      if (feedback.clearedType == ChatListClearChatResultType.archived) {
        final hideFeedback = await _viewModel.hideChat(chatId);
        if (hideFeedback.type == ChatListFeedbackType.error) {
          _restoreRemovedChat(chatId);
          _showFeedback(context, hideFeedback);
          return;
        }
      }
      _scheduleRemovedChatCleanup(chatId);
      _showFeedback(context, feedback);
    } catch (e) {
      if (!mounted) return;
      _restoreRemovedChat(chatId);
      showGlassSnackBar(
        context,
        message: 'Gagal membersihkan chat: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  void _showFeedback(BuildContext context, ChatListFeedback feedback) {
    if (feedback.type == ChatListFeedbackType.none ||
        feedback.message.isEmpty) {
      return;
    }
    final tone = switch (feedback.type) {
      ChatListFeedbackType.success => GlassSnackTone.success,
      ChatListFeedbackType.info => GlassSnackTone.info,
      ChatListFeedbackType.warning => GlassSnackTone.warning,
      ChatListFeedbackType.error => GlassSnackTone.error,
      ChatListFeedbackType.none => GlassSnackTone.info,
    };
    showGlassSnackBar(context, message: feedback.message, tone: tone);
  }

  Widget _archivedBanner({
    required int count,
    required bool hasUnread,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _surfaceStrong,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _surfaceBorder),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.15),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined, color: Colors.white),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Chat Diarsipkan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasUnread)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _surfaceBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.18),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions(BuildContext context, Map chat) {
    final chatId = (chat['chatId'] ?? '').toString();
    if (chatId.isEmpty) return;
    final bool isPinned = chat['isPinned'] == true;
    final bool isArchived = chat['isArchived'] == true;
    final bool isFavorite = chat['isFavorite'] == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceSoft,
                border: Border.all(color: _surfaceBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      isFavorite ? Icons.star_outline : Icons.star,
                      color: isFavorite
                          ? const Color(0xFFFFD54F)
                          : Colors.white,
                    ),
                    title: Text(
                      isFavorite
                          ? 'Hapus dari favorit'
                          : 'Tambahkan ke favorit',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _setFavorite(
                        chatId,
                        favorite: !isFavorite,
                        context: context,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                      color: Colors.white,
                    ),
                    title: Text(
                      isPinned ? 'Lepas pin' : 'Pin chat ke atas',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _setPinned(
                        chatId,
                        pin: !isPinned,
                        context: context,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Hapus semua chat',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _confirmClearChat(context, chatId);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      color: Colors.white,
                    ),
                    title: Text(
                      isArchived
                          ? 'Kembalikan ke daftar utama'
                          : 'Pindahkan ke arsip',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      if (isArchived) {
                        await _unhideChat(
                          chatId,
                          context: context,
                          showMessage: true,
                        );
                      } else {
                        await _hideChat(chatId, context);
                      }
                    },
                  ),
                  if (_viewModel.isAdmin)
                    ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Kelola sebagai admin',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showChatActions(
                          context,
                          chatId,
                          (chat['name'] ?? '').toString(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _authenticateArchive(BuildContext context) async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      if (!supported || !canCheck || available.isEmpty) {
        showGlassSnackBar(
          context,
          message: 'Perangkat tidak mendukung Face ID/Touch ID/Fingerprint',
          tone: GlassSnackTone.error,
        );
        return false;
      }
      final reason =
          available.any(
            (b) => b == BiometricType.face || b == BiometricType.strong,
          )
          ? 'Gunakan Face ID/biometrik untuk membuka arsip chat'
          : 'Gunakan fingerprint untuk membuka arsip chat';
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
      if (!authenticated && mounted) {
        showGlassSnackBar(
          context,
          message: 'Face ID dibatalkan',
          tone: GlassSnackTone.info,
        );
      }
      return authenticated;
    } catch (e) {
      showGlassSnackBar(
        context,
        message: 'Tidak bisa membuka arsip: $e',
        tone: GlassSnackTone.error,
      );
      return false;
    }
  }

  Future<void> _showArchivedList(
    BuildContext context,
    List<Map<String, dynamic>> archivedChats,
  ) {
    if (archivedChats.isEmpty) return Future.value();
    return _authenticateArchive(context).then((allowed) {
      if (!allowed) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArchivedChatsPage(
            archivedChats: archivedChats,
            chatTileBuilder: (ctx, chat) => _buildChatTile(
              context: ctx,
              chat: chat,
              isArchivedSection: true,
            ),
          ),
        ),
      );
    });
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: _viewModel.setSearchQuery,
              decoration: const InputDecoration(
                hintText: 'Tanya AI atau cari',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _glassChip(
            label: 'Semua',
            selected: _viewModel.tabIndex == 0,
            onTap: () => _viewModel.setTabIndex(0),
          ),
          const SizedBox(width: 8),
          _glassChip(
            label: 'Belum Dibaca',
            selected: _viewModel.tabIndex == 1,
            onTap: () => _viewModel.setTabIndex(1),
          ),
          const SizedBox(width: 8),
          _glassChip(
            label: 'Favorit',
            selected: _viewModel.tabIndex == 2,
            onTap: () => _viewModel.setTabIndex(2),
          ),
          const SizedBox(width: 8),
          _glassChip(
            label: 'Grup',
            selected: _viewModel.tabIndex == 3,
            onTap: () => _viewModel.setTabIndex(3),
          ),
        ],
      ),
    );
  }

  Widget _chatTileDynamic(Map c, BuildContext tileContext) {
    String timeString = '';
    final dt = _normalizeToDateTime(c['lastMessageAt']);
    if (dt != null) {
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        timeString =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        timeString = '${dt.day}/${dt.month}';
      }
    }
    final bool isGroup = c['isGroup'] == true;
    final bool isPinned = c['isPinned'] == true;
    final bool hasUnread = (c['unread'] ?? 0) > 0;
    final int membersCount = c['membersCount'] is int
        ? c['membersCount'] as int
        : int.tryParse('${c['membersCount'] ?? 0}') ?? 0;
    final currentUid = _viewModel.currentUserUid;
    List<String> deletedFor = const [];
    final rawDeleted = c['lastMessageDeletedFor'];
    if (rawDeleted is Iterable) {
      deletedFor = rawDeleted.map((e) => e.toString()).toList(growable: false);
    }
    final bool hideLastMessage =
        currentUid != null && deletedFor.contains(currentUid);
    final String lastMessage = hideLastMessage
        ? ''
        : (c['lastMessage'] ?? '').toString();
    final String subtitleText = lastMessage.isNotEmpty
        ? lastMessage
        : (isGroup ? '$membersCount anggota' : 'Mulai percakapan');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _surfaceBorder),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildAvatar(
                c['avatarUrl'] as String? ?? '',
                name: c['name'] as String? ?? '',
                isGroup: isGroup,
              ),
              if (hasUnread)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeString,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(
                height: 13,
                width: 28,
                child: isPinned
                    ? Align(
                        alignment: Alignment.bottomLeft,
                        child: Transform.translate(
                          offset: const Offset(0, 8),
                          child: const Icon(
                            Icons.push_pin,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (hasUnread)
                _badge(c['unread'] ?? 0)
              else
                const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  void _maybeUpdateMemberInfo({
    required String chatId,
    required String peerUid,
    required String name,
    required String avatarUrl,
    required List<String> members,
  }) {
    final currentUid = _viewModel.currentUserUid;
    if (currentUid == null || currentUid.isEmpty) return;
    if (!members.contains(currentUid)) return;

    final payload = <String, dynamic>{};
    if (name.trim().isNotEmpty) {
      payload['name'] = name;
    }
    if (avatarUrl.trim().isNotEmpty) {
      payload['avatarUrl'] = avatarUrl;
    }
    if (payload.isEmpty) return;
    final updateKey = '$chatId|$peerUid|${name.trim()}|${avatarUrl.trim()}';
    if (_memberInfoUpdateQueue.contains(updateKey)) return;
    _memberInfoUpdateQueue.add(updateKey);

    _viewModel
        .updateMemberInfo(
          chatId: chatId,
          peerUid: peerUid,
          name: name,
          avatarUrl: avatarUrl,
        )
        .catchError((_) {})
        .whenComplete(() {
          _memberInfoUpdateQueue.remove(updateKey);
        });
  }

  void _updateProfileCache(String uid, {String? name, String? avatarUrl}) {
    if (uid.isEmpty) return;
    final normalizedName = name?.trim();
    final normalizedAvatar = avatarUrl?.trim();
    if ((normalizedName == null || normalizedName.isEmpty) &&
        (normalizedAvatar == null || normalizedAvatar.isEmpty)) {
      return;
    }
    _viewModel.updateProfileCache(
      uid,
      name: normalizedName,
      avatarUrl: normalizedAvatar,
    );
  }

  void _prefetchAvatar(String? url) {
    final normalized = url?.trim() ?? '';
    if (!mounted || normalized.isEmpty || !normalized.startsWith('http')) {
      return;
    }
    unawaited(
      AvatarThumbnailCacheService.instance.prefetch(
        imageUrl: normalized,
        targetSize: 96,
        quality: 64,
      ),
    );
    unawaited(
      precacheImage(NetworkImage(normalized), context).catchError((_) {}),
    );
  }

  Future<String?> _getAvatarThumbPath(String avatarUrl) async {
    final normalized = avatarUrl.trim();
    if (normalized.isEmpty || !normalized.startsWith('http')) {
      return null;
    }

    final cached = _avatarThumbPathCache[normalized];
    if (cached != null && cached.isNotEmpty && File(cached).existsSync()) {
      return cached;
    }

    final inFlight = _avatarThumbFutureCache[normalized];
    if (inFlight != null) {
      return inFlight;
    }

    final future = AvatarThumbnailCacheService.instance
        .getOrCreateThumbnailPath(
          imageUrl: normalized,
          targetSize: 96,
          quality: 64,
        )
        .then((path) {
          _avatarThumbPathCache[normalized] = path;
          return path;
        })
        .catchError((_) => null)
        .whenComplete(() {
          _avatarThumbFutureCache.remove(normalized);
        });

    _avatarThumbFutureCache[normalized] = future;
    return future;
  }

  Widget _buildAvatar(String avatar, {bool isGroup = false, String name = ''}) {
    String _initial(String input) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return '?';
      return trimmed.characters.first.toUpperCase();
    }

    Widget _initialAvatar() {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white.withOpacity(0.1),
        child: Text(
          _initial(name.isNotEmpty ? name : (isGroup ? 'G' : 'U')),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (avatar.isEmpty) {
      return _initialAvatar();
    }

    if (avatar.startsWith('http')) {
      return FutureBuilder<String?>(
        future: _getAvatarThumbPath(avatar),
        builder: (context, snap) {
          final localPath = snap.data;
          if (localPath != null &&
              localPath.isNotEmpty &&
              File(localPath).existsSync()) {
            return CircleAvatar(
              radius: 24,
              backgroundImage: FileImage(File(localPath)),
            );
          }
          return CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(avatar),
          );
        },
      );
    }

    return FutureBuilder<String?>(
      future: _getResolvedAvatar(avatar),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done &&
            snap.hasData &&
            snap.data != null &&
            snap.data!.isNotEmpty) {
          return CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(snap.data!),
          );
        }

        return _initialAvatar();
      },
    );
  }

  Widget _permissionDeniedView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_outline, color: Colors.white70, size: 48),
          SizedBox(height: 16),
          Text(
            'Akses chat ditolak. Pastikan akun Anda masih menjadi anggota percakapan atau hubungi admin.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<String?> _getResolvedAvatar(String avatar) async {
    if (avatar.isEmpty) return null;

    if (_viewModel.avatarCache.containsKey(avatar)) {
      final cached = _viewModel.avatarCache[avatar];
      _prefetchAvatar(cached);
      return cached;
    }

    final inFlight = _avatarResolveCache[avatar];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _viewModel
        .resolveAvatarUrl(avatar)
        .then((url) {
          _viewModel.cacheAvatar(avatar, url);
          _prefetchAvatar(url);
          return url;
        })
        .catchError((_) {
          _viewModel.cacheAvatar(avatar, null);
          return null;
        })
        .whenComplete(() {
          _avatarResolveCache.remove(avatar);
        });
    _avatarResolveCache[avatar] = future;
    return future;
  }

  Future<ChatListUserProfile?> _profileFutureFor(String uid) {
    final existing = _profileFetchCache[uid];
    if (existing != null) return existing;
    final future = _viewModel
        .fetchUserProfile(uid)
        .then((profile) {
          if (profile != null) {
            _updateProfileCache(
              uid,
              name: profile.name,
              avatarUrl: profile.avatarUrl,
            );
            _prefetchAvatar(profile.avatarUrl);
          } else {
            _profileFetchCache.remove(uid);
          }
          return profile;
        })
        .catchError((_) {
          _profileFetchCache.remove(uid);
          return null;
        });
    _profileFetchCache[uid] = future;
    return future;
  }

  Widget _badge(int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFF25D366),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        '$n',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showChatActions(BuildContext context, String chatId, String name) {
    if (!_viewModel.isAdmin) {
      showGlassSnackBar(
        context,
        message: 'Hanya admin yang bisa mengelola dan menghapus chat.',
        tone: GlassSnackTone.warning,
      );
      return;
    }
    final rootContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.cleaning_services,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Bersihkan chat',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.of(rootContext).pop();
                      await _clearChatMessages(chatId);
                      if (!mounted || !rootContext.mounted) return;
                      showGlassSnackBar(
                        rootContext,
                        message: 'Chat dibersihkan',
                        tone: GlassSnackTone.success,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Hapus chat',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.of(rootContext).pop();
                      await _animateChatRemoval(chatId);
                      try {
                        await _deleteChat(chatId);
                        if (!mounted || !rootContext.mounted) return;
                        _scheduleRemovedChatCleanup(chatId);
                        showGlassSnackBar(
                          rootContext,
                          message: 'Chat dihapus',
                          tone: GlassSnackTone.success,
                        );
                      } catch (e) {
                        _restoreRemovedChat(chatId);
                        if (!mounted || !rootContext.mounted) return;
                        showGlassSnackBar(
                          rootContext,
                          message: 'Gagal menghapus chat: $e',
                          tone: GlassSnackTone.error,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _animateChatRemoval(String chatId) async {
    if (!mounted || chatId.isEmpty) return;
    if (_removingChatIds.contains(chatId)) return;
    setState(() {
      _removingChatIds.add(chatId);
    });
    await Future<void>.delayed(const Duration(milliseconds: 240));
  }

  void _restoreRemovedChat(String chatId) {
    if (!mounted || chatId.isEmpty) return;
    if (!_removingChatIds.contains(chatId)) return;
    setState(() {
      _removingChatIds.remove(chatId);
    });
  }

  void _scheduleRemovedChatCleanup(String chatId) {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_removingChatIds.remove(chatId)) {
        setState(() {});
      }
    });
  }

  Future<void> _clearChatMessages(String chatId) async {
    await _viewModel.clearChatMessages(chatId);
  }

  Future<void> _deleteChat(String chatId) async {
    await _viewModel.deleteChat(chatId);
  }
}

Widget _glassChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: (selected
                ? Colors.white.withOpacity(0.35)
                : Colors.white.withOpacity(0.16)),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _glassIconButton({required IconData icon, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    ),
  );
}
