import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../shared/models/document_record.dart';
import '../shared/services/document_repository.dart';

class PemberkasanUploadRequest {
  const PemberkasanUploadRequest({
    required this.uid,
    required this.title,
    required this.file,
    this.notes,
    this.expiresAt,
    this.reminderInterval,
  });

  final String uid;
  final String title;
  final PlatformFile file;
  final String? notes;
  final DateTime? expiresAt;
  final Duration? reminderInterval;
}

class PemberkasanUploadResult {
  const PemberkasanUploadResult({
    required this.documentId,
    required this.title,
    required this.expiresAt,
    required this.reminderInterval,
  });

  final String documentId;
  final String title;
  final DateTime? expiresAt;
  final Duration? reminderInterval;
}

class PemberkasanRepositoryException implements Exception {
  const PemberkasanRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class PemberkasanRepository {
  String? get currentUserUid;

  Stream<String?> watchAuthUserIds();

  Stream<List<DocumentRecord>> watchDocuments({required String uid});

  Future<PemberkasanUploadResult> uploadDocument(
    PemberkasanUploadRequest request,
  );

  Future<void> deleteDocument(DocumentRecord record);
}

class PemberkasanRepositoryImpl implements PemberkasanRepository {
  PemberkasanRepositoryImpl({
    DocumentRepository? documentRepository,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _documentRepository = documentRepository ?? DocumentRepository(),
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final DocumentRepository _documentRepository;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  @override
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  Stream<String?> watchAuthUserIds() {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  @override
  Stream<List<DocumentRecord>> watchDocuments({required String uid}) {
    return _documentRepository.watchDocuments(uid: uid);
  }

  @override
  Future<PemberkasanUploadResult> uploadDocument(
    PemberkasanUploadRequest request,
  ) async {
    try {
      final storagePath = _buildStoragePath(request.uid, request.file.name);
      final ref = _storage.ref(storagePath);
      final contentType = _resolveContentType(request.file);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await _readBytesWeb(request.file);
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
      } else {
        final path = request.file.path;
        if (path == null || path.trim().isEmpty) {
          throw const PemberkasanRepositoryException(
            'Path file tidak ditemukan.',
          );
        }
        uploadTask = ref.putFile(
          File(path),
          SettableMetadata(contentType: contentType),
        );
      }

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      final expiresAt = request.expiresAt != null
          ? DateTime(
              request.expiresAt!.year,
              request.expiresAt!.month,
              request.expiresAt!.day,
              23,
              59,
              59,
              999,
            )
          : null;

      final documentId = await _documentRepository.addDocument(
        uid: request.uid,
        title: request.title.trim(),
        storagePath: storagePath,
        downloadUrl: downloadUrl,
        createdBy: request.uid,
        expiresAt: expiresAt,
        reminderInterval: request.reminderInterval,
        originalFileName: request.file.name,
        extra: request.notes != null && request.notes!.trim().isNotEmpty
            ? <String, dynamic>{'notes': request.notes!.trim()}
            : null,
      );

      return PemberkasanUploadResult(
        documentId: documentId,
        title: request.title.trim(),
        expiresAt: expiresAt,
        reminderInterval: request.reminderInterval,
      );
    } on PemberkasanRepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PemberkasanRepositoryException(
        error.message ?? 'Operasi Firebase gagal (${error.code}).',
      );
    } catch (error) {
      throw PemberkasanRepositoryException('Terjadi kesalahan: $error');
    }
  }

  @override
  Future<void> deleteDocument(DocumentRecord record) async {
    try {
      if (record.storagePath.isNotEmpty) {
        try {
          await _storage.ref(record.storagePath).delete();
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') {
            rethrow;
          }
        }
      }

      await _documentRepository.deleteDocument(documentId: record.id);
    } on FirebaseException catch (error) {
      throw PemberkasanRepositoryException(
        error.message ?? 'Gagal menghapus dokumen (${error.code}).',
      );
    } catch (error) {
      throw PemberkasanRepositoryException(
        'Terjadi kesalahan saat menghapus dokumen: $error',
      );
    }
  }

  String _buildStoragePath(String uid, String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return 'pemberkasan/$uid/${timestamp}_$sanitized';
  }

  Future<Uint8List> _readBytesWeb(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    throw const PemberkasanRepositoryException(
      'Tidak dapat membaca konten file.',
    );
  }

  String _resolveContentType(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    const knownTypes = <String, String>{
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'bmp': 'image/bmp',
      'heic': 'image/heic',
      'webp': 'image/webp',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'json': 'application/json',
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      '7z': 'application/x-7z-compressed',
    };
    return knownTypes[ext] ?? 'application/octet-stream';
  }
}
