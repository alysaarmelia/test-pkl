import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/services/auth_session_service.dart';

enum LoginFlowStatus { success, emailNotVerified, authError, failure }

class LoginFlowResult {
  const LoginFlowResult({
    required this.status,
    this.authErrorCode,
    this.message,
    this.profileCompleted = false,
  });

  final LoginFlowStatus status;
  final String? authErrorCode;
  final String? message;
  final bool profileCompleted;
}

enum SignupFlowStatus { success, authError, failure }

class SignupFlowResult {
  const SignupFlowResult({
    required this.status,
    this.authErrorCode,
    this.message,
    this.verificationWarningMessage,
  });

  final SignupFlowStatus status;
  final String? authErrorCode;
  final String? message;
  final String? verificationWarningMessage;
}

enum SignupVerificationStatus { success, warning, failure }

class SignupVerificationResult {
  const SignupVerificationResult({required this.status, required this.message});

  final SignupVerificationStatus status;
  final String message;
}

class VerifyResetCodeResult {
  const VerifyResetCodeResult({
    required this.success,
    this.email,
    this.code,
    this.message,
  });

  final bool success;
  final String? email;
  final String? code;
  final String? message;
}

class AuthActionResult {
  const AuthActionResult({required this.success, this.code, this.message});

  final bool success;
  final String? code;
  final String? message;
}

abstract class AuthCredentialsSessionDelegate {
  Future<void> recordLoginTime();
}

class AuthCredentialsSessionDelegateImpl
    implements AuthCredentialsSessionDelegate {
  AuthCredentialsSessionDelegateImpl({AuthSessionService? service})
    : _service = service ?? AuthSessionService();

  final AuthSessionService _service;

  @override
  Future<void> recordLoginTime() => _service.recordLoginTime();
}

abstract class AuthCredentialsRepository {
  String? get currentUserEmail;

  Future<LoginFlowResult> login({
    required String email,
    required String password,
  });

  Future<SignupFlowResult> signup({
    required String username,
    required String email,
    required String password,
  });

  Future<SignupVerificationResult> resendVerificationEmail();

  Future<bool> reloadAndCheckEmailVerified();

  Future<VerifyResetCodeResult> verifyPasswordResetCode(String code);

  Future<AuthActionResult> sendPasswordResetEmail(String email);

  Future<AuthActionResult> confirmPasswordReset({
    required String code,
    required String newPassword,
  });
}

class AuthCredentialsRepositoryImpl implements AuthCredentialsRepository {
  AuthCredentialsRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AuthCredentialsSessionDelegate? sessionDelegate,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _sessionDelegate =
           sessionDelegate ?? AuthCredentialsSessionDelegateImpl();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AuthCredentialsSessionDelegate _sessionDelegate;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  Future<LoginFlowResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user != null && !user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } catch (_) {}
        return const LoginFlowResult(status: LoginFlowStatus.emailNotVerified);
      }

      await _sessionDelegate.recordLoginTime();

      try {
        final uid = _auth.currentUser?.uid;
        if (uid == null || uid.isEmpty) {
          return const LoginFlowResult(
            status: LoginFlowStatus.success,
            profileCompleted: false,
          );
        }
        final snap = await _firestore.collection('users').doc(uid).get();
        final completed =
            snap.exists &&
            (snap.data()?['profileCompleted'] == true ||
                snap.data()?['isComplete'] == true);
        return LoginFlowResult(
          status: LoginFlowStatus.success,
          profileCompleted: completed,
        );
      } catch (_) {
        return const LoginFlowResult(
          status: LoginFlowStatus.success,
          profileCompleted: false,
        );
      }
    } on FirebaseAuthException catch (e) {
      return LoginFlowResult(
        status: LoginFlowStatus.authError,
        authErrorCode: e.code,
        message: e.message,
      );
    } catch (e) {
      return LoginFlowResult(
        status: LoginFlowStatus.failure,
        message: e.toString(),
      );
    }
  }

  @override
  Future<SignupFlowResult> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await cred.user?.updateDisplayName(username);

      try {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'name': username,
            'profileCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      String? warning;
      try {
        await _auth.setLanguageCode('id');
        await cred.user?.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        warning = e.code == 'too-many-requests'
            ? 'Terlalu banyak permintaan dari perangkat ini. Coba lagi beberapa menit.'
            : (e.message ?? 'Gagal mengirim email verifikasi');
      } catch (_) {}

      return SignupFlowResult(
        status: SignupFlowStatus.success,
        verificationWarningMessage: warning,
      );
    } on FirebaseAuthException catch (e) {
      return SignupFlowResult(
        status: SignupFlowStatus.authError,
        authErrorCode: e.code,
        message: e.message,
      );
    } catch (e) {
      return SignupFlowResult(
        status: SignupFlowStatus.failure,
        message: e.toString(),
      );
    }
  }

  @override
  Future<SignupVerificationResult> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const SignupVerificationResult(
        status: SignupVerificationStatus.warning,
        message: 'Sesi pendaftaran tidak ditemukan. Coba daftar ulang.',
      );
    }
    if (user.emailVerified) {
      return const SignupVerificationResult(
        status: SignupVerificationStatus.warning,
        message: 'Email sudah terverifikasi.',
      );
    }

    try {
      await _auth.setLanguageCode('id');
      await user.sendEmailVerification();
      return const SignupVerificationResult(
        status: SignupVerificationStatus.success,
        message: 'Email verifikasi dikirim ulang',
      );
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'too-many-requests'
          ? 'Terlalu banyak permintaan dari perangkat ini. Coba lagi beberapa menit.'
          : (e.message ?? 'Gagal mengirim email verifikasi');
      return SignupVerificationResult(
        status: SignupVerificationStatus.failure,
        message: msg,
      );
    } catch (e) {
      return SignupVerificationResult(
        status: SignupVerificationStatus.failure,
        message: 'Gagal mengirim email verifikasi: $e',
      );
    }
  }

  @override
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified == true;
  }

  @override
  Future<VerifyResetCodeResult> verifyPasswordResetCode(String code) async {
    try {
      final email = await _auth.verifyPasswordResetCode(code);
      return VerifyResetCodeResult(success: true, email: email);
    } on FirebaseAuthException catch (e) {
      return VerifyResetCodeResult(
        success: false,
        code: e.code,
        message: e.message,
      );
    } catch (e) {
      return VerifyResetCodeResult(success: false, message: e.toString());
    }
  }

  @override
  Future<AuthActionResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const AuthActionResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthActionResult(success: false, code: e.code, message: e.message);
    } catch (e) {
      return AuthActionResult(success: false, message: e.toString());
    }
  }

  @override
  Future<AuthActionResult> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
      return const AuthActionResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthActionResult(success: false, code: e.code, message: e.message);
    } catch (e) {
      return AuthActionResult(success: false, message: e.toString());
    }
  }
}
