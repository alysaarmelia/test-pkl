import 'package:cipta_vera_mandiri_digital/app/services/auth_session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class HomePageRepository {
  Future<Duration?> remainingSessionTime();

  Future<void> clearSession();

  Future<void> signOut();
}

class HomePageRepositoryImpl implements HomePageRepository {
  HomePageRepositoryImpl({
    AuthSessionService? sessionService,
    FirebaseAuth? auth,
  }) : _sessionService = sessionService ?? AuthSessionService(),
       _auth = auth ?? FirebaseAuth.instance;

  final AuthSessionService _sessionService;
  final FirebaseAuth _auth;

  @override
  Future<Duration?> remainingSessionTime() {
    return _sessionService.remainingTime();
  }

  @override
  Future<void> clearSession() {
    return _sessionService.clearSession();
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}
