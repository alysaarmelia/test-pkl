import 'package:get/get.dart';

import '../repositories/auth_credentials_repository.dart';

class AuthCredentialsViewModel extends GetxController {
  AuthCredentialsViewModel({AuthCredentialsRepository? repository})
    : _repository = repository ?? AuthCredentialsRepositoryImpl();

  final AuthCredentialsRepository _repository;

  String? get currentUserEmail => _repository.currentUserEmail;

  Future<LoginFlowResult> login({
    required String email,
    required String password,
  }) {
    return _repository.login(email: email, password: password);
  }

  Future<SignupFlowResult> signup({
    required String username,
    required String email,
    required String password,
  }) {
    return _repository.signup(
      username: username,
      email: email,
      password: password,
    );
  }

  Future<SignupVerificationResult> resendVerificationEmail() {
    return _repository.resendVerificationEmail();
  }

  Future<bool> reloadAndCheckEmailVerified() {
    return _repository.reloadAndCheckEmailVerified();
  }

  Future<VerifyResetCodeResult> verifyPasswordResetCode(String code) {
    return _repository.verifyPasswordResetCode(code);
  }

  Future<AuthActionResult> sendPasswordResetEmail(String email) {
    return _repository.sendPasswordResetEmail(email);
  }

  Future<AuthActionResult> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) {
    return _repository.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }
}
