import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

class TestUser extends Fake implements User {
  TestUser({required this.uid, this.email, this.displayName, this.photoURL});

  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  @override
  final String? photoURL;
}

class TestAuth extends Fake implements FirebaseAuth {
  TestAuth({User? user}) : _user = user;

  final User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(_user);

  @override
  Stream<User?> userChanges() => authStateChanges();

  @override
  Stream<User?> idTokenChanges() => authStateChanges();
}

class RecordingAuth extends TestAuth {
  RecordingAuth({required User user}) : _userMutable = user, super(user: user);

  bool signedOut = false;
  final User _userMutable;

  @override
  User? get currentUser => _userMutable;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}
