import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../shared/models/leave_request.dart';
import '../shared/services/leave_request_repository.dart';

class LeavePageUserData {
  const LeavePageUserData({required this.uid, this.displayName, this.email});

  final String uid;
  final String? displayName;
  final String? email;
}

abstract class LeavePageRepository {
  LeavePageUserData? get currentUser;

  Future<List<LeaveAttachment>> uploadAttachments({
    required String uid,
    required List<PlatformFile> files,
  });

  Future<void> cleanupUploaded(List<LeaveAttachment> attachments);

  Future<void> submitLeave({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    List<LeaveAttachment> attachments,
  });
}

class LeavePageRepositoryImpl implements LeavePageRepository {
  LeavePageRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    LeaveRequestRepository? leaveRequestRepository,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _leaveRequestRepository =
           leaveRequestRepository ?? LeaveRequestRepository();

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final LeaveRequestRepository _leaveRequestRepository;

  @override
  LeavePageUserData? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return LeavePageUserData(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
    );
  }

  @override
  Future<List<LeaveAttachment>> uploadAttachments({
    required String uid,
    required List<PlatformFile> files,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uploaded = <LeaveAttachment>[];

    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final safeName = _sanitizeFileName(file.name);
        final storagePath =
            'leave_requests/$uid/support/$timestamp-$i-$safeName';
        final contentType = _resolveContentType(file);
        final ref = _storage.ref(storagePath);

        UploadTask task;
        if (kIsWeb) {
          final bytes = file.bytes ?? await _readBytesWeb(file);
          task = ref.putData(bytes, SettableMetadata(contentType: contentType));
        } else {
          final path = file.path;
          if (path == null) {
            throw Exception('Path file tidak ditemukan untuk ${file.name}.');
          }
          task = ref.putFile(
            File(path),
            SettableMetadata(contentType: contentType),
          );
        }

        final snapshot = await task.whenComplete(() {});
        final url = await snapshot.ref.getDownloadURL();
        uploaded.add(
          LeaveAttachment(
            name: file.name,
            url: url,
            storagePath: storagePath,
            contentType: contentType,
            size: file.size,
          ),
        );
      }
    } catch (_) {
      if (uploaded.isNotEmpty) {
        await cleanupUploaded(uploaded);
      }
      rethrow;
    }

    return uploaded;
  }

  @override
  Future<void> cleanupUploaded(List<LeaveAttachment> attachments) async {
    for (final attachment in attachments) {
      try {
        await _storage.ref(attachment.storagePath).delete().catchError((_) {});
      } catch (_) {
        // Ignore cleanup failures.
      }
    }
  }

  @override
  Future<void> submitLeave({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? requesterName,
    String? requesterEmail,
    List<LeaveAttachment> attachments = const <LeaveAttachment>[],
  }) {
    return _leaveRequestRepository.submitLeave(
      uid: uid,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      attachments: attachments,
    );
  }

  Future<Uint8List> _readBytesWeb(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    throw Exception('Tidak dapat membaca file ${file.name}.');
  }

  String _sanitizeFileName(String input) {
    final cleaned = input.replaceAll(RegExp(r'\s+'), '_');
    return cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '');
  }

  String _resolveContentType(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
