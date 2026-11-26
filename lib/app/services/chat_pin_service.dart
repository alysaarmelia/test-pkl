import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPinService {
  static const int _maxAttempts = 12;
  static final Random _rng = _createRandom();

  static Random _createRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      // Random.secure is not available on Flutter Web / some platforms.
      return Random();
    }
  }

  static Future<String> generateUniquePin(String uid) async {
    final firestore = FirebaseFirestore.instance;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final randomNumber = 100000 + _rng.nextInt(900000);
      final pin = 'CV${randomNumber.toString().padLeft(6, '0')}M';
      final normPin = pin.replaceAll(RegExp(r'\s+'), '').toUpperCase();

      try {
        await _claimPin(firestore, uid, normPin);
        return normPin;
      } on FirebaseException catch (e) {
        // Retry on common collision signals.
        if (e.code != 'aborted' &&
            e.code != 'already-exists' &&
            e.code != 'permission-denied') {
          rethrow;
        }
      }
    }

    throw Exception(
      'Unable to generate unique PIN at this time. Please try again.',
    );
  }

  static Future<void> _claimPin(
    FirebaseFirestore firestore,
    String uid,
    String normPin,
  ) async {
    await firestore.runTransaction((transaction) async {
      final pinRef = firestore.collection('pins').doc(normPin);
      final userRef = firestore.collection('users').doc(uid);

      transaction.set(pinRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(userRef, {
        'chatPin': normPin,
        'pin': normPin,
        'userPin': normPin,
        'pinAssignedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
