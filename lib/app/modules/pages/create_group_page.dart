import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/chat_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/create_group_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/create_group_view_model.dart';
import 'package:get/get.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key, this.repository});

  final CreateGroupRepository? repository;

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  late final CreateGroupViewModel _viewModel;
  late final String _viewModelTag;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'create-group-${identityHashCode(this)}';
    _viewModel = Get.put(
      CreateGroupViewModel(repository: widget.repository),
      tag: _viewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<CreateGroupViewModel>(tag: _viewModelTag)) {
      Get.delete<CreateGroupViewModel>(tag: _viewModelTag, force: true);
    }
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showFeedback(CreateGroupFeedback feedback) {
    if (feedback.type == CreateGroupFeedbackType.none ||
        feedback.message.isEmpty) {
      return;
    }
    final tone = switch (feedback.type) {
      CreateGroupFeedbackType.success => GlassSnackTone.success,
      CreateGroupFeedbackType.info => GlassSnackTone.info,
      CreateGroupFeedbackType.warning => GlassSnackTone.warning,
      CreateGroupFeedbackType.error => GlassSnackTone.error,
      CreateGroupFeedbackType.none => GlassSnackTone.info,
    };
    showGlassSnackBar(context, message: feedback.message, tone: tone);
  }

  Future<void> _pickImage() async {
    final feedback = await _viewModel.pickImageFromGallery();
    if (!mounted) return;
    _showFeedback(feedback);
  }

  Future<void> _toggleMember(CreateGroupContact contact) async {
    final feedback = await _viewModel.toggleMember(contact);
    if (!mounted) return;
    _showFeedback(feedback);
  }

  Future<void> _createGroup() async {
    final result = await _viewModel.createGroup(
      groupName: _nameCtrl.text,
      groupDescription: _descCtrl.text,
    );
    if (!mounted) return;
    _showFeedback(result.feedback);
    if (!result.shouldOpenChat) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: result.chatId!,
          peerName: result.groupName ?? _nameCtrl.text.trim(),
          peerAvatarUrl: null,
          isGroup: true,
        ),
      ),
    );
  }

  bool get _creating => _viewModel.creating;

  CreateGroupMyProfile? get _myProfile => _viewModel.myProfile;

  Map<String, CreateGroupSelectedMember> get _selectedMembers {
    return _viewModel.selectedMembers;
  }

  String? get _pickedImagePath => _viewModel.pickedImagePath;

  String get _myUid => _viewModel.currentUserUid ?? '';

  void _removeSelectedMember(String uid) {
    _viewModel.removeSelectedMember(uid);
  }

  List<CreateGroupContact> _filterContacts(List<CreateGroupContact> contacts) {
    return _viewModel.buildFilteredContacts(contacts);
  }

  bool _isSelectedMember(String uid) {
    return _viewModel.isSelected(uid);
  }

  Stream<List<CreateGroupContact>>? get _contactsStream {
    return _viewModel.contactsStream;
  }

  Widget _buildSelectedMembers() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (_myProfile != null)
          _memberBadge(
            name: _myProfile!.name,
            pin: _myProfile!.pin,
            avatarUrl: _myProfile!.avatarUrl,
            highlightSelf: true,
          ),
        if (_selectedMembers.isEmpty)
          const Text(
            'Belum ada anggota tambahan',
            style: TextStyle(color: Colors.white54),
          ),
        ..._selectedMembers.entries.map((entry) {
          final member = entry.value;
          return _memberBadge(
            name: member.name,
            pin: member.pin,
            avatarUrl: member.avatarUrl,
            onRemove: _creating ? null : () => _removeSelectedMember(entry.key),
          );
        }),
      ],
    );
  }

  ImageProvider<Object>? _avatarImageProvider() {
    final path = _pickedImagePath?.trim() ?? '';
    if (path.isEmpty) return null;
    return FileImage(File(path));
  }

  Widget _buildContactList() {
    final myUid = _myUid;
    if (myUid.isEmpty || _contactsStream == null) {
      return const Center(
        child: Text(
          'Harus login untuk melihat kontak',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return StreamBuilder<List<CreateGroupContact>>(
      stream: _contactsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !(snapshot.hasData && snapshot.data!.isNotEmpty)) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat kontak: ${snapshot.error}',
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }

        final contacts = snapshot.data ?? const <CreateGroupContact>[];
        final filtered = _filterContacts(contacts);
        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'Kontak tidak ditemukan',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final contact = filtered[index];
            final uid = contact.uid;
            final shown = contact.displayLabel;
            final pin = contact.resolvedPin;
            final photoUrl = contact.resolvedAvatar;
            final selected = _isSelectedMember(uid);

            return GestureDetector(
              onTap: _creating ? null : () => _toggleMember(contact),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              shown.isNotEmpty ? shown[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shown,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'PIN: ${pin.isNotEmpty ? pin : '-'}',
                            style: TextStyle(
                              color: pin.isNotEmpty
                                  ? Colors.white70
                                  : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: Colors.white),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CreateGroupViewModel>(
      tag: _viewModelTag,
      builder: (_) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
          title: const Text('Grup Baru'),
          centerTitle: true,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: _creating ? null : _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 62,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            backgroundImage: _avatarImageProvider(),
                            child: _pickedImagePath == null
                                ? const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white70,
                                    size: 36,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nama Grup',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameCtrl,
                          enabled: !_creating,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Misal: Tim Marketing',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deskripsi (opsional)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descCtrl,
                          enabled: !_creating,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                'Tuliskan tujuan grup atau catatan singkat',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Anggota Grup',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSelectedMembers(),
                  const SizedBox(height: 16),
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilih dari kontak',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchCtrl,
                          enabled: !_creating,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Cari nama atau PIN kontak',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white70,
                            ),
                          ),
                          onChanged: _viewModel.setSearchQuery,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(height: 220, child: _buildContactList()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creating ? null : _createGroup,
                      icon: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.group_add),
                      label: Text(_creating ? 'Membuat grup...' : 'Buat Grup'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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

  Widget _memberBadge({
    required String name,
    required String pin,
    String? avatarUrl,
    VoidCallback? onRemove,
    bool highlightSelf = false,
  }) {
    final normalizedPin = pin.trim().isEmpty ? '-' : pin.trim().toUpperCase();
    final baseColor = highlightSelf ? 0.26 : 0.18;
    final borderAlpha = highlightSelf ? 0.55 : 0.35;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: baseColor),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    highlightSelf ? '$name (Anda)' : name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'PIN: $normalizedPin',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
