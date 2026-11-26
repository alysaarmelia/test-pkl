import 'dart:async';

import 'package:get/get.dart';

import '../repositories/leave_requests_repository.dart';
import '../shared/models/leave_request.dart';

class LeaveRequestCardViewModel extends GetxController {
  LeaveRequestCardViewModel({
    required LeaveRequest initialRequest,
    LeaveRequestsRepository? repository,
  }) : _repository = repository ?? LeaveRequestsRepositoryImpl(),
       _request = initialRequest {
    _applyBaseNames(initialRequest);
    _subscribe(initialRequest.id);
    unawaited(_resolveNames(initialRequest));
  }

  final LeaveRequestsRepository _repository;

  LeaveRequest _request;
  String _approverName = '';
  String _requesterName = '';
  StreamSubscription<LeaveRequest?>? _requestSub;
  bool _disposed = false;

  LeaveRequest get request => _request;
  String get approverName => _approverName;
  String get requesterName => _requesterName;

  void updateFromParent(LeaveRequest value) {
    final previous = _request;
    final requestChanged = previous.id != value.id;

    final shouldRefreshNames =
        requestChanged ||
        previous.approverUid != value.approverUid ||
        previous.approverEmail != value.approverEmail ||
        previous.approverName != value.approverName ||
        previous.uid != value.uid ||
        previous.requesterEmail != value.requesterEmail ||
        previous.requesterName != value.requesterName ||
        previous.status != value.status;

    _request = value;
    _applyBaseNames(value);

    if (requestChanged) {
      _subscribe(value.id);
    }
    if (shouldRefreshNames) {
      unawaited(_resolveNames(value));
    }
  }

  void _subscribe(String requestId) {
    _requestSub?.cancel();
    _requestSub = _repository.watchRequestById(requestId).listen((updated) {
      if (_disposed || updated == null || updated.id != _request.id) return;
      _request = updated;
      _applyBaseNames(updated);
      _notifySafely();
      unawaited(_resolveNames(updated));
    }, onError: (_) {});
  }

  void _applyBaseNames(LeaveRequest request) {
    _approverName = _initialApproverName(request);
    _requesterName = _initialRequesterName(request);
  }

  Future<void> _resolveNames(LeaveRequest request) async {
    var nextApprover = _initialApproverName(request);
    var nextRequester = _initialRequesterName(request);

    final approverUid = request.approverUid?.trim();
    final needsApproverLookup =
        (request.approverName?.trim().isEmpty ?? true) &&
        approverUid != null &&
        approverUid.isNotEmpty;

    if (needsApproverLookup) {
      final fetched = await _repository.fetchUserNameByUid(approverUid);
      if (fetched.isNotEmpty) {
        nextApprover = fetched;
      }
    }

    final requesterUid = request.uid.trim();
    final needsRequesterLookup =
        (request.requesterName?.trim().isEmpty ?? true) &&
        requesterUid.isNotEmpty;

    if (needsRequesterLookup) {
      final fetched = await _repository.fetchUserNameByUid(requesterUid);
      if (fetched.isNotEmpty) {
        nextRequester = fetched;
      }
    }

    if (_disposed || request.id != _request.id) return;
    if (nextApprover == _approverName && nextRequester == _requesterName) {
      return;
    }
    _approverName = nextApprover;
    _requesterName = nextRequester;
    _notifySafely();
  }

  String _initialApproverName(LeaveRequest request) {
    final approverName = request.approverName?.trim();
    if (approverName != null && approverName.isNotEmpty) return approverName;
    final email = request.approverEmail?.trim();
    if (email != null && email.isNotEmpty) return _prettyNameFromEmail(email);
    final uid = request.approverUid?.trim();
    if (uid != null && uid.isNotEmpty) return uid;
    return '';
  }

  String _initialRequesterName(LeaveRequest request) {
    final requesterName = request.requesterName?.trim();
    if (requesterName != null && requesterName.isNotEmpty) return requesterName;
    final email = request.requesterEmail?.trim();
    if (email != null && email.isNotEmpty) return _prettyNameFromEmail(email);
    return request.uid;
  }

  String _prettyNameFromEmail(String email) {
    final prefix = email.split('@').first;
    final parts = prefix
        .split(RegExp(r'[._\-]+'))
        .where((segment) => segment.isNotEmpty);
    if (parts.isEmpty) return email;
    return parts
        .map(
          (segment) =>
              segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  void _notifySafely() {
    if (_disposed || isClosed) return;
    update();
  }

  @override
  void onClose() {
    _disposed = true;
    unawaited(_requestSub?.cancel() ?? Future<void>.value());
    _requestSub = null;
    super.onClose();
  }
}
