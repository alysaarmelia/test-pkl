import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:cipta_vera_mandiri_digital/app/services/app_notification_service.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/leave_request.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/material_request.dart';

class UserActivityNotificationService {
  UserActivityNotificationService._();

  static final UserActivityNotificationService _instance =
      UserActivityNotificationService._();
  factory UserActivityNotificationService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _appNotifications = AppNotificationService();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _leaveSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _materialSub;

  bool _attendanceLoaded = false;
  final Set<String> _knownAttendanceIds = <String>{};
  bool _attendancePermissionDenied = false;

  bool _leaveLoaded = false;
  final Map<String, LeaveRequestStatus> _leaveStatuses =
      <String, LeaveRequestStatus>{};
  bool _leavePermissionDenied = false;

  bool _materialLoaded = false;
  final Map<String, String> _materialStatuses = <String, String>{};
  bool _materialPermissionDenied = false;

  void start() {
    _authSub ??= _auth.authStateChanges().listen((user) {
      _resetSubscriptions();
      if (user != null) {
        debugPrint(
          '[UserActivityNotification] Starting listeners for uid=${user.uid}',
        );
        _subscribeToAttendance(user.uid);
        _subscribeToLeaveRequests(user.uid);
        _subscribeToMaterialRequests(user.uid);
      } else {
        debugPrint('[UserActivityNotification] No authenticated user.');
      }
    });
  }

  void dispose() {
    _resetSubscriptions();
    _authSub?.cancel();
    _authSub = null;
  }

  void _resetSubscriptions() {
    _attendanceSub?.cancel();
    _attendanceSub = null;
    _leaveSub?.cancel();
    _leaveSub = null;
    _materialSub?.cancel();
    _materialSub = null;

    _attendanceLoaded = false;
    _leaveLoaded = false;
    _materialLoaded = false;

    _knownAttendanceIds.clear();
    _leaveStatuses.clear();
    _materialStatuses.clear();
    _attendancePermissionDenied = false;
    _leavePermissionDenied = false;
    _materialPermissionDenied = false;
  }

