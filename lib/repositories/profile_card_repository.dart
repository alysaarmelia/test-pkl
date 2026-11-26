import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/models/attendance_window.dart';
import '../shared/models/leave_request.dart';
import '../shared/services/attendance_window_repository.dart';
import '../shared/services/leave_request_repository.dart';

class ProfileCardUserProfile {
  const ProfileCardUserProfile({
    required this.pin,
    required this.name,
    required this.role,
    required this.photoUrl,
  });

  final String pin;
  final String name;
  final String role;
  final String photoUrl;
}

class ProfileCardAttendanceEntry {
  const ProfileCardAttendanceEntry({
    required this.id,
    required this.date,
    required this.status,
    required this.timestamp,
  });

  final String id;
  final DateTime date;
  final String status;
  final int timestamp;
}

abstract class ProfileCardRepository {
  String? get currentUserUid;

  Stream<String?> watchAuthUserIds();

  Stream<ProfileCardUserProfile?> watchUserProfile(String uid);

  Stream<List<ProfileCardAttendanceEntry>> watchAttendance(String uid);

  Stream<List<ProfileCardAttendanceEntry>> watchAbsen(String uid);

  Stream<List<ProfileCardAttendanceEntry>> watchUserAttendance(String uid);

  Stream<List<LeaveRequest>> watchLeaveRequests({
    required String uid,
    int limit,
  });

  Stream<AttendanceWindow?> watchWindow(DateTime date);
}

class ProfileCardRepositoryImpl implements ProfileCardRepository {
  ProfileCardRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    LeaveRequestRepository? leaveRequestRepository,
    AttendanceWindowRepository? attendanceWindowRepository,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _leaveRequestRepository =
           leaveRequestRepository ?? LeaveRequestRepository(),
       _attendanceWindowRepository =
           attendanceWindowRepository ?? AttendanceWindowRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LeaveRequestRepository _leaveRequestRepository;
  final AttendanceWindowRepository _attendanceWindowRepository;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Stream<String?> watchAuthUserIds() {
    return _auth.userChanges().map((user) => user?.uid);
  }

  @override
  Stream<ProfileCardUserProfile?> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;

      final pin = _firstNonEmpty([
        data['pin'],
        data['chatPin'],
        data['userPin'],
        data['PIN'],
      ]);
      final name = _firstNonEmpty([
        data['name'],
        data['displayName'],
        data['fullName'],
        data['username'],
      ]);
      final role = _firstNonEmpty([
        data['role'],
        data['team'],
        data['department'],
        data['division'],
      ]);
      final photoUrl = _firstNonEmpty([
        data['photoUrl'],
        data['avatarUrl'],
        data['profilePhoto'],
      ]);

      return ProfileCardUserProfile(
        pin: pin,
        name: name,
        role: role,
        photoUrl: photoUrl,
      );
    });
  }

  @override
  Stream<List<ProfileCardAttendanceEntry>> watchAttendance(String uid) {
    return _firestore
        .collectionGroup('attendance')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map(_mapAttendanceSnapshot);
  }

  @override
  Stream<List<ProfileCardAttendanceEntry>> watchAbsen(String uid) {
    return _firestore
        .collectionGroup('absen')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map(_mapAttendanceSnapshot);
  }

  @override
  Stream<List<ProfileCardAttendanceEntry>> watchUserAttendance(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .snapshots()
        .map(_mapAttendanceSnapshot);
  }

  @override
  Stream<List<LeaveRequest>> watchLeaveRequests({
    required String uid,
    int limit = 200,
  }) {
    return _leaveRequestRepository
        .watchUserRequests(uid: uid, limit: limit)
        .map((items) {
          final sorted = List<LeaveRequest>.of(items)
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
          return List<LeaveRequest>.unmodifiable(sorted);
        });
  }

  @override
  Stream<AttendanceWindow?> watchWindow(DateTime date) {
    return _attendanceWindowRepository.watchWindow(date);
  }

  List<ProfileCardAttendanceEntry> _mapAttendanceSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final entries = <ProfileCardAttendanceEntry>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rawTimestamp =
          data['date'] ?? data['createdAt'] ?? data['timestamp'] ?? data['time'];
      final date = _extractDate(rawTimestamp);
      final timestamp = _extractMillis(rawTimestamp);
      
      if (date == null) continue;

      final status =
          (data['status'] ??
                  data['type'] ??
                  data['kind'] ??
                  data['action'] ??
                  '')
              .toString();

      entries.add(
        ProfileCardAttendanceEntry(
          id: doc.id,
          date: date,
          status: status,
          timestamp: timestamp,
        ),
      );
    }
    return List<ProfileCardAttendanceEntry>.unmodifiable(entries);
  }

  int _extractMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is String) {
      final dt = DateTime.tryParse(value);
      return dt?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  DateTime? _extractDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
