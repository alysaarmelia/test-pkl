import 'package:firebase_auth/firebase_auth.dart';

import '../shared/services/leave_request_repository.dart';

class PermissionPageUserData {
  const PermissionPageUserData({
    required this.uid,
    this.displayName,
    this.email,
  });

  final String uid;
  final String? displayName;
  final String? email;
}

abstract class PermissionPageRepository {
  PermissionPageUserData? get currentUser;

  Future<void> submitPermission({
    required String uid,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    Map<String, dynamic>? metadata,
  });
}

class PermissionPageRepositoryImpl implements PermissionPageRepository {
  PermissionPageRepositoryImpl({
    FirebaseAuth? auth,
    LeaveRequestRepository? leaveRequestRepository,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _leaveRequestRepository =
           leaveRequestRepository ?? LeaveRequestRepository();

  final FirebaseAuth _auth;
  final LeaveRequestRepository _leaveRequestRepository;

  @override
  PermissionPageUserData? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return PermissionPageUserData(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
    );
  }

  @override
  Future<void> submitPermission({
    required String uid,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    Map<String, dynamic>? metadata,
  }) {
    return _leaveRequestRepository.submitPermission(
      uid: uid,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      startAt: startAt,
      endAt: endAt,
      reason: reason,
      metadata: metadata,
    );
  }
}
