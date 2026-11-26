import 'dart:io';

import 'package:cipta_vera_mandiri_digital/repositories/attendance_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/attendance_window.dart';
import 'package:cipta_vera_mandiri_digital/view_models/attendance_view_model.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class AttendanceController extends GetxController {
  AttendanceController({AttendanceViewModel? viewModel})
    : _viewModel = viewModel ?? AttendanceViewModel();

  final AttendanceViewModel _viewModel;

  final Rxn<DateTime> checkInAt = Rxn<DateTime>();
  final Rxn<File> inFaceRecognition = Rxn<File>();
  final Rxn<File> inBackPhoto = Rxn<File>();
  final Rxn<Position> inPos = Rxn<Position>();

  final RxInt inStepIndex = 0.obs;
  final RxBool stateLoaded = false.obs;
  final RxBool isSavingAttendance = false.obs;

  final Rxn<AttendanceWindow> attendanceWindow = Rxn<AttendanceWindow>();
  final RxBool attendanceWindowLoaded = false.obs;
  final RxBool attendanceAvailable = false.obs;
  final RxBool isLateNow = false.obs;
  final RxBool hasAttendanceToday = false.obs;
  final RxBool checkingExistingAttendance = false.obs;
  final RxnString attendanceStatusMessage = RxnString();
  final Rx<Color> attendanceStatusColor = Colors.white.obs;
  final Rx<Duration> currentLateDuration = Duration.zero.obs;
  final RxnString lateReasonError = RxnString();
  final RxnString lastAttendanceAnnouncementKey = RxnString();

  final RxBool isDetecting = false.obs;
  final RxBool screenFlashActive = false.obs;

  final Rxn<AttendanceUserData> currentUser = Rxn<AttendanceUserData>();
  final RxnString userName = RxnString();

  String? get activeUid => _viewModel.currentUid;

  Future<AttendanceUserData?> loadCurrentUserData() {
    return _viewModel.loadCurrentUserData();
  }

  Future<DateTime?> fetchAttendanceToday({String? userId}) {
    final resolvedUserId = userId ?? currentUser.value?.uid;
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return Future<DateTime?>.value(null);
    }
    return _viewModel.fetchAttendanceToday(userId: resolvedUserId);
  }

  Stream<AttendanceWindow?> watchAttendanceWindow(DateTime date) {
    return _viewModel.watchAttendanceWindow(date);
  }

  AttendanceAvailabilityDecision evaluateAttendanceAvailability(DateTime now) {
    return _viewModel.evaluateAttendanceAvailability(
      window: attendanceWindow.value,
      now: now,
      hasAttendanceToday: hasAttendanceToday.value,
      checkInAt: checkInAt.value,
    );
  }

  Future<AttendanceAttemptResult> attemptCheckIn({
    required String lateReason,
    required String project,
  }) {
    return _viewModel.attemptCheckIn(
      user: currentUser.value,
      userName: userName.value,
      window: attendanceWindow.value,
      attendanceAvailable: attendanceAvailable.value,
      isLateNow: isLateNow.value,
      lateReason: lateReason,
      project: project,
      facePhoto: inFaceRecognition.value,
      locationPhoto: inBackPhoto.value,
      latitude: inPos.value?.latitude,
      longitude: inPos.value?.longitude,
    );
  }

  String formatClock(DateTime value) => _viewModel.formatClock(value);

  Color statusColorForTone(AttendanceUiTone tone) {
    switch (tone) {
      case AttendanceUiTone.success:
        return const Color(0xFF4CAF50);
      case AttendanceUiTone.warning:
        return const Color(0xFF8E24AA);
      case AttendanceUiTone.error:
        return Colors.redAccent;
      case AttendanceUiTone.info:
        return Colors.white;
    }
  }

  void applyUserData(AttendanceUserData? user) {
    currentUser.value = user;
    userName.value = user?.displayName;
  }

  void applyExistingAttendance(DateTime recordedAt) {
    hasAttendanceToday.value = true;
    checkInAt.value = recordedAt;
    attendanceStatusMessage.value = 'Selamat Beraktivitas dan bekerja.';
    attendanceStatusColor.value = const Color(0xFF4CAF50);
  }

  void applyWindowLoadError() {
    attendanceWindow.value = null;
    attendanceWindowLoaded.value = true;
    attendanceAvailable.value = false;
    isLateNow.value = false;
    currentLateDuration.value = Duration.zero;
    attendanceStatusColor.value = Colors.redAccent;
    attendanceStatusMessage.value = 'Absen belum dibuka admin';
  }

  void applyAvailabilityDecision(AttendanceAvailabilityDecision decision) {
    attendanceWindowLoaded.value = true;
    attendanceStatusMessage.value = decision.message;
    attendanceStatusColor.value = statusColorForTone(decision.tone);
    attendanceAvailable.value = decision.available;
    isLateNow.value = decision.late;
    currentLateDuration.value = decision.lateDuration;
    if (!decision.late) {
      lateReasonError.value = null;
    }
  }
}
