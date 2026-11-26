import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminAttendanceRecord {
  AdminAttendanceRecord({
    required this.id,
    required this.path,
    required this.uid,
    required this.raw,
    this.status,
    this.type,
    this.date,
    this.createdAt,
    this.eventTime,
    this.latitude,
    this.longitude,
    this.project,
    this.facePhotoUrl,
    this.facePhotoStoragePath,
    this.locationPhotoUrl,
    this.locationPhotoStoragePath,
    this.userAttendancePath,
  });

  factory AdminAttendanceRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    String? pickUrl(dynamic value) {
      final str = _asString(value)?.trim();
      if (str == null || str.isEmpty) return null;
      return _isLikelyUrl(str) ? str : null;
    }

    String? pickStoragePath(dynamic value) {
      final str = _asString(value)?.trim();
      if (str == null || str.isEmpty) return null;
      return _isLikelyUrl(str) ? null : str;
    }

    final faceUrl =
        pickUrl(data['facePhotoUrl']) ??
        pickUrl(data['faceRecognitionUrl']) ??
        pickUrl(data['faceRecognitionPath']);
    final locationUrl =
        pickUrl(data['locationPhotoUrl']) ??
        pickUrl(data['backPhotoUrl']) ??
        pickUrl(data['backPhotoPath']);

    final faceStorage =
        pickStoragePath(data['facePhotoStoragePath']) ??
        pickStoragePath(data['faceRecognitionPath']);
    final locationStorage =
        pickStoragePath(data['locationPhotoStoragePath']) ??
        pickStoragePath(data['backPhotoPath']);

    final uid = _asString(data['uid']) ?? _asString(data['userUid']) ?? '';

    return AdminAttendanceRecord(
      id: doc.id,
      path: doc.reference.path,
      uid: uid,
      status: _asString(data['status']),
      type: _asString(data['type']),
      date: _asDate(data['date']),
      createdAt: _asDate(data['createdAt']),
      eventTime: _asDateFromMillis(data['time']) ?? _asDate(data['time']),
      latitude: _asDouble(data['latitude'] ?? data['lat']),
      longitude: _asDouble(data['longitude'] ?? data['lon']),
      project: _asString(data['project'] ?? data['job'] ?? data['keterangan']),
      facePhotoUrl: faceUrl,
      facePhotoStoragePath: faceStorage,
      locationPhotoUrl: locationUrl,
      locationPhotoStoragePath: locationStorage,
      userAttendancePath: _asString(data['userAttendancePath']),
      raw: data,
    );
  }

  final String id;
  final String path;
  final String uid;
  final Map<String, dynamic> raw;
  final String? status;
  final String? type;
  final DateTime? date;
  final DateTime? createdAt;
  final DateTime? eventTime;
  final double? latitude;
  final double? longitude;
  final String? project;
  final String? facePhotoUrl;
  final String? facePhotoStoragePath;
  final String? locationPhotoUrl;
  final String? locationPhotoStoragePath;
  final String? userAttendancePath;

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasFacePhoto =>
      _isLikelyUrl(facePhotoUrl) ||
      (facePhotoStoragePath != null && facePhotoStoragePath!.trim().isNotEmpty);
  bool get hasLocationPhoto =>
      _isLikelyUrl(locationPhotoUrl) ||
      (locationPhotoStoragePath != null &&
          locationPhotoStoragePath!.trim().isNotEmpty);

  DateTime? get effectiveDateTime => eventTime ?? createdAt ?? date;

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      if ('$value'.length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
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
        if (value.length == 10) {
          return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
    }
    return null;
  }

  static DateTime? _asDateFromMillis(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final millis = int.tryParse(value);
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _isLikelyUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }
}

class AdminUserSummary {
  AdminUserSummary({
    required this.uid,
    required this.displayName,
    this.email,
    this.pin,
    this.department,
    this.team,
    this.role,
    this.photoUrl,
    Map<String, dynamic>? raw,
  }) : raw = raw ?? const <String, dynamic>{};

  factory AdminUserSummary.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    String? pickFirstNonEmpty(List<dynamic> values) {
      for (final value in values) {
        if (value == null) continue;
        final str = value.toString().trim();
        if (str.isNotEmpty) return str;
      }
      return null;
    }

    final displayName =
        pickFirstNonEmpty([
          data['name'],
          data['fullName'],
          data['displayName'],
          data['username'],
          data['email'],
        ]) ??
        doc.id;

