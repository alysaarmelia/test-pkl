import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum AttendanceLivenessChallenge { blink, lookLeft, lookRight, smile }

class AttendanceLivenessService {
  AttendanceLivenessService({this.onChallengeExpired});

  final VoidCallback? onChallengeExpired;

  static const List<AttendanceLivenessChallenge> _challengePool =
      <AttendanceLivenessChallenge>[
        AttendanceLivenessChallenge.blink,
        AttendanceLivenessChallenge.lookLeft,
        AttendanceLivenessChallenge.lookRight,
        AttendanceLivenessChallenge.smile,
      ];

  static const Duration _blinkValidityWindow = Duration(seconds: 2);
  static const Duration _blinkClosureMinDuration = Duration(milliseconds: 90);
  static const int _minClosedFramesForBlink = 1;
  static const int _minOpenFramesForBlink = 1;
  static const double _yawChallengeThreshold = 12;
  static const Duration _yawHoldDuration = Duration(milliseconds: 140);
  static const Duration _challengeFreshDuration = Duration(seconds: 4);
  static const double _eyeClosedThreshold = 0.4;
  static const double _eyeOpenThreshold = 0.58;
  static const double _smileThreshold = 0.55;

  bool _blinkDone = false;
  bool _yawMoved = false;
  bool _eyesWereClosed = false;
  DateTime? _lastBlinkAt;
  double? _baseYaw;
  AttendanceLivenessChallenge? _currentChallenge;
  bool _challengePassed = false;
  List<AttendanceLivenessChallenge> _challengeSequence =
      const <AttendanceLivenessChallenge>[];
  int _challengeIndex = 0;
  int _consecutiveClosedFrames = 0;
  int _consecutiveOpenFrames = 0;
  DateTime? _eyesClosedSince;
  DateTime? _yawExceededSince;
  DateTime? _challengeCompletedAt;
  Timer? _challengeExpiryTimer;
  AttendanceLivenessChallenge? _lastChallengeType;

  AttendanceLivenessChallenge? get currentChallenge => _currentChallenge;
  bool get challengePassed => _challengePassed;

  bool get isChallengeReady {
    if (!_challengePassed || _challengeCompletedAt == null) return false;
    return DateTime.now()
            .difference(_challengeCompletedAt!)
            .compareTo(_challengeFreshDuration) <=
        0;
  }

  void dispose() {
    _challengeExpiryTimer?.cancel();
    _challengeExpiryTimer = null;
  }

  void pickNewChallenge() {
    final rnd = math.Random();
    final List<AttendanceLivenessChallenge> choices =
        List<AttendanceLivenessChallenge>.from(_challengePool);
    if (_lastChallengeType != null && choices.length > 1) {
      choices.remove(_lastChallengeType);
    }
    final AttendanceLivenessChallenge selected =
        choices[rnd.nextInt(choices.length)];
    _challengeExpiryTimer?.cancel();
    _challengeSequence = <AttendanceLivenessChallenge>[selected];
    _challengeIndex = 0;
    _currentChallenge = selected;
    _challengePassed = false;
    _challengeCompletedAt = null;
    _lastChallengeType = selected;
    _resetLivenessTracking(fullReset: true);
  }

  void handleNoFaceDetected() {
    _resetLivenessTracking(fullReset: true);
    _invalidateChallenge();
  }

  void resetAfterVerification() {
    _invalidateChallenge();
    _resetLivenessTracking(fullReset: true);
  }

  bool updateFromFace(Face face) {
    if (_challengePassed || _currentChallenge == null) {
      return false;
    }
    final String before = _uiSignature();
    try {
      final DateTime now = DateTime.now();
      final double? leftEye = face.leftEyeOpenProbability;
      final double? rightEye = face.rightEyeOpenProbability;
      final double? smile = face.smilingProbability;

      if (leftEye != null || rightEye != null) {
        double? minEyeProb;
        double? maxEyeProb;
        if (leftEye != null) {
          minEyeProb = leftEye;
          maxEyeProb = leftEye;
        }
        if (rightEye != null) {
          minEyeProb = minEyeProb == null
              ? rightEye
              : math.min(minEyeProb, rightEye);
          maxEyeProb = maxEyeProb == null
              ? rightEye
              : math.max(maxEyeProb, rightEye);
        }

        final bool closed =
            minEyeProb != null && minEyeProb < _eyeClosedThreshold;
        final bool open = maxEyeProb != null && maxEyeProb > _eyeOpenThreshold;

        if (closed) {
          _eyesWereClosed = true;
          _eyesClosedSince ??= now;
          _consecutiveClosedFrames = (_consecutiveClosedFrames + 1).clamp(0, 10);
          _consecutiveOpenFrames = 0;
        }

        if (open) {
          _consecutiveOpenFrames = (_consecutiveOpenFrames + 1).clamp(0, 10);
          if (_eyesWereClosed &&
              _eyesClosedSince != null &&
              _consecutiveClosedFrames >= _minClosedFramesForBlink &&
              _consecutiveOpenFrames >= _minOpenFramesForBlink &&
              now.difference(_eyesClosedSince!) >= _blinkClosureMinDuration) {
            _eyesWereClosed = false;
            _eyesClosedSince = null;
            _consecutiveClosedFrames = 0;
            _blinkDone = true;
            _lastBlinkAt = now;
          }
        } else if (!closed) {
          _consecutiveClosedFrames = 0;
          if (_eyesClosedSince != null &&
              now.difference(_eyesClosedSince!).inMilliseconds > 800) {
            _eyesClosedSince = null;
            _eyesWereClosed = false;
          }
        }

        if (!closed && !open) {
          _consecutiveOpenFrames = 0;
        }
      } else {
        _eyesWereClosed = false;
        _eyesClosedSince = null;
        _consecutiveClosedFrames = 0;
        _consecutiveOpenFrames = 0;
      }

      final double? yaw = face.headEulerAngleY;
      if (yaw != null) {
        _baseYaw ??= yaw;
        if (_baseYaw != null) {
          final double delta = yaw - _baseYaw!;
          if (delta.abs() > _yawChallengeThreshold) {
            _yawExceededSince ??= now;
          } else {
            _yawExceededSince = null;
          }

          if (!_yawMoved &&
              _yawExceededSince != null &&
              now.difference(_yawExceededSince!) >= _yawHoldDuration) {
            _yawMoved = true;
          }
        }
      } else {
        _baseYaw = null;
        _yawExceededSince = null;
      }

      bool passed = false;
      final bool blinkFresh =
          _lastBlinkAt != null &&
          now.difference(_lastBlinkAt!) <= _blinkValidityWindow;
      switch (_currentChallenge) {
        case AttendanceLivenessChallenge.blink:
          passed = _blinkDone;
          break;
        case AttendanceLivenessChallenge.lookLeft:
          if (yaw != null && _baseYaw != null) {
            final double delta = yaw - _baseYaw!;
            passed = delta < -_yawChallengeThreshold && blinkFresh && _yawMoved;
          }
          break;
        case AttendanceLivenessChallenge.lookRight:
          if (yaw != null && _baseYaw != null) {
            final double delta = yaw - _baseYaw!;
            passed = delta > _yawChallengeThreshold && blinkFresh && _yawMoved;
          }
          break;
        case AttendanceLivenessChallenge.smile:
          if (smile != null) {
            passed = smile > _smileThreshold && blinkFresh;
          }
          break;
        default:
          passed = false;
      }

      if (passed) {
        _advanceChallengeStep();
      }
    } catch (_) {
      // ignore liveness failures for a single frame
    }
    return before != _uiSignature();
  }

