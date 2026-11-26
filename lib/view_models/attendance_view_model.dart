import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../repositories/attendance_history_repository.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/attendance_window_page_repository.dart';
import '../shared/models/attendance_window.dart';

enum AttendanceUiTone { info, success, warning, error }

enum AttendanceAttemptType {
  success,
  alreadyCheckedIn,
  requiresLogin,
  requiresLocation,
  notOpen,
  closed,
  lateReasonRequired,
  failed,
}

class AttendanceAnnouncement {
  const AttendanceAnnouncement({
    required this.key,
    required this.message,
    required this.tone,
  });

  final String key;
  final String message;
  final AttendanceUiTone tone;
}

class AttendanceReminder {
  const AttendanceReminder({
    required this.key,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final String key;
  final DateTime scheduledAt;
  final String title;
  final String body;
}

class AttendanceAvailabilityDecision {
  const AttendanceAvailabilityDecision({
    required this.message,
    required this.tone,
    required this.available,
    required this.late,
    required this.lateDuration,
    this.nextTrigger,
    this.resubscribe = false,
    this.announcement,
    this.openReminder,
    this.closeReminder,
    this.clearOpenReminder = false,
    this.clearCloseReminder = false,
  });

  final String message;
  final AttendanceUiTone tone;
  final bool available;
  final bool late;
  final Duration lateDuration;
  final DateTime? nextTrigger;
  final bool resubscribe;
  final AttendanceAnnouncement? announcement;
  final AttendanceReminder? openReminder;
  final AttendanceReminder? closeReminder;
  final bool clearOpenReminder;
  final bool clearCloseReminder;
}

class AttendanceAttemptResult {
  const AttendanceAttemptResult({
    required this.type,
    required this.message,
    required this.tone,
    this.checkInAt,
    this.submitResult,
    this.permissionDenied = false,
  });

  final AttendanceAttemptType type;
  final String message;
  final AttendanceUiTone tone;
  final DateTime? checkInAt;
  final SubmitCheckInResult? submitResult;
  final bool permissionDenied;
}

class SubmitCheckInParams {
  const SubmitCheckInParams({
    required this.uid,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.isLateCheckIn,
    this.userName,
    this.userEmail,
    this.project,
    this.lateReason,
    this.facePhoto,
    this.locationPhoto,
  });

  final String uid;
  final String? userName;
  final String? userEmail;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final bool isLateCheckIn;
  final String? project;
  final String? lateReason;
  final File? facePhoto;
  final File? locationPhoto;
}

class SubmitCheckInResult {
  const SubmitCheckInResult({
    required this.faceUploadFailed,
    required this.locationUploadFailed,
    required this.noteText,
  });

  final bool faceUploadFailed;
  final bool locationUploadFailed;
  final String noteText;
}

class AttendanceViewModel extends GetxController {
  AttendanceViewModel({
    AttendanceRepository? repository,
    AttendanceHistoryRepository? attendanceHistoryRepository,
    AttendanceWindowPageRepository? attendanceWindowRepository,
  }) : _repository = repository ?? AttendanceRepositoryImpl(),
       _attendanceHistoryRepository =
           attendanceHistoryRepository ?? AttendanceHistoryRepositoryImpl(),
       _attendanceWindowRepository =
           attendanceWindowRepository ?? AttendanceWindowPageRepositoryImpl();

  final AttendanceRepository _repository;
  final AttendanceHistoryRepository _attendanceHistoryRepository;
  final AttendanceWindowPageRepository _attendanceWindowRepository;

  String? get currentUid => _repository.currentUid;

  Future<AttendanceUserData?> loadCurrentUserData() {
    return _repository.loadCurrentUserData();
  }

  Future<DateTime?> fetchAttendanceToday({
    required String userId,
    DateTime? now,
  }) {
    return _repository.fetchAttendanceToday(userId: userId, now: now);
  }

  Future<void> saveCheckInToFirestore({
    required String uid,
    required String? userName,
    required String? userEmail,
    required Map<String, dynamic> attendanceData,
  }) {
    return _repository.saveCheckInToFirestore(
      uid: uid,
      userName: userName,
      userEmail: userEmail,
      attendanceData: attendanceData,
    );
  }

  Future<UploadedAttendanceMedia> uploadAttendanceMedia({
    required String userId,
    required DateTime timestamp,
    File? facePhoto,
    File? locationPhoto,
    int maxDimension = 1600,
    int minCompressBytes = 600 * 1024,
  }) {
    return _repository.uploadAttendanceMedia(
      userId: userId,
      timestamp: timestamp,
      facePhoto: facePhoto,
      locationPhoto: locationPhoto,
      maxDimension: maxDimension,
      minCompressBytes: minCompressBytes,
    );
  }

  Future<SubmitCheckInResult> submitCheckIn(SubmitCheckInParams params) async {
    final uploads = await _repository.uploadAttendanceMedia(
      userId: params.uid,
      timestamp: params.timestamp,
      facePhoto: params.facePhoto,
      locationPhoto: params.locationPhoto,
    );

    final data = <String, dynamic>{
      'uid': params.uid,
      'type': 'checkin',
      'status': params.isLateCheckIn ? 'checkin terlambat' : 'checkin',
      'date': params.timestamp,
      'createdAt': params.timestamp,
      'time': params.timestamp.millisecondsSinceEpoch,
      'latitude': params.latitude,
      'longitude': params.longitude,
    };
    if (params.project != null && params.project!.trim().isNotEmpty) {
      data['project'] = params.project!.trim();
    }
    if (uploads.faceUrl != null) {
      data['facePhotoUrl'] = uploads.faceUrl;
      data['faceRecognitionUrl'] = uploads.faceUrl;
    }
    if (uploads.faceStoragePath != null) {
      data['facePhotoStoragePath'] = uploads.faceStoragePath;
      data['faceRecognitionPath'] = uploads.faceStoragePath;
    }
    if (uploads.locationUrl != null) {
      data['locationPhotoUrl'] = uploads.locationUrl;
      data['backPhotoUrl'] = uploads.locationUrl;
    }
    if (uploads.locationStoragePath != null) {
      data['locationPhotoStoragePath'] = uploads.locationStoragePath;
      data['backPhotoPath'] = uploads.locationStoragePath;
    }

    final noteText = params.isLateCheckIn
        ? ((params.lateReason != null && params.lateReason!.trim().isNotEmpty)
              ? 'Check-in terlambat: ${params.lateReason!.trim()}'
              : 'Check-in terlambat')
        : 'Check-in dari aplikasi';
    data['note'] = noteText;

    final commitFuture = _repository.saveCheckInToFirestore(
      uid: params.uid,
      userName: params.userName,
      userEmail: params.userEmail,
      attendanceData: data,
    );
    final historyFuture = _attendanceHistoryRepository
        .saveCheckInRecord(
          date: params.timestamp,
          latitude: params.latitude,
          longitude: params.longitude,
          project: params.project,
          note: noteText,
        )
        .catchError((error, stackTrace) {
          debugPrint('Failed to persist local attendance history: $error');
          if (stackTrace != null) {
            debugPrintStack(stackTrace: stackTrace);
          }
        });
    await Future.wait([commitFuture, historyFuture]);

    return SubmitCheckInResult(
      faceUploadFailed: uploads.faceUploadFailed,
      locationUploadFailed: uploads.locationUploadFailed,
      noteText: noteText,
    );
  }

  Stream<AttendanceWindow?> watchAttendanceWindow(DateTime date) {
    return _attendanceWindowRepository.watchWindow(date);
  }

  String formatClock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  AttendanceAvailabilityDecision evaluateAttendanceAvailability({
    required AttendanceWindow? window,
    required DateTime now,
    required bool hasAttendanceToday,
    required DateTime? checkInAt,
  }) {
    if (hasAttendanceToday || checkInAt != null) {
      return const AttendanceAvailabilityDecision(
        message: 'Anda sudah Absen hari ini.',
        tone: AttendanceUiTone.success,
        available: false,
        late: false,
        lateDuration: Duration.zero,
        clearOpenReminder: true,
        clearCloseReminder: true,
      );
    }

    if (window == null) {
      return const AttendanceAvailabilityDecision(
        message: 'Absen belum dibuka admin',
        tone: AttendanceUiTone.error,
        available: false,
        late: false,
        lateDuration: Duration.zero,
      );
    }

    if (window.isBeforeOpen(now)) {
      final openLabel = formatClock(window.openAt);
      final minutesUntilOpen = window.openAt.difference(now).inMinutes.clamp(
        0,
        999,
      );
      final scheduleAt = window.openAt.subtract(const Duration(minutes: 30));
      final openReminder = AttendanceReminder(
        key: 'open-${window.date.toIso8601String()}',
        scheduledAt: scheduleAt,
        title: 'Absensi dibuka 30 menit lagi',
        body: 'Absensi hari ini mulai pukul $openLabel. Siapkan absen Anda.',
      );
      if (minutesUntilOpen <= 30) {
        return AttendanceAvailabilityDecision(
          message: 'Absen belum dibuka admin (mulai pukul $openLabel)',
          tone: AttendanceUiTone.error,
          available: false,
          late: false,
          lateDuration: Duration.zero,
          openReminder: openReminder,
          announcement: AttendanceAnnouncement(
            key: 'open-soon-${window.date.toIso8601String()}',
            message:
                'Absensi dibuka dalam $minutesUntilOpen menit (pukul $openLabel).',
            tone: AttendanceUiTone.info,
          ),
          nextTrigger: window.openAt,
        );
      }
      return AttendanceAvailabilityDecision(
        message: 'Absen belum dibuka admin (mulai pukul $openLabel)',
        tone: AttendanceUiTone.error,
        available: false,
        late: false,
        lateDuration: Duration.zero,
        openReminder: openReminder,
        nextTrigger: scheduleAt,
      );
    }

    if (window.isAfterClose(now)) {
      final closeGraceLabel = formatClock(window.closeGraceDeadline());
      final tomorrow = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      return AttendanceAvailabilityDecision(
        message: 'Absen telah ditutup. Toleransi berakhir pukul $closeGraceLabel.',
        tone: AttendanceUiTone.error,
        available: false,
        late: false,
        lateDuration: Duration.zero,
        nextTrigger: tomorrow,
        resubscribe: true,
        announcement: AttendanceAnnouncement(
          key: 'closed-${window.date.toIso8601String()}',
          message:
              'Absen telah ditutup admin. Anda sudah melewati jam absen yang ditentukan. Toleransi berakhir pukul $closeGraceLabel.',
          tone: AttendanceUiTone.error,
        ),
      );
    }

    final threshold = window.lateThreshold();
    final thresholdLabel = formatClock(threshold);
    final closeGraceLabel = formatClock(window.closeGraceDeadline());
    if (window.isLate(now)) {
      final toleranceMinutes = window.lateGraceMinutes.clamp(0, 999).toInt();
      final lateDuration = Duration(minutes: toleranceMinutes);
      final remainingTolerance = window
          .closeGraceDeadline()
          .difference(now)
          .inMinutes
          .clamp(0, toleranceMinutes)
          .toInt();
      final message =
          'Absen telah ditutup. Anda terlambat $toleranceMinutes menit. Toleransi berakhir pukul $closeGraceLabel'
          '${remainingTolerance > 0 ? ' (sisa $remainingTolerance menit).' : '.'}';
      return AttendanceAvailabilityDecision(
        message: message,
        tone: AttendanceUiTone.warning,
        available: true,
        late: true,
        lateDuration: lateDuration,
        nextTrigger: window.closeGraceDeadline(),
        announcement: AttendanceAnnouncement(
          key: 'late-${window.date.toIso8601String()}',
          message: remainingTolerance > 0
              ? 'Absen telah ditutup admin. Anda terlambat $toleranceMinutes menit (sisa toleransi $remainingTolerance menit, tutup pukul $closeGraceLabel).'
              : 'Absen telah ditutup admin. Anda terlambat $toleranceMinutes menit. Toleransi berakhir pukul $closeGraceLabel.',
          tone: AttendanceUiTone.warning,
        ),
      );
    }

    final timeUntilClose = threshold.difference(now).inMinutes.clamp(0, 999);
    final toleranceMinutes = window.lateGraceMinutes.clamp(0, 999).toInt();
    final message =
        'Absen dibuka hingga pukul $thresholdLabel. Sisa waktu $timeUntilClose menit. Diberikan toleransi $toleranceMinutes menit setelah penutupan (hingga pukul $closeGraceLabel).';
    final scheduleAt = threshold.subtract(const Duration(minutes: 10));
    final closeReminder = AttendanceReminder(
      key: 'close-${window.date.toIso8601String()}',
      scheduledAt: scheduleAt,
      title: 'Absensi ditutup 10 menit lagi',
      body: 'Absen ditutup pukul $thresholdLabel. Segera lakukan absen sekarang.',
    );
    if (timeUntilClose <= 10) {
      return AttendanceAvailabilityDecision(
        message: message,
        tone: AttendanceUiTone.success,
        available: true,
        late: false,
        lateDuration: Duration.zero,
        closeReminder: closeReminder,
        announcement: AttendanceAnnouncement(
          key: 'close-soon-${window.date.toIso8601String()}',
          message:
              'Absen akan ditutup dalam $timeUntilClose menit (pukul $thresholdLabel). Segera absen.',
          tone: AttendanceUiTone.warning,
        ),
        nextTrigger: threshold,
      );
    }

    return AttendanceAvailabilityDecision(
      message: message,
      tone: AttendanceUiTone.success,
      available: true,
      late: false,
      lateDuration: Duration.zero,
      closeReminder: closeReminder,
      announcement: AttendanceAnnouncement(
        key: 'tolerance-${window.date.toIso8601String()}',
        message:
            'Absen dibuka hingga pukul $thresholdLabel. Setelah itu toleransi $toleranceMinutes menit hingga pukul $closeGraceLabel.',
        tone: AttendanceUiTone.info,
      ),
      nextTrigger: scheduleAt,
    );
  }

  Future<AttendanceAttemptResult> attemptCheckIn({
    required AttendanceUserData? user,
    required String? userName,
    required AttendanceWindow? window,
    required bool attendanceAvailable,
    required bool isLateNow,
    required String lateReason,
    required String project,
    required File? facePhoto,
    required File? locationPhoto,
    required double? latitude,
    required double? longitude,
  }) async {
    if (user == null) {
      return const AttendanceAttemptResult(
        type: AttendanceAttemptType.requiresLogin,
        message: 'Harus login terlebih dahulu.',
        tone: AttendanceUiTone.error,
      );
    }
    if (latitude == null || longitude == null) {
      return const AttendanceAttemptResult(
        type: AttendanceAttemptType.requiresLocation,
        message: 'Lokasi belum tersedia. Ambil ulang lokasi.',
        tone: AttendanceUiTone.warning,
      );
    }

    final existingToday = await fetchAttendanceToday(userId: user.uid);
    if (existingToday != null) {
      return AttendanceAttemptResult(
        type: AttendanceAttemptType.alreadyCheckedIn,
        message: 'Anda sudah absen hari ini.',
        tone: AttendanceUiTone.info,
        checkInAt: existingToday,
      );
    }

    final now = DateTime.now();
    if (!attendanceAvailable || (window != null && window.isBeforeOpen(now))) {
      return const AttendanceAttemptResult(
        type: AttendanceAttemptType.notOpen,
        message: 'Absen belum dibuka admin.',
        tone: AttendanceUiTone.warning,
      );
    }
    if (window != null && window.isAfterClose(now)) {
      return const AttendanceAttemptResult(
        type: AttendanceAttemptType.closed,
        message: 'Jam absen telah ditutup admin.',
        tone: AttendanceUiTone.warning,
      );
    }

    bool isLateCheckIn = false;
    if (window != null) {
      isLateCheckIn = window.isLate(now);
    } else if (isLateNow) {
      isLateCheckIn = true;
    }

    final lateReasonText = lateReason.trim();
    if (isLateCheckIn && lateReasonText.isEmpty) {
      return const AttendanceAttemptResult(
        type: AttendanceAttemptType.lateReasonRequired,
        message: 'Alasan keterlambatan wajib diisi.',
        tone: AttendanceUiTone.warning,
      );
    }

    try {
      final projectText = project.trim();
      final submitResult = await submitCheckIn(
        SubmitCheckInParams(
          uid: user.uid,
          userName: userName,
          userEmail: user.email,
          timestamp: now,
          latitude: latitude,
          longitude: longitude,
          isLateCheckIn: isLateCheckIn,
          project: projectText.isNotEmpty ? projectText : null,
          lateReason: lateReasonText.isNotEmpty ? lateReasonText : null,
          facePhoto: facePhoto,
          locationPhoto: locationPhoto,
        ),
      );
      return AttendanceAttemptResult(
        type: AttendanceAttemptType.success,
        message: 'Check-in berhasil tersimpan.',
        tone: AttendanceUiTone.success,
        checkInAt: now,
        submitResult: submitResult,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to save attendance: $error');
      debugPrintStack(stackTrace: stackTrace);
      final reason = describeAttendanceSaveError(error);
      return AttendanceAttemptResult(
        type: AttendanceAttemptType.failed,
        message: 'Gagal menyimpan absen: $reason',
        tone: AttendanceUiTone.error,
        permissionDenied: isPermissionDeniedError(error),
      );
    }
  }

  bool isPermissionDeniedError(Object error) {
    return _extractErrorCode(error) == 'permission-denied';
  }

  String describeAttendanceSaveError(Object error) {
    final firebaseCode = _extractErrorCode(error);
    final firebaseMessage = _extractErrorMessage(error);
    if (firebaseCode != null) {
      if (firebaseCode == 'permission-denied') {
        return 'akses ditolak oleh server';
      }
      if (firebaseCode == 'unavailable') {
        return 'jaringan tidak stabil';
      }
      if (firebaseMessage != null && firebaseMessage.trim().isNotEmpty) {
        return firebaseMessage.trim();
      }
      return 'kode error $firebaseCode';
    }
    if (error is SocketException) {
      return 'koneksi internet terputus';
    }
    if (error is TimeoutException) {
      return 'koneksi ke server melebihi waktu tunggu';
    }
    return error.toString();
  }

  String? _extractErrorCode(Object error) {
    try {
      final dynamic dynamicError = error;
      final dynamic code = dynamicError.code;
      if (code is String && code.trim().isNotEmpty) {
        return code.trim();
      }
    } catch (_) {}
    return null;
  }

  String? _extractErrorMessage(Object error) {
    try {
      final dynamic dynamicError = error;
      final dynamic message = dynamicError.message;
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {}
    return null;
  }
}
