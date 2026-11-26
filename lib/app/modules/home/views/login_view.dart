import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cipta_vera_mandiri_digital/app/constants/assets.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_credentials_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_credentials_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_panel.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/app/services/biometric_auth_service.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

class LoginView extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onSignUpTap;
  final VoidCallback onLoginSuccess;
  final AuthCredentialsRepository? repository;
  final AuthCredentialsViewModel? viewModel;

  const LoginView({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.onSignUpTap,
    required this.onLoginSuccess,
    this.repository,
    this.viewModel,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

enum _LoginMethod { manual, biometric }

class _LoginViewState extends State<LoginView> {
  late final AuthCredentialsViewModel _authViewModel;
  late final String _viewModelTag;
  static const Duration _layoutAnimationDuration = Duration(milliseconds: 360);
  static const Curve _layoutAnimationCurve = Curves.easeOutCubic;
  static const Curve _layoutAnimationReverseCurve = Curves.easeInOutCubic;

  bool _obscurePassword = true;
  bool _loading = false;
  late final AssetImage _logoImage = const AssetImage(AppAssets.cvmLogo);
  bool _logoCached = false;
  bool _biometricAvailable = false;
  bool _biometricInProgress = false;
  bool _biometricOptedIn = true;
  final BiometricAuthService _biometricService = BiometricAuthService();

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'login-auth-${identityHashCode(this)}';
    _authViewModel = Get.put(
        widget.viewModel ??
            AuthCredentialsViewModel(
              repository: widget.repository ?? AuthCredentialsRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
    _prepareBiometricAvailability();
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

  Future<void> _prepareBiometricAvailability() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    try {
      final optIn = await _biometricService.isOptInEnabled();
      final available = optIn && await _biometricService.canUseBiometricLogin();
      if (mounted) {
        setState(() {
          _biometricAvailable = available;
          _biometricOptedIn = optIn;
        });
      }
    } catch (e) {
      debugPrint('Biometric availability check failed: $e');
    }
  }

  Future<void> _handleLogin() async {
    final email = widget.usernameController.text.trim();
    final pass = widget.passwordController.text.trim();

    // Validasi sederhana
    if (email.isEmpty || pass.isEmpty) {
      showGlassSnackBar(
        context,
        message: 'Email dan password wajib diisi',
        tone: GlassSnackTone.warning,
      );
      return;
    }
    final emailOk = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
    if (!emailOk) {
      showGlassSnackBar(
        context,
        message: 'Format email tidak valid',
        tone: GlassSnackTone.warning,
      );
      return;
    }

    await _loginWithCredentials(
      email: email,
      password: pass,
      method: _LoginMethod.manual,
    );
  }

  Future<void> _loginWithCredentials({
    required String email,
    required String password,
    required _LoginMethod method,
  }) async {
    setState(() => _loading = true);
    try {
      final result = await _authViewModel.login(
        email: email,
        password: password,
      );
      switch (result.status) {
        case LoginFlowStatus.emailNotVerified:
          if (!mounted) return;
          showGlassSnackBar(
            context,
            message:
                'Email belum diverifikasi. Cek inbox/spam dan verifikasi dulu.',
            tone: GlassSnackTone.warning,
          );
          return;
        case LoginFlowStatus.success:
          if (Platform.isIOS || Platform.isAndroid) {
            final optIn = await _biometricService.isOptInEnabled();
            if (optIn) {
              await _biometricService.saveCredentials(
                email: email,
                password: password,
              );
            }
            await _prepareBiometricAvailability();
          }
          if (!mounted) return;
          if (!result.profileCompleted) {
            Navigator.pushReplacementNamed(context, Routes.COMPLETE_PROFILE);
            return;
          }
          widget.onLoginSuccess();
          return;
        case LoginFlowStatus.authError:
          String msg = 'Gagal login';
          switch (result.authErrorCode) {
            case 'user-not-found':
              msg = 'Akun tidak ditemukan';
              if (method == _LoginMethod.biometric) {
                await _biometricService.clearCredentials();
                await _prepareBiometricAvailability();
              }
              break;
            case 'wrong-password':
              msg = 'Password salah';
              if (method == _LoginMethod.biometric) {
                msg =
                    'Sesi Face ID sudah tidak valid. Login manual lalu aktifkan lagi.';
                await _biometricService.clearCredentials();
                await _prepareBiometricAvailability();
              }
              break;
            case 'invalid-credential':
              msg = 'Email atau password salah';
              break;
            case 'invalid-email':
              msg = 'Email tidak valid';
              break;
            case 'too-many-requests':
              msg = 'Terlalu banyak percobaan. Coba lagi nanti.';
              break;
          }
          if (mounted) {
            showGlassSnackBar(
              context,
              message: msg,
              tone: GlassSnackTone.error,
            );
          }
          return;
        case LoginFlowStatus.failure:
          if (mounted) {
            showGlassSnackBar(
              context,
              message: 'Terjadi kesalahan: ${result.message ?? 'Unknown'}',
              tone: GlassSnackTone.error,
            );
          }
          return;
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(
          context,
          message: 'Terjadi kesalahan: $e',
          tone: GlassSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_loading || _biometricInProgress) return;
    setState(() => _biometricInProgress = true);

    try {
      final creds = await _biometricService.authenticateAndGetCredentials(
        reason: Platform.isIOS
            ? 'Gunakan Face ID untuk login'
            : 'Gunakan sidik jari untuk login',
      );
      if (creds == null) {
        if (mounted) {
          showGlassSnackBar(
            context,
            message:
                'Face ID dibatalkan atau belum diaktifkan. Login manual dulu.',
            tone: GlassSnackTone.warning,
          );
        }
        return;
      }

      await _loginWithCredentials(
        email: creds.email,
        password: creds.password,
        method: _LoginMethod.biometric,
      );
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(
          context,
          message: 'Face ID gagal: $e',
          tone: GlassSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _biometricInProgress = false);
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
                      : (isCompactHeight ? 28.0 : 45.0);
                  final bottomPadding = isKeyboardVisible
                      ? 16.0
                      : (isCompactHeight ? 24.0 : 40.0);
                  double fieldSpacing = isCompactHeight ? 10.0 : 15.0;
                  double blockSpacing = isCompactHeight ? 14.0 : 40.0;
                  double buttonHeight = isCompactHeight ? 48.0 : 60.0;
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
                  double buttonSpacing =
                      blockSpacing + (isCompactHeight ? 18.0 : 36.0);
                  if (isVeryCompact) {
                    buttonSpacing = blockSpacing + 12.0;
                  }
                  final formSection = _buildFormSection(
                    fieldSpacing,
                    buttonSpacing,
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
                                    maxWidth: 420,
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

  Widget _buildEmailField() {
    return TextField(
      controller: widget.usernameController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        hintText: 'Username',
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.person, color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
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
        hintText: 'Password',
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
          borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.0)),
        ),
      ),
    );
  }

  Widget _buildLoginButton(double height) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: GlassPanel(
        opacity: 0.30,
        borderRadius: BorderRadius.circular(30),
        shadows: const [],
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            shadowColor: Colors.transparent,
            elevation: 0,
          ),
          onPressed: _loading ? null : _handleLogin,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _loading
                ? Shimmer.fromColors(
                    baseColor: Colors.white.withOpacity(0.4),
                    highlightColor: Colors.white,
                    child: const Text(
                      "Memproses...",
                      key: ValueKey('login-loading'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 1.1,
                      ),
                    ),
                  )
                : const Text(
                    "Login",
                    key: ValueKey('login-text'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton(double height) {
    final bool disabled =
        _loading || _biometricInProgress || !_biometricAvailable;
    final String label = Platform.isIOS
        ? 'Login dengan Face ID'
        : 'Login dengan sidik jari';
    final IconData icon = Platform.isIOS
        ? Icons.face_retouching_natural_rounded
        : Icons.fingerprint_rounded;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: GlassPanel(
        opacity: 0.22,
        borderRadius: BorderRadius.circular(30),
        shadows: const [],
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            shadowColor: Colors.transparent,
            elevation: 0,
          ),
          onPressed: disabled ? null : _handleBiometricLogin,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _biometricInProgress
                ? Row(
                    key: const ValueKey('biometric-loading'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      _BiometricWaitingLabel(),
                    ],
                  )
                : Row(
                    key: const ValueKey('biometric-ready'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _disabledBiometricText() {
    if (!(Platform.isIOS || Platform.isAndroid)) return '';
    if (!_biometricOptedIn) {
      return Platform.isIOS
          ? 'Face ID dinonaktifkan. Aktifkan kembali di menu Pengaturan.'
          : 'Sidik jari dinonaktifkan. Aktifkan kembali di menu Pengaturan.';
    }
    return Platform.isIOS
        ? 'Login manual sekali untuk mengaktifkan Face ID di perangkat ini.'
        : 'Login manual sekali untuk mengaktifkan sidik jari di perangkat ini.';
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
    final double forgotSpacing = fieldSpacing <= 8 ? 4.0 : 8.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildEmailField(),
        SizedBox(height: fieldSpacing),
        _buildPasswordField(),
        SizedBox(height: forgotSpacing),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Get.toNamed(Routes.FORGOT_PASSWORD);
            },
            child: const Text(
              'Lupa password?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(height: blockSpacing),
        _buildLoginButton(buttonHeight),
        if ((Platform.isIOS || Platform.isAndroid) &&
            _biometricOptedIn &&
            (_biometricAvailable || _biometricInProgress)) ...[
          SizedBox(height: fieldSpacing),
          _buildBiometricButton(buttonHeight),
        ],
        if ((Platform.isIOS || Platform.isAndroid) &&
            _biometricOptedIn &&
            !_biometricAvailable &&
            !_biometricInProgress) ...[
          SizedBox(height: fieldSpacing * 0.7),
          Text(
            _disabledBiometricText(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if ((Platform.isIOS || Platform.isAndroid) &&
            !_biometricOptedIn &&
            !_biometricInProgress) ...[
          SizedBox(height: fieldSpacing * 0.7),
          Text(
            _disabledBiometricText(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        SizedBox(height: fieldSpacing),
        _buildSignupLink(),
      ],
    );
  }

  Widget _buildSignupLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        const Text(
          "Don't have an account?",
          style: TextStyle(color: Colors.white),
        ),
        GestureDetector(
          onTap: widget.onSignUpTap,
          child: const Text(
            "Sign up",
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
}

class _BiometricWaitingLabel extends StatelessWidget {
  const _BiometricWaitingLabel();

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    return Text(
      isIOS ? 'Menunggu Face ID...' : 'Menunggu sidik jari...',
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: Colors.white,
      ),
    );
  }
}
