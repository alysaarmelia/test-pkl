import 'dart:async';

import 'package:get/get.dart';

import '../repositories/profile_card_repository.dart';
import '../shared/models/attendance_window.dart';
import '../shared/models/leave_request.dart';

class ProfileCardViewModel extends GetxController {
  ProfileCardViewModel({ProfileCardRepository? repository})
    : _repository = repository ?? ProfileCardRepositoryImpl();

  final ProfileCardRepository _repository;

  String? _currentUserUid;
  Stream<ProfileCardUserProfile?> _userProfileStream =
      const Stream<ProfileCardUserProfile?>.empty();
  Stream<List<ProfileCardAttendanceEntry>> _attendanceStream =
      const Stream<List<ProfileCardAttendanceEntry>>.empty();
  Stream<List<ProfileCardAttendanceEntry>> _absenStream =
      const Stream<List<ProfileCardAttendanceEntry>>.empty();
  Stream<List<ProfileCardAttendanceEntry>> _userAttendanceStream =
      const Stream<List<ProfileCardAttendanceEntry>>.empty();
  Stream<List<LeaveRequest>> _leaveRequestsStream =
      const Stream<List<LeaveRequest>>.empty();
  Stream<AttendanceWindow?> _windowStream =
      const Stream<AttendanceWindow?>.empty();

  StreamSubscription<String?>? _authSubscription;

  String? get currentUserUid => _currentUserUid;
  Stream<ProfileCardUserProfile?> get userProfileStream => _userProfileStream;
  Stream<List<ProfileCardAttendanceEntry>> get attendanceStream =>
      _attendanceStream;
  Stream<List<ProfileCardAttendanceEntry>> get absenStream => _absenStream;
  Stream<List<ProfileCardAttendanceEntry>> get userAttendanceStream =>
      _userAttendanceStream;
  Stream<List<LeaveRequest>> get leaveRequestsStream => _leaveRequestsStream;
  Stream<AttendanceWindow?> get windowStream => _windowStream;

  @override
  void onInit() {
    super.onInit();
    _bindAuthState(_repository.currentUserUid);
    _authSubscription = _repository.watchAuthUserIds().listen(_bindAuthState);
  }

  @override
  void onClose() {
    unawaited(_authSubscription?.cancel() ?? Future<void>.value());
    _authSubscription = null;
    super.onClose();
  }

  void _bindAuthState(String? uid) {
    _windowStream = _repository.watchWindow(DateTime.now());
    if (uid == null || uid.isEmpty) {
      _currentUserUid = null;
      _userProfileStream = const Stream<ProfileCardUserProfile?>.empty();
      _attendanceStream =
          const Stream<List<ProfileCardAttendanceEntry>>.empty();
      _absenStream = const Stream<List<ProfileCardAttendanceEntry>>.empty();
      _userAttendanceStream =
          const Stream<List<ProfileCardAttendanceEntry>>.empty();
      _leaveRequestsStream = const Stream<List<LeaveRequest>>.empty();
      _windowStream = const Stream<AttendanceWindow?>.empty();
      _notify();
      return;
    }

    if (_currentUserUid == uid) {
      return;
    }

    _currentUserUid = uid;
    _userProfileStream = _repository.watchUserProfile(uid);
    _attendanceStream = _repository.watchAttendance(uid);
    _absenStream = _repository.watchAbsen(uid);
    _userAttendanceStream = _repository.watchUserAttendance(uid);
    _leaveRequestsStream = _repository.watchLeaveRequests(uid: uid);
    _notify();
  }

  void _notify() {
    if (isClosed) return;
    update();
  }
}
