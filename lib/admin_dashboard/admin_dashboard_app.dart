import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cipta_vera_mandiri_digital/app/services/biometric_auth_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/web_authn_login_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'views/dashboard_shell.dart';
import 'views/login_page.dart';

const List<String> _dashboardModuleRoleKeys = [
  'attendance',
  'requests',
  'calendar',
  'documents',
  'material',
  'users',
];

class AdminDashboardApp extends StatefulWidget {
  const AdminDashboardApp({super.key});

  @override
  State<AdminDashboardApp> createState() => _AdminDashboardAppState();
}

class _AdminDashboardAppState extends State<AdminDashboardApp> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _error;
  Future<bool>? _adminCheckFuture;
  String? _adminCheckedUid;
  final WebAuthnLoginManager _webAuthnManager = createWebAuthnLoginManager();

  @override
  Widget build(BuildContext context) {
    final cachedUser = _auth.currentUser;
    return GetMaterialApp(
      title: 'CVMD Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data ?? cachedUser;
          if (user == null) {
            if (_adminCheckFuture != null || _adminCheckedUid != null) {
              _clearAdminCheckCache();
            }
            return AdminLoginPage(
              isBusy: _isLoading,
              errorMessage: _error,
              onAuthenticate: _handleLogin,
              onForgotPassword: _handleForgotPassword,
            );
          }

          final adminCheckFuture = _ensureAdminAccess(user);

          return FutureBuilder<bool>(
            future: adminCheckFuture,
            builder: (context, adminSnapshot) {
              final verifying =
                  adminSnapshot.connectionState != ConnectionState.done;
              if (adminSnapshot.data == true) {
                return AdminDashboardShell(onLogout: _handleLogout);
              }

              return AdminLoginPage(
                isBusy: _isLoading || verifying,
                errorMessage: verifying ? null : _error,
                onAuthenticate: _handleLogin,
                onForgotPassword: _handleForgotPassword,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleLogin(String email, String password) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _clearAdminCheckCache();
    });

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null && !user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } catch (_) {}
        await _auth.signOut();
        if (!mounted) return;
        setState(() {
          _error =
              'Email belum diverifikasi. Silakan cek inbox/spam untuk verifikasi.';
        });
        return;
      }

      await _maybeSaveBiometricCredentials(email, password);
      await _maybeRegisterWebAuthn(email, password);
    } on FirebaseAuthException catch (e) {
      final message = _mapAuthError(e.code, e.message);
      if (!mounted) return;
      setState(() {
        _error = message;
      });
    } catch (e, st) {
      debugPrint('Unexpected error during admin login: $e');
      debugPrint(st.toString());
      if (!mounted) return;
      setState(() {
        _error = 'Terjadi kesalahan. Silakan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw ForgotPasswordException(_mapResetPasswordError(e.code, e.message));
    } catch (e, st) {
      debugPrint('Unexpected error during password reset: $e');
      debugPrint(st.toString());
      throw ForgotPasswordException('Terjadi kesalahan. Silakan coba lagi.');
    }
  }

  Future<bool> _ensureAdminAccess(User user) {
    if (_adminCheckedUid != user.uid || _adminCheckFuture == null) {
      _adminCheckedUid = user.uid;
      _adminCheckFuture = _verifyAdmin(user);
    }
    return _adminCheckFuture!;
  }

  Future<bool> _verifyAdmin(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      final roles = _parseRoles(data?['roles']);
      final hasAccess = _hasAdminPermission(roles);
      if (!hasAccess) {
        await _auth.signOut();
        if (mounted) {
          setState(() {
            _error = 'Anda bukan admin.';
            _clearAdminCheckCache();
          });
        }
        return false;
      }
      if (mounted && _error != null) {
        setState(() {
          _error = null;
        });
      }
      return true;
    } catch (e, st) {
      debugPrint('Failed to verify admin role: $e');
      debugPrint(st.toString());
      await _auth.signOut();
      if (mounted) {
        setState(() {
          _error = 'Gagal memverifikasi role admin. Coba lagi.';
          _clearAdminCheckCache();
        });
      }
      return false;
    }
  }

  Map<String, dynamic> _parseRoles(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return <String, dynamic>{};
  }

  bool _hasAdminPermission(Map<String, dynamic> roles) {
    if (roles['superAdmin'] == true || roles['admin'] == true) {
      return true;
    }
    for (final key in _dashboardModuleRoleKeys) {
      if (roles[key] == true) {
        return true;
      }
    }
    return false;
  }

  void _clearAdminCheckCache() {
    _adminCheckFuture = null;
    _adminCheckedUid = null;
  }

  String _mapAuthError(String code, String? fallbackMessage) {
    switch (code) {
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
        return 'Password salah.';
      case 'invalid-email':
        return 'Email tidak valid.';
      case 'invalid-credential':
        return 'Email atau kata sandi salah.';
      case 'user-disabled':
        return 'Akun dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan login. Coba lagi beberapa saat.';
      default:
        return fallbackMessage ?? 'Gagal masuk. Silakan coba lagi.';
    }
  }

  String _mapResetPasswordError(String code, String? fallbackMessage) {
    switch (code) {
      case 'invalid-email':
        return 'Email tidak valid.';
      case 'missing-email':
        return 'Masukkan email admin.';
      case 'user-not-found':
        return 'Akun dengan email tersebut tidak ditemukan.';
      case 'too-many-requests':
        return 'Terlalu banyak permintaan reset. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Koneksi bermasalah. Periksa jaringan Anda.';
      default:
        return fallbackMessage ?? 'Gagal mengirim tautan reset.';
    }
  }

  Future<void> _maybeSaveBiometricCredentials(
    String email,
    String password,
  ) async {
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    final supported =
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.android ||
        platform == TargetPlatform.macOS;
    if (!supported) return;
    try {
      await BiometricAuthService().saveCredentials(
        email: email.trim(),
        password: password,
      );
    } catch (e, st) {
      debugPrint('Failed to save biometric credentials: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _maybeRegisterWebAuthn(String email, String password) async {
    if (!kIsWeb) return;
    try {
      final alreadyHasPasskey = await _webAuthnManager.hasPasskey();
      if (alreadyHasPasskey) return;
      await _webAuthnManager.saveCredentials(
        email: email.trim(),
        password: password,
      );
    } catch (e, st) {
      debugPrint('Failed to save WebAuthn credentials: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      setState(_clearAdminCheckCache);
    } catch (e, st) {
      debugPrint('Failed to sign out: $e');
      debugPrint(st.toString());
      if (!mounted) return;
      setState(() {
        _error = 'Gagal logout. Silakan coba lagi.';
      });
    }
  }

  ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Poppins',
    );
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2959C4),
      brightness: brightness,
    );
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0F1529)
          : const Color(0xFFF6F8FC),
      textTheme: base.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF1A2139)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
    );
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
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
        child: Center(
          child: SizedBox(
            height: 56,
            width: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
              backgroundColor: Colors.white30,
            ),
          ),
        ),
      ),
    );
  }
}
