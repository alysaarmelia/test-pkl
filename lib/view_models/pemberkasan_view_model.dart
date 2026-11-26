import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../shared/models/document_record.dart';
import '../app/services/document_reminder_manager.dart';
import '../app/services/notification_service.dart';
import '../repositories/pemberkasan_repository.dart';

enum PemberkasanFeedbackType { success, info, warning, error, none }

class PemberkasanFeedback {
  const PemberkasanFeedback({required this.type, this.message = ''});

  final PemberkasanFeedbackType type;
  final String message;

  static const none = PemberkasanFeedback(type: PemberkasanFeedbackType.none);
}

class PemberkasanUploadInput {
  const PemberkasanUploadInput({
    required this.title,
    required this.file,
    this.notes,
    this.expiresAt,
    this.reminderInterval,
  });

  final String title;
  final PlatformFile file;
  final String? notes;
  final DateTime? expiresAt;
  final Duration? reminderInterval;
}

class PemberkasanViewModel extends GetxController {
  PemberkasanViewModel({
    PemberkasanRepository? repository,
    DocumentReminderManager? reminderManager,
    NotificationService? notificationService,
    bool enableReminders = true,
  }) : _repository = repository ?? PemberkasanRepositoryImpl(),
       _reminderManager = reminderManager ?? DocumentReminderManager(),
       _notificationService = notificationService ?? NotificationService(),
       _enableReminders = enableReminders;

  final PemberkasanRepository _repository;
  final DocumentReminderManager _reminderManager;
  final NotificationService _notificationService;
  final bool _enableReminders;

  String? _currentUserUid;
  Stream<List<DocumentRecord>>? _documentsStream;
  bool _isUploading = false;
  Set<String> _deletingDocumentIds = <String>{};

  StreamSubscription<String?>? _authSubscription;

  String? get currentUserUid => _currentUserUid;
  Stream<List<DocumentRecord>>? get documentsStream => _documentsStream;
  bool get isUploading => _isUploading;

  bool isDeleting(String documentId) {
    return _deletingDocumentIds.contains(documentId);
  }

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

  Future<void> syncDocuments(List<DocumentRecord> documents) async {
    if (!_enableReminders) return;
    await _reminderManager.syncDocuments(documents);
  }

  Future<PemberkasanFeedback> uploadDocument(
    PemberkasanUploadInput input,
  ) async {
    if (_isUploading) return PemberkasanFeedback.none;

    final uid = _currentUserUid;
    if (uid == null || uid.isEmpty) {
      return const PemberkasanFeedback(
        type: PemberkasanFeedbackType.warning,
        message: 'Silakan masuk untuk menambahkan dokumen.',
      );
    }

    _isUploading = true;
    _notify();
    try {
      final result = await _repository.uploadDocument(
        PemberkasanUploadRequest(
          uid: uid,
          title: input.title,
          file: input.file,
          notes: input.notes,
          expiresAt: input.expiresAt,
          reminderInterval: input.reminderInterval,
        ),
      );

      if (_enableReminders) {
        await _reminderManager.scheduleForDocument(
          documentId: result.documentId,
          title: result.title,
          expiresAt: result.expiresAt,
          reminderInterval: result.reminderInterval,
        );
      }

      return const PemberkasanFeedback(
        type: PemberkasanFeedbackType.success,
        message: 'Dokumen berhasil ditambahkan.',
      );
    } on PemberkasanRepositoryException catch (error) {
      return PemberkasanFeedback(
        type: PemberkasanFeedbackType.error,
        message: error.message,
      );
    } catch (error) {
      return PemberkasanFeedback(
        type: PemberkasanFeedbackType.error,
        message: 'Terjadi kesalahan: $error',
      );
    } finally {
      _isUploading = false;
      _notify();
    }
  }

  Future<PemberkasanFeedback> deleteDocument(DocumentRecord record) async {
    if (_deletingDocumentIds.contains(record.id)) {
      return PemberkasanFeedback.none;
    }

    _deletingDocumentIds = <String>{..._deletingDocumentIds, record.id};
    _notify();

    try {
      if (_enableReminders) {
        await _notificationService.cancelDocumentReminder(
          documentId: record.id,
        );
      }
      await _repository.deleteDocument(record);
      return PemberkasanFeedback(
        type: PemberkasanFeedbackType.success,
        message: 'Dokumen "${record.title}" dihapus.',
      );
    } on PemberkasanRepositoryException catch (error) {
      return PemberkasanFeedback(
        type: PemberkasanFeedbackType.error,
        message: error.message,
      );
    } catch (error) {
      return PemberkasanFeedback(
        type: PemberkasanFeedbackType.error,
        message: 'Terjadi kesalahan saat menghapus dokumen: $error',
      );
    } finally {
      _deletingDocumentIds = Set<String>.from(_deletingDocumentIds)
        ..remove(record.id);
      _notify();
    }
  }

  void _bindAuthState(String? uid) {
    if (_currentUserUid == uid && _documentsStream != null) {
      return;
    }
    _currentUserUid = uid;
    if (uid == null || uid.isEmpty) {
      _documentsStream = null;
    } else {
      _documentsStream = _repository.watchDocuments(uid: uid);
    }
    _notify();
  }

  void _notify() {
    if (isClosed) return;
    update();
  }
}
