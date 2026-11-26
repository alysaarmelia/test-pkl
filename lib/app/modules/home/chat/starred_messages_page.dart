import 'dart:ui' show ImageFilter;
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/starred_messages_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/starred_messages_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';

/// Halaman daftar semua Pesan Berbintang untuk satu chat.
///
/// Beri salah satu dari [chatId] atau [peerUid]. Jika [chatId] null,
/// halaman akan mencoba resolve berdasarkan kombinasi uid saat ini + peerUid.
class StarredMessagesPage extends StatefulWidget {
  final String? chatId;
  final String? peerUid;
  final String? peerName;
  final StarredMessagesRepository? repository;
  final StarredMessagesViewModel? viewModel;

  const StarredMessagesPage({
    super.key,
    this.chatId,
    this.peerUid,
    this.peerName,
    this.repository,
    this.viewModel,
  });

  @override
  State<StarredMessagesPage> createState() => _StarredMessagesPageState();
}

class _StarredMessagesPageState extends State<StarredMessagesPage> {
  String? _resolvedChatId;
  bool _resolving = false;
  late final StarredMessagesViewModel _viewModel;
  late final String _viewModelTag;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'starred-msg-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            StarredMessagesViewModel(
              repository: widget.repository ?? StarredMessagesRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
    _ensureChatId();
  }

  @override
  void dispose() {
    if (Get.isRegistered<StarredMessagesViewModel>(tag: _viewModelTag)) {
      Get.delete<StarredMessagesViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  Future<void> _ensureChatId() async {
    if (_resolvedChatId != null) return;
    setState(() => _resolving = true);
    final cid = await _resolveChatId(widget.chatId, widget.peerUid);
    if (!mounted) return;
    setState(() {
      _resolvedChatId = cid;
      _resolving = false;
    });
  }

  Future<String?> _resolveChatId(String? chatId, String? peerUid) async {
    return _viewModel.resolveChatId(chatId: chatId, peerUid: peerUid);
  }

  @override
  Widget build(BuildContext context) {
    final hasPeer =
        (widget.peerName != null && widget.peerName!.trim().isNotEmpty);
    final titleText = hasPeer
        ? 'Pesan Berbintang • ${widget.peerName}'
        : 'Pesan Berbintang';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.25),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: HomeGlassTheme.background(
        child: SafeArea(
          child: _resolving
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : (_resolvedChatId == null
                    ? _emptyState('Chat belum ditemukan')
                    : _StarredList(
                        chatId: _resolvedChatId!,
                        myUid: _viewModel.currentUserUid,
                        viewModel: _viewModel,
                      )),
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_border, color: Colors.white70, size: 48),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _StarredList extends StatelessWidget {
  final String chatId;
  final String myUid;
  final StarredMessagesViewModel viewModel;
  const _StarredList({
    required this.chatId,
    required this.myUid,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    if (myUid.isEmpty) {
      return const Center(
        child: Text(
          'Silakan login ulang untuk melihat pesan berbintang',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final streamBy = viewModel.watchStarredBy(chatId: chatId, myUid: myUid);
    final streamLegacy = viewModel.watchLegacyStarred(chatId: chatId);

    return StreamBuilder<List<StarredMessageRecord>>(
      stream: streamBy,
      builder: (context, snapBy) {
        return StreamBuilder<List<StarredMessageRecord>>(
          stream: streamLegacy,
          builder: (context, snapLegacy) {
            if (snapBy.connectionState == ConnectionState.waiting &&
                snapLegacy.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            // Toleran terhadap error salah satu stream
            final recordsBy = snapBy.data ?? const <StarredMessageRecord>[];
            final recordsLegacy =
                snapLegacy.data ?? const <StarredMessageRecord>[];
            final filtered = viewModel.combineAndFilter(
              byRecords: recordsBy,
              legacyRecords: recordsLegacy,
              myUid: myUid,
            );

            if (filtered.isEmpty) {
              if (snapBy.hasError || snapLegacy.hasError) {
                final err = (snapBy.error ?? snapLegacy.error).toString();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Gagal memuat pesan berbintang: $err',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.star_border, color: Colors.white70, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada pesan berbintang',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final type = item.type;
                final timeStr = viewModel.formatTime(item.time);

                return _glassCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: Icon(
                      type == 'image'
                          ? Icons.photo
                          : type == 'file'
                          ? Icons.insert_drive_file
                          : Icons.chat_bubble_outline,
                      color: Colors.white,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: timeStr == null
                        ? null
                        : Text(
                            timeStr,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                    trailing: IconButton(
                      icon: const Icon(Icons.star, color: Colors.amber),
                      onPressed: () async {
                        // Toggle off bintang
                        try {
                          await viewModel.removeStar(
                            chatId: chatId,
                            messageId: item.id,
                            myUid: myUid,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          showGlassSnackBar(
                            context,
                            message: 'Gagal menghapus bintang: $e',
                            tone: GlassSnackTone.error,
                          );
                        }
                      },
                    ),
                    onTap: () {
                      // TODO: bisa navigasi ke pesan di ChatPage
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

Widget _glassCard({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
        ),
        child: child,
      ),
    ),
  );
}
