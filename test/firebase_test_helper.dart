import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setupFirebaseForTesting() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}
