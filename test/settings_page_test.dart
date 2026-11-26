import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/pages/settings_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/settings_repository.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';

import 'firebase_test_helper.dart';
import 'test_doubles.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('menampilkan profil guest ketika belum login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          repository: SettingsRepositoryImpl(auth: TestAuth()),
          enableBiometric: false,
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Tidak masuk'), findsOneWidget);
  });

  testWidgets('menampilkan nama dan role dari firestore', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set({
      'name': 'Budi Santoso',
      'role': 'Manager',
      'pin': 'PIN999',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          repository: SettingsRepositoryImpl(
            auth: TestAuth(user: TestUser(uid: 'u1')),
            firestore: firestore,
          ),
          enableBiometric: false, // hindari pemanggilan local_auth di test
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
  });

  testWidgets('logout menampilkan dialog lalu memanggil signOut', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.window.physicalSizeTestValue = const Size(900, 1600);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set({
      'name': 'Tester',
      'role': 'QA',
    });
    final auth = RecordingAuth(user: TestUser(uid: 'u1'));

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          Routes.SPLASH: (_) => const Scaffold(body: Text('Splash Screen')),
        },
        home: SettingsPage(
          repository: SettingsRepositoryImpl(auth: auth, firestore: firestore),
          enableBiometric: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Log Out'), 600);
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(find.text('Keluar Akun'), findsOneWidget);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(auth.signedOut, isTrue);
    expect(find.text('Splash Screen'), findsOneWidget);
  });
}
