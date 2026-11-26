import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:cipta_vera_mandiri_digital/app/services/avatar_thumbnail_cache_service.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/group_profile_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/group_profile_view_model.dart';

import 'contact_list_page.dart';
import 'media_docs_page.dart';

class GroupProfilePage extends StatefulWidget {
  final String chatId;
  final GroupProfileRepository? repository;
  final GroupProfileViewModel? viewModel;
  final ImagePicker? imagePicker;
  final ImageCropper? imageCropper;

  const GroupProfilePage({
    super.key,
    required this.chatId,
    this.repository,
    this.viewModel,
    this.imagePicker,
    this.imageCropper,
  });

  @override
  State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  late final GroupProfileViewModel _viewModel;
  late final String _viewModelTag;
  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();
  late final ImageCropper _cropper = widget.imageCropper ?? ImageCropper();
  bool _isUploadingImage = false;
  final Map<String, String?> _avatarThumbPathCache = <String, String?>{};
  final Map<String, Future<String?>> _avatarThumbFutureCache =
      <String, Future<String?>>{};

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'group-profile-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            GroupProfileViewModel(
              repository: widget.repository ?? GroupProfileRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<GroupProfileViewModel>(tag: _viewModelTag)) {
      Get.delete<GroupProfileViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  // Helpers for consistent glass UI, mirroring UserProfilePage
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

  Widget _glassButtonIcon({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool fullWidth = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(fullWidth ? 18 : 30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: fullWidth ? double.infinity : null,
              height: fullWidth ? 52 : 46,
              padding: EdgeInsets.symmetric(horizontal: fullWidth ? 20 : 16),
              decoration: BoxDecoration(
                color: (color ?? Colors.white).withOpacity(0.28),
                borderRadius: BorderRadius.circular(fullWidth ? 18 : 30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: fullWidth
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    final first = parts.first.characters.first.toUpperCase();
    final last = parts.last.characters.first.toUpperCase();
    return '$first$last';
  }

  String _resolveMemberName(
    Map<String, dynamic> data, {
    String fallback = 'Anggota',
  }) {
    final candidates = [
      data['name'],
      data['displayName'],
      data['fullName'],
      data['username'],
      data['userName'],
      fallback,
    ];
    for (final c in candidates) {
      if (c == null) continue;
      final value = c.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  String _resolveMemberAvatar(Map<String, dynamic> data) {
    final candidates = [
      data['avatarUrl'],
      data['photoUrl'],
      data['profilePhoto'],
      data['photoURL'],
      data['avatar'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      final value = c.toString().trim();
      if (value.isEmpty) continue;
      if (value.toLowerCase() == 'null') continue;
      return value;
    }
    return '';
  }

  Future<String?> _getAvatarThumbPath(
    String avatarUrl, {
    int targetSize = 96,
    int quality = 64,
  }) async {
    final normalized = avatarUrl.trim();
    if (normalized.isEmpty || !normalized.startsWith('http')) return null;

    final cached = _avatarThumbPathCache[normalized];
    if (cached != null && cached.isNotEmpty && File(cached).existsSync()) {
      return cached;
    }

    final inFlight = _avatarThumbFutureCache[normalized];
    if (inFlight != null) return inFlight;

    final future = AvatarThumbnailCacheService.instance
        .getOrCreateThumbnailPath(
          imageUrl: normalized,
          targetSize: targetSize,
          quality: quality,
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

  Future<void> _clearGroupChatHistory() async {
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
                      'Bersihkan Chat Grup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tindakan ini akan menghapus seluruh riwayat pesan grup untuk semua anggota. Yakin ingin melanjutkan?',
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

    if (confirmed != true) return;

    try {
      await _viewModel.clearGroupChatHistory(widget.chatId);

      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Riwayat chat grup telah dibersihkan',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal membersihkan chat: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _leaveGroup() async {
    final currentUserId = _viewModel.currentUserUid;
    if (currentUserId.isEmpty) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Sesi login tidak ditemukan',
        tone: GlassSnackTone.warning,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keluar Grup',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Anda yakin ingin keluar dari grup ini? Anda tidak akan menerima pesan baru.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text(
                            'Batal',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.28),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                  width: 1,
                                ),
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text(
                                  'Keluar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
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

    if (confirmed == true) {
      try {
        await _viewModel.leaveGroup(chatId: widget.chatId, uid: currentUserId);
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (!mounted) return;
        showGlassSnackBar(
          context,
          message: 'Failed to leave group: $e',
          tone: GlassSnackTone.error,
        );
      }
    }
  }

  Future<void> _changeGroupName(String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubah Nama Grup',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Nama grup',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                            'Batal',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                  width: 1,
                                ),
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Simpan',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
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
    if (ok == true) {
      final name = ctrl.text.trim();
      if (name.isEmpty) return;
      try {
        await _viewModel.updateGroupName(chatId: widget.chatId, name: name);
        if (!mounted) return;
        showGlassSnackBar(
          context,
          message: 'Nama grup diperbarui',
          tone: GlassSnackTone.success,
        );
      } catch (e) {
        if (!mounted) return;
        showGlassSnackBar(
          context,
          message: 'Gagal menyimpan: $e',
          tone: GlassSnackTone.error,
        );
      }
    }
  }

  Future<void> _pickNewAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _isUploadingImage = true);
      // Crop image to let user adjust position/size
      final CroppedFile? cropped = await _cropper.cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Foto Grup',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: 'Crop Foto Grup', aspectRatioLockEnabled: false),
        ],
      );
      if (cropped == null) {
        if (mounted) setState(() => _isUploadingImage = false);
        return;
      }
      await _viewModel.uploadGroupAvatar(
        chatId: widget.chatId,
        filePath: cropped.path,
      );
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      showGlassSnackBar(
        context,
        message: 'Foto grup diperbarui',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      showGlassSnackBar(
        context,
        message: 'Gagal memperbarui foto: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _setAdmin(
    String uid, {
    required bool value,
    String? creatorUid,
  }) async {
    try {
      // Prevent demoting the original creator
      if (!value && creatorUid != null && uid == creatorUid) {
        if (!mounted) return;
        showGlassSnackBar(
          context,
          message: 'Admin utama tidak bisa dicabut',
          tone: GlassSnackTone.warning,
        );
        return;
      }
      await _viewModel.setAdmin(chatId: widget.chatId, uid: uid, value: value);
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: value ? 'Pengguna dijadikan admin' : 'Hak admin dicabut',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal mengubah admin: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _removeMember(String uid) async {
    try {
      await _viewModel.removeMember(chatId: widget.chatId, uid: uid);
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Anggota dikeluarkan dari grup',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal mengeluarkan anggota: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _confirmRemoveMember(String name, String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keluarkan anggota?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Apakah Anda yakin ingin mengeluarkan $name dari grup?',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text(
                            'Batal',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.28),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                  width: 1,
                                ),
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text(
                                  'Keluarkan',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
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

    if (ok == true) {
      await _removeMember(uid);
    }
  }

  void _navigateToAddMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ContactListPage(chatId: widget.chatId, isGroup: true),
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
        title: const Text('Grup'),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
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
          child: StreamBuilder<GroupProfileChatData>(
            stream: _viewModel.watchGroup(widget.chatId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              final group = snap.data ?? const GroupProfileChatData();
              final groupName = group.groupName;
              final groupAvatarUrl = group.groupAvatarUrl;
              final memberInfo = group.memberInfo;
              final admins = group.admins;
              final createdBy = group.createdBy;
              final membersCount = group.members.isNotEmpty
                  ? group.members.length
                  : memberInfo.length;

              final myUid = _viewModel.currentUserUid;
              // Admin utama (createdBy) selalu dianggap admin.
              final isAdmin = admins.contains(myUid) || (createdBy == myUid);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (groupAvatarUrl.isNotEmpty &&
                              groupAvatarUrl.startsWith('http'))
                            FutureBuilder<String?>(
                              future: _getAvatarThumbPath(
                                groupAvatarUrl,
                                targetSize: 128,
                                quality: 66,
                              ),
                              builder: (context, avatarSnap) {
                                final localPath = avatarSnap.data;
                                final imageProvider =
                                    (localPath != null &&
                                        localPath.isNotEmpty &&
                                        File(localPath).existsSync())
                                    ? FileImage(File(localPath))
                                    : NetworkImage(groupAvatarUrl)
                                          as ImageProvider;
                                return CircleAvatar(
                                  radius: 56,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  backgroundImage: imageProvider,
                                );
                              },
                            )
                          else
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              child: const Icon(
                                Icons.group,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          if (_isUploadingImage)
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.7),
                                  width: 1,
                                ),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          if (isAdmin && !_isUploadingImage)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _pickNewAvatar,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.9),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Info grup
                    _glassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nama Grup',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    groupName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isAdmin)
                                  IconButton(
                                    onPressed: () =>
                                        _changeGroupName(groupName),
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.people,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$membersCount anggota',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Aksi cepat
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (isAdmin)
                              _glassButtonIcon(
                                icon: Icons.person_add_alt,
                                label: 'Tambah',
                                onPressed: _navigateToAddMembers,
                              ),
                            _glassButtonIcon(
                              icon: Icons.delete_sweep,
                              label: 'Hapus chat',
                              onPressed: _clearGroupChatHistory,
                              color: Colors.orangeAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _glassButtonIcon(
                          icon: Icons.exit_to_app,
                          label: 'Keluar dari grup',
                          onPressed: _leaveGroup,
                          color: Colors.redAccent,
                          fullWidth: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _sectionHeader(
                      'Media & Dokumen',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MediaDocsPage(chatId: widget.chatId),
                          ),
                        );
                      },
                    ),
                    StreamBuilder<GroupProfileMediaDocsPreview>(
                      stream: _viewModel.watchMediaDocsPreview(widget.chatId),
                      builder: (context, msgSnap) {
                        if (msgSnap.connectionState ==
                                ConnectionState.waiting &&
                            !msgSnap.hasData) {
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
                            const GroupProfileMediaDocsPreview();
                        final images = preview.images;
                        final files = preview.files;

                        return _glassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                        borderRadius: BorderRadius.circular(10),
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
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                          color: Colors.white.withOpacity(0.1),
                                          height: 1,
                                        ),
                                    itemBuilder: (context, i) {
                                      final f = files[i];
                                      return ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                        leading: const Icon(
                                          Icons.insert_drive_file,
                                          color: Colors.white70,
                                        ),
                                        title: Text(
                                          f.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    _sectionHeader('Anggota'),
                    _glassCard(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: memberInfo.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.white.withOpacity(0.1),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final memberId = memberInfo.keys.elementAt(index);
                          final info =
                              memberInfo[memberId] ?? const <String, dynamic>{};
                          final name = _resolveMemberName(info);
                          final avatar = _resolveMemberAvatar(info);
                          final hasHttpAvatar =
                              avatar.isNotEmpty && avatar.startsWith('http');
                          // Tampilkan badge Admin untuk yang ada di daftar atau creator.
                          final isAdm =
                              admins.contains(memberId) ||
                              (createdBy == memberId);
                          // Admin bisa kelola selain dirinya sendiri dan tidak bisa kelola creator.
                          final canManage =
                              isAdmin &&
                              memberId != myUid &&
                              memberId != createdBy;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.65),
                                  width: 1.4,
                                ),
                              ),
                              child: hasHttpAvatar
                                  ? FutureBuilder<String?>(
                                      future: _getAvatarThumbPath(
                                        avatar,
                                        targetSize: 80,
                                        quality: 62,
                                      ),
                                      builder: (context, avatarSnap) {
                                        final localPath = avatarSnap.data;
                                        final imageProvider =
                                            (localPath != null &&
                                                localPath.isNotEmpty &&
                                                File(localPath).existsSync())
                                            ? FileImage(File(localPath))
                                            : NetworkImage(avatar)
                                                  as ImageProvider;
                                        return CircleAvatar(
                                          radius: 20,
                                          backgroundImage: imageProvider,
                                          backgroundColor: Colors.white
                                              .withOpacity(0.18),
                                        );
                                      },
                                    )
                                  : CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.18,
                                      ),
                                      child: Text(
                                        _initialsFromName(name),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isAdm)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      'Admin',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (canManage) ...[
                                  const SizedBox(width: 6),
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      popupMenuTheme: PopupMenuThemeData(
                                        color: Colors.black.withOpacity(0.35),
                                        surfaceTintColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          side: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.32,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        elevation: 0,
                                        textStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    child: PopupMenuButton<String>(
                                      elevation: 0,
                                      color: Colors.black.withOpacity(0.35),
                                      surfaceTintColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      clipBehavior: Clip.antiAlias,
                                      offset: const Offset(0, 10),
                                      onSelected: (value) {
                                        if (value == 'promote') {
                                          _setAdmin(
                                            memberId,
                                            value: true,
                                            creatorUid: createdBy,
                                          );
                                        } else if (value == 'demote') {
                                          _setAdmin(
                                            memberId,
                                            value: false,
                                            creatorUid: createdBy,
                                          );
                                        } else if (value == 'remove') {
                                          _confirmRemoveMember(name, memberId);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (!isAdm)
                                          PopupMenuItem(
                                            value: 'promote',
                                            child: const Text(
                                              'Jadikan admin',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        if (isAdm)
                                          PopupMenuItem(
                                            value: 'demote',
                                            child: const Text(
                                              'Cabut admin',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        const PopupMenuDivider(height: 10),
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.person_remove_alt_1,
                                                color: Colors.redAccent,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Keluarkan',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(
                                          Icons.more_vert,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
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
}
