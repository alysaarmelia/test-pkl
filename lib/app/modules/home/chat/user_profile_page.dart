import 'dart:ui' show ImageFilter;
import 'package:characters/characters.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/media_docs_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/starred_messages_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/user_profile_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/user_profile_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserProfilePage extends StatefulWidget {
  final String peerUid;
  final UserProfileRepository? repository;
  final UserProfileViewModel? viewModel;

  const UserProfilePage({
    Key? key,
    required this.peerUid,
    this.repository,
    this.viewModel,
  }) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _addingContact = false;
  late final UserProfileViewModel _viewModel;
  late final String _viewModelTag;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'user-profile-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            UserProfileViewModel(
              repository: widget.repository ?? UserProfileRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<UserProfileViewModel>(tag: _viewModelTag)) {
      Get.delete<UserProfileViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  Future<String?> _resolveChatId() async {
    return _viewModel.resolveChatId(peerUid: widget.peerUid);
  }

  void _showFeedback(UserProfileFeedback feedback) {
    if (!mounted) return;
    final tone = switch (feedback.type) {
      UserProfileFeedbackType.success => GlassSnackTone.success,
      UserProfileFeedbackType.info => GlassSnackTone.info,
      UserProfileFeedbackType.warning => GlassSnackTone.warning,
      UserProfileFeedbackType.error => GlassSnackTone.error,
      UserProfileFeedbackType.none => GlassSnackTone.info,
    };
    showGlassSnackBar(context, message: feedback.message, tone: tone);
  }

  Future<void> _addContactForBoth(UserProfilePeerProfile peerProfile) async {
    if (_addingContact) return;

    setState(() => _addingContact = true);
    try {
      final feedback = await _viewModel.addContactForBoth(
        peerUid: widget.peerUid,
        peerProfile: peerProfile,
      );
      _showFeedback(feedback);
    } finally {
      if (mounted) {
        setState(() => _addingContact = false);
      }
    }
  }

  Future<void> _clearChatHistory() async {
    final chatId = await _resolveChatId();
    if (!mounted) return;
    if (chatId == null) {
      showGlassSnackBar(context, message: 'Chat tidak ditemukan');
      return;
    }

    final confirmed = await showDialog<bool>(
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
                      Icons.delete_sweep,
                      color: Colors.white,
                      size: 42,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Bersihkan Chat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Anda yakin ingin menghapus semua pesan di chat ini? Tindakan ini tidak dapat diurungkan.',
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
                            onPressed: () => Navigator.of(ctx).pop(false),
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
                            onPressed: () => Navigator.of(ctx).pop(true),
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

    if (!mounted) return;
    if (confirmed != true) return;

    final feedback = await _viewModel.clearChatHistory(chatId);
    _showFeedback(feedback);
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onTap != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Lihat semua',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: const Text('Profil'),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white.withOpacity(0.15)),
        ),
      ),
      body: HomeGlassTheme.background(
        child: SafeArea(
          child: StreamBuilder<UserProfilePeerProfile>(
            stream: _viewModel.watchPeerProfile(widget.peerUid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              final profile =
                  snap.data ??
                  const UserProfilePeerProfile(
                    uid: '',
                    name: 'Pengguna',
                    role: '',
                    pin: '',
                    photoUrl: '',
                  );
              final name = profile.name;
              final role = profile.role;
              final pin = profile.pin;
              final photoUrl = profile.photoUrl;
              final myUid = _viewModel.currentUserUid;
              String initial() {
                final trimmed = name.trim();
                if (trimmed.isEmpty) return '?';
                return trimmed.characters.first.toUpperCase();
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.65),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? Text(
                                  initial(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Kartu info (glass)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _rowItem('Nama', name),
                              if (role.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _rowItem('Role', role),
                              ],
                              if (pin.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _rowItem('PIN', pin),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Aksi cepat (opsional)
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _glassButtonIcon(
                            icon: Icons.chat_bubble_outline,
                            label: 'Chat',
                            onPressed: () {
                              Navigator.pop(
                                context,
                              ); // kembali ke chat yg sudah terbuka
                            },
                          ),
                          if (myUid.isNotEmpty)
                            StreamBuilder<bool>(
                              stream: _viewModel.watchIsInMyContacts(
                                peerUid: widget.peerUid,
                              ),
                              builder: (context, contactSnap) {
                                final already = contactSnap.data == true;
                                return _glassButtonIcon(
                                  icon: already
                                      ? Icons.check_circle_outline
                                      : Icons.person_add_alt_1_outlined,
                                  label: already
                                      ? 'Sudah di kontak'
                                      : (_addingContact
                                            ? 'Menambahkan...'
                                            : 'Tambahkan Kontak'),
                                  onPressed: (already || _addingContact)
                                      ? null
                                      : () => _addContactForBoth(profile),
                                  loading: _addingContact,
                                );
                              },
                            )
                          else
                            _glassButtonIcon(
                              icon: Icons.person_add_alt_1_outlined,
                              label: _addingContact
                                  ? 'Menambahkan...'
                                  : 'Tambahkan Kontak',
                              onPressed: _addingContact
                                  ? null
                                  : () => _addContactForBoth(profile),
                              loading: _addingContact,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    FutureBuilder<String?>(
                      future: _resolveChatId(),
                      builder: (context, chatSnap) {
                        final chatId = chatSnap.data;
                        return _sectionHeader(
                          'Media & Dokumen',
                          onTap: (chatId == null)
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MediaDocsPage(chatId: chatId),
                                    ),
                                  );
                                },
                        );
                      },
                    ),
                    FutureBuilder<String?>(
                      future: _resolveChatId(),
                      builder: (context, chatSnap) {
                        final chatId = chatSnap.data;
                        if (chatId == null) return const SizedBox();
                        return StreamBuilder<UserProfileMediaDocsPreview>(
                          stream: _viewModel.watchMediaDocsPreview(chatId),
                          builder: (context, msgSnap) {
                            if (msgSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }
                            final preview =
                                msgSnap.data ??
                                const UserProfileMediaDocsPreview();
                            final images = preview.images;
                            final files = preview.files;

                            return _glassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Grid foto (jika ada)
                                    if (images.isNotEmpty)
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: images.length > 6
                                            ? 6
                                            : images.length,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 6,
                                              mainAxisSpacing: 6,
                                            ),
                                        itemBuilder: (context, i) {
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Image.network(
                                              images[i],
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      Row(
                                        children: const [
                                          Icon(
                                            Icons.photo_library_outlined,
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Lihat semua media',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                    if (files.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Divider(
                                        color: Colors.white.withOpacity(0.15),
                                        height: 1,
                                      ),
                                      const SizedBox(height: 12),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: files.length > 6
                                            ? 6
                                            : files.length,
                                        separatorBuilder: (_, __) => Divider(
                                          color: Colors.white.withOpacity(0.1),
                                          height: 1,
                                        ),
                                        itemBuilder: (context, i) {
                                          final f = files[i];
                                          final name = f.name;
                                          return ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 0,
                                                ),
                                            leading: const Icon(
                                              Icons.insert_drive_file,
                                              color: Colors.white,
                                            ),
                                            title: Text(
                                              name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            subtitle: Text(
                                              f.url,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            onTap: () {
                                              // TODO: buka viewer/download
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    FutureBuilder<String?>(
                      future: _resolveChatId(),
                      builder: (context, chatSnap) {
                        final chatId = chatSnap.data;
                        return _sectionHeader(
                          'Pesan Berbintang',
                          onTap: (chatId == null)
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StarredMessagesPage(
                                        chatId: chatId,
                                        peerUid: widget.peerUid,
                                        peerName: name,
                                      ),
                                    ),
                                  );
                                },
                        );
                      },
                    ),
                    FutureBuilder<String?>(
                      future: _resolveChatId(),
                      builder: (context, chatSnap) {
                        final chatId = chatSnap.data;
                        if (chatId == null) return const SizedBox();
                        return Builder(
                          builder: (context) {
                            final myUid = _viewModel.currentUserUid;
                            if (myUid.isEmpty) {
                              return _glassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.white70,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Silakan login ulang untuk melihat pesan berbintang',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return StreamBuilder<UserProfileStarredSummary?>(
                              stream: _viewModel.watchStarredSummary(
                                chatId: chatId,
                                myUid: myUid,
                              ),
                              builder: (context, starSnap) {
                                if (starSnap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }
                                final summary = starSnap.data;
                                if (summary == null) {
                                  return _glassCard(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: const [
                                          Icon(
                                            Icons.star_border,
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Belum ada pesan berbintang',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                final text = summary.text;
                                final ts = summary.timestamp;
                                final timeStr = (ts != null)
                                    ? '${ts.day}/${ts.month}/${ts.year} • ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                                    : '';

                                return _glassCard(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    leading: const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                    ),
                                    title: Text(
                                      text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      timeStr,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    // Tombol aksi berbahaya
                    _glassCard(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.delete_sweep,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Bersihkan Chat',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: _clearChatHistory,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Powered by
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Powered by',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'lib/app/assets/images/cvm.png',
                                height: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Cipta Vera Mandiri Digital',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _rowItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _glassButtonIcon({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool loading = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.32),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.2,
            ),
          ),
          child: TextButton.icon(
            onPressed: loading ? null : onPressed,
            icon: loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(icon, color: Colors.white),
            label: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