    final department = pickFirstNonEmpty([
      data['department'],
      data['division'],
      data['team'],
      data['role'],
    ]);

    return AdminUserSummary(
      uid: doc.id,
      displayName: displayName,
      email: pickFirstNonEmpty([
        data['email'],
        data['userEmail'],
        data['contactEmail'],
      ]),
      pin: pickFirstNonEmpty([
        data['pin'],
        data['chatPin'],
        data['userPin'],
        data['PIN'],
      ]),
      department: department,
      team: pickFirstNonEmpty([
        data['team'],
        data['division'],
        data['department'],
      ]),
      role: pickFirstNonEmpty([
        data['role'],
        data['position'],
        data['jobTitle'],
      ]),
      photoUrl: pickFirstNonEmpty([
        data['photoUrl'],
        data['photoURL'],
        data['avatarUrl'],
        data['profilePhoto'],
      ]),
      raw: data,
    );
  }

  final String uid;
  final String displayName;
  final String? email;
  final String? pin;
  final String? department;
  final String? team;
  final String? role;
  final String? photoUrl;
  final Map<String, dynamic> raw;

  String? get secondaryLabel =>
      department ?? team ?? role ?? (email?.isNotEmpty == true ? email : null);
}

class AdminAttendanceRepository {
  AdminAttendanceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminAttendanceRecord>> watchRecentAttendance({int limit = 200}) {
    return _firestore
        .collection('attendance_feed')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminAttendanceRecord.fromSnapshot)
              .where((record) => record.uid.isNotEmpty)
              .toList(),
        );
  }

  Stream<List<AdminAttendanceRecord>> watchAttendanceForRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _firestore
        .collection('attendance_feed')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminAttendanceRecord.fromSnapshot)
              .where((record) => record.uid.isNotEmpty)
              .toList(),
        );
  }

  Stream<List<AdminUserSummary>> watchAllUsers() {
    return _firestore.collection('users').snapshots().map(
      (snap) => snap.docs.map(AdminUserSummary.fromSnapshot).toList(),
    );
  }

  Future<List<AdminAttendanceRecord>> fetchAttendanceForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _firestore
        .collection('attendance_feed')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: false)
        .get();
    return snapshot.docs
        .map(AdminAttendanceRecord.fromSnapshot)
        .where((record) => record.uid.isNotEmpty)
        .toList();
  }

  Future<AdminUserSummary?> fetchUserSummary(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AdminUserSummary.fromSnapshot(doc);
  }

  Future<void> updateAttendanceStatus(
    AdminAttendanceRecord record, {
    required String status,
    required String type,
    required String label,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final normalizedUid = record.uid.trim();
    if (normalizedUid.isEmpty) return;

    // Force mobile-app friendly values for 'Hadir' status
    // Use exact comparison to avoid 'Tidak Hadir' being caught as 'Hadir'
    bool isHadir = (label.toLowerCase() == 'hadir') || 
                   (status.toLowerCase() == 'hadir') || 
                   (status.toLowerCase() == 'checkin');
    
    String finalStatus = isHadir ? 'checkin' : status;
    String finalType = isHadir ? 'masuk' : type;
    String finalLabel = isHadir ? 'Hadir' : label;

    final updateData = <String, dynamic>{
      'uid': normalizedUid,
      'userUid': normalizedUid,
      'status': finalStatus,
      'type': finalType,
      'statusLabel': finalLabel,
      'adminStatus': {
        'status': finalStatus,
        'type': finalType,
        'label': finalLabel,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser?.uid,
        'updatedByEmail': currentUser?.email,
      },
      'manualByAdmin': true,
      'note': 'Status diubah menjadi $finalLabel oleh Admin',
    };

    if (isHadir) {
      updateData['attendanceStatus'] = 'hadir';
      updateData['checkInStatus'] = 'hadir';
    } else {
      updateData['attendanceStatus'] = 'tidakhadir';
      updateData['checkInStatus'] = 'tidakhadir';
    }

    final batch = _firestore.batch();
    final start = DateTime(record.date!.year, record.date!.month, record.date!.day);
    final end = start.add(const Duration(days: 1));
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    // 1. Update ALL records in attendance_feed for this user and date
    final userFeedSnapshot = await _firestore
        .collection('attendance_feed')
        .where('userUid', isEqualTo: normalizedUid)
        .get();

    final allFeedDocs = userFeedSnapshot.docs.where((doc) {
      final data = doc.data();
      final d = _toDateTime(data['date'] ?? data['createdAt'] ?? data['timestamp'] ?? data['time']);
      if (d != null) {
        final day = DateTime(d.year, d.month, d.day);
        return day.isAtSameMomentAs(start);
      }
      return false;
    }).toList();

    for (final doc in allFeedDocs) {
      batch.update(doc.reference, updateData);
    }
    
    // Also ensure the specific record passed is updated if not already caught
    bool recordCaught = allFeedDocs.any((doc) => doc.reference.path == record.path);
    if (!recordCaught) {
      batch.update(_firestore.doc(record.path), updateData);
    }

    // 2. Sync to user subcollections
    final collections = ['attendance', 'absen'];
    
    for (final col in collections) {
      final userRecordsSnapshot = await _firestore
          .collection('users')
          .doc(normalizedUid)
          .collection(col)
          .get();
      
      final matchingDocs = userRecordsSnapshot.docs.where((doc) {
        final data = doc.data();
        final d = _toDateTime(data['date'] ?? data['createdAt'] ?? data['timestamp'] ?? data['time']);
        if (d != null) {
          final day = DateTime(d.year, d.month, d.day);
          return day.isAtSameMomentAs(start);
        }
        return false;
      }).toList();

      if (matchingDocs.isNotEmpty) {
        for (final doc in matchingDocs) {
          batch.update(doc.reference, updateData);
        }
      } else {
        // Record doesn't exist in this collection, CREATE IT
        final newDocRef = _firestore
            .collection('users')
            .doc(normalizedUid)
            .collection(col)
            .doc();
            
        final newData = Map<String, dynamic>.from(updateData);
        newData['date'] = Timestamp.fromDate(start);
        newData['time'] = startMs;
        newData['createdAt'] = FieldValue.serverTimestamp();
        
        batch.set(newDocRef, newData);
      }
    }

    await batch.commit();
  }

  Future<void> createManualAttendanceRecord({
    required String uid,
    required String? userName,
    required String? userEmail,
    required String status,
    required String type,
    required String label,
    required DateTime date,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final normalizedUid = uid.trim();
    
    // Ensure date is at 00:00:00 to match mobile app's 'onlyDate' logic
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final timestamp = Timestamp.fromDate(normalizedDate);

    // Force mobile-app friendly values for 'Hadir' status
    bool isHadir = (label.toLowerCase() == 'hadir') || 
                   (status.toLowerCase() == 'hadir') || 
                   (status.toLowerCase() == 'checkin');

    // Use passed parameters but normalize for mobile app compatibility if it's 'Hadir'
    String finalStatus = isHadir ? 'checkin' : status; 
    String finalType = isHadir ? 'masuk' : type;
    String finalLabel = isHadir ? 'Hadir' : label;

    // 1. Prepare refs for all possible mobile app locations
    final userAttendanceRef = _firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('attendance')
        .doc();
        
    final userAbsenRef = _firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('absen')
        .doc();

    final recordData = <String, dynamic>{
      'uid': normalizedUid,
      'userUid': normalizedUid,
      'userId': normalizedUid,
      'userName': userName,
      'userEmail': userEmail,
      'status': finalStatus,
      'type': finalType,
      'statusLabel': finalLabel,
      'date': timestamp,
      'createdAt': FieldValue.serverTimestamp(),
      'time': normalizedDate.millisecondsSinceEpoch,
      'serverTime': FieldValue.serverTimestamp(),
      'source': 'admin_dashboard',
      'manualByAdmin': true,
      'userAttendancePath': userAttendanceRef.path,
      'adminStatus': {
        'status': finalStatus,
        'type': finalType,
        'label': finalLabel,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser?.uid,
        'updatedByEmail': currentUser?.email,
      },
      'attendanceStatus': isHadir ? 'hadir' : 'tidakhadir',
      'checkInStatus': isHadir ? 'hadir' : 'tidakhadir',
    };

    // Use a batch to write to all locations simultaneously
    final batch = _firestore.batch();
    batch.set(userAttendanceRef, recordData);
    batch.set(userAbsenRef, recordData);
    
    // 2. Add to global feed
    final feedRef = _firestore.collection('attendance_feed').doc();
    batch.set(feedRef, recordData);
    
    await batch.commit();
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
