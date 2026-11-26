import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';
import '../models/document_record.dart';

class DocumentRepository {
  DocumentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionName = 'employee_documents';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Future<String> addDocument({
    required String uid,
    required String title,
    required String storagePath,
    required String downloadUrl,
    DateTime? expiresAt,
    Duration? reminderInterval,
    String? originalFileName,
    Map<String, dynamic>? extra,
    String? createdBy,
    List<String>? divisions,
  }) async {
    final now = Timestamp.now();
    final sanitizedDivisions =
        CalendarDivision.sanitizeList(divisions ?? const [CalendarDivision.all]);
    final data = <String, dynamic>{
      'uid': uid,
      'title': title,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'createdAt': now,
      'updatedAt': now,
      'divisions': sanitizedDivisions,
      if (createdBy != null) 'createdBy': createdBy,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      if (reminderInterval != null && reminderInterval.inDays > 0)
        'reminderIntervalDays': reminderInterval.inDays,
      if (originalFileName != null) 'originalFileName': originalFileName,
      if (extra != null) ...extra,
    };
    final doc = await _collection.add(data);
    return doc.id;
  }

  Stream<List<DocumentRecord>> watchDocuments({
    required String uid,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> query =
        _collection.where('uid', isEqualTo: uid);
    if (limit > 0) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(DocumentRecord.fromSnapshot)
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit > 0 && items.length > limit) {
        return items.take(limit).toList(growable: false);
      }
      return items;
    });
  }

  Future<List<DocumentRecord>> fetchDocuments({
    required String uid,
    int limit = 200,
    bool preferServer = false,
  }) async {
    Query<Map<String, dynamic>> query =
        _collection.where('uid', isEqualTo: uid);
    if (limit > 0) {
      query = query.limit(limit);
    }
    final options =
        preferServer ? const GetOptions(source: Source.server) : null;
    final snapshot =
        options != null ? await query.get(options) : await query.get();
    final items = snapshot.docs
        .map(DocumentRecord.fromSnapshot)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit > 0 && items.length > limit) {
      return items.take(limit).toList(growable: false);
    }
    return items;
  }

  Stream<List<DocumentRecord>> watchAllDocuments({
    int limit = 500,
  }) {
    Query<Map<String, dynamic>> query = _collection;
    if (limit > 0) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(DocumentRecord.fromSnapshot)
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit > 0 && items.length > limit) {
        return items.take(limit).toList(growable: false);
      }
      return items;
    });
  }

  Future<List<DocumentRecord>> fetchAllDocuments({
    int limit = 500,
    bool preferServer = false,
  }) async {
    Query<Map<String, dynamic>> query = _collection;
    if (limit > 0) {
      query = query.limit(limit);
    }
    final options =
        preferServer ? const GetOptions(source: Source.server) : null;
    final snapshot =
        options != null ? await query.get(options) : await query.get();
    final items = snapshot.docs
        .map(DocumentRecord.fromSnapshot)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit > 0 && items.length > limit) {
      return items.take(limit).toList(growable: false);
    }
    return items;
  }

  Future<void> deleteDocument({
    required String documentId,
  }) {
    return _collection.doc(documentId).delete();
  }

  Future<void> updateDocumentReminder({
    required String documentId,
    Duration? reminderInterval,
    DateTime? expiresAt,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (reminderInterval == null)
        'reminderIntervalDays': FieldValue.delete()
      else if (reminderInterval.inDays > 0)
        'reminderIntervalDays': reminderInterval.inDays,
      if (expiresAt == null)
        'expiresAt': FieldValue.delete()
      else
        'expiresAt': Timestamp.fromDate(expiresAt),
    };
    data.removeWhere((key, value) => value == null);
    await _collection.doc(documentId).update(data);
  }
}
