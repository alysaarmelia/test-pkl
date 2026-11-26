import 'dart:async';

import 'package:get/get.dart';

import '../repositories/attendance_history_repository.dart';
import '../repositories/leave_requests_repository.dart';
import '../shared/models/attendance_record.dart';
import '../shared/models/leave_request.dart';

class AttendanceHistorySection {
  const AttendanceHistorySection({required this.title, required this.items});

  final String title;
  final List<AttendanceRecord> items;
}

class AttendanceHistoryViewModel extends GetxController {
  AttendanceHistoryViewModel({
    AttendanceHistoryRepository? attendanceHistoryRepository,
    LeaveRequestsRepository? leaveRepository,
  }) : _attendanceHistoryRepository =
           attendanceHistoryRepository ?? AttendanceHistoryRepositoryImpl(),
       _leaveRepository = leaveRepository ?? LeaveRequestsRepositoryImpl();

  final AttendanceHistoryRepository _attendanceHistoryRepository;
  final LeaveRequestsRepository _leaveRepository;

  StreamSubscription<List<LeaveRequest>>? _cutiSub;
  StreamSubscription<List<LeaveRequest>>? _izinSub;

  Future<List<AttendanceRecord>> _attendanceFuture = Future.value(
    const <AttendanceRecord>[],
  );
  List<LeaveRequest> _cutiRequests = const <LeaveRequest>[];
  List<LeaveRequest> _izinRequests = const <LeaveRequest>[];
  bool _loadingCuti = false;
  bool _loadingIzin = false;
  Object? _cutiError;
  Object? _izinError;
  bool _isDisposed = false;

  Future<List<AttendanceRecord>> get attendanceFuture => _attendanceFuture;
  String? get currentUserUid => _attendanceHistoryRepository.currentUserUid;
  List<LeaveRequest> get cutiRequests => _cutiRequests;
  List<LeaveRequest> get izinRequests => _izinRequests;
  bool get loadingCuti => _loadingCuti;
  bool get loadingIzin => _loadingIzin;
  Object? get cutiError => _cutiError;
  Object? get izinError => _izinError;

  void _notifySafely() {
    if (_isDisposed || isClosed) return;
    update();
  }

  void init() {
    _attendanceFuture = _attendanceHistoryRepository.loadRecords();

    final uid = currentUserUid;
    if (uid != null && uid.isNotEmpty) {
      _loadingCuti = true;
      _loadingIzin = true;
      _cutiSub = _leaveRepository
          .watchUserRequests(uid: uid, kind: 'cuti')
          .listen(_onCutiData, onError: (error, stack) => _onCutiError(error));
      _izinSub = _leaveRepository
          .watchUserRequests(uid: uid, kind: 'izin')
          .listen(_onIzinData, onError: (error, stack) => _onIzinError(error));
    }

    _notifySafely();
    unawaited(_loadInitialLeaveData(preferServer: true));
  }

  void refreshData() {
    _attendanceFuture = _attendanceHistoryRepository.loadRecords();
    _notifySafely();
    unawaited(_loadInitialLeaveData(preferServer: true));
  }

  List<AttendanceHistorySection> buildSections(List<AttendanceRecord> items) {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    final today = <AttendanceRecord>[];
    final w1 = <AttendanceRecord>[];
    final w2 = <AttendanceRecord>[];
    final w3 = <AttendanceRecord>[];
    final w4 = <AttendanceRecord>[];

    for (final r in items) {
      final d0 = DateTime(r.date.year, r.date.month, r.date.day);
      if (d0 == todayKey) {
        today.add(r);
        continue;
      }
      if (r.date.month == now.month && r.date.year == now.year) {
        switch (_weekOfMonth(r.date)) {
          case 1:
            w1.add(r);
            break;
          case 2:
            w2.add(r);
            break;
          case 3:
            w3.add(r);
            break;
          default:
            w4.add(r);
        }
      }
    }

    final sections = <AttendanceHistorySection>[];
    if (today.isNotEmpty) {
      sections.add(AttendanceHistorySection(title: 'Hari Ini', items: today));
    }
    if (w1.isNotEmpty) {
      sections.add(
        AttendanceHistorySection(title: 'Minggu Pertama', items: w1),
      );
    }
    if (w2.isNotEmpty) {
      sections.add(AttendanceHistorySection(title: 'Minggu Kedua', items: w2));
    }
    if (w3.isNotEmpty) {
      sections.add(AttendanceHistorySection(title: 'Minggu Ketiga', items: w3));
    }
    if (w4.isNotEmpty) {
      sections.add(
        AttendanceHistorySection(title: 'Minggu Keempat', items: w4),
      );
    }
    return sections;
  }

  int _weekOfMonth(DateTime d) {
    final day = d.day;
    final w = ((day - 1) ~/ 7) + 1;
    return w > 4 ? 4 : w;
  }

  void _onCutiData(List<LeaveRequest> data) {
    if (_isDisposed) return;
    _cutiRequests = List<LeaveRequest>.unmodifiable(data);
    _loadingCuti = false;
    _cutiError = null;
    _notifySafely();
  }

  void _onIzinData(List<LeaveRequest> data) {
    if (_isDisposed) return;
    _izinRequests = List<LeaveRequest>.unmodifiable(data);
    _loadingIzin = false;
    _izinError = null;
    _notifySafely();
  }

  void _onCutiError(Object error) {
    if (_isDisposed) return;
    _cutiError = error;
    _loadingCuti = false;
    _notifySafely();
  }

  void _onIzinError(Object error) {
    if (_isDisposed) return;
    _izinError = error;
    _loadingIzin = false;
    _notifySafely();
  }

  Future<void> _loadInitialLeaveData({bool preferServer = false}) async {
    final uid = currentUserUid;
    if (uid == null || uid.isEmpty) return;

    Future<void> loadKind({
      required String kind,
      required void Function(List<LeaveRequest>) onSuccess,
      required void Function(Object error) onError,
      required void Function(bool) setLoading,
    }) async {
      setLoading(true);
      try {
        final result = await _leaveRepository.fetchUserRequests(
          uid: uid,
          kind: kind,
          preferServer: preferServer,
        );
        if (_isDisposed) return;
        onSuccess(List<LeaveRequest>.unmodifiable(result));
      } catch (error) {
        if (_isDisposed) return;
        onError(error);
      }
    }

    await Future.wait([
      loadKind(
        kind: 'cuti',
        onSuccess: (items) {
          _cutiRequests = items;
          _cutiError = null;
          _loadingCuti = false;
          _notifySafely();
        },
        onError: (error) {
          _cutiError = error;
          _loadingCuti = false;
          _notifySafely();
        },
        setLoading: (value) {
          if (value && !_loadingCuti) {
            _loadingCuti = true;
            _notifySafely();
          }
        },
      ),
      loadKind(
        kind: 'izin',
        onSuccess: (items) {
          _izinRequests = items;
          _izinError = null;
          _loadingIzin = false;
          _notifySafely();
        },
        onError: (error) {
          _izinError = error;
          _loadingIzin = false;
          _notifySafely();
        },
        setLoading: (value) {
          if (value && !_loadingIzin) {
            _loadingIzin = true;
            _notifySafely();
          }
        },
      ),
    ]);
  }

  @override
  void onClose() {
    _isDisposed = true;
    unawaited(_cutiSub?.cancel() ?? Future<void>.value());
    unawaited(_izinSub?.cancel() ?? Future<void>.value());
    _cutiSub = null;
    _izinSub = null;
    super.onClose();
  }
}
