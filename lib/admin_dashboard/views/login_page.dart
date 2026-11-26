import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:cipta_vera_mandiri_digital/app/services/biometric_auth_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/web_authn_support.dart';
import 'package:cipta_vera_mandiri_digital/app/services/web_authn_login_manager.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({
    super.key,
    required this.onAuthenticate,
    required this.onForgotPassword,
    this.isBusy = false,
    this.errorMessage,
  });

  final Future<void> Function(String email, String password) onAuthenticate;
  final Future<void> Function(String email) onForgotPassword;
  final bool isBusy;
  final String? errorMessage;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _biometricAvailable = false;
  bool _biometricBusy = false;
  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _webAuthnBusy = false;
  bool _webAuthnSupported = false;
  bool _webAuthnHasCredential = false;
  final WebAuthnSupport _webAuthnSupport = createWebAuthnSupport();
  final WebAuthnLoginManager _webAuthnManager = createWebAuthnLoginManager();
  late final AnimationController _shimmerController;

  bool get _biometricSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminLoginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear only the password field after a failed login while keeping email intact.
    if (widget.errorMessage != null &&
        widget.errorMessage != oldWidget.errorMessage) {
      _passwordCtrl.clear();
    }
    if (widget.isBusy && !oldWidget.isBusy) {
      _shimmerController.repeat();
    } else if (!widget.isBusy && oldWidget.isBusy) {
      _shimmerController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF070E1A),
                  Color(0xFF132347),
                  Color(0xFF1C2F58),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -90,
            left: -70,
            child: const _BlurOrb(
              size: 240,
              colors: [
                Color.fromARGB(38, 255, 255, 255),
                Color.fromARGB(33, 173, 216, 230),
              ],
            ),
          ),
          Positioned(
            bottom: -70,
            right: -40,
            child: const _BlurOrb(
              size: 280,
              colors: [
                Color.fromARGB(35, 216, 191, 216),
                Color.fromARGB(25, 135, 206, 250),
              ],
            ),
          ),
          Positioned(
            bottom: 110,
            left: 40,
            child: const _BlurOrb(
              size: 130,
              colors: [
                Color.fromARGB(28, 255, 255, 255),
                Color.fromARGB(28, 224, 255, 255),
              ],
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.32),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 32,
                          offset: const Offset(0, 26),
                          spreadRadius: -14,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 54,
                                    child: Image.asset(
                                      'lib/app/assets/images/cvm.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Cipta Vera Mandiri Digital',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final header = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Masuk Admin',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Kelola absensi, cuti, dan izin dalam satu dasbor.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                );

                                if (constraints.maxWidth < 360) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [header],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [Expanded(child: header)],
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _emailCtrl,
                              style: const TextStyle(color: Colors.white),
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                theme,
                                label: 'Email',
                                icon: Icons.mail_outline,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Masukkan email admin.';
                                }
                                if (!value.contains('@')) {
                                  return 'Format email tidak valid.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _passwordCtrl,
                              style: const TextStyle(color: Colors.white),
                              textInputAction: TextInputAction.done,
                              obscureText: _obscure,
                              decoration:
                                  _inputDecoration(
                                    theme,
                                    label: 'Kata sandi',
                                    icon: Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Masukkan kata sandi.';
                                }
                                if (value.length < 6) {
                                  return 'Minimal 6 karakter.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: widget.isBusy
                                    ? null
                                    : _showForgotPasswordDialog,
                                child: const Text('Lupa kata sandi?'),
                              ),
                            ),
                            if (widget.errorMessage != null) ...[
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.errorMessage!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.error,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: _GlassButton(
                                enabled: !widget.isBusy,
                                onPressed: widget.isBusy ? null : _submit,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: widget.isBusy
                                      ? Padding(
                                          key: const ValueKey('btn-shimmer'),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: _ShimmerBar(
                                            animation: _shimmerController,
                                            height: 18,
                                            width: double.infinity,
                                            borderRadius: 10,
                                          ),
                                        )
                                      : Row(
                                          key: const ValueKey('btn-normal'),
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.login_rounded),
                                            SizedBox(width: 10),
                                            Text('Masuk'),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            if (_biometricSupportedPlatform) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _biometricBusy
                                        ? const SizedBox(
                                            key: ValueKey('bio-loading'),
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.fingerprint_rounded,
                                            key: ValueKey('bio-ready'),
                                          ),
                                  ),
                                  label: Text(
                                    defaultTargetPlatform == TargetPlatform.iOS
                                        ? 'Masuk dengan Face ID'
                                        : defaultTargetPlatform ==
                                              TargetPlatform.macOS
                                        ? 'Masuk dengan Touch ID'
                                        : 'Masuk dengan sidik jari',
                                  ),
                                  onPressed:
                                      (_biometricAvailable &&
                                          !_biometricBusy &&
                                          !widget.isBusy)
                                      ? _handleBiometricLogin
                                      : null,
                                ),
                              ),
                              if (!_biometricAvailable && !_biometricBusy)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    left: 4,
                                  ),
                                  child: Text(
                                    'Aktifkan login biometrik dengan login manual sekali di perangkat ini.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                            ],
                            if (kIsWeb) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _webAuthnBusy
                                        ? const SizedBox(
                                            key: ValueKey('webauthn-loading'),
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.fingerprint_rounded,
                                            key: ValueKey('webauthn-ready'),
                                          ),
                                  ),
                                  label: const Text(
                                    'Masuk dengan biometrik (Web)',
                                  ),
                                  onPressed:
                                      (_webAuthnSupported &&
                                          _webAuthnHasCredential &&
                                          !_webAuthnBusy &&
                                          !widget.isBusy)
                                      ? _handleWebAuthnLogin
                                      : null,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Text(
                                  !_webAuthnSupported
                                      ? 'Browser belum mendukung WebAuthn/Passkey.'
                                      : _webAuthnHasCredential
                                      ? 'Gunakan passkey/biometrik browser lewat WebAuthn.'
                                      : 'Aktifkan dengan login manual sekali di browser ini untuk menyimpan passkey.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Gunakan kredensial admin yang telah terdaftar untuk mengakses sistem.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  InputDecoration _inputDecoration(
    ThemeData theme, {
    required String label,
    required IconData icon,
  }) {
    final color = Colors.white70;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: color),
      prefixIcon: Icon(icon, color: color),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.4),
      ),
    );
  }

  void _submit() {
    if (widget.isBusy) return;
    if (!_formKey.currentState!.validate()) return;
    widget.onAuthenticate(_emailCtrl.text, _passwordCtrl.text);
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isBusy) _shimmerController.repeat();
    _prepareBiometricAvailability();
    _prepareWebAuthnAvailability();
  }

  Future<void> _prepareBiometricAvailability() async {
    if (!_biometricSupportedPlatform) return;
    try {
      final optIn = await _biometricService.isOptInEnabled();
      final available = optIn && await _biometricService.canUseBiometricLogin();
      if (!mounted) return;
      setState(() {
        _biometricAvailable = available;
      });
    } catch (e) {
      debugPrint('Biometric availability check failed: $e');
    }
  }

  Future<void> _prepareWebAuthnAvailability() async {
    if (!kIsWeb) return;
    setState(() => _webAuthnBusy = true);
    try {
      final supported = await _webAuthnSupport.isSupported();
      final hasCredential = supported
          ? await _webAuthnManager.hasPasskey()
          : false;
      if (!mounted) return;
      setState(() {
        _webAuthnSupported = supported;
        _webAuthnHasCredential = hasCredential;
      });
    } catch (e) {
      debugPrint('WebAuthn availability check failed: $e');
    } finally {
      if (mounted) setState(() => _webAuthnBusy = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (!_biometricSupportedPlatform) return;
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);
    try {
      final creds = await _biometricService.authenticateAndGetCredentials(
        reason: defaultTargetPlatform == TargetPlatform.iOS
            ? 'Gunakan Face ID untuk login admin'
            : defaultTargetPlatform == TargetPlatform.macOS
                ? 'Gunakan Touch ID untuk login admin'
                : 'Gunakan sidik jari untuk login admin',
      );
      if (creds == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Login biometrik dibatalkan atau belum diaktifkan.',
              ),
            ),
          );
        }
        return;
      }
      _emailCtrl.text = creds.email;
      _passwordCtrl.text = creds.password;
      await widget.onAuthenticate(creds.email, creds.password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal login biometrik: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _biometricBusy = false);
      }
    }
  }

  Future<void> _handleWebAuthnLogin() async {
    if (!kIsWeb || !_webAuthnSupported || !_webAuthnHasCredential) return;
    setState(() => _webAuthnBusy = true);
    try {
      final creds = await _webAuthnManager.authenticate();
      if (creds == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login biometrik web gagal atau dibatalkan.'),
            ),
          );
        }
        return;
      }
      _emailCtrl.text = creds.email;
      _passwordCtrl.text = creds.password;
      await widget.onAuthenticate(creds.email, creds.password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal login biometrik web: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _webAuthnBusy = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailCtrl.text.trim());
    final formKey = GlobalKey<FormState>();
    String? dialogError;
    bool isSending = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Reset kata sandi'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masukkan email admin. Kami akan mengirim tautan untuk '
                      'mengatur ulang kata sandi.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      enabled: !isSending,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Masukkan email admin.';
                        }
                        if (!value.contains('@')) {
                          return 'Format email tidak valid.';
                        }
                        return null;
                      },
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setDialogState(() {
                            isSending = true;
                            dialogError = null;
                          });
                          try {
                            await widget.onForgotPassword(
                              emailController.text.trim(),
                            );
                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (error) {
                            String message;
                            if (error is ForgotPasswordException) {
                              message = error.message;
                            } else {
                              message =
                                  'Gagal mengirim tautan reset. Coba lagi.';
                            }
                            setDialogState(() {
                              isSending = false;
                              dialogError = message;
                            });
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kirim'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (!mounted || result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan reset kata sandi telah dikirim ke email.'),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.child,
    required this.onPressed,
    this.enabled = true,
    this.borderRadius = 16,
    this.height = 52,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;
  final double borderRadius;
  final double height;

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.white.withOpacity(0.12);
    final borderColor = Colors.white.withOpacity(0.26);
    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: baseColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              side: BorderSide(color: borderColor),
            ),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(borderRadius),
              splashColor: Colors.white.withOpacity(0.18),
              highlightColor: Colors.white.withOpacity(0.08),
              child: SizedBox(
                height: height,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({
    required this.animation,
    required this.height,
    this.width,
    this.borderRadius = 12,
  });

  final Animation<double> animation;
  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.withOpacity(0.08);
    final highlight = Colors.white.withOpacity(0.26);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.08, 0.5, 0.92],
              transform: _SlideGradientTransform(animation.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.slidePercent);
  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0,
      0,
    );
  }
}

class ForgotPasswordException implements Exception {
  ForgotPasswordException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            center: Alignment.center,
            radius: 0.85,
          ),
        ),
      ),
    );
  }
}
