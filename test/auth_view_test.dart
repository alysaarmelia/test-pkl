import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/views/auth_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/login_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/signup_view.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('AuthView berpindah Login -> Signup -> Login', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(900, 1600);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(const MaterialApp(home: AuthView()));

    expect(find.byKey(const ValueKey('login')), findsOneWidget);
    expect(find.byKey(const ValueKey('signup')), findsNothing);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('signup')), findsOneWidget);

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login')), findsOneWidget);
  });

  testWidgets('LoginView menolak email/password kosong', (tester) async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginView(
            usernameController: usernameCtrl,
            passwordController: passwordCtrl,
            onSignUpTap: () {},
            onLoginSuccess: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(find.text('Email dan password wajib diisi'), findsOneWidget);
  });

  testWidgets('SignupView menolak input kosong', (tester) async {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignupView(
            onLoginTap: () {},
            usernameController: usernameCtrl,
            emailController: emailCtrl,
            passwordController: passCtrl,
            confirmPasswordController: confirmCtrl,
            onSignupTap: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sign Up'));
    await tester.pump();

    expect(find.text('Username wajib diisi'), findsOneWidget);
  });
}
