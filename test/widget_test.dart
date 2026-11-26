import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_helper.dart';

void main() {
  testWidgets('firebase setup helper initializes default app', (tester) async {
    await setupFirebaseForTesting();
    expect(Firebase.apps, isNotEmpty);
  });
}
