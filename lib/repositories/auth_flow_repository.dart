import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/services/auth_session_service.dart';

abstract class AuthFlowSessionDelegate {
  Future<bool> hasActiveSession();

  Future<void> clearSession();
}

class AuthFlowSessionDelegateImpl implements AuthFlowSessionDelegate {
  AuthFlowSessionDelegateImpl({AuthSessionService? service})
    : _service = service ?? AuthSessionService();

  final AuthSessionService _service;

  @override
  Future<bool> hasActiveSession() => _service.hasActiveSession();

  @override
  Future<void> clearSession() => _service.clearSession();
}

abstract class AuthFlowRepository {
  bool get hasCurrentUser;

  Future<bool> shouldAutoLogin();

  Future<String> resolveFriendlyName();
}

class AuthFlowRepositoryImpl implements AuthFlowRepository {
  AuthFlowRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AuthFlowSessionDelegate? sessionDelegate,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _sessionDelegate = sessionDelegate ?? AuthFlowSessionDelegateImpl();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AuthFlowSessionDelegate _sessionDelegate;

  @override
  bool get hasCurrentUser => _auth.currentUser != null;

  @override
  Future<bool> shouldAutoLogin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final hasSession = await _sessionDelegate.hasActiveSession();
    if (hasSession) return true;

    await _sessionDelegate.clearSession();
    await _auth.signOut();
    return false;
  }

  @override
  Future<String> resolveFriendlyName() async {
    final user = _auth.currentUser;
    if (user == null) return 'Pengguna';

    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final name = (doc.data()?['name'] as String?)?.trim() ?? '';
      if (name.isNotEmpty) return name;
    } catch (_) {}

    return 'Pengguna';
  }
}
