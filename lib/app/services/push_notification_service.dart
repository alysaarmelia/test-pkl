import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:cipta_vera_mandiri_digital/firebase_options.dart';

import 'app_notification_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Pastikan binding dan plugin diregistrasi saat isolate background dibuat.
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // already initialized
  }
  await NotificationService().init(fromBackground: true);
  final notification = message.notification;
  final data = Map<String, dynamic>.from(message.data);
  final rawType = (data['type'] as String?)?.toLowerCase().trim();
  final title = notification?.title ?? data['title'] as String? ?? 'Notifikasi';
  final body = notification?.body ?? data['body'] as String? ?? '';
  final payload = data['payload'] as String?;

  if (rawType == 'chat') {
    final chatId = data['chatId'] as String? ?? payload ?? 'chat';
    final isGroup = data['isGroup'] == true ||
        ((data['isGroup'] as String?)?.toLowerCase().trim() == 'true');
    await NotificationService().showChatNotification(
      chatId: chatId,
      title: title,
      body: body.isEmpty ? 'Pesan baru' : body,
      isGroup: isGroup,
    );
    return;
  }

  final isAttendance = rawType == 'attendance' || rawType == 'absensi';
  if (isAttendance) {
    await NotificationService().showAttendanceNotification(
      title: title,
      body: body,
      payload: payload,
    );
    return;
  }

  await NotificationService().showSimpleNotification(
    title: title,
    body: body,
    payload: payload,
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      debugPrint('[PushNotificationService] Web detected, skipping native push init.');
      _initialized = true;
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.setAutoInitEnabled(true);
    if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      debugPrint('[PushNotificationService] Notification permission: $settings');
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleOpenedMessage(message, fromInitial: false),
    );

    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        _refreshAndPersistToken(user.uid);
      }
    });

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _persistToken(uid: user.uid, token: token);
      }
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _refreshAndPersistToken(user.uid);
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleOpenedMessage(initialMessage, fromInitial: true);
    }

    _initialized = true;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    _tokenSubscription = null;
    _authSubscription = null;
    _initialized = false;
  }

  Future<void> subscribeToTopic(String topic) {
    return _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) {
    return _messaging.unsubscribeFromTopic(topic);
  }

  Future<String?> getToken() {
    return _messaging.getToken();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _handleMessage(message, opened: false);
  }

  Future<void> _handleMessage(
    RemoteMessage message, {
    required bool opened,
  }) async {
    final notification = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final title =
        notification?.title ?? data['title'] as String? ?? 'Notifikasi';
    final body = notification?.body ?? data['body'] as String? ?? '';
    final rawType = (data['type'] as String?)?.toLowerCase().trim();
    if (title.trim().isEmpty && body.trim().isEmpty && data.isEmpty) {
      return;
    }

    if (rawType == 'chat') {
      // Chat notifications sudah ditangani via Cloud Messaging (background)
      // atau listener Firestore (foreground). Hindari duplikasi di sini.
      return;
    }

    final type = _typeFromData(data);
    await AppNotificationService().addNotification(
      type: type,
      title: title,
      body: body.isEmpty ? 'Lihat detail notifikasi.' : body,
      data: data,
      markUnread: true,
      showLocalNotification: !opened,
      showInAppBanner: !opened,
      payload: data['payload'] as String?,
    );
  }

  Future<void> _handleOpenedMessage(
    RemoteMessage message, {
    required bool fromInitial,
  }) async {
    await _handleMessage(message, opened: true);
  }

  Future<void> _refreshAndPersistToken(String uid) async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint(
            '[PushNotificationService] APNs token not ready yet; will retry later.',
          );
          return;
        }
      }
      final token = await _messaging.getToken();
      if (token != null) {
        await _persistToken(uid: uid, token: token);
      }
    } catch (e, st) {
      debugPrint('[PushNotificationService] Failed to get FCM token: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _persistToken({
    required String uid,
    required String token,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[PushNotificationService] Saved token for uid=$uid');
    } catch (e, st) {
      debugPrint('[PushNotificationService] Failed to persist token: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _removeToken({
    required String uid,
    required String token,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
      debugPrint('[PushNotificationService] Removed token for uid=$uid');
    } catch (e, st) {
      debugPrint('[PushNotificationService] Failed to remove token: $e');
      debugPrint(st.toString());
    }
  }

  AppNotificationType _typeFromData(Map<String, dynamic> data) {
    final raw = (data['type'] as String?)?.toLowerCase().trim();
    switch (raw) {
      case 'calendar':
        return AppNotificationType.calendar;
      case 'attendance':
      case 'absensi':
        return AppNotificationType.attendance;
      case 'leave':
      case 'izin':
      case 'cuti':
        return AppNotificationType.leave;
      case 'material':
        return AppNotificationType.material;
      case 'document':
      case 'dokumen':
        return AppNotificationType.document;
      default:
        return AppNotificationType.general;
    }
  }
}
