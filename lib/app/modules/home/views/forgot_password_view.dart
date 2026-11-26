import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_credentials_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_credentials_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_panel.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';

enum _ResetStage { requestEmail, verifyingCode, setNewPassword }

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key, this.repository, this.viewModel});

  final AuthCredentialsRepository? repository;
  final AuthCredentialsViewModel? viewModel;

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  late final AuthCredentialsViewModel _authViewModel;
  late final String _viewModelTag;
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _isProcessing = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  _ResetStage _stage = _ResetStage.requestEmail;
  String? _oobCode;
  String? _resetEmail;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'forgot-auth-${identityHashCode(this)}';
    _authViewModel = Get.put(
        widget.viewModel ??
            AuthCredentialsViewModel(
              repository: widget.repository ?? AuthCredentialsRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
    _maybeHandleIncomingLink();
  }

  @override
  void dispose() {
    if (Get.isRegistered<AuthCredentialsViewModel>(tag: _viewModelTag)) {
      Get.delete<AuthCredentialsViewModel>(tag: _viewModelTag, force: true);
    }
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _maybeHandleIncomingLink() {
    final params = Get.parameters;
    if (params.isEmpty) return;
    final code = params['oobCode'];
    final mode = params['mode'];
    if (code != null &&
        code.isNotEmpty &&
        (mode == null || mode == 'resetPassword')) {
      _oobCode = code;
      _stage = _ResetStage.verifyingCode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyCode(code);
      });
    }
  }

  Future<void> _verifyCode(String code) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final result = await _authViewModel.verifyPasswordResetCode(code);
      if (!mounted) return;
      if (result.success && (result.email?.isNotEmpty ?? false)) {
        setState(() {
          _resetEmail = result.email;
          _stage = _ResetStage.setNewPassword;
        });
        showGlassSnackBar(
          context,
          message: 'Kode terverifikasi. Silakan buat password baru.',
          tone: GlassSnackTone.success,
        );
      } else {
        setState(() {
          _stage = _ResetStage.requestEmail;
          _oobCode = null;
        });
        showGlassSnackBar(
          context,
          message: _mapVerifyError(result.code ?? '', result.message),
          tone: GlassSnackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleText;
    final description = _descriptionText;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: HomeGlassTheme.background(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassPanel(
                  enableBlur: true,
                  opacity: 0.32,
                  borderRadius: BorderRadius.circular(30),
                  padding: const EdgeInsets.fromLTRB(26, 32, 26, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        height: 1,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.25),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildStageContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_stage) {
      case _ResetStage.requestEmail:
        return _buildEmailForm();
      case _ResetStage.verifyingCode:
        return _buildVerifyingState();
      case _ResetStage.setNewPassword:
        return _buildNewPasswordForm();
    }
  }

  Widget _buildEmailForm() {
    return KeyedSubtree(
      key: const ValueKey('email-stage'),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _fieldLabel(
              'Alamat email terdaftar',
              subtitle:
                  'Kami akan mengirim tautan aman untuk mengatur ulang password Anda.',
            ),
            TextFormField(
              controller: _emailController,
              enabled: !_isProcessing,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                icon: Icons.mail_outline,
                hintText: 'Email admin atau karyawan',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Email wajib diisi.';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(text)) {
                  return 'Format email tidak valid.';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: _primaryButtonStyle,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isProcessing ? 'Mengirim...' : 'Kirim Tautan Reset',
                ),
                onPressed: _isProcessing ? null : _handleSubmit,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _isProcessing ? null : _handleBack,
                child: const Text(
                  'Kembali ke halaman login',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyingState() {
    return KeyedSubtree(
      key: const ValueKey('verifying-stage'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Memverifikasi tautan reset password...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPasswordForm() {
    return KeyedSubtree(
      key: const ValueKey('password-stage'),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _fieldLabel(
              'Password baru',
              subtitle: 'Gunakan kombinasi huruf, angka, atau simbol.',
            ),
            TextFormField(
              controller: _newPasswordController,
              enabled: !_isProcessing,
              obscureText: _obscureNewPassword,
              style: const TextStyle(color: Colors.white),
              decoration:
                  _inputDecoration(
                    icon: Icons.lock_outline,
                    hintText: 'Password baru',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white,
                      ),
                    ),
                  ),
              validator: (value) {
                final text = value ?? '';
                if (text.length < 6) {
                  return 'Password minimal 6 karakter.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _fieldLabel('Konfirmasi password baru'),
            TextFormField(
              controller: _confirmPasswordController,
              enabled: !_isProcessing,
              obscureText: _obscureConfirmPassword,
              style: const TextStyle(color: Colors.white),
              decoration:
                  _inputDecoration(
                    icon: Icons.lock_reset,
                    hintText: 'Konfirmasi password baru',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white,
                      ),
                    ),
                  ),
              validator: (value) {
                final confirm = value ?? '';
                final newPass = _newPasswordController.text;
                if (confirm.isEmpty) {
                  return 'Konfirmasi password wajib diisi.';
                }
                if (confirm != newPass) {
                  return 'Konfirmasi password tidak sama.';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: _primaryButtonStyle,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isProcessing ? 'Menyimpan...' : 'Simpan Password Baru',
                ),
                onPressed: _isProcessing ? null : _handleConfirmReset,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _isProcessing ? null : _navigateToLogin,
                child: const Text(
                  'Kembali ke halaman login',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle get _primaryButtonStyle {
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFF2563EB),
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  Widget _fieldLabel(String text, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hintText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      hintStyle: const TextStyle(color: Colors.white70),
      hintText: hintText,
      prefixIcon: Icon(icon, color: Colors.white),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() => _isProcessing = true);

    try {
      final result = await _authViewModel.sendPasswordResetEmail(email);
      if (!mounted) return;
      if (result.success) {
        _resetEmail = email;
        showGlassSnackBar(
          context,
          message: 'Tautan reset password telah dikirim. Periksa email Anda.',
          tone: GlassSnackTone.success,
        );
      } else {
        showGlassSnackBar(
          context,
          message: _mapResetError(result.code ?? '', result.message),
          tone: GlassSnackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleConfirmReset() async {
    if (_oobCode == null) {
      showGlassSnackBar(
        context,
        message: 'Kode reset tidak ditemukan. Minta tautan baru.',
        tone: GlassSnackTone.error,
      );
      setState(() {
        _stage = _ResetStage.requestEmail;
      });
      return;
    }

    if (!_passwordFormKey.currentState!.validate()) return;

    final newPassword = _newPasswordController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() => _isProcessing = true);

    try {
      final result = await _authViewModel.confirmPasswordReset(
        code: _oobCode!,
        newPassword: newPassword,
      );
      if (!mounted) return;
      if (result.success) {
        showGlassSnackBar(
          context,
          message:
              'Password berhasil diganti. Silakan login dengan password baru.',
          tone: GlassSnackTone.success,
        );
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        _navigateToLogin();
      } else {
        showGlassSnackBar(
          context,
          message: _mapConfirmError(result.code ?? '', result.message),
          tone: GlassSnackTone.error,
        );
        final code = result.code ?? '';
        if (code == 'expired-action-code' || code == 'invalid-action-code') {
          setState(() {
            _stage = _ResetStage.requestEmail;
            _oobCode = null;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _mapResetError(String code, String? message) {
    switch (code) {
      case 'invalid-email':
        return 'Email tidak valid.';
      case 'missing-email':
        return 'Masukkan email Anda.';
      case 'user-not-found':
        return 'Akun dengan email tersebut tidak ditemukan.';
      case 'user-disabled':
        return 'Akun dinonaktifkan. Hubungi admin.';
      case 'too-many-requests':
        return 'Terlalu banyak permintaan. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Periksa koneksi internet Anda dan coba lagi.';
      default:
        return message ?? 'Gagal mengirim tautan reset.';
    }
  }

  String _mapVerifyError(String code, String? message) {
    switch (code) {
      case 'expired-action-code':
        return 'Tautan reset sudah kedaluwarsa. Minta tautan baru.';
      case 'invalid-action-code':
        return 'Tautan reset tidak valid. Gunakan tautan terbaru dari email.';
      case 'user-disabled':
        return 'Akun dinonaktifkan. Hubungi admin.';
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      default:
        return message ?? 'Gagal memverifikasi tautan reset.';
    }
  }

  String _mapConfirmError(String code, String? message) {
    switch (code) {
      case 'expired-action-code':
        return 'Tautan reset kedaluwarsa. Minta tautan baru dan coba lagi.';
      case 'invalid-action-code':
        return 'Tautan reset tidak valid. Kirim ulang tautan reset.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      default:
        return message ?? 'Gagal menyimpan password baru.';
    }
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Get.offAllNamed(Routes.LOGIN);
  }

  String get _titleText {
    switch (_stage) {
      case _ResetStage.setNewPassword:
        return 'Buat Password Baru';
      default:
        return 'Reset Password';
    }
  }

  String get _descriptionText {
    switch (_stage) {
      case _ResetStage.requestEmail:
        return 'Masukkan email yang terdaftar. Kami akan mengirim tautan untuk mengatur ulang password Anda.';
      case _ResetStage.verifyingCode:
        return 'Memverifikasi tautan reset password Anda...';
      case _ResetStage.setNewPassword:
        final targetEmail = _resetEmail ?? 'akun Anda';
        return 'Masukkan password baru untuk $targetEmail. Pastikan Anda mengingatnya.';
    }
  }
}
