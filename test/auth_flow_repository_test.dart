import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/repositories/auth_flow_repository.dart';

import 'test_doubles.dart';

class _FakeSessionDelegate implements AuthFlowSessionDelegate {
  _FakeSessionDelegate({required this.active});

  bool active;
  bool cleared = false;

  @override
  Future<bool> hasActiveSession() async => active;

  @override
  Future<void> clearSession() async {
    cleared = true;
  }
}

void main() {
  test('shouldAutoLogin true jika user ada dan session aktif', () async {
    final auth = RecordingAuth(
      user: TestUser(uid: 'u-1', displayName: 'Ayu'),
    );
    final session = _FakeSessionDelegate(active: true);
    final repository = AuthFlowRepositoryImpl(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
      sessionDelegate: session,
    );

    final result = await repository.shouldAutoLogin();

    expect(result, isTrue);
    expect(session.cleared, isFalse);
    expect(auth.signedOut, isFalse);
  });

  test(
    'shouldAutoLogin false jika session expired dan user di-signout',
    () async {
      final auth = RecordingAuth(
        user: TestUser(uid: 'u-1', displayName: 'Ayu'),
      );
      final session = _FakeSessionDelegate(active: false);
      final repository = AuthFlowRepositoryImpl(
        auth: auth,
        firestore: FakeFirebaseFirestore(),
        sessionDelegate: session,
      );

      final result = await repository.shouldAutoLogin();

      expect(result, isFalse);
      expect(session.cleared, isTrue);
      expect(auth.signedOut, isTrue);
    },
  );

  test('resolveFriendlyName prioritas displayName', () async {
    final auth = TestAuth(
      user: TestUser(uid: 'u-1', displayName: 'Nama App'),
    );
    final repository = AuthFlowRepositoryImpl(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
      sessionDelegate: _FakeSessionDelegate(active: true),
    );

    final name = await repository.resolveFriendlyName();

    expect(name, 'Nama App');
  });

  test('resolveFriendlyName fallback ke users.name di firestore', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u-1').set({'name': 'Nama DB'});

    final auth = TestAuth(
      user: TestUser(uid: 'u-1', displayName: ''),
    );
    final repository = AuthFlowRepositoryImpl(
      auth: auth,
      firestore: firestore,
      sessionDelegate: _FakeSessionDelegate(active: true),
    );

    final name = await repository.resolveFriendlyName();

    expect(name, 'Nama DB');
  });
}
