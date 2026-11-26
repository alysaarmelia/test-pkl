import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../firebase_options.dart';
import '../view_models/profile_model.dart';

enum ProfileRepositoryResultType { success, cancelled, failure }

class ProfileRepositoryResult {
  const ProfileRepositoryResult({required this.type, this.failure});

  final ProfileRepositoryResultType type;
  final ProfileRepositoryFailure? failure;

  bool get isSuccess => type == ProfileRepositoryResultType.success;
  bool get isCancelled => type == ProfileRepositoryResultType.cancelled;

  const ProfileRepositoryResult.success()
    : type = ProfileRepositoryResultType.success,
      failure = null;

  const ProfileRepositoryResult.cancelled()
    : type = ProfileRepositoryResultType.cancelled,
      failure = null;

  const ProfileRepositoryResult.failure(this.failure)
    : type = ProfileRepositoryResultType.failure;
}

enum ProfileRepositoryFailure {
  galleryPermissionDenied,
  galleryOpenFailed,
  uploadFailed,
  deleteFailed,
}

abstract class ProfileRepository {
  String? get currentUid;

  Stream<ProfileData?> watchProfile(String uid);

  Future<ProfileRepositoryResult> updateProfilePhoto(String uid);

  Future<ProfileRepositoryResult> removeProfilePhoto(String uid);
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  FirebaseStorage? _storage;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<ProfileData?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      return ProfileData.fromMap(data);
    });
  }

  @override
  Future<ProfileRepositoryResult> updateProfilePhoto(String uid) async {
    XFile? picked;
    try {
      final picker = ImagePicker();
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    } on PlatformException catch (error) {
      const permissionDeniedCodes = {
        'photo_access_denied',
        'camera_access_denied',
        'permission_denied',
      };
      final failure = permissionDeniedCodes.contains(error.code)
          ? ProfileRepositoryFailure.galleryPermissionDenied
          : ProfileRepositoryFailure.galleryOpenFailed;
      return ProfileRepositoryResult.failure(failure);
    } catch (_) {
      return const ProfileRepositoryResult.failure(
        ProfileRepositoryFailure.galleryOpenFailed,
      );
    }

    if (picked == null) {
      return const ProfileRepositoryResult.cancelled();
    }

    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Atur Foto Profil',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            statusBarColor: Colors.black,
            activeControlsWidgetColor: Colors.white,
            hideBottomControls: true,
            showCropGrid: true,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Atur Foto Profil',
            aspectRatioLockEnabled: true,
            rotateButtonsHidden: true,
            resetButtonHidden: true,
            aspectRatioPickerButtonHidden: true,
            minimumAspectRatio: 1.0,
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
          ),
        ],
      );
    } catch (_) {
      // If crop fails, continue with original image.
    }

    try {
      final uploadBytes = await _prepareUploadBytes(
        picked: picked,
        cropped: cropped,
      );

      var storage = _storage ??= FirebaseStorage.instance;
      final configuredBucket =
          DefaultFirebaseOptions.currentPlatform.storageBucket;
      if (configuredBucket != null && configuredBucket.isNotEmpty) {
        final bucket = configuredBucket.startsWith('gs://')
            ? configuredBucket
            : 'gs://$configuredBucket';
        try {
          storage = FirebaseStorage.instanceFor(bucket: bucket);
        } catch (_) {
          storage = _storage ?? FirebaseStorage.instance;
        }
      }

      final ref = storage.ref().child('profile_pictures/$uid.jpg');
      final snapshot = await ref.putData(
        uploadBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=7200',
        ),
      );

      if (snapshot.state != TaskState.success) {
        return const ProfileRepositoryResult.failure(
          ProfileRepositoryFailure.uploadFailed,
        );
      }

      final url = await _getDownloadUrlWithRetry(snapshot.ref);
      await _firestore.collection('users').doc(uid).update({'photoUrl': url});

      return const ProfileRepositoryResult.success();
    } on FirebaseException catch (_) {
      return const ProfileRepositoryResult.failure(
        ProfileRepositoryFailure.uploadFailed,
      );
    } catch (_) {
      return const ProfileRepositoryResult.failure(
        ProfileRepositoryFailure.uploadFailed,
      );
    }
  }

  @override
  Future<ProfileRepositoryResult> removeProfilePhoto(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'photoUrl': FieldValue.delete(),
      });

      final storage = _storage ??= FirebaseStorage.instance;
      final ref = storage.ref().child('profile_pictures/$uid.jpg');
      await ref.delete();

      return const ProfileRepositoryResult.success();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return const ProfileRepositoryResult.success();
      }
      return const ProfileRepositoryResult.failure(
        ProfileRepositoryFailure.deleteFailed,
      );
    } catch (_) {
      return const ProfileRepositoryResult.failure(
        ProfileRepositoryFailure.deleteFailed,
      );
    }
  }

  Future<Uint8List> _prepareUploadBytes({
    required XFile picked,
    CroppedFile? cropped,
  }) async {
    Uint8List rawBytes;
    try {
      if (cropped != null && !kIsWeb) {
        rawBytes = await File(cropped.path).readAsBytes();
      } else if (!kIsWeb) {
        rawBytes = await File(picked.path).readAsBytes();
      } else {
        rawBytes = await picked.readAsBytes();
      }
    } catch (_) {
      rawBytes = await picked.readAsBytes();
    }

    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      const maxSide = 1080;
      final needsResize = decoded.width > maxSide || decoded.height > maxSide;
      final processed = needsResize
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxSide : null,
              height: decoded.height > decoded.width ? maxSide : null,
              interpolation: img.Interpolation.average,
            )
          : decoded;

      return Uint8List.fromList(img.encodeJpg(processed, quality: 82));
    } catch (_) {
      return rawBytes;
    }
  }

  Future<String> _getDownloadUrlWithRetry(
    Reference ref, {
    int maxAttempts = 5,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await ref.getDownloadURL();
      } on FirebaseException catch (error) {
        final notFoundCodes = {
          'object-not-found',
          'storage/object-not-found',
          'not-found',
          '404',
        };

        if (!notFoundCodes.contains(error.code) || attempt >= maxAttempts) {
          rethrow;
        }

        final delayMs = (300 * pow(2, attempt - 1)).toInt();
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }
}
