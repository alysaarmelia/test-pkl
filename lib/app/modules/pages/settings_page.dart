import 'dart:async';
import 'dart:ui';

import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/contact_list_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/chat_list_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/profile_page.dart'
    as profile;
import 'package:cipta_vera_mandiri_digital/repositories/settings_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/settings_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/widgets/floating_nav_bar.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_panel.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:get/get.dart';

class SettingsPage extends StatefulWidget {
  final void Function(int)? onMenuSelected;
  final int profileTabIndex;
  final SettingsRepository? repository;
  final bool enableBiometric;

  const SettingsPage({
    super.key,
    this.onMenuSelected,
    this.profileTabIndex =
        BottomNav.profile, // sesuaikan index profil jika berbeda
    this.repository,
    this.enableBiometric = true,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final String _settingsViewModelTag;
  late final SettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _settingsViewModelTag = 'settings-${identityHashCode(this)}';
    _viewModel = Get.put(
      SettingsViewModel(
        enableBiometric: widget.enableBiometric,
        repository: widget.repository ?? SettingsRepositoryImpl(),
      ),
      tag: _settingsViewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<SettingsViewModel>(tag: _settingsViewModelTag)) {
      Get.delete<SettingsViewModel>(tag: _settingsViewModelTag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentUserUid = _viewModel.currentUserUid.value;
      final profileData = _viewModel.profileData.value;
      final profileLoading = _viewModel.profileLoading.value;
      final profileError = _viewModel.profileError.value;
      final requestingNotifications = _viewModel.requestingNotifications.value;
      final signingOut = _viewModel.signingOut.value;
      final biometricSupported = _viewModel.biometricSupported.value;
      final biometricOptIn = _viewModel.biometricOptIn.value;
      final biometricBusy = _viewModel.biometricBusy.value;
      final biometricHasCreds = _viewModel.biometricHasCreds.value;
      final biometricPlatformSupported = _viewModel.biometricPlatformSupported;

      return Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Container(
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
                top: -140,
                left: -100,
                diameter: 320,
                colors: HomeGlassTheme.orbBlue,
              ),
              HomeGlassTheme.orb(
                top: 260,
                right: -160,
                diameter: 380,
                colors: HomeGlassTheme.orbPurple,
              ),
              HomeGlassTheme.orb(
                bottom: -220,
                left: 0,
                diameter: 420,
                colors: HomeGlassTheme.orbMint,
              ),
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengaturan',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: HomeGlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (currentUserUid == null || currentUserUid.isEmpty)
                        _buildProfileSection(null, 'Guest', 'Tidak masuk')
                      else if (profileLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (profileError != null)
                        _buildProfileSection(
                          null,
                          'User',
                          'Role tidak tersedia',
                        )
                      else
                        _buildProfileSection(
                          profileData?.photoUrl,
                          profileData?.displayName ?? 'Nama Tidak Ditemukan',
                          profileData?.role ?? 'Role belum ditentukan',
                        ),
                      const SizedBox(height: 26),
                      _GlassSection(
                        children: [
                          _settingsTile(
                            icon: Icons.contacts_outlined,
                            text: 'Kontak',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContactListPage(),
                                ),
                              );
                            },
                            isFirst: true,
                            isLast: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _GlassSection(
                        children: [
                          _settingsTile(
                            icon: Icons.person_outline,
                            text: 'Profil',
                            onTap: _navigateToProfile,
                            isFirst: true,
                          ),
                          _divider(),
                          _settingsTile(
                            icon: Icons.chat_bubble_outline,
                            text: 'Chat',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChatListPage(),
                                ),
                              );
                            },
                          ),
                          _divider(),
                          _settingsTile(
                            icon: Icons.notifications_none,
                            text: 'Pemberitahuan',
                            onTap: requestingNotifications
                                ? null
                                : () => _handleNotificationTap(),
                            trailing: requestingNotifications
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                            isLast: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (biometricPlatformSupported) ...[
                        _GlassSection(
                          children: [
                            _settingsTile(
                              icon: Icons.fingerprint_outlined,
                              text: 'Aktifkan Biometric ID',
                              onTap: (!biometricSupported || biometricBusy)
                                  ? null
                                  : () => _toggleBiometric(!biometricOptIn),
                              trailing: Switch(
                                value: biometricSupported && biometricOptIn,
                                onChanged:
                                    (biometricSupported && !biometricBusy)
                                    ? (value) => _toggleBiometric(value)
                                    : null,
                                activeColor: Colors.white,
                                activeTrackColor: Colors.lightBlueAccent
                                    .withOpacity(0.6),
                                inactiveThumbColor: Colors.white70,
                              ),
                              isFirst: true,
                              isLast: true,
                            ),
                            if (!biometricSupported)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  0,
                                  18,
                                  14,
                                ),
                                child: Text(
                                  'Biometric ID tidak tersedia pada perangkat ini.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (biometricOptIn &&
                                biometricSupported &&
                                !biometricHasCreds)
                              const SizedBox.shrink(),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      _GlassSection(
                        children: [
                          _settingsTile(
                            icon: Icons.language,
                            text: 'Website',
                            onTap: () {},
                            isFirst: true,
                          ),
                          _divider(),
                          _settingsTile(
                            icon: Icons.logout,
                            text: 'Log Out',
                            onTap: signingOut ? null : () => _handleLogout(),
                            trailing: signingOut
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                            isLast: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _toggleBiometric(bool enable) async {
    final feedback = await _viewModel.toggleBiometric(enable);
    if (!mounted) return;
    _showFeedback(feedback);
  }

  Future<void> _handleNotificationTap() async {
    final feedback = await _viewModel.requestNotificationAccess();
    if (!mounted) return;
    _showFeedback(feedback);
    if (feedback.openSystemSettings) {
      await openAppSettings();
    }
  }

  void _showFeedback(SettingsFeedback feedback) {
    if (feedback.type == SettingsFeedbackType.none ||
        feedback.message.isEmpty) {
      return;
    }
    showGlassSnackBar(
      context,
      message: feedback.message,
      tone: _toGlassTone(feedback.type),
    );
  }

  GlassSnackTone _toGlassTone(SettingsFeedbackType type) {
    switch (type) {
      case SettingsFeedbackType.success:
        return GlassSnackTone.success;
      case SettingsFeedbackType.info:
        return GlassSnackTone.info;
      case SettingsFeedbackType.warning:
        return GlassSnackTone.warning;
      case SettingsFeedbackType.error:
        return GlassSnackTone.error;
      case SettingsFeedbackType.none:
        return GlassSnackTone.info;
    }
  }

  void _navigateToProfile() {
    if (widget.onMenuSelected != null) {
      widget.onMenuSelected!(widget.profileTabIndex);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const profile.ProfilePage()),
    );
  }

  void _showMyQrDialog() {
    final pin = _viewModel.profilePin.value;
    if (pin == null || pin.isEmpty) {
      showGlassSnackBar(
        context,
        message: 'PIN belum tersedia. Pastikan profil sudah lengkap.',
        tone: GlassSnackTone.warning,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 5, 24, 21),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                border: Border.all(
                  width: 1.2,
                  color: Colors.white.withOpacity(0.100),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.22),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PIN Saya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: QrImageView(
                        data: pin,
                        version: QrVersions.auto,
                        size: 220,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      pin,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bagikan PIN atau kode QR ini agar rekan dapat menambah Anda ke kontak.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.white.withOpacity(0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    if (_viewModel.signingOut.value) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.45),
          builder: (context) {
            return Center(
              child: GlassPanel(
                enableBlur: true,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                borderRadius: BorderRadius.circular(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Keluar Akun',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Anda yakin ingin keluar dari akun ini?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.white.withOpacity(0.15),
                              ),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: const Color(0xFFE11D48),
                              ),
                              child: const Text('Keluar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      final feedback = await _viewModel.logout();
      if (!mounted) return;
      if (feedback.type == SettingsFeedbackType.error) {
        _showFeedback(feedback);
        return;
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.SPLASH, (route) => false);
    } catch (error) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal logout: $error',
        tone: GlassSnackTone.error,
      );
    }
  }

  Widget _buildProfileSection(String? photoUrl, String name, String role) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigateToProfile,
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withOpacity(0.08),
            highlightColor: Colors.white.withOpacity(0.04),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              decoration: BoxDecoration(
                color: HomeGlassTheme.surfaceStrong,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: HomeGlassTheme.surfaceBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(4, 12, 28, 0.26),
                    offset: Offset(0, 18),
                    blurRadius: 36,
                    spreadRadius: -16,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: HomeGlassTheme.surfaceBorder.withOpacity(0.9),
                      ),
                      color: Colors.white.withOpacity(hasPhoto ? 0.04 : 0.12),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                      child: !hasPhoto
                          ? const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 32,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: HomeGlassTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (role.isNotEmpty)
                          Text(
                            role,
                            style: const TextStyle(
                              color: HomeGlassTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Material(
                        color: Colors.white.withOpacity(0.12),
                        child: InkWell(
                          onTap: _showMyQrDialog,
                          borderRadius: BorderRadius.circular(16),
                          splashColor: Colors.white.withOpacity(0.12),
                          highlightColor: Colors.white.withOpacity(0.08),
                          child: const SizedBox(
                            height: 48,
                            width: 48,
                            child: Icon(
                              Icons.qr_code_2_outlined,
                              color: HomeGlassTheme.textSecondary,
                              size: 28,
                            ),
                          ),
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
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: HomeGlassTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomeGlassTheme.surfaceBorder),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}

Widget _settingsTile({
  required IconData icon,
  required String text,
  required VoidCallback? onTap,
  bool isFirst = false,
  bool isLast = false,
  Widget? trailing,
  Widget? subtitle,
}) {
  final enabled = onTap != null;
  final iconColor = enabled
      ? HomeGlassTheme.textSecondary
      : HomeGlassTheme.textSecondary.withOpacity(0.4);
  final textColor = enabled
      ? HomeGlassTheme.textPrimary
      : HomeGlassTheme.textPrimary.withOpacity(0.45);
  final shape = (isFirst || isLast)
      ? RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
        )
      : null;

  return ListTile(
    leading: Icon(icon, color: iconColor),
    title: Text(
      text,
      style: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: subtitle,
    trailing:
        trailing ?? Icon(Icons.arrow_forward_ios, color: iconColor, size: 18),
    onTap: onTap,
    enabled: enabled,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    shape: shape,
    dense: true,
    horizontalTitleGap: 14,
    minLeadingWidth: 0,
  );
}

Widget _divider() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 18),
    height: 1,
    color: HomeGlassTheme.textSecondary.withOpacity(0.18),
  );
}
