import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AttendanceUserData {
  const AttendanceUserData({
    required this.uid,
    required this.displayName,
    this.email,
  });

  final String uid;
  final String displayName;
  final String? email;
}

class UploadedAttendanceMedia {
  const UploadedAttendanceMedia({
    this.faceUrl,
    this.faceStoragePath,
    this.locationUrl,
    this.locationStoragePath,
    this.faceUploadFailed = false,
    this.locationUploadFailed = false,
  });

  final String? faceUrl;
  final String? faceStoragePath;
  final String? locationUrl;
  final String? locationStoragePath;
  final bool faceUploadFailed;
  final bool locationUploadFailed;

  bool get hasFace => faceUrl != null && faceUrl!.isNotEmpty;
  bool get hasLocation => locationUrl != null && locationUrl!.isNotEmpty;
}

abstract class AttendanceRepository {
  String? get currentUid;

  Future<AttendanceUserData?> loadCurrentUserData();

  Future<DateTime?> fetchAttendanceToday({
    required String userId,
    DateTime? now,
  });

  Future<void> saveCheckInToFirestore({
    required String uid,
    required String? userName,
    required String? userEmail,
    required Map<String, dynamic> attendanceData,
  });

  Future<UploadedAttendanceMedia> uploadAttendanceMedia({
    required String userId,
    required DateTime timestamp,
    File? facePhoto,
    File? locationPhoto,
    int maxDimension = 1600,
    int minCompressBytes = 600 * 1024,
  });
}

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<AttendanceUserData?> loadCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    var preferredName = user.displayName;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        final fetchedName =
            (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '')
                .toString()
                .trim();
        if (fetchedName.isNotEmpty) {
          preferredName = fetchedName;
        }
      }
    } catch (_) {}

    final normalizedName =
        (preferredName != null && preferredName.trim().isNotEmpty)
        ? preferredName.trim()
        : ((user.email ?? 'Pengguna').trim().isNotEmpty
              ? user.email!.trim()
              : 'Pengguna');

    return AttendanceUserData(
      uid: user.uid,
      displayName: normalizedName,
      email: user.email,
    );
  }

  @override
  Future<DateTime?> fetchAttendanceToday({
    required String userId,
    DateTime? now,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;

    final baseTime = now ?? DateTime.now();
    final startOfDay = DateTime(baseTime.year, baseTime.month, baseTime.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(normalizedUserId)
          .collection('attendance')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            isLessThan: Timestamp.fromDate(endOfDay),
          )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      return _toDateTime(data['date']) ?? startOfDay;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveCheckInToFirestore({
    required String uid,
    required String? userName,
    required String? userEmail,
    required Map<String, dynamic> attendanceData,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    final firestore = _firestore;
    final attendanceDoc = firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('attendance')
        .doc();
    final feedDoc = firestore.collection('attendance_feed').doc();

    final normalizedData = _normalizeForFirestore(attendanceData);
    final feedData = <String, dynamic>{
      ...normalizedData,
      'userUid': normalizedUid,
      'userName': userName,
      'userEmail': userEmail,
      'source': 'mobile',
      'userAttendancePath': attendanceDoc.path,
    };

    final batch = firestore.batch();
    batch.set(attendanceDoc, normalizedData);
    batch.set(feedDoc, feedData);
    await batch.commit();
  }

  @override
  Future<UploadedAttendanceMedia> uploadAttendanceMedia({
    required String userId,
    required DateTime timestamp,
    File? facePhoto,
    File? locationPhoto,
    int maxDimension = 1600,
    int minCompressBytes = 600 * 1024,
  }) async {
    final dateSegment =
        '${timestamp.year.toString().padLeft(4, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')}';
    final baseRef = _storage.ref().child('attendance/$userId/$dateSegment');

    String? faceUrl;
    String? facePath;
    bool faceFailed = false;

    String? locationUrl;
    String? locationPath;
    bool locationFailed = false;

    final List<Future<void>> uploadTasks = [];

    if (_fileExists(facePhoto)) {
      final originalFacePhoto = facePhoto!;
      uploadTasks.add(() async {
        File uploadFile = originalFacePhoto;
        try {
          uploadFile = await _prepareImageForUpload(
            originalFacePhoto,
            maxDimension: maxDimension,
            minCompressBytes: minCompressBytes,
          );
          final ext = _resolveExtension(uploadFile.path);
          final ref = baseRef.child(
            '${timestamp.millisecondsSinceEpoch}_face$ext',
          );
          final metadata = SettableMetadata(
            contentType: _inferContentType(uploadFile.path),
          );
          final task = await ref.putFile(uploadFile, metadata);
          faceUrl = await task.ref.getDownloadURL();
          facePath = task.ref.fullPath;
        } catch (e, st) {
          faceFailed = true;
          debugPrint('Failed to upload face photo: $e');
          debugPrintStack(stackTrace: st);
        } finally {
          await _cleanupTempUpload(uploadFile, originalFacePhoto);
        }
      }());
    }

    if (_fileExists(locationPhoto)) {
      final originalLocationPhoto = locationPhoto!;
      uploadTasks.add(() async {
        File uploadFile = originalLocationPhoto;
        try {
          uploadFile = await _prepareImageForUpload(
            originalLocationPhoto,
            maxDimension: maxDimension,
            minCompressBytes: minCompressBytes,
          );
          final ext = _resolveExtension(uploadFile.path);
          final ref = baseRef.child(
            '${timestamp.millisecondsSinceEpoch}_location$ext',
          );
          final metadata = SettableMetadata(
            contentType: _inferContentType(uploadFile.path),
          );
          final task = await ref.putFile(uploadFile, metadata);
          locationUrl = await task.ref.getDownloadURL();
          locationPath = task.ref.fullPath;
        } catch (e, st) {
          locationFailed = true;
          debugPrint('Failed to upload location photo: $e');
          debugPrintStack(stackTrace: st);
        } finally {
          await _cleanupTempUpload(uploadFile, originalLocationPhoto);
        }
      }());
    }

    if (uploadTasks.isNotEmpty) {
      await Future.wait(uploadTasks);
    }

    return UploadedAttendanceMedia(
      faceUrl: faceUrl,
      faceStoragePath: facePath,
      locationUrl: locationUrl,
      locationStoragePath: locationPath,
      faceUploadFailed: faceFailed,
      locationUploadFailed: locationFailed,
    );
  }

  String _resolveExtension(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (ext.isEmpty) return '.jpg';
    return ext;
  }

  String _inferContentType(String filePath) {
    switch (_resolveExtension(filePath)) {
      case '.png':
        return 'image/png';
      case '.heic':
      case '.heif':
        return 'image/heic';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  bool _fileExists(File? file) {
    if (file == null) return false;
    try {
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<File> _prepareImageForUpload(
    File source, {
    required int maxDimension,
    required int minCompressBytes,
  }) async {
    try {
      final bytes = await source.readAsBytes();
      final optimizedBytes = await compute(
        _optimizeAttendancePhotoBytes,
        _ImageOptimizationPayload(
          bytes: bytes,
          maxDimension: maxDimension,
          minCompressBytes: minCompressBytes,
        ),
      );

      if (optimizedBytes == null) {
        return source;
      }

      final tempDir = await getTemporaryDirectory();
      final optimizedFile = File(
        p.join(
          tempDir.path,
          'att_upload_${DateTime.now().microsecondsSinceEpoch}.jpg',
        ),
      );
      await optimizedFile.writeAsBytes(optimizedBytes, flush: true);
      return optimizedFile;
    } catch (e, st) {
      debugPrint('Failed to optimize attendance photo: $e');
      debugPrintStack(stackTrace: st);
      return source;
    }
  }

  Future<void> _cleanupTempUpload(File processed, File original) async {
    if (processed.path == original.path) return;
    try {
      await processed.delete();
    } catch (_) {}
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  dynamic _normalizeForFirestore(dynamic value) {
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (value is Map) {
      final normalized = <String, dynamic>{};
      value.forEach((key, nestedValue) {
        normalized[key.toString()] = _normalizeForFirestore(nestedValue);
      });
      return normalized;
    }
    if (value is Iterable) {
      return value.map(_normalizeForFirestore).toList(growable: false);
    }
    return value;
  }
}

class _ImageOptimizationPayload {
  const _ImageOptimizationPayload({
    required this.bytes,
    required this.maxDimension,
    required this.minCompressBytes,
  });

  final Uint8List bytes;
  final int maxDimension;
  final int minCompressBytes;
}

Uint8List? _optimizeAttendancePhotoBytes(_ImageOptimizationPayload payload) {
  final img.Image? decoded = img.decodeImage(payload.bytes);
  if (decoded == null) return null;

  final int maxSide = math.max(decoded.width, decoded.height);
  final bool needsResize = maxSide > payload.maxDimension;
  final bool needsCompress = payload.bytes.length > payload.minCompressBytes;

  if (!needsResize && !needsCompress) {
    return null;
  }

  img.Image processed = decoded;
  if (needsResize) {
    final double scale = payload.maxDimension / maxSide;
    final int targetWidth = math.max(1, (decoded.width * scale).round());
    final int targetHeight = math.max(1, (decoded.height * scale).round());
    processed = img.copyResize(
      decoded,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
  }

  int quality = 85;
  if (payload.bytes.length > 2 * 1024 * 1024) {
    quality = 70;
  } else if (payload.bytes.length > 1024 * 1024) {
    quality = 78;
  }

  final optimizedBytes = img.encodeJpg(processed, quality: quality);

  if (!needsResize && optimizedBytes.length >= payload.bytes.length) {
    return null;
  }

  return Uint8List.fromList(optimizedBytes);
}
