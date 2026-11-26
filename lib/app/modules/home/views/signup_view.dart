import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cipta_vera_mandiri_digital/app/constants/assets.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_credentials_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_credentials_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_panel.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SignupView extends StatefulWidget {
  final VoidCallback onLoginTap;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onSignupTap;
  final AuthCredentialsRepository? repository;
  final AuthCredentialsViewModel? viewModel;
  const SignupView({
    super.key,
    required this.onLoginTap,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onSignupTap,
    this.repository,
    this.viewModel,
  });

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  late final AuthCredentialsViewModel _authViewModel;
  late final String _viewModelTag;
  static const Duration _layoutAnimationDuration = Duration(milliseconds: 360);
  static const Curve _layoutAnimationCurve = Curves.easeOutCubic;
  static const Curve _layoutAnimationReverseCurve = Curves.easeInOutCubic;

  bool _obscurePassword = true;
  bool _loading = false;
  late final AssetImage _logoImage = const AssetImage(AppAssets.cvmLogo);
  bool _logoCached = false;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'signup-auth-${identityHashCode(this)}';
    _authViewModel = Get.put(
        widget.viewModel ??
            AuthCredentialsViewModel(
              repository: widget.repository ?? AuthCredentialsRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<AuthCredentialsViewModel>(tag: _viewModelTag)) {
      Get.delete<AuthCredentialsViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_logoCached) {
      precacheImage(_logoImage, context);
      _logoCached = true;
    }
  }

  Future<void> _handleSignup() async {
    final username = widget.usernameController.text.trim();
    final email = widget.emailController.text.trim();
    final pass = widget.passwordController.text.trim();
    final confirm = widget.confirmPasswordController.text.trim();

    String? error;
    if (username.isEmpty)
      error = 'Username wajib diisi';
    else if (email.isEmpty)
      error = 'Email wajib diisi';
    else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email))
      error = 'Format email tidak valid';
    else if (pass.length < 6)
      error = 'Password minimal 6 karakter';
    else if (pass != confirm)
      error = 'Konfirmasi password tidak sama';

    if (error != null) {
      if (!mounted) return;
      showGlassSnackBar(context, message: error, tone: GlassSnackTone.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      final signupResult = await _authViewModel.signup(
        username: username,
        email: email,
        password: pass,
      );
      if (signupResult.status == SignupFlowStatus.authError) {
        String msg = 'Gagal membuat akun';
        switch (signupResult.authErrorCode) {
          case 'email-already-in-use':
            msg = 'Email sudah terdaftar';
            break;
          case 'invalid-email':
            msg = 'Email tidak valid';
            break;
          case 'weak-password':
            msg = 'Password terlalu lemah';
            break;
          case 'operation-not-allowed':
            msg = 'Metode email/password belum diaktifkan di Firebase Console';
            break;
        }
        if (!mounted) return;
        showGlassSnackBar(context, message: msg, tone: GlassSnackTone.error);
        return;
      }
      if (signupResult.status == SignupFlowStatus.failure) {
        if (!mounted) return;
        showGlassSnackBar(
          context,
          message:
              'Terjadi kesalahan: ${signupResult.message ?? 'Unknown error'}',
          tone: GlassSnackTone.error,
        );
        return;
      }
      if (signupResult.verificationWarningMessage != null &&
          signupResult.verificationWarningMessage!.isNotEmpty &&
          mounted) {
        showGlassSnackBar(
          context,
          message: signupResult.verificationWarningMessage!,
          tone: GlassSnackTone.warning,
        );
      }

      if (!mounted) return;
      // Tampilkan modal verifikasi agar user bisa resend & cek status
      // Jangan langsung ke login—tahan di modal hingga verified
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setStateSheet) {
                bool _sheetAlive = true;
                int resendCooldown = 0; // detik
                Timer? cooldownTimer;
                void startCooldown(int seconds) {
                  resendCooldown = seconds;
                  if (ctx.mounted && _sheetAlive) setStateSheet(() {});
                  cooldownTimer?.cancel();
                  cooldownTimer = Timer.periodic(const Duration(seconds: 1), (
                    t,
                  ) {
                    if (!ctx.mounted || !_sheetAlive) {
                      t.cancel();
                      return;
                    }
                    if (resendCooldown <= 1) {
                      t.cancel();
                      resendCooldown = 0;
                    } else {
                      resendCooldown -= 1;
                    }
                    if (ctx.mounted && _sheetAlive) setStateSheet(() {});
                  });
                }

                bool localLoading = false;
                final emailShown = _authViewModel.currentUserEmail ?? email;
                return WillPopScope(
                  onWillPop: () async {
                    cooldownTimer?.cancel();
                    _sheetAlive = false;
                    return true;
                  },
                  child: GlassPanel(
                    enableBlur: true,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    padding: EdgeInsets.zero,
                    shadows: const [],
                    child: DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.3,
                      minChildSize: 0.2,
                      maxChildSize: 0.6,
                      builder: (context, scrollController) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Center(
                                  child: SizedBox(
                                    width: 40,
                                    child: Divider(thickness: 4),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Verifikasi Email',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Kami mengirim email verifikasi ke:\n$emailShown',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GlassPanel(
                                        opacity: 0.25,
                                        borderRadius: BorderRadius.circular(20),
                                        shadows: const [],
                                        child: TextButton(
                                          onPressed:
                                              (localLoading ||
                                                  resendCooldown > 0)
                                              ? null
                                              : () async {
                                                  try {
                                                    if (ctx.mounted &&
                                                        _sheetAlive) {
                                                      setStateSheet(
                                                        () =>
                                                            localLoading = true,
                                                      );
                                                    }
                                                    final resendResult =
                                                        await _authViewModel
                                                            .resendVerificationEmail();
                                                    if (!mounted) return;
                                                    if (resendResult.status ==
                                                        SignupVerificationStatus
                                                            .success) {
                                                      showGlassSnackBar(
                                                        context,
                                                        message: resendResult
                                                            .message,
                                                        tone: GlassSnackTone
                                                            .success,
                                                      );
                                                      startCooldown(60);
                                                    } else if (resendResult
                                                            .status ==
                                                        SignupVerificationStatus
                                                            .warning) {
                                                      showGlassSnackBar(
                                                        context,
                                                        message: resendResult
                                                            .message,
                                                        tone: GlassSnackTone
                                                            .warning,
                                                      );
                                                      startCooldown(60);
                                                    } else {
                                                      showGlassSnackBar(
                                                        context,
                                                        message: resendResult
                                                            .message,
                                                        tone: GlassSnackTone
                                                            .error,
                                                      );
                                                      startCooldown(90);
                                                    }
                                                  } finally {
                                                    if (ctx.mounted &&
                                                        _sheetAlive) {
                                                      setStateSheet(
                                                        () => localLoading =
                                                            false,
                                                      );
                                                    }
                                                  }
                                                },
                                          child: localLoading
                                              ? const SizedBox(
                                                  height: 16,
                                                  width: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Text(
                                                  resendCooldown > 0
                                                      ? 'Kirim Ulang (${resendCooldown}s)'
                                                      : 'Kirim Ulang',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GlassPanel(
                                        opacity: 0.25,
                                        borderRadius: BorderRadius.circular(20),
                                        shadows: const [],
                                        child: TextButton(
                                          onPressed: localLoading
                                              ? null
                                              : () async {
                                                  final verified =
                                                      await _authViewModel
                                                          .reloadAndCheckEmailVerified();
                                                  if (verified) {
                                                    cooldownTimer?.cancel();
                                                    _sheetAlive = false;
                                                    if (Navigator.of(
                                                      ctx,
                                                    ).canPop()) {
                                                      Navigator.of(ctx).pop();
                                                    }
                                                    widget.onLoginTap();
                                                  } else {
                                                    if (mounted) {
                                                      showGlassSnackBar(
                                                        context,
                                                        message:
                                                            'Belum terverifikasi. Cek email & klik tautannya.',
                                                        tone: GlassSnackTone
                                                            .warning,
                                                      );
                                                    }
                                                  }
                                                },
                                          child: const Text(
                                            'Saya Sudah Verifikasi',
                                            style: TextStyle(
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const SizedBox(height: 16),
                                const Text(
                                  'Tips: cek folder Spam/Promotions jika belum masuk.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Terjadi kesalahan: $e',
        tone: GlassSnackTone.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: HomeGlassTheme.background(
          child: AnimatedPadding(
            duration: _layoutAnimationDuration,
            curve: _layoutAnimationCurve,
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isKeyboardVisible = media.viewInsets.bottom > 0;
                  final isCompactHeight = constraints.maxHeight < 760;
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 20.0
                      : 32.0;
                  final topPadding = isKeyboardVisible
                      ? 16.0
                      : (isCompactHeight ? 22.0 : 44.0);
                  final bottomPadding = isKeyboardVisible
                      ? 16.0
                      : (isCompactHeight ? 24.0 : 40.0);
                  double fieldSpacing = isCompactHeight ? 8.0 : 16.0;
                  double blockSpacing = isCompactHeight ? 12.0 : 24.0;
                  double buttonHeight = isCompactHeight ? 48.0 : 52.0;
                  final bool isVeryCompact = constraints.maxHeight < 560;
                  final double baseLogoHeight = constraints.maxHeight.isFinite
                      ? (constraints.maxHeight * 0.18)
                            .clamp(56.0, isCompactHeight ? 88.0 : 108.0)
                            .toDouble()
                      : (isCompactHeight ? 88.0 : 108.0);
                  final double logoHeight = isVeryCompact
                      ? baseLogoHeight.clamp(54.0, 72.0)
                      : baseLogoHeight;
                  final double titleFontSize = isVeryCompact
                      ? 16
                      : (isCompactHeight ? 20 : 22);

                  if (isVeryCompact) {
                    fieldSpacing = 6.0;
                    blockSpacing = 10.0;
                    buttonHeight = 46.0;
                  }

                  final bool showFooter =
                      !isKeyboardVisible &&
                      !isVeryCompact &&
                      constraints.maxHeight > 620;
                  final logoSection = _buildLogoSection(
                    logoHeight,
                    fieldSpacing,
                    titleFontSize,
                  );
                  final formSection = _buildFormSection(
                    fieldSpacing,
                    blockSpacing,
                    buttonHeight,
                  );
                  final poweredBySection = _buildPoweredByFooter();
                  final alignment = (isKeyboardVisible || isVeryCompact)
                      ? Alignment.topCenter
                      : Alignment.center;
                  final physics = (isKeyboardVisible || isVeryCompact)
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics();

                  final contentChildren = <Widget>[
                    logoSection,
                    SizedBox(height: blockSpacing),
                    formSection,
                  ];

                  return Column(
                    children: [
                      Expanded(
                        child: AnimatedPadding(
                          duration: _layoutAnimationDuration,
                          curve: _layoutAnimationCurve,
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            topPadding,
                            horizontalPadding,
                            showFooter ? blockSpacing : bottomPadding,
                          ),
                          child: SingleChildScrollView(
                            physics: physics,
                            child: AnimatedAlign(
                              duration: _layoutAnimationDuration,
                              curve: _layoutAnimationCurve,
                              alignment: alignment,
                              child: RepaintBoundary(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: contentChildren,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: _layoutAnimationDuration,
                        switchInCurve: _layoutAnimationCurve,
                        switchOutCurve: _layoutAnimationReverseCurve,
                        child: showFooter
                            ? Padding(
                                key: const ValueKey('footer-visible'),
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  0,
                                  horizontalPadding,
                                  bottomPadding,
                                ),
                                child: poweredBySection,
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('footer-hidden'),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupButton(double height) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: GlassPanel(
        opacity: 0.30,
        borderRadius: BorderRadius.circular(30),
        shadows: const [],
        child: TextButton(
          onPressed: _loading ? null : _handleSignup,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(
    double logoHeight,
    double spacing,
    double titleFontSize,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: _layoutAnimationDuration,
          curve: _layoutAnimationCurve,
          height: logoHeight,
          width: logoHeight,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: RepaintBoundary(
            child: Image(
              image: _logoImage,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
        AnimatedContainer(
          duration: _layoutAnimationDuration,
          curve: _layoutAnimationCurve,
          height: spacing,
        ),
        AnimatedDefaultTextStyle(
          duration: _layoutAnimationDuration,
          curve: _layoutAnimationCurve,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: titleFontSize,
            color: Colors.white,
            height: 1.3,
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "CIPTA VERA MANDIRI\nDIGITAL",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(
    double fieldSpacing,
    double blockSpacing,
    double buttonHeight,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextField("Username", Icons.person, widget.usernameController),
        SizedBox(height: fieldSpacing),
        _buildTextField("Email", Icons.email, widget.emailController),
        SizedBox(height: fieldSpacing),
        _buildPasswordField(),
        SizedBox(height: fieldSpacing),
        _buildConfirmPasswordField(),
        SizedBox(height: blockSpacing),
        _buildSignupButton(buttonHeight),
        SizedBox(height: fieldSpacing),
        _buildLoginLink(),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        const Text(
          "Already have an account?",
          style: TextStyle(color: Colors.white),
        ),
        GestureDetector(
          onTap: widget.onLoginTap,
          child: const Text(
            "Login",
            style: TextStyle(
              color: Color.fromARGB(255, 46, 121, 251),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoweredByFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Powered by',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
              child: Image(
                image: _logoImage,
                height: 18,
                filterQuality: FilterQuality.low,
              ),
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
    );
  }

  Widget _buildTextField(
    String hint,
    IconData icon,
    TextEditingController ctrl,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: hint.toLowerCase() == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: widget.passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        hintText: "Password",
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.lock, color: Colors.white),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: widget.confirmPasswordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        hintText: "Confirm Password",
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.lock, color: Colors.white),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
