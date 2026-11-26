import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';

import '../../../view_models/profile_model.dart';
import '../../../repositories/profile_repository.dart';
import '../../../view_models/profile_view_model.dart';

class ProfilePage extends StatefulWidget {
  final ProfileRepository? repository;

  const ProfilePage({super.key, this.repository});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final String _profileViewModelTag;
  late final ProfileViewModel _viewModel;
  late final AnimationController _avatarShimmerController;

  @override
  void initState() {
    super.initState();
    _profileViewModelTag = 'profile-${identityHashCode(this)}';
    _viewModel = Get.put(
      ProfileViewModel(
        repository: widget.repository ?? ProfileRepositoryImpl(),
      ),
      tag: _profileViewModelTag,
    );
    _avatarShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    if (Get.isRegistered<ProfileViewModel>(tag: _profileViewModelTag)) {
      Get.delete<ProfileViewModel>(tag: _profileViewModelTag, force: true);
    }
    _avatarShimmerController.dispose();
    super.dispose();
  }

  Future<void> _updateProfilePicture() async {
    final feedback = await _viewModel.updateProfilePicture();
    if (!mounted) return;
    _showFeedback(feedback);
  }

  Future<void> _removeImage() async {
    final feedback = await _viewModel.removeProfilePicture();
    if (!mounted) return;
    _showFeedback(feedback);
  }

  void _showFeedback(ProfileFeedback feedback) {
    if (feedback.type == ProfileFeedbackType.none || feedback.message.isEmpty) {
      return;
    }
    final tone = switch (feedback.type) {
      ProfileFeedbackType.success => GlassSnackTone.success,
      ProfileFeedbackType.info => GlassSnackTone.info,
      ProfileFeedbackType.error => GlassSnackTone.error,
      ProfileFeedbackType.none => GlassSnackTone.info,
    };
    showGlassSnackBar(context, message: feedback.message, tone: tone);
  }

