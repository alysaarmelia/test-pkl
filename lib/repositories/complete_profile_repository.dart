import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../app/services/chat_pin_service.dart';

class CompleteProfilePinResult {
  const CompleteProfilePinResult({
    required this.success,
    this.pin,
    this.message,
  });

  final bool success;
  final String? pin;
  final String? message;
}

class CompleteProfileSaveRequest {
  const CompleteProfileSaveRequest({
    required this.uid,
    required this.name,
    required this.division,
    required this.pin,
    this.imageUrl,
    this.email,
  });

  final String uid;
  final String name;
  final String division;
  final String pin;
  final String? imageUrl;
  final String? email;
}

class CompleteProfileRepositoryException implements Exception {
  const CompleteProfileRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class CompleteProfileRepository {
  String? get currentUserUid;
  String? get currentUserEmail;

  Future<CompleteProfilePinResult> ensureUserPin();

  Future<String> uploadProfilePicture({
    required File image,
    required String uid,
  });

  Future<void> saveProfile(CompleteProfileSaveRequest request);
}

class CompleteProfileRepositoryImpl implements CompleteProfileRepository {
  CompleteProfileRepositoryImpl({
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
  String? get currentUserUid => _auth.currentUser?.uid;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  Future<CompleteProfilePinResult> ensureUserPin() async {
    try {
      final uid = currentUserUid;
      if (uid == null || uid.isEmpty) {
        return const CompleteProfilePinResult(
          success: false,
          message: 'Sesi pengguna tidak ditemukan.',
        );
      }

      final doc = await _firestore.collection('users').doc(uid).get();
      var pin = _extractExistingPin(doc.data());
      if (pin == null || pin.isEmpty) {
        pin = await ChatPinService.generateUniquePin(uid);
      }

      return CompleteProfilePinResult(success: true, pin: pin);
    } on FirebaseException catch (error) {
      return CompleteProfilePinResult(
        success: false,
        message: error.message ?? 'Gagal memuat PIN (${error.code}).',
      );
    } catch (error) {
      return CompleteProfilePinResult(
        success: false,
        message: 'Gagal memuat PIN: $error',
      );
    }
  }

  @override
  Future<String> uploadProfilePicture({
    required File image,
    required String uid,
  }) async {
    try {
      final storageRef = _storage.ref().child('profile_pictures/$uid.jpg');
      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask.whenComplete(() {});
      return snapshot.ref.getDownloadURL();
    } on FirebaseException catch (error) {
      throw CompleteProfileRepositoryException(
        error.message ?? 'Gagal mengunggah gambar (${error.code}).',
      );
    } catch (error) {
      throw CompleteProfileRepositoryException(
        'Gagal mengunggah gambar: $error',
      );
    }
  }

  @override
  Future<void> saveProfile(CompleteProfileSaveRequest request) async {
    try {
      await _firestore.collection('users').doc(request.uid).set({
        'name': request.name,
        'role': request.division,
        if (request.imageUrl != null && request.imageUrl!.trim().isNotEmpty)
          'photoUrl': request.imageUrl,
        if (request.email != null && request.email!.trim().isNotEmpty)
          'email': request.email,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (request.pin.trim().isNotEmpty) ...{
          'pin': request.pin.trim(),
          'chatPin': request.pin.trim(),
          'userPin': request.pin.trim(),
        },
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw CompleteProfileRepositoryException(
        error.message ?? 'Gagal menyimpan profil (${error.code}).',
      );
    } catch (error) {
      throw CompleteProfileRepositoryException(
        'Gagal menyimpan profil: $error',
      );
    }
  }

  String? _extractExistingPin(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;
    for (final key in const ['pin', 'chatPin', 'userPin', 'PIN']) {
      final value = data[key];
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return null;
  }
}
