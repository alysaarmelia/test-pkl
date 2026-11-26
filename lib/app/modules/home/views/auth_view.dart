import 'package:cipta_vera_mandiri_digital/app/modules/home/views/home_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/calendar_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/chat_list_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/profile_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/settings_page.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_flow_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_flow_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/welcome_view.dart';

import 'login_view.dart' as my_views;
import 'signup_view.dart' as my_views;

class AuthView extends StatefulWidget {
  const AuthView({super.key, this.repository, this.viewModel});

  final AuthFlowRepository? repository;
  final AuthFlowViewModel? viewModel;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  late final AuthFlowViewModel _viewModel;
  late final String _viewModelTag;
  bool showLogin = true;
  // ignore: unused_field
  int _selectedIndex = 0;

  // ignore: unused_field
  late final List<Widget> _pages;

  // Controller untuk login
  final loginUsernameController = TextEditingController();
  final loginPasswordController = TextEditingController();

  // Controller untuk signup
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  void _goToSignup() => setState(() => showLogin = false);

  void _goToLogin() => setState(() => showLogin = true);

  Future<void> _handleLoginSuccess({required bool showWelcome}) async {
    if (!_viewModel.hasCurrentUser) return;
    if (showWelcome) {
      Get.offAll(() => const WelcomeView());
    } else {
      Get.offAllNamed(Routes.HOME);
    }
  }

  Future<void> _handleManualLoginSuccess() =>
      _handleLoginSuccess(showWelcome: true);

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'auth-flow-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            AuthFlowViewModel(
              repository: widget.repository ?? AuthFlowRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
    _pages = [
      HomeView(
        onMenuSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        onLogout: () {
          setState(() {
            showLogin = true;
          });
          return Future<void>.value();
        },
      ),
      const ChatListPage(),
      const CalendarPage(),
      const ProfilePage(),
      const SettingsPage(),
    ];
    _attemptAutoLogin();
  }

  @override
  void dispose() {
    if (Get.isRegistered<AuthFlowViewModel>(tag: _viewModelTag)) {
      Get.delete<AuthFlowViewModel>(tag: _viewModelTag, force: true);
    }
    loginUsernameController.dispose();
    loginPasswordController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _attemptAutoLogin() async {
    final stillValid = await _viewModel.shouldAutoLogin();
    if (!mounted) return;
    if (stillValid) {
      await Future<void>.delayed(Duration.zero);
      _handleLoginSuccess(showWelcome: false);
    } else {
      setState(() => showLogin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF007BC1), Color(0xFF6EC6FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: showLogin
            ? my_views.LoginView(
                key: const ValueKey('login'),
                usernameController: loginUsernameController,
                passwordController: loginPasswordController,
                onSignUpTap: _goToSignup,
                onLoginSuccess: _handleManualLoginSuccess,
              )
            : my_views.SignupView(
                key: const ValueKey('signup'),
                onLoginTap: _goToLogin,
                usernameController: usernameController,
                emailController: emailController,
                passwordController: passwordController,
                confirmPasswordController: confirmPasswordController,
                onSignupTap: () {
                  // aksi signup sukses
                  _goToLogin();
                },
              ),
      ),
    );
  }
}
