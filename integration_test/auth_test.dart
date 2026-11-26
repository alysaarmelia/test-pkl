// Black Box UC-01 (registrasi) dan UC-02 (login, lupa kata sandi).
// Halaman nyata (LoginView, SignupView, ForgotPasswordView) dipompa dengan
// repository bawaan yang memakai Firebase Auth/Firestore EMULATOR.
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/forgot_password_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/login_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/signup_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/emulator.dart';
import 'support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Emu.setup();
  });

  Widget loginView({
    required TextEditingController email,
    required TextEditingController password,
    required void Function() onSuccess,
  }) {
    return LoginView(
      usernameController: email,
      passwordController: password,
      onSignUpTap: () {},
      onLoginSuccess: onSuccess,
    );
  }

  // ---------------------------------------------------------------- UC-01
  bbTest('BB-01', 'Registrasi data lengkap -> akun dibuat & email verifikasi dikirim',
      (tester) async {
    final username = TextEditingController(text: 'Siti Aminah');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = TextEditingController(text: 'bb01.$stamp@demo-cvm.test');
    final pass = TextEditingController(text: kDefaultPassword);
    final confirm = TextEditingController(text: kDefaultPassword);

    await pumpApp(
      tester,
      SignupView(
        onLoginTap: () {},
        usernameController: username,
        emailController: email,
        passwordController: pass,
        confirmPasswordController: confirm,
        onSignupTap: () {},
      ),
    );

    await tapVisible(tester, find.text('Sign Up'));
    // Setelah sukses, aplikasi menampilkan bottom sheet "Verifikasi Email".
    await pumpUntil(tester, find.text('Verifikasi Email'),
        timeout: const Duration(seconds: 40));

    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull, reason: 'Akun harus dibuat dan sedang login');
    expect(user!.email, email.text);
    expect(user.emailVerified, isFalse);
    expect(await Emu.hasOobCode(email.text, 'VERIFY_EMAIL'), isTrue,
        reason: 'Auth emulator harus mencatat email verifikasi');

    final profile = await Emu.getDoc('users', user.uid);
    expect(profile, isNotNull, reason: 'Dokumen users/{uid} harus dibuat');
    expect(profile!['name'], 'Siti Aminah');
    expect(profile['profileCompleted'], false);
  });

  bbTest('BB-02', 'Registrasi isian kosong -> ditolak + pesan validasi',
      (tester) async {
    final username = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    final confirm = TextEditingController();

    await pumpApp(
      tester,
      SignupView(
        onLoginTap: () {},
        usernameController: username,
        emailController: email,
        passwordController: pass,
        confirmPasswordController: confirm,
        onSignupTap: () {},
      ),
    );

    Future<void> submitExpecting(String message) async {
      await dismissSnackBars(tester);
      await tapVisible(tester, find.text('Sign Up'));
      await pumpUntil(tester, find.text(message));
    }

    // Semua kosong.
    await submitExpecting('Username wajib diisi');
    // Validasi lanjutan, satu per satu.
    username.text = 'Siti';
    await submitExpecting('Email wajib diisi');
    email.text = 'bukan-email';
    await submitExpecting('Format email tidak valid');
    email.text = 'siti@demo-cvm.test';
    pass.text = '123';
    await submitExpecting('Password minimal 6 karakter');
    pass.text = kDefaultPassword;
    confirm.text = 'berbeda123';
    await submitExpecting('Konfirmasi password tidak sama');

    expect(FirebaseAuth.instance.currentUser, isNull,
        reason: 'Tidak boleh ada akun yang dibuat');
    expect(await Emu.oobCodes(), isEmpty);
  });

  // ---------------------------------------------------------------- UC-02
  bbTest('BB-03', 'Login akun terverifikasi & profil lengkap -> lanjut ke Beranda',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb03');
    await Emu.seedUserProfile(acc, role: 'Finance', profileCompleted: true);

    final email = TextEditingController(text: acc.email);
    final pass = TextEditingController(text: acc.password);
    var reachedHome = false;
    await pumpApp(
      tester,
      loginView(
        email: email,
        password: pass,
        onSuccess: () => reachedHome = true,
      ),
    );

    await tapVisible(tester, find.byKey(const ValueKey('login-text')));
    await pumpUntilTrue(tester, () => reachedHome,
        reason: 'onLoginSuccess (menuju Beranda) tidak dipanggil');
    expect(FirebaseAuth.instance.currentUser?.email, acc.email);
  });

  bbTest('BB-04', 'Login email belum terverifikasi -> ditolak, email verifikasi dikirim ulang',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb04', emailVerified: false);
    await Emu.seedUserProfile(acc, role: 'Finance', profileCompleted: true);

    final email = TextEditingController(text: acc.email);
    final pass = TextEditingController(text: acc.password);
    var reachedHome = false;
    await pumpApp(
      tester,
      loginView(
        email: email,
        password: pass,
        onSuccess: () => reachedHome = true,
      ),
    );

    await tapVisible(tester, find.byKey(const ValueKey('login-text')));
    await pumpUntil(
      tester,
      find.text('Email belum diverifikasi. Cek inbox/spam dan verifikasi dulu.'),
    );
    expect(reachedHome, isFalse);
    expect(await Emu.hasOobCode(acc.email, 'VERIFY_EMAIL'), isTrue,
        reason: 'Email verifikasi harus dikirim ulang');
  });

  bbTest('BB-05', 'Login isian kosong -> tidak diproses, muncul pesan validasi',
      (tester) async {
    final email = TextEditingController();
    final pass = TextEditingController();
    var reachedHome = false;
    await pumpApp(
      tester,
      loginView(
        email: email,
        password: pass,
        onSuccess: () => reachedHome = true,
      ),
    );

    await tapVisible(tester, find.byKey(const ValueKey('login-text')));
    await pumpUntil(tester, find.text('Email dan password wajib diisi'));

    // Hanya email terisi -> tetap ditolak.
    await dismissSnackBars(tester);
    email.text = 'seseorang@demo-cvm.test';
    await tapVisible(tester, find.byKey(const ValueKey('login-text')));
    await pumpUntil(tester, find.text('Email dan password wajib diisi'));

    expect(reachedHome, isFalse);
    expect(FirebaseAuth.instance.currentUser, isNull);
  });

  // Tambahan (tidak ada di lembar Excel; usulan baris baru): kata sandi salah.
  bbTest('BB-TAMBAHAN-01', 'Login kata sandi salah -> pesan galat, tetap di halaman login',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bbt01');
    await Emu.seedUserProfile(acc, role: 'Finance', profileCompleted: true);

    final email = TextEditingController(text: acc.email);
    final pass = TextEditingController(text: 'SalahTotal999');
    var reachedHome = false;
    await pumpApp(
      tester,
      loginView(
        email: email,
        password: pass,
        onSuccess: () => reachedHome = true,
      ),
    );

    await tapVisible(tester, find.byKey(const ValueKey('login-text')));
    // Kode galat emulator bisa wrong-password atau invalid-credential
    // tergantung versi plugin; aplikasi memetakan keduanya ke pesan berbeda.
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == 'Password salah' ||
                w.data == 'Email atau password salah'),
      ),
    );
    expect(reachedHome, isFalse);
    expect(FirebaseAuth.instance.currentUser, isNull);
  });

  bbTest('BB-08', 'Lupa kata sandi -> email atur ulang dikirim',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb08');
    await Emu.seedUserProfile(acc, role: 'Finance', profileCompleted: true);

    await pumpApp(tester, const ForgotPasswordView());

    await enterInto(tester, find.byType(TextFormField).first, acc.email);
    await tapVisible(tester, find.text('Kirim Tautan Reset'));
    await pumpUntil(
      tester,
      find.text('Tautan reset password telah dikirim. Periksa email Anda.'),
    );
    expect(await Emu.hasOobCode(acc.email, 'PASSWORD_RESET'), isTrue,
        reason: 'Auth emulator harus mencatat email reset password');
  });
}
