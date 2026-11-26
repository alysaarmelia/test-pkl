import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:cipta_vera_mandiri_digital/absensi/controllers/attendance_controller.dart';
import 'package:cipta_vera_mandiri_digital/absensi/services/attendance_camera_service.dart';
import 'package:cipta_vera_mandiri_digital/absensi/services/attendance_camera_input_converter.dart';
import 'package:cipta_vera_mandiri_digital/absensi/services/attendance_face_verification_service.dart';
import 'package:cipta_vera_mandiri_digital/absensi/services/attendance_liveness_service.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/bindings/shared_preferences.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/services/notification_service.dart';
import 'package:cipta_vera_mandiri_digital/main.dart';
import 'package:cipta_vera_mandiri_digital/repositories/attendance_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/attendance_window.dart';
import 'package:cipta_vera_mandiri_digital/view_models/attendance_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:get/get.dart';

part 'attendance_page_views.dart';

enum _InStep { faceRecognition, location, backPhoto, confirm }

enum _NotifyTone { info, success, warning, error }

const Duration _faceAnalysisThrottle = Duration(milliseconds: 140);

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  static const routeName = '/attendance';

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final AttendanceController _controller;

  // --- Camera and Face Detection ---
  CameraController? _cameraController;
  bool _usingInfraredCamera = false;
  bool get _screenFlashActive => _controller.screenFlashActive.value;
  set _screenFlashActive(bool value) =>
      _controller.screenFlashActive.value = value;
  DateTime? _lastAnalyzedFrameAt;
  late final AttendanceCameraService _cameraService;
  final NotificationService _notificationService = NotificationService();
  late final AttendanceFaceVerificationService _faceVerificationService;
  String? _scheduledOpenNotificationKey;
  String? _scheduledCloseNotificationKey;

  bool get _shouldUseScreenFlash => !_usingInfraredCamera && !Platform.isIOS;
  static const Duration _snackDuration = Duration(seconds: 3);

  void _showSnack(String message, {_NotifyTone tone = _NotifyTone.info}) {
    if (!mounted) return;
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();

    final Color bgColor;
    final IconData icon;
    switch (tone) {
      case _NotifyTone.success:
        bgColor = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline;
        break;
      case _NotifyTone.warning:
        bgColor = const Color(0xFFED6C02);
        icon = Icons.warning_amber_rounded;
        break;
      case _NotifyTone.error:
        bgColor = const Color(0xFFC62828);
        icon = Icons.error_outline;
        break;
      case _NotifyTone.info:
        bgColor = const Color(0xFF1565C0);
        icon = Icons.info_outline;
        break;
    }

    const borderRadius = BorderRadius.all(Radius.circular(20));

    scaffold.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: _snackDuration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 16),
              child: child,
            ),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgColor.withAlpha(80), bgColor.withAlpha(40)],
                  ),
                  border: Border.all(
                    color: Colors.white.withAlpha(70),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _announceAttendanceStatus({
    required String key,
    required String message,
    _NotifyTone tone = _NotifyTone.info,
  }) {
    if (!mounted) return;
    if (_lastAttendanceAnnouncementKey == key) return;
    _lastAttendanceAnnouncementKey = key;
    _showSnack(message, tone: tone);
  }

  Future<void> _scheduleLocalAttendanceReminder({
    required String key,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    _lastAttendanceAnnouncementKey = key;
    try {
      await _notificationService.scheduleAttendanceNotification(
        id: key,
        title: title,
        body: body,
        scheduledAt: at,
      );
    } catch (e, st) {
      debugPrint('Failed to schedule attendance reminder: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _cancelAttendanceReminder(String? key) async {
    if (key == null) return;
    try {
      await _notificationService.cancelAttendanceNotification(key);
    } catch (e) {
      debugPrint('Failed to cancel attendance reminder: $e');
    }
  }

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.2,
    ),
  );
  bool _isProcessing = false;
  List<Face> _faces = [];
  Size? _absoluteImageSize;
  bool _faceDetectedInFrame = false;
  bool? _ownerVerified; // null=unknown, true=match, false=mismatch
  late final AttendanceLivenessService _livenessService;
  DateTime? _lastOverlayUpdate;
  AttendanceLivenessChallenge? get _challenge =>
      _livenessService.currentChallenge;
  bool get _challengePassed => _livenessService.challengePassed;
  bool get _isChallengeReady => _livenessService.isChallengeReady;

  void _pickNewChallenge() {
    _setStateSafe(() {
      _ownerVerified = null;
      _livenessService.pickNewChallenge();
    });
  }

  DateTime? get checkInAt => _controller.checkInAt.value;
  set checkInAt(DateTime? value) => _controller.checkInAt.value = value;

  File? get _inFaceRecognition => _controller.inFaceRecognition.value;
  set _inFaceRecognition(File? value) =>
      _controller.inFaceRecognition.value = value;

  File? get _inBackPhoto => _controller.inBackPhoto.value;
  set _inBackPhoto(File? value) => _controller.inBackPhoto.value = value;

  Position? get _inPos => _controller.inPos.value;
  set _inPos(Position? value) => _controller.inPos.value = value;

  _InStep get _inStep => _InStep.values[_controller.inStepIndex.value];
  set _inStep(_InStep value) => _controller.inStepIndex.value = value.index;

  bool get _stateLoaded => _controller.stateLoaded.value;
  set _stateLoaded(bool value) => _controller.stateLoaded.value = value;

  bool get _isSavingAttendance => _controller.isSavingAttendance.value;
  set _isSavingAttendance(bool value) =>
      _controller.isSavingAttendance.value = value;

  StreamSubscription<AttendanceWindow?>? _windowSubscription;

  bool get _attendanceWindowLoaded => _controller.attendanceWindowLoaded.value;
  set _attendanceWindowLoaded(bool value) =>
      _controller.attendanceWindowLoaded.value = value;

  bool get _attendanceAvailable => _controller.attendanceAvailable.value;
  set _attendanceAvailable(bool value) =>
      _controller.attendanceAvailable.value = value;

  bool get _isLateNow => _controller.isLateNow.value;

  bool get _hasAttendanceToday => _controller.hasAttendanceToday.value;
  set _hasAttendanceToday(bool value) =>
      _controller.hasAttendanceToday.value = value;

  bool get _checkingExistingAttendance =>
      _controller.checkingExistingAttendance.value;
  set _checkingExistingAttendance(bool value) =>
      _controller.checkingExistingAttendance.value = value;

  String? get _attendanceStatusMessage =>
      _controller.attendanceStatusMessage.value;
  set _attendanceStatusMessage(String? value) =>
      _controller.attendanceStatusMessage.value = value;

  Color get _attendanceStatusColor => _controller.attendanceStatusColor.value;
  set _attendanceStatusColor(Color value) =>
      _controller.attendanceStatusColor.value = value;

  Timer? _attendanceWindowTimer;
  Duration get _currentLateDuration => _controller.currentLateDuration.value;

  final TextEditingController _lateReasonController = TextEditingController();
  String? get _lateReasonError => _controller.lateReasonError.value;
  set _lateReasonError(String? value) =>
      _controller.lateReasonError.value = value;

  String? get _lastAttendanceAnnouncementKey =>
      _controller.lastAttendanceAnnouncementKey.value;
  set _lastAttendanceAnnouncementKey(String? value) =>
      _controller.lastAttendanceAnnouncementKey.value = value;

  _NotifyTone _toNotifyTone(AttendanceUiTone tone) {
    switch (tone) {
      case AttendanceUiTone.info:
        return _NotifyTone.info;
      case AttendanceUiTone.success:
        return _NotifyTone.success;
      case AttendanceUiTone.warning:
        return _NotifyTone.warning;
      case AttendanceUiTone.error:
        return _NotifyTone.error;
    }
  }

  // --- Check-out requirements ---

  final TextEditingController _projectController = TextEditingController();
  bool get _isDetecting => _controller.isDetecting.value;
  set _isDetecting(bool value) => _controller.isDetecting.value = value;

  AttendanceUserData? get _currentUser => _controller.currentUser.value;

  String? get _userName => _controller.userName.value;

  String? get _activeUid => _controller.activeUid;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<AttendanceController>();
    _cameraService = Get.find<AttendanceCameraService>();
    _faceVerificationService = Get.find<AttendanceFaceVerificationService>();
    _livenessService = AttendanceLivenessService(
      onChallengeExpired: () {
        if (!mounted) return;
        _setStateSafe(() {});
      },
    );
    _attendanceStatusMessage = 'Memuat jadwal absensi...';
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadPersistedState();
    unawaited(_loadUserData());
    _subscribeAttendanceWindow();
    unawaited(_initializeFaceVerification());
    unawaited(_initializeCamera());
  }

  Future<void> _loadUserData() async {
    final user = await _controller.loadCurrentUserData();
    if (user == null) {
      if (mounted) {
        _setStateSafe(() {
          _controller.applyUserData(null);
          _checkingExistingAttendance = false;
        });
      } else {
        _controller.applyUserData(null);
        _checkingExistingAttendance = false;
      }
      return;
    }

    if (mounted) {
      _setStateSafe(() => _checkingExistingAttendance = true);
    } else {
      _checkingExistingAttendance = true;
    }

    if (!mounted) return;
    _setStateSafe(() {
      _controller.applyUserData(user);
    });
    _prefetchFaceProfileStatus();
    unawaited(_checkExistingAttendanceToday());
  }

  Future<void> _prefetchFaceProfileStatus() async {
    if (_currentUser == null || !_faceVerificationService.isReady) return;
    await _fetchFaceProfileExists();
  }

  Future<DateTime?> _fetchAttendanceToday() async {
    final userId = _currentUser?.uid;
    if (userId == null) return null;
    return _controller.fetchAttendanceToday(userId: userId);
  }

  Future<void> _checkExistingAttendanceToday() async {
    if (!_checkingExistingAttendance) {
      if (mounted) {
        _setStateSafe(() => _checkingExistingAttendance = true);
      } else {
        _checkingExistingAttendance = true;
      }
    }
    try {
      final recordedAt = await _fetchAttendanceToday();
      if (recordedAt == null) return;

      final previousStep = _inStep;
      if (mounted) {
        _setStateSafe(() {
          _controller.applyExistingAttendance(recordedAt);
          _inStep = _InStep.confirm;
        });
      } else {
        _controller.applyExistingAttendance(recordedAt);
        _inStep = _InStep.confirm;
      }
      _handleStepTransition(previousStep, _InStep.confirm);
      await AppPreferences.setCheckIn(checkInAt, uid: _activeUid);
    } catch (e, st) {
      debugPrint('Failed to check existing attendance: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted) {
        _setStateSafe(() => _checkingExistingAttendance = false);
      } else {
        _checkingExistingAttendance = false;
      }
      _evaluateAttendanceAvailability();
    }
  }

  Future<bool> _fetchFaceProfileExists({bool force = false}) async {
    return _faceVerificationService.hasStoredFaceProfile(
      userId: _currentUser?.uid,
      force: force,
    );
  }

  @override
  void dispose() {
    _isProcessing = true;
    _faceDetector.close();
    _livenessService.dispose();
    _attendanceWindowTimer?.cancel();
    _windowSubscription?.cancel();
    _cancelAttendanceReminder(_scheduledOpenNotificationKey);
    _cancelAttendanceReminder(_scheduledCloseNotificationKey);
    _lateReasonController.dispose();
    _projectController.dispose();
    unawaited(_cameraService.disposeFaceCamera());
    super.dispose();
  }

  Future<void> _initializeFaceVerification() async {
    try {
      await _faceVerificationService.init();
      await _prefetchFaceProfileStatus();
    } catch (e) {
      _showSnack(
        'Gagal inisialisasi Face Verification: $e',
        tone: _NotifyTone.error,
      );
    }
  }

  Future<void> _initializeCamera() async {
    if (_inStep != _InStep.faceRecognition || !mounted) {
      return;
    }
    try {
      final initResult = await _cameraService.initializeFaceCamera(
        availableCameras: cameras,
      );
      if (initResult == null) {
        return;
      }
      if (!mounted || _inStep != _InStep.faceRecognition) {
        await _cameraService.disposeFaceCamera();
        _cameraController = null;
        _usingInfraredCamera = false;
        return;
      }
      _setStateSafe(() {
        _cameraController = initResult.controller;
        _usingInfraredCamera = initResult.usingInfraredCamera;
        _screenFlashActive = false;
      });
      _startImageStream();
    } on AttendanceCameraException catch (e) {
      _showSnack(e.message, tone: _NotifyTone.error);
    } catch (e) {
      _showSnack('Gagal inisialisasi kamera: $e', tone: _NotifyTone.error);
    }
  }

  Future<void> _stopImageStreamIfNeeded() {
    return _cameraService.stopImageStreamIfNeeded();
  }

  void _startImageStream() {
    if (_cameraController == null || _inStep != _InStep.faceRecognition) {
      return;
    }
    unawaited(
      _cameraService.startImageStream((CameraImage image) {
        if (_inStep != _InStep.faceRecognition) return;
        if (_isProcessing) return;
        final now = DateTime.now();
        if (_lastAnalyzedFrameAt != null &&
            now.difference(_lastAnalyzedFrameAt!) < _faceAnalysisThrottle) {
          return;
        }
        _lastAnalyzedFrameAt = now;
        _isProcessing = true;
        _processCameraImage(image);
      }),
    );
  }

  Future<void> _disposeFaceCamera() async {
    await _stopImageStreamIfNeeded();
    _lastAnalyzedFrameAt = null;
    await _cameraService.disposeFaceCamera();
    _cameraController = null;
    _usingInfraredCamera = false;
  }

  void _handleStepTransition(_InStep previous, _InStep current) {
    if (previous == current) return;
    if (previous == _InStep.faceRecognition &&
        current != _InStep.faceRecognition) {
      unawaited(_disposeFaceCamera());
    } else if (current == _InStep.faceRecognition) {
      if (_cameraController == null) {
        _initializeCamera();
      } else {
        _startImageStream();
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_inStep != _InStep.faceRecognition) {
      _isProcessing = false;
      return;
    }
    final controller = _cameraController;
    if (controller == null) {
      _isProcessing = false;
      return;
    }
    final inputImage = AttendanceCameraInputConverter.fromCameraImage(
      image: image,
      controller: controller,
    );

    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    try {
      final faces = await _faceDetector.processImage(inputImage);
      bool livenessChanged = false;

      if (faces.isNotEmpty) {
        livenessChanged = _livenessService.updateFromFace(faces.first);
      }

      final bool previousFaceDetected = _faceDetectedInFrame;
      final DateTime now = DateTime.now();
      final bool shouldRebuild =
          (faces.isNotEmpty != previousFaceDetected) ||
          livenessChanged ||
          _lastOverlayUpdate == null ||
          now.difference(_lastOverlayUpdate!) >=
              const Duration(milliseconds: 120);

      void applyOverlayState() {
        _faces = faces;
        _faceDetectedInFrame = faces.isNotEmpty;
        _absoluteImageSize = inputImage.metadata?.size;
        if (faces.isEmpty) {
          _livenessService.handleNoFaceDetected();
        }
      }

      if (shouldRebuild && mounted) {
        _setStateSafe(() {
          applyOverlayState();
          _lastOverlayUpdate = now;
        });
      } else {
        applyOverlayState();
      }
    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      _isProcessing = false;
    }
  }

  String _challengeLabel() => _livenessService.challengeLabel();

  IconData _challengeIcon() => _livenessService.challengeIcon();

  Future<void> _loadPersistedState() async {
    final uid = _activeUid;
    if (uid != null) {
      await AppPreferences.clearLegacyCheckIn();
    }
    checkInAt = AppPreferences.getCheckInAt(uid: uid);
    if (checkInAt != null) {
      final now = DateTime.now();
      final last = checkInAt!;
      final isSameDay =
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day;
      if (!isSameDay) {
        checkInAt = null;
        await AppPreferences.setCheckIn(null, uid: uid);
        _hasAttendanceToday = false;
      } else {
        _hasAttendanceToday = true;
      }
    }
    final previousStep = _inStep;
    final nextStep = checkInAt != null
        ? _InStep.confirm
        : _InStep.faceRecognition;
    _stateLoaded = true;
    if (mounted) {
      _setStateSafe(() {
        _inStep = nextStep;
      });
    } else {
      _inStep = nextStep;
    }
    _handleStepTransition(previousStep, nextStep);
  }

  void _subscribeAttendanceWindow() {
    final today = DateTime.now();
    _attendanceWindowLoaded = false;
    _windowSubscription?.cancel();
    _attendanceWindowTimer?.cancel();
    _lastAttendanceAnnouncementKey = null;
    _windowSubscription = _controller
        .watchAttendanceWindow(today)
        .listen(
          (window) {
            _attendanceWindowTimer?.cancel();
            if (!mounted) return;
            _setStateSafe(() {
              _controller.attendanceWindow.value = window;
              _attendanceWindowLoaded = true;
            });
            _evaluateAttendanceAvailability();
          },
          onError: (error, stack) {
            debugPrint('Failed to load attendance window: $error');
            debugPrintStack(stackTrace: stack);
            _attendanceWindowTimer?.cancel();
            if (!mounted) return;
            _setStateSafe(() {
              _controller.applyWindowLoadError();
            });
          },
        );
  }

  void _evaluateAttendanceAvailability() {
    _attendanceWindowTimer?.cancel();
    final now = DateTime.now();
    final decision = _controller.evaluateAttendanceAvailability(now);

    if (decision.clearOpenReminder) {
      _cancelAttendanceReminder(_scheduledOpenNotificationKey);
      _scheduledOpenNotificationKey = null;
    }
    if (decision.clearCloseReminder) {
      _cancelAttendanceReminder(_scheduledCloseNotificationKey);
      _scheduledCloseNotificationKey = null;
    }

    final openReminder = decision.openReminder;
    if (openReminder != null &&
        _scheduledOpenNotificationKey != openReminder.key) {
      _cancelAttendanceReminder(_scheduledOpenNotificationKey);
      _scheduledOpenNotificationKey = openReminder.key;
      _scheduleLocalAttendanceReminder(
        key: openReminder.key,
        at: openReminder.scheduledAt.isAfter(now)
            ? openReminder.scheduledAt
            : now.add(const Duration(seconds: 1)),
        title: openReminder.title,
        body: openReminder.body,
      );
    }

    final closeReminder = decision.closeReminder;
    if (closeReminder != null &&
        _scheduledCloseNotificationKey != closeReminder.key) {
      _cancelAttendanceReminder(_scheduledCloseNotificationKey);
      _scheduledCloseNotificationKey = closeReminder.key;
      _scheduleLocalAttendanceReminder(
        key: closeReminder.key,
        at: closeReminder.scheduledAt.isAfter(now)
            ? closeReminder.scheduledAt
            : now.add(const Duration(seconds: 1)),
        title: closeReminder.title,
        body: closeReminder.body,
      );
    }

    if (!mounted) return;
    _setStateSafe(() {
      _controller.applyAvailabilityDecision(decision);
      if (!decision.late) {
        if (_lateReasonController.text.isNotEmpty) {
          _lateReasonController.clear();
        }
      }
    });

    final announcement = decision.announcement;
    if (announcement != null) {
      _announceAttendanceStatus(
        key: announcement.key,
        message: announcement.message,
        tone: _toNotifyTone(announcement.tone),
      );
    }

    if (decision.nextTrigger != null) {
      _scheduleWindowTimer(
        decision.nextTrigger!,
        resubscribe: decision.resubscribe,
      );
    }
  }

  void _scheduleWindowTimer(DateTime trigger, {bool resubscribe = false}) {
    _attendanceWindowTimer?.cancel();
    final delay = trigger.difference(DateTime.now());
    if (delay.isNegative) {
      if (resubscribe) {
        _subscribeAttendanceWindow();
      } else {
        _evaluateAttendanceAvailability();
      }
      return;
    }
    _attendanceWindowTimer = Timer(delay + const Duration(seconds: 1), () {
      if (!mounted) return;
      if (resubscribe) {
        _subscribeAttendanceWindow();
      } else {
        _evaluateAttendanceAvailability();
      }
    });
  }

  Widget _lateReasonCard() {
    return _glassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.pending_actions, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alasan Keterlambatan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lateReasonController,
            readOnly: _isSavingAttendance,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) {
              _setStateSafe(() {
                if (_lateReasonError != null) {
                  _lateReasonError = null;
                }
              });
            },
            decoration: InputDecoration(
              hintText: 'Tuliskan alasan keterlambatan Anda',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              errorText: _lateReasonError,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _persistState() async {
    await AppPreferences.setCheckIn(checkInAt, uid: _activeUid);
  }

  bool get _canCheckIn =>
      _inFaceRecognition != null && _inPos != null && _inBackPhoto != null;

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> _captureAndVerifyFace() async {
    if (_cameraController == null ||
        !_faceDetectedInFrame ||
        _currentUser == null) {
      return;
    }
    if (!_isChallengeReady) {
      _showSnack(
        'Selesaikan tantangan liveness terlebih dahulu.',
        tone: _NotifyTone.warning,
      );
      return;
    }

    final userId = _currentUser!.uid;

    _setStateSafe(() => _isDetecting = true);
    await _stopImageStreamIfNeeded();

    late final XFile xFile;
    try {
      if (_shouldUseScreenFlash && mounted) {
        _setStateSafe(() => _screenFlashActive = true);
        await Future.delayed(const Duration(milliseconds: 180));
      }

      xFile = await _cameraService.takeFacePicture(
        useTorch: _usingInfraredCamera,
      );
    } catch (e) {
      _setStateSafe(() => _isDetecting = false);
      if (_shouldUseScreenFlash && mounted) {
        _setStateSafe(() => _screenFlashActive = false);
      }
      if (mounted) {
        _startImageStream();
      }
      return;
    }

    if (_shouldUseScreenFlash && mounted) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          _setStateSafe(() => _screenFlashActive = false);
        }
      });
    }

    final File? correctedFile = await _faceVerificationService
        .normalizeCapturedFaceFile(xFile);
    if (correctedFile == null) {
      _showSnack(
        'Gagal memproses foto. Silakan coba lagi.',
        tone: _NotifyTone.error,
      );
      _setStateSafe(() => _isDetecting = false);
      if (mounted) {
        _startImageStream();
      }
      return;
    }

    // --- Verification Logic ---
    bool success = false;
    try {
      final bool isRegistered = await _fetchFaceProfileExists();
      final String imagePathForVerification = correctedFile.path;

      if (isRegistered) {
        _showSnack('Memverifikasi wajah Anda...', tone: _NotifyTone.info);
        success = await _faceVerificationService.verifyRegisteredProfile(
          userId: userId,
          imagePath: imagePathForVerification,
          threshold: 0.70,
        );
        _showSnack(
          success ? 'Verifikasi wajah berhasil!' : 'Wajah tidak cocok.',
          tone: success ? _NotifyTone.success : _NotifyTone.warning,
        );
      } else {
        _showSnack('Mendaftarkan wajah baru...', tone: _NotifyTone.info);
        await _faceVerificationService.registerNewProfile(
          userId: userId,
          imagePath: imagePathForVerification,
        );
        success = true;
        _showSnack('Pendaftaran wajah berhasil!', tone: _NotifyTone.success);
      }
    } catch (e) {
      success = false;
      debugPrint('Error during face verification/registration: $e');
      _showSnack('Terjadi error saat verifikasi: $e', tone: _NotifyTone.error);
    }

    if (!mounted) return;

    _setStateSafe(() {
      _isDetecting = false;
      _ownerVerified = success;
      if (success) {
        _inFaceRecognition = correctedFile;
      } else if (!success) {
        _inFaceRecognition = null;
      }
      _livenessService.resetAfterVerification();
    });

    _startImageStream();
  }

  Future<void> _captureBackPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (x != null) {
      _setStateSafe(() {
        _inBackPhoto = File(x.path);
      });
    }
  }

  Future<void> _captureLocation() async {
    final ok = await _ensureLocationPermission();
    if (!ok) {
      _showSnack(
        'Aktifkan lokasi & beri izin aplikasi.',
        tone: _NotifyTone.warning,
      );
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _setStateSafe(() {
      _inPos = pos;
    });
  }

  Future<void> _submitAttendance() async {
    if (!mounted) return;
    final previousStep = _inStep;
    _setStateSafe(() => _isSavingAttendance = true);

    final attempt = await _controller.attemptCheckIn(
      lateReason: _lateReasonController.text,
      project: _projectController.text,
    );
    if (!mounted) return;

    switch (attempt.type) {
      case AttendanceAttemptType.success:
        final savedAt = attempt.checkInAt ?? DateTime.now();
        _setStateSafe(() {
          checkInAt = savedAt;
          _hasAttendanceToday = true;
          _inStep = _InStep.confirm;
          _attendanceStatusMessage = 'Selamat Beraktivitas dan bekerja.';
          _attendanceStatusColor = const Color(0xFF4CAF50);
          if (_lateReasonController.text.isNotEmpty) {
            _lateReasonController.clear();
          }
          _lateReasonError = null;
          _isSavingAttendance = false;
        });
        _handleStepTransition(previousStep, _InStep.confirm);
        await _persistState();

        String successMessage = 'Check-in berhasil tersimpan.';
        _NotifyTone successTone = _NotifyTone.success;
        final submitResult = attempt.submitResult;
        final bool faceWarn = submitResult?.faceUploadFailed ?? false;
        final bool locationWarn = submitResult?.locationUploadFailed ?? false;
        if (faceWarn && locationWarn) {
          successMessage = 'Check-in tersimpan tanpa foto (unggahan gagal).';
          successTone = _NotifyTone.warning;
        } else if (faceWarn) {
          successMessage =
              'Check-in tersimpan, tetapi foto wajah gagal diunggah.';
          successTone = _NotifyTone.warning;
        } else if (locationWarn) {
          successMessage =
              'Check-in tersimpan, tetapi foto lokasi gagal diunggah.';
          successTone = _NotifyTone.warning;
        }
        _showSnack(successMessage, tone: successTone);
        break;
      case AttendanceAttemptType.alreadyCheckedIn:
        final existingAt = attempt.checkInAt;
        _setStateSafe(() {
          _hasAttendanceToday = true;
          checkInAt = existingAt;
          _attendanceStatusMessage = 'Selamat Beraktivitas dan bekerja.';
          _attendanceStatusColor = const Color(0xFF4CAF50);
          _inStep = _InStep.confirm;
          _isSavingAttendance = false;
        });
        _handleStepTransition(previousStep, _InStep.confirm);
        await AppPreferences.setCheckIn(checkInAt, uid: _activeUid);
        _showSnack(attempt.message, tone: _toNotifyTone(attempt.tone));
        break;
      case AttendanceAttemptType.lateReasonRequired:
        _setStateSafe(() {
          _isSavingAttendance = false;
          _lateReasonError = 'Alasan keterlambatan wajib diisi.';
        });
        _showSnack(attempt.message, tone: _toNotifyTone(attempt.tone));
        break;
      case AttendanceAttemptType.closed:
        _setStateSafe(() => _isSavingAttendance = false);
        _evaluateAttendanceAvailability();
        _showSnack(attempt.message, tone: _toNotifyTone(attempt.tone));
        break;
      case AttendanceAttemptType.failed:
        _setStateSafe(() {
          _isSavingAttendance = false;
          if (attempt.permissionDenied) {
            _attendanceAvailable = false;
            _attendanceStatusColor = Colors.redAccent;
            _attendanceStatusMessage =
                'Absen ditolak server. Hubungi admin untuk mendapatkan akses.';
          }
        });
        _showSnack(attempt.message, tone: _toNotifyTone(attempt.tone));
        break;
      case AttendanceAttemptType.requiresLogin:
      case AttendanceAttemptType.requiresLocation:
      case AttendanceAttemptType.notOpen:
        _setStateSafe(() => _isSavingAttendance = false);
        _showSnack(attempt.message, tone: _toNotifyTone(attempt.tone));
        break;
    }
  }

  void _nextInStep() {
    final previousStep = _inStep;
    _InStep nextStep = previousStep;
    if (previousStep == _InStep.faceRecognition) {
      nextStep = _InStep.location;
    } else if (previousStep == _InStep.location) {
      nextStep = _InStep.backPhoto;
    } else if (previousStep == _InStep.backPhoto) {
      nextStep = _InStep.confirm;
    }
    if (nextStep == previousStep) return;
    _setStateSafe(() => _inStep = nextStep);
    _handleStepTransition(previousStep, nextStep);
  }

  void _setStateSafe(VoidCallback fn) {
    fn();
    if (!mounted) return;
    _controller.update();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceController>(
      builder: (_) {
        final mediaQuery = MediaQuery.of(context);
        final contentTopInset = mediaQuery.padding.top + kToolbarHeight + 16;
        final bool alreadyCheckedIn = _hasAttendanceToday || checkInAt != null;
        final bool checkingAttendance =
            _checkingExistingAttendance && !alreadyCheckedIn;
        final bool showAvailability = !alreadyCheckedIn && !checkingAttendance;
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            foregroundColor: Colors.white,
            title: const Text(
              'Absen Kehadiran',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: HomeGlassTheme.background(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, contentTopInset, 16, 16),
                      child: _stateLoaded
                          ? Column(
                              children: [
                                if (showAvailability) ...[
                                  _buildAvailabilityBanner(),
                                  const SizedBox(height: 16),
                                ],
                                Expanded(
                                  child: () {
                                    if (alreadyCheckedIn) {
                                      return AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        child: () {
                                          switch (_inStep) {
                                            case _InStep.faceRecognition:
                                              return _inFaceRecognitionView();
                                            case _InStep.location:
                                              return _inLocationView();
                                            case _InStep.backPhoto:
                                              return _inBackPhotoView();
                                            case _InStep.confirm:
                                              return _inConfirmView();
                                          }
                                        }(),
                                      );
                                    }

                                    if (checkingAttendance ||
                                        !_attendanceWindowLoaded) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (_attendanceAvailable) {
                                      return AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        child: () {
                                          switch (_inStep) {
                                            case _InStep.faceRecognition:
                                              return _inFaceRecognitionView();
                                            case _InStep.location:
                                              return _inLocationView();
                                            case _InStep.backPhoto:
                                              return _inBackPhotoView();
                                            case _InStep.confirm:
                                              return _inConfirmView();
                                          }
                                        }(),
                                      );
                                    }

                                    return _buildLockedView();
                                  }(),
                                ),
                              ],
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
                if (_screenFlashActive)
                  Positioned.fill(child: Container(color: Colors.white)),
              ],
            ),
          ),
        );
      },
    );
  }
}
