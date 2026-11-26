import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../repositories/permission_page_repository.dart';

enum PermissionPageFeedbackType { success, warning, error, none }

class PermissionPageFeedback {
  const PermissionPageFeedback({
    required this.type,
    this.message = '',
    this.shouldResetForm = false,
  });

  final PermissionPageFeedbackType type;
  final String message;
  final bool shouldResetForm;

  static const none = PermissionPageFeedback(
    type: PermissionPageFeedbackType.none,
  );
}

class PermissionPageViewModel extends GetxController {
  PermissionPageViewModel({PermissionPageRepository? repository})
    : _repository = repository ?? PermissionPageRepositoryImpl();

  final PermissionPageRepository _repository;

  int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<PermissionPageFeedback> submitPermissionRequest({
    required DateTime? requestDate,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required String reason,
    required String Function(TimeOfDay time) formatTimeText,
    required String Function(DateTime date) formatDateText,
  }) async {
    final normalizedReason = reason.trim();
    if (requestDate == null || startTime == null || endTime == null) {
      return const PermissionPageFeedback(
        type: PermissionPageFeedbackType.warning,
        message: 'Lengkapi data izin terlebih dahulu',
      );
    }
    if (normalizedReason.isEmpty) {
      return const PermissionPageFeedback(
        type: PermissionPageFeedbackType.warning,
        message: 'Alasan izin wajib diisi.',
      );
    }

    final startAt = DateTime(
      requestDate.year,
      requestDate.month,
      requestDate.day,
      startTime.hour,
      startTime.minute,
    );
    final endAt = DateTime(
      requestDate.year,
      requestDate.month,
      requestDate.day,
      endTime.hour,
      endTime.minute,
    );

    if (!endAt.isAfter(startAt)) {
      return const PermissionPageFeedback(
        type: PermissionPageFeedbackType.warning,
        message: 'Jam selesai harus setelah jam mulai.',
      );
    }

    final user = _repository.currentUser;
    if (user == null) {
      return const PermissionPageFeedback(
        type: PermissionPageFeedbackType.warning,
        message: 'Harus login terlebih dahulu',
      );
    }

    try {
      await _repository.submitPermission(
        uid: user.uid,
        requesterName: user.displayName,
        requesterEmail: user.email,
        startAt: startAt,
        endAt: endAt,
        reason: normalizedReason,
        metadata: {
          'requestDate': formatDateText(requestDate),
          'startTimeText': formatTimeText(startTime),
          'endTimeText': formatTimeText(endTime),
          'startMinutes': toMinutes(startTime),
          'endMinutes': toMinutes(endTime),
        },
      );

      return const PermissionPageFeedback(
        type: PermissionPageFeedbackType.success,
        message: 'Pengajuan izin dikirim. Menunggu persetujuan.',
        shouldResetForm: true,
      );
    } catch (error) {
      return PermissionPageFeedback(
        type: PermissionPageFeedbackType.error,
        message: 'Gagal mengajukan izin: $error',
      );
    }
  }
}