  void _subscribeToAttendance(String uid) {
    if (_attendancePermissionDenied) return;
    _attendanceSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .orderBy('createdAt')
        .snapshots()
        .listen(
          (snapshot) async {
            final now = DateTime.now();

            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added) continue;
              final data = change.doc.data();
              if (data == null) continue;

              final alreadyKnown = _knownAttendanceIds.contains(change.doc.id);
              final createdAt =
                  _asDate(data['createdAt']) ?? _asDate(data['date']);
              final isRecent =
                  createdAt != null &&
                  now.difference(createdAt.toLocal()).abs() <=
                      const Duration(minutes: 3);
              final hasPendingWrites = change.doc.metadata.hasPendingWrites;

              _knownAttendanceIds.add(change.doc.id);

              if (!_attendanceLoaded && !hasPendingWrites && !isRecent) {
                debugPrint(
                  '[UserActivityNotification] Skip historical attendance '
                  '${change.doc.id} createdAt=$createdAt',
                );
                continue;
              }
              if (alreadyKnown) continue;

              debugPrint(
                '[UserActivityNotification] New attendance ${change.doc.id} '
                'recent=$isRecent pending=$hasPendingWrites data=$data',
              );
              await _handleAttendanceRecord(docId: change.doc.id, data: data);
            }

            _attendanceLoaded = true;
          },
          onError: (error, stack) {
            _handleStreamError(
              stream: 'attendance',
              error: error,
              stack: stack,
              onPermissionDenied: () {
                _attendancePermissionDenied = true;
                _attendanceSub?.cancel();
                _attendanceSub = null;
              },
            );
          },
        );
  }

  Future<void> _handleAttendanceRecord({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final statusRaw =
        _asString(data['status']) ?? _asString(data['type']) ?? '';
    final lower = statusRaw.toLowerCase();
    final bool isCheckIn =
        lower.contains('checkin') || lower == 'in' || lower == 'masuk';
    final bool isCheckOut =
        lower.contains('checkout') || lower == 'out' || lower == 'pulang';

    final createdAt =
        _asDate(data['createdAt']) ?? _asDate(data['date']) ?? DateTime.now();
    final project = _asString(data['project']) ?? '';

    String title;
    if (isCheckIn) {
      title = 'Check-in berhasil';
    } else if (isCheckOut) {
      title = 'Check-out berhasil';
    } else {
      title = 'Absensi terekam';
    }

    final parts = <String>['Pukul ${_formatTime(createdAt)}'];
    if (project.trim().isNotEmpty) {
      parts.add(project.trim());
    }
    final body = parts.isEmpty
        ? 'Data absensi berhasil disimpan.'
        : parts.join(' • ');

    debugPrint(
      '[UserActivityNotification] Trigger notification: $title | $body',
    );
    await _appNotifications.addNotification(
      type: AppNotificationType.attendance,
      title: title,
      body: body,
      data: {
        'status': statusRaw,
        'attendanceId': docId,
        'project': project,
        'timestamp': createdAt.toIso8601String(),
      },
      showLocalNotification: true,
      showInAppBanner: true,
      payload: docId,
    );
  }

  void _subscribeToLeaveRequests(String uid) {
    if (_leavePermissionDenied) return;
    _leaveSub = _firestore
        .collection('leave_requests')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) async {
            if (!_leaveLoaded) {
              for (final doc in snapshot.docs) {
                final request = LeaveRequest.fromSnapshot(doc);
                _leaveStatuses[doc.id] = request.status;
              }
              _leaveLoaded = true;
              return;
            }

            for (final change in snapshot.docChanges) {
              final data = change.doc.data();
              if (data == null) continue;
              final request = LeaveRequest.fromSnapshot(change.doc);
              final prevStatus = _leaveStatuses[request.id];
              _leaveStatuses[request.id] = request.status;

              if (request.status == LeaveRequestStatus.pending) {
                continue;
              }

              if (prevStatus == request.status) {
                continue;
              }
              debugPrint(
                '[UserActivityNotification] Leave status change '
                '${request.id}: $prevStatus -> ${request.status}',
              );
              await _handleLeaveDecision(request);
            }
          },
          onError: (error, stack) {
            _handleStreamError(
              stream: 'leave_requests',
              error: error,
              stack: stack,
              onPermissionDenied: () {
                _leavePermissionDenied = true;
                _leaveSub?.cancel();
                _leaveSub = null;
              },
            );
          },
        );
  }

  Future<void> _handleLeaveDecision(LeaveRequest request) async {
    final bool approved = request.status == LeaveRequestStatus.approved;
    final kindLabel = request.isLeave
        ? 'Cuti'
        : (request.isPermission ? 'Izin' : 'Pengajuan');
    final title = '$kindLabel ${approved ? 'disetujui' : 'ditolak'}';

    final dateRange = _formatDateRange(request.startAt, request.endAt);
    final note = request.decisionNote?.trim();

    final parts = <String>[];
    if (dateRange.isNotEmpty) parts.add(dateRange);
    if (note != null && note.isNotEmpty) parts.add(note);
    final approver = request.approverName?.trim();
    if (approver != null && approver.isNotEmpty) {
      parts.add('Oleh $approver');
    }
    final body = parts.isEmpty
        ? 'Periksa detail pengajuan Anda.'
        : parts.join(' • ');

    debugPrint(
      '[UserActivityNotification] Trigger leave notification '
      '${request.id}: $title | $body',
    );
    await _appNotifications.addNotification(
      type: AppNotificationType.leave,
      title: title,
      body: body,
      data: {
        'requestId': request.id,
        'status': request.status.name,
        'startAt': request.startAt.toIso8601String(),
        'endAt': request.endAt.toIso8601String(),
      },
      showLocalNotification: true,
      showInAppBanner: true,
      payload: request.id,
    );
  }

  void _subscribeToMaterialRequests(String uid) {
    if (_materialPermissionDenied) return;
    _materialSub = _firestore
        .collection('material_requests')
        .where('requesterUid', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) async {
            if (!_materialLoaded) {
              for (final doc in snapshot.docs) {
                final request = MaterialRequest.fromSnapshot(doc);
                _materialStatuses[doc.id] = request.status;
              }
              _materialLoaded = true;
              return;
            }

            for (final change in snapshot.docChanges) {
              final data = change.doc.data();
              if (data == null) continue;
              final request = MaterialRequest.fromSnapshot(change.doc);
              final previous = _materialStatuses[request.id];
              _materialStatuses[request.id] = request.status;

              if (previous == request.status) continue;
              if (request.status == MaterialRequestStatus.pending) continue;

              debugPrint(
                '[UserActivityNotification] Material status change '
                '${request.id}: $previous -> ${request.status}',
              );
              await _handleMaterialStatus(request);
            }
          },
          onError: (error, stack) {
            _handleStreamError(
              stream: 'material_requests',
              error: error,
              stack: stack,
              onPermissionDenied: () {
                _materialPermissionDenied = true;
                _materialSub?.cancel();
                _materialSub = null;
              },
            );
          },
        );
  }

  Future<void> _handleMaterialStatus(MaterialRequest request) async {
    String? title;
    switch (request.status) {
      case MaterialRequestStatus.approved:
        title = 'Permintaan material disetujui';
        break;
      case MaterialRequestStatus.delivered:
        title = 'Material siap diterima';
        break;
      default:
        title = null;
    }
    if (title == null) return;

    final parts = <String>[];
    if (request.projectName.trim().isNotEmpty) {
      parts.add(request.projectName.trim());
    }
    final approver = request.approverName.trim();
    if (approver.isNotEmpty) {
      parts.add('Oleh $approver');
    }
    final receiver = request.receivedBy?.trim();
    if (receiver != null && receiver.isNotEmpty) {
      parts.add('Dikonfirmasi oleh $receiver');
    }
    final body = parts.isEmpty
        ? 'Periksa detail permintaan Anda.'
        : parts.join(' • ');

    debugPrint(
      '[UserActivityNotification] Trigger material notification '
      '${request.id}: $title | $body',
    );
    await _appNotifications.addNotification(
      type: AppNotificationType.material,
      title: title,
      body: body,
      data: {
        'requestId': request.id,
        'status': request.status,
        'project': request.projectName,
      },
      showLocalNotification: true,
      showInAppBanner: true,
      payload: request.id,
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final startDate = _formatDate(start);
    final endDate = _formatDate(end);
    if (startDate == endDate) {
      return startDate;
    }
    return '$startDate - $endDate';
  }

  String _formatDate(DateTime value) {
    final months = <String>[
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final local = value.toLocal();
    final month = months[(local.month - 1).clamp(0, months.length - 1)];
    return '${local.day} $month ${local.year}';
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _handleStreamError({
    required String stream,
    required Object error,
    required StackTrace stack,
    required VoidCallback onPermissionDenied,
  }) {
    debugPrint('[UserActivityNotification] $stream stream error: $error');
    debugPrint(stack.toString());
    if (error is FirebaseException && error.code == 'permission-denied') {
      debugPrint(
        '[UserActivityNotification] $stream listener disabled due to permission-denied.',
      );
      onPermissionDenied();
    }
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final asInt = int.tryParse(value);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
    }
    return null;
  }
}
