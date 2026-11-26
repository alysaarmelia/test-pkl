import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../repositories/leave_page_repository.dart';
import '../shared/models/leave_request.dart';

enum LeavePageFeedbackType { success, warning, error, none }

class LeavePageFeedback {
  const LeavePageFeedback({
    required this.type,
    this.message = '',
    this.shouldResetForm = false,
  });

  final LeavePageFeedbackType type;
  final String message;
  final bool shouldResetForm;

  static const none = LeavePageFeedback(type: LeavePageFeedbackType.none);
}

class LeavePageViewModel extends GetxController {
  LeavePageViewModel({LeavePageRepository? repository})
    : _repository = repository ?? LeavePageRepositoryImpl();

  final LeavePageRepository _repository;

  Future<LeavePageFeedback> submitLeaveRequest({
    required DateTime? startDate,
    required DateTime? endDate,
    required String reason,
    required List<PlatformFile> attachments,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      return const LeavePageFeedback(
        type: LeavePageFeedbackType.warning,
        message: 'Alasan cuti wajib diisi.',
      );
    }
    if (startDate == null || endDate == null) {
      return const LeavePageFeedback(
        type: LeavePageFeedbackType.warning,
        message: 'Lengkapi data cuti terlebih dahulu',
      );
    }

    final user = _repository.currentUser;
    if (user == null) {
      return const LeavePageFeedback(
        type: LeavePageFeedbackType.warning,
        message: 'Harus login terlebih dahulu',
      );
    }

    DateTime normalizedStart = startDate;
    DateTime normalizedEnd = endDate;
    if (normalizedEnd.isBefore(normalizedStart)) {
      final temp = normalizedStart;
      normalizedStart = normalizedEnd;
      normalizedEnd = temp;
    }

    List<LeaveAttachment> uploadedAttachments = const <LeaveAttachment>[];
    try {
      if (attachments.isNotEmpty) {
        uploadedAttachments = await _repository.uploadAttachments(
          uid: user.uid,
          files: attachments,
        );
      }

      await _repository.submitLeave(
        uid: user.uid,
        requesterName: user.displayName,
        requesterEmail: user.email,
        startDate: normalizedStart,
        endDate: normalizedEnd,
        reason: normalizedReason,
        attachments: uploadedAttachments,
      );

      return LeavePageFeedback(
        type: LeavePageFeedbackType.success,
        message:
            'Pengajuan cuti dikirim${attachments.isEmpty ? '' : ' dengan lampiran'}. Menunggu persetujuan.',
        shouldResetForm: true,
      );
    } catch (error) {
      if (uploadedAttachments.isNotEmpty) {
        await _repository.cleanupUploaded(uploadedAttachments);
      }
      return LeavePageFeedback(
        type: LeavePageFeedbackType.error,
        message: 'Gagal mengajukan cuti: $error',
      );
    }
  }
}
