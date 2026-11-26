import 'package:cipta_vera_mandiri_digital/app/modules/home/controllers/login_controller.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_credentials_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_credentials_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthCredentialsRepository implements AuthCredentialsRepository {
  LoginFlowResult nextResult = const LoginFlowResult(
    status: LoginFlowStatus.success,
    profileCompleted: true,
  );

  Duration delay = Duration.zero;
  int loginCalls = 0;
  String? receivedEmail;
  String? receivedPassword;

  @override
  String? get currentUserEmail => null;

  @override
  Future<LoginFlowResult> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    receivedEmail = email;
    receivedPassword = password;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return nextResult;
  }

  @override
  Future<SignupFlowResult> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<SignupVerificationResult> resendVerificationEmail() async {
    throw UnimplementedError();
  }

  @override
  Future<bool> reloadAndCheckEmailVerified() async => false;

  @override
  Future<VerifyResetCodeResult> verifyPasswordResetCode(String code) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthActionResult> sendPasswordResetEmail(String email) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthActionResult> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    throw UnimplementedError();
  }
}

class _SpyLoginController extends LoginController {
  _SpyLoginController({required super.viewModel});

  final List<String> shownMessages = <String>[];
  String? navigatedRoute;

  @override
  void showSnackbar(String title, String message) {
    shownMessages.add('$title::$message');
  }

  @override
  void navigateTo(String routeName) {
    navigatedRoute = routeName;
  }
}

void main() {
  test('login tidak memanggil repository saat input kosong', () async {
    final fakeRepository = _FakeAuthCredentialsRepository();
    final controller = _SpyLoginController(
      viewModel: AuthCredentialsViewModel(repository: fakeRepository),
    );

    controller.emailController.text = '';
    controller.passwordController.text = '';
    await controller.login();

    expect(fakeRepository.loginCalls, 0);
    expect(controller.isLoading.value, isFalse);
    expect(controller.navigatedRoute, isNull);
    expect(
      controller.shownMessages.last,
      contains('Email & Password tidak boleh kosong'),
    );
  });

  test('login sukses ke /home jika profil lengkap', () async {
    final fakeRepository = _FakeAuthCredentialsRepository()
      ..nextResult = const LoginFlowResult(
        status: LoginFlowStatus.success,
        profileCompleted: true,
      );
    final controller = _SpyLoginController(
      viewModel: AuthCredentialsViewModel(repository: fakeRepository),
    );

    controller.emailController.text = ' user@example.com ';
    controller.passwordController.text = 'secret';
    await controller.login();

    expect(fakeRepository.loginCalls, 1);
    expect(fakeRepository.receivedEmail, 'user@example.com');
    expect(fakeRepository.receivedPassword, 'secret');
    expect(controller.isLoading.value, isFalse);
    expect(controller.navigatedRoute, '/home');
  });

  test('login sukses ke /complete-profile jika profil belum lengkap', () async {
    final fakeRepository = _FakeAuthCredentialsRepository()
      ..nextResult = const LoginFlowResult(
        status: LoginFlowStatus.success,
        profileCompleted: false,
      );
    final controller = _SpyLoginController(
      viewModel: AuthCredentialsViewModel(repository: fakeRepository),
    );

    controller.emailController.text = 'user@example.com';
    controller.passwordController.text = 'secret';
    await controller.login();

    expect(controller.navigatedRoute, '/complete-profile');
    expect(controller.isLoading.value, isFalse);
  });

  test('login auth error tidak melakukan navigasi', () async {
    final fakeRepository = _FakeAuthCredentialsRepository()
      ..nextResult = const LoginFlowResult(
        status: LoginFlowStatus.authError,
        authErrorCode: 'invalid-email',
      );
    final controller = _SpyLoginController(
      viewModel: AuthCredentialsViewModel(repository: fakeRepository),
    );

    controller.emailController.text = 'invalid';
    controller.passwordController.text = 'secret';
    await controller.login();

    expect(fakeRepository.loginCalls, 1);
    expect(controller.navigatedRoute, isNull);
    expect(controller.isLoading.value, isFalse);
    expect(controller.shownMessages.last, contains('Format email tidak valid'));
  });

  test('isLoading true selama proses login berlangsung', () async {
    final fakeRepository = _FakeAuthCredentialsRepository()
      ..delay = const Duration(milliseconds: 30);
    final controller = _SpyLoginController(
      viewModel: AuthCredentialsViewModel(repository: fakeRepository),
    );

    controller.emailController.text = 'user@example.com';
    controller.passwordController.text = 'secret';

    final future = controller.login();
    expect(controller.isLoading.value, isTrue);
    await future;

    expect(controller.isLoading.value, isFalse);
  });
}