  String challengeLabel() {
    if (_challengePassed) return 'Tantangan terpenuhi';
    if (_currentChallenge == null) return 'Mulai tantangan liveness';
    final int totalSteps = _challengeSequence.isEmpty ? 1 : _challengeSequence.length;
    final int currentStep = (_challengeIndex + 1).clamp(1, totalSteps);
    final String baseLabel;
    switch (_currentChallenge) {
      case AttendanceLivenessChallenge.blink:
        baseLabel = 'Kedipkan mata Anda';
        break;
      case AttendanceLivenessChallenge.lookLeft:
        baseLabel = 'Kedip lalu tengok ke kiri';
        break;
      case AttendanceLivenessChallenge.lookRight:
        baseLabel = 'Kedip lalu tengok ke kanan';
        break;
      case AttendanceLivenessChallenge.smile:
        baseLabel = 'Kedip lalu tersenyum ke kamera';
        break;
      default:
        baseLabel = 'Lakukan instruksi liveness';
    }
    return totalSteps > 1
        ? 'Langkah $currentStep/$totalSteps • $baseLabel'
        : baseLabel;
  }

  IconData challengeIcon() {
    if (_challengePassed) return Icons.check_circle;
    switch (_currentChallenge) {
      case AttendanceLivenessChallenge.blink:
        return Icons.remove_red_eye;
      case AttendanceLivenessChallenge.smile:
        return Icons.emoji_emotions;
      case AttendanceLivenessChallenge.lookLeft:
      case AttendanceLivenessChallenge.lookRight:
        return Icons.swipe;
      default:
        return Icons.help_outline;
    }
  }

  void _advanceChallengeStep() {
    if (_challengeSequence.isEmpty) return;
    final bool hasNext = _challengeIndex + 1 < _challengeSequence.length;
    if (hasNext) {
      _challengeIndex++;
      _currentChallenge = _challengeSequence[_challengeIndex];
      _resetLivenessTracking(fullReset: false);
    } else {
      _markChallengeCompleted();
    }
  }

  void _markChallengeCompleted() {
    _challengePassed = true;
    _currentChallenge = null;
    _challengeSequence = const <AttendanceLivenessChallenge>[];
    _challengeCompletedAt = DateTime.now();
    _challengeExpiryTimer?.cancel();
    _challengeExpiryTimer = Timer(_challengeFreshDuration, () {
      _invalidateChallenge();
      _resetLivenessTracking(fullReset: true);
      onChallengeExpired?.call();
    });
  }

  void _invalidateChallenge() {
    _challengeExpiryTimer?.cancel();
    _challengeExpiryTimer = null;
    _challengePassed = false;
    _challengeCompletedAt = null;
    _challengeSequence = const <AttendanceLivenessChallenge>[];
    _challengeIndex = 0;
    _currentChallenge = null;
  }

  void _resetLivenessTracking({required bool fullReset}) {
    _blinkDone = false;
    if (fullReset) {
      _lastBlinkAt = null;
    }
    _yawMoved = false;
    _eyesWereClosed = false;
    _consecutiveClosedFrames = 0;
    _consecutiveOpenFrames = 0;
    _eyesClosedSince = null;
    _yawExceededSince = null;
    _baseYaw = null;
  }

  String _uiSignature() {
    return '${_currentChallenge?.index ?? -1}|$_challengePassed|$_challengeIndex|$_blinkDone|$_yawMoved|${_challengeCompletedAt?.millisecondsSinceEpoch ?? 0}';
  }
}
