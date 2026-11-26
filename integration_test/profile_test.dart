// Black Box UC-03 (melengkapi profil). Foto profil (kamera/galeri + crop)
// sengaja tidak diotomasi -> lihat README_integration.md (uji manual).
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/login_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/profile/complete_profile_page.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'support/emulator.dart';
import 'support/test_helpers.dart';

/// Penanda halaman "Beranda" pengganti. HomePage asli menarik RSS berita,
/// notifikasi lokal, FCM, dll. sehingga tidak dipompa di tes ini.
const String kHomeStub = 'BERANDA_STUB';

List<GetPage<dynamic>> get _pages => <GetPage<dynamic>>[
      GetPage<dynamic>(
        name: Routes.COMPLETE_PROFILE,
        page: () => const CompleteProfilePage(),
      ),
      GetPage<dynamic>(
        name: Routes.HOME,
        page: () => const Scaffold(body: Center(child: Text(kHomeStub))),
      ),
    ];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Emu.setup();
  });

  bbTest('BB-09', 'Login pertama, profil belum lengkap -> diarahkan ke Lengkapi Profil',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb09');
    await Emu.seedUserProfile(acc, profileCompleted: false);

    final email = TextEditingController(text: acc.email);
    final pass = TextEditingController(text: acc.password);
    var reachedHome = false;
    await pumpApp(
      tester,
      LoginView(
        usernameController: email,
        passwordController: pass,
        onSignUpTap: () {},
        onLoginSuccess: () => reachedHome = true,
      ),
      pages: _pages,
    );

    await tapVisible(tester, find.byKey(const ValueKey('login-text')));
    await pumpUntil(tester, find.text('Lengkapi Data Diri Anda'),
        timeout: const Duration(seconds: 40));
    expect(reachedHome, isFalse,
        reason: 'Profil belum lengkap: tidak boleh langsung ke Beranda');
  });

  bbTest('BB-10', 'Melengkapi profil (nama + divisi Finance, tanpa foto) -> tersimpan, PIN terbit, ke Beranda',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb10');
    await Emu.seedUserProfile(acc, profileCompleted: false);
    await Emu.signIn(acc);

    await pumpApp(tester, const CompleteProfilePage(), pages: _pages);

    // PIN dibuat otomatis (transaksi ke koleksi pins). Tunggu terisi.
    final pinField = find.byWidgetPredicate(
      (w) =>
          w is EditableText &&
          RegExp(r'^CV\d{6}M$').hasMatch(w.controller.text),
      description: 'kolom PIN terisi (format CV######M)',
    );
    await pumpUntil(tester, pinField, timeout: const Duration(seconds: 40));

    await enterInto(tester, byHint('Nama Lengkap'), 'Budi Santoso');

    await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Finance').last);
    await settle(tester);

    await tapVisible(tester, find.text('Simpan'));
    await pumpUntil(tester, find.text(kHomeStub),
        timeout: const Duration(seconds: 40));

    final saved = await Emu.getDoc('users', acc.uid);
    expect(saved, isNotNull);
    expect(saved!['name'], 'Budi Santoso');
    expect(saved['role'], 'Finance');
    expect(saved['profileCompleted'], true);
    final pin = saved['pin'] as String?;
    expect(pin, isNotNull);
    expect(RegExp(r'^CV\d{6}M$').hasMatch(pin!), isTrue,
        reason: 'Format PIN aktual: $pin');
    expect(saved['chatPin'], pin);
    final pinDoc = await Emu.getDoc('pins', pin);
    expect(pinDoc?['uid'], acc.uid, reason: 'PIN harus terdaftar di koleksi pins');
  });

  bbTest('BB-10 (validasi)', 'Simpan profil dengan nama & divisi kosong -> pesan validasi, tidak tersimpan',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb10v');
    await Emu.seedUserProfile(acc, profileCompleted: false);
    await Emu.signIn(acc);

    await pumpApp(tester, const CompleteProfilePage(), pages: _pages);
    await pumpFor(tester, const Duration(seconds: 2));

    await tapVisible(tester, find.text('Simpan'));
    await pumpUntil(tester, find.text('Nama wajib diisi'));
    expect(find.text('Divisi wajib dipilih'), findsWidgets);
    expect(find.text(kHomeStub), findsNothing);

    final saved = await Emu.getDoc('users', acc.uid);
    expect(saved!['profileCompleted'], false);
  });
}