  Future<void> _showPhotoOptions(bool hasPhoto) async {
    if (_viewModel.uploadingPhoto.value) {
      showGlassSnackBar(
        context,
        message: 'Sedang memproses foto, tunggu sebentar.',
        tone: GlassSnackTone.info,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.3,
              minChildSize: 0.2,
              maxChildSize: 0.6,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 10,
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Edit foto profil',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text("Pilih foto"),
                                trailing: const Icon(Icons.photo),
                                onTap: () {
                                  Navigator.pop(context);
                                  _updateProfilePicture();
                                },
                              ),
                              if (hasPhoto) ...[
                                ListTile(
                                  title: const Text(
                                    "Hapus foto",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  trailing: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _removeImage();
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final uid = _viewModel.currentUid;
      final isUploadingPhoto = _viewModel.uploadingPhoto.value;

      return Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Profil',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: HomeGlassTheme.textPrimary,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: HomeGlassTheme.backgroundGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              HomeGlassTheme.orb(
                top: -120,
                left: -80,
                diameter: 320,
                colors: HomeGlassTheme.orbBlue,
              ),
              HomeGlassTheme.orb(
                top: 320,
                right: -140,
                diameter: 360,
                colors: HomeGlassTheme.orbPurple,
              ),
              HomeGlassTheme.orb(
                bottom: -220,
                left: 20,
                diameter: 440,
                colors: HomeGlassTheme.orbMint,
              ),
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    kToolbarHeight + 6,
                    20,
                    120,
                  ),
                  child: uid == null
                      ? const _ProfileMessage(
                          message:
                              'Tidak menemukan sesi pengguna. Silakan login ulang.',
                        )
                      : StreamBuilder<ProfileData?>(
                          stream: _viewModel.watchProfile(uid),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              if (!_viewModel.hasActiveSession) {
                                return const _ProfileMessage(
                                  message:
                                      'Sesi berakhir. Silakan login kembali untuk melihat profil.',
                                );
                              }
                              return const _ProfileMessage(
                                message:
                                    'Terjadi kesalahan saat memuat profil.',
                              );
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            }
                            final profile = snapshot.data;
                            if (!snapshot.hasData || profile == null) {
                              return const _ProfileMessage(
                                message: 'Data profil tidak ditemukan.',
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _ProfileHeaderCard(
                                  hasPhoto: profile.hasPhoto,
                                  photoUrl: profile.photoUrl,
                                  displayName: profile.displayName,
                                  displaySubtitle: profile.displayRole,
                                  isUpdatingPhoto: isUploadingPhoto,
                                  shimmerAnimation: _avatarShimmerController,
                                  onEditPhoto: () =>
                                      _showPhotoOptions(profile.hasPhoto),
                                ),
                                const SizedBox(height: 24),
                                _buildInfoTile(
                                  'Nama',
                                  profile.displayName,
                                  Icons.verified_user,
                                  false,
                                  null,
                                ),
                                const SizedBox(height: 14),
                                _buildInfoTile(
                                  'PIN',
                                  profile.displayPin,
                                  Icons.lock,
                                  false,
                                  null,
                                ),
                                const SizedBox(height: 14),
                                _buildInfoTile(
                                  'Role',
                                  profile.displayRole,
                                  Icons.work_outline,
                                  false,
                                  null,
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildInfoTile(
    String title,
    String subtitle,
    IconData icon,
    bool editable,
    VoidCallback? onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: HomeGlassTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: editable
                    ? HomeGlassTheme.surfaceStrong
                    : HomeGlassTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HomeGlassTheme.surfaceBorder),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: editable ? onTap : null,
                  splashColor: Colors.white.withOpacity(0.08),
                  highlightColor: Colors.white.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 16,
                              color: HomeGlassTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          icon,
                          size: 20,
                          color: HomeGlassTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: HomeGlassTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AvatarShimmer extends StatelessWidget {
  const _AvatarShimmer({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(animation.value);
            final pulse = 0.18 + 0.12 * sin(pi * 2 * t);
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black.withOpacity(0.12)),
                Opacity(opacity: pulse.clamp(0, 0.35), child: child),
              ],
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(255, 255, 255, 0.08),
                  Color.fromRGBO(255, 255, 255, 0.28),
                  Color.fromRGBO(255, 255, 255, 0.08),
                ],
                stops: [0.22, 0.5, 0.78],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.hasPhoto,
    required this.photoUrl,
    required this.displayName,
    required this.displaySubtitle,
    required this.isUpdatingPhoto,
    required this.shimmerAnimation,
    required this.onEditPhoto,
  });

  final bool hasPhoto;
  final String photoUrl;
  final String displayName;
  final String displaySubtitle;
  final bool isUpdatingPhoto;
  final Animation<double> shimmerAnimation;
  final VoidCallback onEditPhoto;

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: isUpdatingPhoto ? null : onEditPhoto,
                  customBorder: const CircleBorder(),
                  splashColor: Colors.white.withOpacity(0.12),
                  highlightColor: Colors.white.withOpacity(0.06),
                  child: Container(
                    width: 130,
                    height: 130,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF48D9F3), Color(0xFF28A8D8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF48D9F3).withOpacity(0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0D1B2A),
                        image: hasPhoto
                            ? DecorationImage(
                                image: NetworkImage(photoUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: !hasPhoto
                          ? Text(
                              _initials(displayName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  elevation: 6,
                  child: InkWell(
                    onTap: isUpdatingPhoto ? null : onEditPhoto,
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0D1B2A),
                        border: Border.all(
                          color: const Color(0xFF48D9F3),
                          width: 2,
                        ),
                      ),
                      child: isUpdatingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF48D9F3),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Color(0xFF48D9F3),
                            ),
                    ),
                  ),
                ),
              ),
              if (isUpdatingPhoto)
                Positioned.fill(
                  child: _AvatarShimmer(animation: shimmerAnimation),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: HomeGlassTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        if (displaySubtitle.isNotEmpty)
          Text(
            displaySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HomeGlassTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
