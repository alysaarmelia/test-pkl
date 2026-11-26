import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone_updated_gradle/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _directChannel =
      AndroidNotificationChannel(
        'direct_messages',
        'Pesan Pribadi',
        description: 'Notifikasi untuk chat personal.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _groupChannel =
      AndroidNotificationChannel(
        'group_messages',
        'Pesan Grup',
        description: 'Notifikasi untuk chat grup.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _calendarChannel =
      AndroidNotificationChannel(
        'calendar_events',
        'Agenda Kalender',
        description: 'Notifikasi ketika ada acara atau agenda baru.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _documentReminderChannel =
      AndroidNotificationChannel(
        'document_reminders',
        'Pengingat Dokumen',
        description: 'Pengingat masa berlaku dokumen pemberkasan.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
        'general_notifications',
        'Notifikasi Umum',
        description: 'Notifikasi umum aplikasi.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _attendanceChannel =
      AndroidNotificationChannel(
        'attendance_notifications_v2',
        'Absensi',
        description: 'Notifikasi terkait aktivitas absensi.',
        importance: Importance.max,
      );

  static const AndroidNotificationChannel _leaveStatusChannel =
      AndroidNotificationChannel(
        'leave_requests',
        'Izin & Cuti',
        description: 'Notifikasi keputusan pengajuan izin atau cuti.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _materialRequestChannel =
      AndroidNotificationChannel(
        'material_requests',
        'Permintaan Material',
        description: 'Notifikasi status permintaan material.',
        importance: Importance.high,
      );

  static const int _maxDocumentReminderSlots = 520;

  bool _initialized = false;
  bool _timezoneConfigured = false;
  bool _androidNotificationPermissionRequested = false;
  bool _androidExactAlarmPermissionRequested = false;
  bool _androidExactAlarmsPermitted = false;

  bool get _supportsNotifications {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> init({bool fromBackground = false}) async {
    if (_initialized) return;
    if (!_supportsNotifications) {
      _initialized = true;
      return;
    }

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: !fromBackground,
      requestBadgePermission: !fromBackground,
      requestSoundPermission: !fromBackground,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'chat',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'reply',
              'Balas',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.authenticationRequired,
              },
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            DarwinNotificationCategoryOption.allowInCarPlay,
          },
        ),
      ],
    );

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _plugin.initialize(initializationSettings);
    if (!fromBackground) {
      await _requestPermissions();
    }
    await _configureAndroidChannel();
    if (!fromBackground) {
      await _configureTimeZone();
    }

    _initialized = true;
  }

  Future<void> _configureAndroidChannel() async {
    if (!_supportsNotifications || !Platform.isAndroid) return;
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_directChannel);
      await androidImplementation.createNotificationChannel(_groupChannel);
      await androidImplementation.createNotificationChannel(_calendarChannel);
      await androidImplementation.createNotificationChannel(
        _documentReminderChannel,
      );
      await androidImplementation.createNotificationChannel(_generalChannel);
      await androidImplementation.createNotificationChannel(_attendanceChannel);
      await androidImplementation.createNotificationChannel(
        _leaveStatusChannel,
      );
      await androidImplementation.createNotificationChannel(
        _materialRequestChannel,
      );
    }
  }

  Future<void> _requestPermissions() async {
    if (!_supportsNotifications) return;
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> showChatNotification({
    required String chatId,
    required String title,
    required String body,
    required bool isGroup,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsNotifications) {
      return;
    }

    final channel = isGroup ? _groupChannel : _directChannel;
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      debugPrint(
        '[NotificationService] Notifications disabled. '
        'Skip chat notification for chatId=$chatId.',
      );
      return;
    }

    final senderName = _resolveSenderName(
      isGroup: isGroup,
      title: title,
      body: body,
    );
    final messageText = _extractMessageText(
      isGroup: isGroup,
      body: body,
    );
    final subtitle = isGroup
        ? senderName.trim().isEmpty
            ? null
            : senderName.trim()
        : null;
    final person = Person(
      name: senderName,
      key: chatId,
      important: true,
    );
    final messagingStyle = MessagingStyleInformation(
      person,
      groupConversation: isGroup,
      conversationTitle: isGroup ? title : null,
      messages: <Message>[
        Message(
          messageText,
          DateTime.now(),
          person,
        ),
      ],
    );

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: messagingStyle,
      groupKey: chatId,
      ticker: title,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
      threadIdentifier: chatId,
      categoryIdentifier: 'chat',
      subtitle: subtitle,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(chatId.hashCode, title, body, details, payload: chatId);
  }

  Future<void> showCalendarEventNotification({
    required String eventId,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsNotifications) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _calendarChannel.id,
      _calendarChannel.name,
      channelDescription: _calendarChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.event,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'calendar_events',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      (eventId.hashCode ^ 0xC41E).abs(),
      title,
      body,
      details,
      payload: payload ?? eventId,
    );
  }

  Future<void> scheduleDocumentReminder({
    required String documentId,
    required int sequence,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsNotifications) {
      return;
    }
    await _configureTimeZone();
    if (scheduledAt.isBefore(DateTime.now())) {
      return;
    }

    var preferExactAlarm = false;
    if (Platform.isAndroid) {
      final ready = await _ensureAndroidSchedulingPermissions();
      if (!ready) return;
      preferExactAlarm = _androidExactAlarmsPermitted;
    }

    final androidDetails = AndroidNotificationDetails(
      _documentReminderChannel.id,
      _documentReminderChannel.name,
      channelDescription: _documentReminderChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDateTime = tz.TZDateTime.from(scheduledAt, tz.local);

    await _scheduleWithAndroidFallback(
      id: _notificationId(documentId, sequence),
      title: title,
      body: body,
      scheduledAt: tzDateTime,
      details: details,
      payload: payload ?? documentId,
      interpretation: UILocalNotificationDateInterpretation.wallClockTime,
      preferExactAlarm: preferExactAlarm,
    );
  }

  Future<void> cancelDocumentReminder({
    required String documentId,
    int? sequence,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsNotifications) {
      return;
    }
    if (sequence != null) {
      await _plugin.cancel(_notificationId(documentId, sequence));
      return;
    }

    for (var i = 0; i < _maxDocumentReminderSlots; i++) {
      await _plugin.cancel(_notificationId(documentId, i));
    }
  }

  Future<void> scheduleAttendanceNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsNotifications) return;
    await _configureTimeZone();
    if (scheduledAt.isBefore(DateTime.now())) return;

    var preferExactAlarm = false;
    if (Platform.isAndroid) {
      final ready = await _ensureAndroidSchedulingPermissions();
      if (!ready) return;
      preferExactAlarm = _androidExactAlarmsPermitted;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _attendanceChannel.id,
        _attendanceChannel.name,
        channelDescription: _attendanceChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        enableVibration: true,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      ),
    );

    final tzDateTime = tz.TZDateTime.from(scheduledAt, tz.local);
    await _scheduleWithAndroidFallback(
      id: _attendanceNotificationId(id),
      title: title,
      body: body,
      scheduledAt: tzDateTime,
      details: details,
      payload: payload ?? id,
      interpretation: UILocalNotificationDateInterpretation.wallClockTime,
      preferExactAlarm: preferExactAlarm,
    );
  }

  Future<void> cancelAttendanceNotification(String id) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsNotifications) return;
    await _plugin.cancel(_attendanceNotificationId(id));
  }

  Future<void> _configureTimeZone() async {
    if (_timezoneConfigured || !_supportsNotifications) {
      return;
    }

    tz.initializeTimeZones();
    String resolvedTimeZone = 'Asia/Jakarta';
    try {
      resolvedTimeZone = await FlutterNativeTimezone.getLocalTimezone();
    } catch (_) {}

    try {
      tz.setLocalLocation(tz.getLocation(resolvedTimeZone));
      _timezoneConfigured = true;
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
        _timezoneConfigured = true;
      } catch (_) {}
    }
  }

  Future<bool> _ensureAndroidSchedulingPermissions() async {
    if (!_supportsNotifications || !Platform.isAndroid) {
      return true;
    }

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation == null) {
      return false;
    }

    var notificationsEnabled = await androidImplementation.areNotificationsEnabled();
    if (notificationsEnabled != true && !_androidNotificationPermissionRequested) {
      _androidNotificationPermissionRequested = true;
      notificationsEnabled =
          await androidImplementation.requestNotificationsPermission();
    }

    if (notificationsEnabled != true) {
      debugPrint(
        '[NotificationService] Android notification permission not granted; '
        'skip scheduling.',
      );
      return false;
    }

    if (!_androidExactAlarmPermissionRequested) {
      _androidExactAlarmPermissionRequested = true;
      final granted =
          await androidImplementation.requestExactAlarmsPermission();
      _androidExactAlarmsPermitted = granted ?? true;
    }

    return true;
  }

  Future<void> _scheduleWithAndroidFallback({
    required int id,
    required String? title,
    required String? body,
    required tz.TZDateTime scheduledAt,
    required NotificationDetails details,
    required String? payload,
    required UILocalNotificationDateInterpretation interpretation,
    bool preferExactAlarm = false,
  }) async {
    final scheduleMode = preferExactAlarm && Platform.isAndroid
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledAt,
        details,
        payload: payload,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: interpretation,
      );
    } on PlatformException catch (e) {
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle &&
          e.code == 'exact_alarms_not_permitted') {
        debugPrint(
          '[NotificationService] Exact alarm not permitted; retry with '
          'inexact schedule.',
        );
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledAt,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: interpretation,
        );
        return;
      }
      rethrow;
    }
  }

  int _notificationId(String documentId, int sequence) {
    final base = documentId.hashCode & 0x7fffffff;
    return ((base << 4) ^ sequence) & 0x7fffffff;
  }

  int _attendanceNotificationId(String key) {
    final base = key.hashCode & 0x7fffffff;
    return ((base << 3) ^ 0x5A17C3) & 0x7fffffff;
  }

  Future<void> showAttendanceNotification({
    required String title,
    required String body,
    String? payload,
  }) {
    return _showAttendanceAlert(
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> showLeaveStatusNotification({
    required String requestId,
    required String title,
    required String body,
  }) {
    return _showOnChannel(
      channel: _leaveStatusChannel,
      title: title,
      body: body,
      payload: requestId,
    );
  }

  Future<void> showMaterialRequestNotification({
    required String requestId,
    required String title,
    required String body,
  }) {
    return _showOnChannel(
      channel: _materialRequestChannel,
      title: title,
      body: body,
      payload: requestId,
    );
  }

  Future<bool> areNotificationsEnabled() async {
    if (!_supportsNotifications) return false;
    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final enabled = await androidImplementation?.areNotificationsEnabled();
      return enabled ?? false;
    }
    if (Platform.isIOS) {
      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final permissions = await iosImplementation?.checkPermissions();
      if (permissions == null) return false;
      return permissions.isEnabled ||
          permissions.isAlertEnabled ||
          permissions.isBadgeEnabled ||
          permissions.isSoundEnabled ||
          permissions.isProvisionalEnabled ||
          permissions.isCriticalEnabled;
    }
    return false;
  }

  String _resolveSenderName({
    required bool isGroup,
    required String title,
    required String body,
  }) {
    final trimmedTitle = title.trim();
    if (!isGroup) {
      return trimmedTitle.isEmpty ? 'Pesan baru' : trimmedTitle;
    }
    final separatorIndex = body.indexOf(':');
    if (separatorIndex <= 0) {
      return trimmedTitle.isEmpty ? 'Pesan grup baru' : trimmedTitle;
    }
    final candidate = body.substring(0, separatorIndex).trim();
    if (candidate.isEmpty) {
      return trimmedTitle.isEmpty ? 'Pesan grup baru' : trimmedTitle;
    }
    return candidate;
  }

  String _extractMessageText({
    required bool isGroup,
    required String body,
  }) {
    final trimmedBody = body.trim();
    if (!isGroup) {
      return trimmedBody;
    }
    final separatorIndex = trimmedBody.indexOf(':');
    if (separatorIndex == -1) {
      return trimmedBody;
    }
    final message = trimmedBody.substring(separatorIndex + 1).trim();
    return message.isEmpty ? trimmedBody : message;
  }

  Future<void> _showOnChannel({
    required AndroidNotificationChannel channel,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsNotifications) {
      return;
    }
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      debugPrint(
        '[NotificationService] Notifications disabled. '
        'Skip showing message on channel ${channel.id}.',
      );
      return;
    }
    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(
      _generateGenericId(),
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _showAttendanceAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsNotifications) return;
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) return;

    final androidDetails = AndroidNotificationDetails(
      _attendanceChannel.id,
      _attendanceChannel.name,
      channelDescription: _attendanceChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(body),
      ticker: title,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _generateGenericId(),
      title,
      body,
      details,
      payload: payload,
    );
  }

  int _generateGenericId() {
    return DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  }

  Future<void> showSimpleNotification({
    required String title,
    required String body,
    String? payload,
  }) {
    return _showOnChannel(
      channel: _generalChannel,
      title: title,
      body: body,
      payload: payload,
    );
  }
}
