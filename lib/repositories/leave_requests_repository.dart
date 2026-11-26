import '../shared/models/leave_request.dart';
import '../shared/services/leave_request_repository.dart';

abstract class LeaveRequestsRepository {
  Future<String> submitLeave({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    Map<String, dynamic>? metadata,
    List<LeaveAttachment> attachments = const <LeaveAttachment>[],
  });

  Future<String> submitPermission({
    required String uid,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    Map<String, dynamic>? metadata,
    List<LeaveAttachment> attachments = const <LeaveAttachment>[],
  });

  Stream<List<LeaveRequest>> watchUserRequests({
    required String uid,
    String? kind,
    int limit = 60,
  });

  Future<List<LeaveRequest>> fetchUserRequests({
    required String uid,
    String? kind,
    int limit = 60,
    bool preferServer = false,
  });

  Stream<LeaveRequest?> watchRequestById(String requestId);

  Future<String> fetchUserNameByUid(String uid);
}

class LeaveRequestsRepositoryImpl implements LeaveRequestsRepository {
  LeaveRequestsRepositoryImpl({LeaveRequestRepository? repository})
    : _repository = repository ?? LeaveRequestRepository();

  final LeaveRequestRepository _repository;

  @override
  Future<String> submitLeave({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    Map<String, dynamic>? metadata,
    List<LeaveAttachment> attachments = const <LeaveAttachment>[],
  }) {
    return _repository.submitLeave(
      uid: uid,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      metadata: metadata,
      attachments: attachments,
    );
  }

  @override
  Future<String> submitPermission({
    required String uid,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    Map<String, dynamic>? metadata,
    List<LeaveAttachment> attachments = const <LeaveAttachment>[],
  }) {
    return _repository.submitPermission(
      uid: uid,
      startAt: startAt,
      endAt: endAt,
      reason: reason,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      metadata: metadata,
      attachments: attachments,
    );
  }

  @override
  Stream<List<LeaveRequest>> watchUserRequests({
    required String uid,
    String? kind,
    int limit = 60,
  }) {
    return _repository.watchUserRequests(uid: uid, kind: kind, limit: limit);
  }

  @override
  Future<List<LeaveRequest>> fetchUserRequests({
    required String uid,
    String? kind,
    int limit = 60,
    bool preferServer = false,
  }) {
    return _repository.fetchUserRequests(
      uid: uid,
      kind: kind,
      limit: limit,
      preferServer: preferServer,
    );
  }

  @override
  Stream<LeaveRequest?> watchRequestById(String requestId) {
    return _repository.watchRequestById(requestId);
  }

  @override
  Future<String> fetchUserNameByUid(String uid) {
    return _repository.fetchUserNameByUid(uid);
  }
}
