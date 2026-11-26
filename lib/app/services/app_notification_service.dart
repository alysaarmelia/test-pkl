import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_reminder_manager.dart';
import 'notification_service.dart';
import '../../shared/models/calendar_event.dart';
import '../../shared/models/document_record.dart';
import '../../shared/services/calendar_event_repository.dart';
import '../../shared/services/document_repository.dart';

enum AppNotificationType {
  calendar,
  attendance,
  leave,
  material,
  document,
  general,
}

class AppNotificationEntry {
  AppNotificationEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.data = const <String, dynamic>{},
    this.isRead = false,
  });

  factory AppNotificationEntry.fromJson(Map<String, dynamic> json) {
    final typeString = (json['type'] as String?) ?? 'general';
    return AppNotificationEntry(
      id: (json['id'] as String?) ?? '',
      type: AppNotificationType.values.firstWhere(
        (value) => value.name == typeString,
        orElse: () => AppNotificationType.general,
      ),
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      data:
          (json['data'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          const <String, dynamic>{},
      isRead: json['isRead'] == true,
    );
  }

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final bool isRead;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'isRead': isRead,
    };
  }

  AppNotificationEntry copyWith({bool? isRead}) {
    return AppNotificationEntry(
      id: id,
      type: type,
      title: title,
      body: body,
      timestamp: timestamp,
      data: data,
      isRead: isRead ?? this.isRead,
    );
  }
}

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService _instance = AppNotificationService._();
  factory AppNotificationService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notifications = NotificationService();
  final DocumentReminderManager _documentReminders = DocumentReminderManager();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _documentsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userProfileSubscription;
  String? _currentUserId;
  Set<String> _userDivisions = <String>{};

  bool _initialCalendarSnapshotLoaded = false;
  bool _initialDocumentSnapshotLoaded = false;
  bool _started = false;
  final Set<String> _knownEventIds = <String>{};
  final Set<String> _knownDocumentIds = <String>{};
  final Set<String> _localDocumentIds = <String>{};
  DateTime? _lastDocumentSeenAt;

  static const String _prefsKeyPrefix = 'app_notifications';
  static const int _maxStoredNotifications = 30;
  static const String _prefsLastDocumentSeenAtKey =
      'app_notifications_documents_last_seen';
  static const String _prefsReminderLogKeyPrefix =
      'app_notifications_reminder_keys';

  final RxList<AppNotificationEntry> _entries = <AppNotificationEntry>[].obs;
  final RxInt _unreadCount = 0.obs;
  final Set<String> _loggedReminderKeys = <String>{};

  RxList<AppNotificationEntry> get notifications => _entries;
  RxInt get unreadCount => _unreadCount;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _currentUserId = _auth.currentUser?.uid;
    await _loadNotificationsFromPrefs(_currentUserId);
    _authSubscription ??= _auth.authStateChanges().listen((user) {
      final newUid = user?.uid;
      if (newUid != _currentUserId) {
        _switchUser(newUid);
      }
      _eventsSubscription?.cancel();
      _eventsSubscription = null;
      _documentsSubscription?.cancel();
      _documentsSubscription = null;
      _initialCalendarSnapshotLoaded = false;
      _initialDocumentSnapshotLoaded = false;
      _knownEventIds.clear();
      _knownDocumentIds.clear();
      _localDocumentIds.clear();
      _lastDocumentSeenAt = null;
      if (user != null) {
        _subscribeToUserProfile(user.uid);
        _subscribeToCalendarEvents(user.uid);
        _subscribeToDocuments(user.uid);
      }
    });
  }

  void dispose() {
    _authSubscription?.cancel();
    _eventsSubscription?.cancel();
    _documentsSubscription?.cancel();
    _userProfileSubscription?.cancel();
    _started = false;
  }

  Future<void> _switchUser(String? newUid) async {
    final previousUid = _currentUserId;
    if (previousUid != null && previousUid != newUid) {
      await _saveNotificationsToPrefs(overrideUid: previousUid);
      await _saveReminderLogKeys(overrideUid: previousUid);
    }

    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _documentsSubscription?.cancel();
    _documentsSubscription = null;
    _userProfileSubscription?.cancel();
    _userDivisions = <String>{};
    _initialCalendarSnapshotLoaded = false;
    _initialDocumentSnapshotLoaded = false;
    _knownEventIds.clear();
    _knownDocumentIds.clear();
    _localDocumentIds.clear();
    _lastDocumentSeenAt = null;
    _loggedReminderKeys.clear();
    _entries.clear();
    _recalculateUnread();

    _currentUserId = newUid;

    if (newUid != null) {
      await _loadNotificationsFromPrefs(newUid);
    }
  }

  void _subscribeToUserProfile(String uid) {
    _userProfileSubscription?.cancel();
    _userProfileSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      _userDivisions = CalendarDivision.divisionsFromUserData(snapshot.data());
    }, onError: (_) {
      _userDivisions = <String>{};
    });
  }

  Future<void> addNotification({
    required AppNotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    bool markUnread = true,
    bool showLocalNotification = false,
    bool showInAppBanner = false,
    String? payload,
    DateTime? timestamp,
  }) async {
    final entry = AppNotificationEntry(
      id: _buildEntryId(type),
      type: type,
      title: title,
      body: body,
      timestamp: timestamp ?? DateTime.now(),
      data: data ?? const <String, dynamic>{},
      isRead: !markUnread,
    );
    _entries.insert(0, entry);
    _trimEntries();
    _recalculateUnread();
    await _saveNotificationsToPrefs();

    if (showLocalNotification) {
      switch (type) {
        case AppNotificationType.calendar:
          await _notifications.showCalendarEventNotification(
            eventId: entry.id,
            title: title,
            body: body,
            payload: payload,
          );
          break;
        case AppNotificationType.attendance:
          await _notifications.showAttendanceNotification(
            title: title,
            body: body,
            payload: payload,
          );
          break;
        case AppNotificationType.leave:
          await _notifications.showLeaveStatusNotification(
            requestId: entry.id,
            title: title,
            body: body,
          );
          break;
        case AppNotificationType.material:
          await _notifications.showMaterialRequestNotification(
            requestId: entry.id,
            title: title,
            body: body,
          );
          break;
        case AppNotificationType.document:
        case AppNotificationType.general:
          await _notifications.showSimpleNotification(
            title: title,
            body: body,
            payload: payload,
          );
          break;
      }
    }

    if (showInAppBanner) {
      _showInAppBanner(title: title, body: body, type: type);
    }
  }

  Future<void> removeNotification(String id) async {
    _entries.removeWhere((item) => item.id == id);
    _recalculateUnread();
    await _saveNotificationsToPrefs();
  }

  Future<void> clearNotifications() async {
    _entries.clear();
    _unreadCount.value = 0;
    await _saveNotificationsToPrefs();
  }

  Future<void> markAllAsRead() async {
    if (_unreadCount.value == 0) return;
    for (var i = 0; i < _entries.length; i++) {
      final item = _entries[i];
      if (!item.isRead) {
        _entries[i] = item.copyWith(isRead: true);
      }
    }
    _unreadCount.value = 0;
    await _saveNotificationsToPrefs();
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _entries.indexWhere(
      (element) => element.id == notificationId,
    );
    if (index == -1) return;
    final target = _entries[index];
    if (target.isRead) return;
    _entries[index] = target.copyWith(isRead: true);
    _recalculateUnread();
    await _saveNotificationsToPrefs();
  }

  void _subscribeToCalendarEvents(String _currentUserId) {
    _eventsSubscription = _firestore
        .collection(CalendarEventRepository.collectionName)
        .orderBy('date')
        .snapshots()
        .listen((snapshot) async {
          final bool isInitialSnapshot = !_initialCalendarSnapshotLoaded;
          if (isInitialSnapshot) {
            _initialCalendarSnapshotLoaded = true;
          }

          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) {
              continue;
            }
            final data = change.doc.data();
            if (data == null) {
              continue;
            }
            final bool hasPendingWrites = change.doc.metadata.hasPendingWrites;
            if (isInitialSnapshot && !hasPendingWrites) {
              _knownEventIds.add(change.doc.id);
              continue;
            }
            if (!hasPendingWrites && _knownEventIds.contains(change.doc.id)) {
              continue;
            }
            _knownEventIds.add(change.doc.id);

            final event = CalendarEvent.fromSnapshot(change.doc);
            if (!_isEventVisible(event)) {
              continue;
            }

            final title = event.title.trim().isNotEmpty
                ? event.title.trim()
                : 'Acara Baru';
            final body = _buildCalendarBody(event);

            await addNotification(
              type: AppNotificationType.calendar,
              title: title,
              body: body,
              data: {
                'eventId': event.id,
                'eventDate': event.date.toIso8601String(),
              },
              markUnread: true,
              showLocalNotification: true,
              showInAppBanner: true,
              payload: event.id,
            );
          }
        });
  }

  void _subscribeToDocuments(String uid) {
    _documentsSubscription?.cancel();
    _initialDocumentSnapshotLoaded = false;
    _knownDocumentIds.clear();
    _localDocumentIds.clear();

    _documentsSubscription = _firestore
        .collection(DocumentRepository.collectionName)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) async {
          _lastDocumentSeenAt ??= await _loadLastDocumentSeenAt(uid);
          // Jika belum pernah ada "last seen", mundurkan patokan 30 hari
          // supaya dokumen yang diunggah saat user offline tetap ter-notify.
          final DateTime defaultLookback =
              DateTime.now().subtract(const Duration(days: 30));
          DateTime lastSeen = _lastDocumentSeenAt ?? defaultLookback;

          final bool isInitialSnapshot = !_initialDocumentSnapshotLoaded;
          if (isInitialSnapshot) {
            _initialDocumentSnapshotLoaded = true;
          }

          DateTime latestSeen = lastSeen;
          final documents =
              snapshot.docs.map(DocumentRecord.fromSnapshot).toList(
                    growable: false,
                  );
          unawaited(_documentReminders.syncDocuments(documents));
          unawaited(_logUpcomingDocumentReminders(documents));
          final Map<String, DocumentRecord> recordsById = {
            for (final doc in documents) doc.id: doc,
          };

          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            if (data == null) {
              continue;
            }

            final String documentId = change.doc.id;
            final bool hasPendingWrites = change.doc.metadata.hasPendingWrites;

            if (hasPendingWrites) {
              _localDocumentIds.add(documentId);
              continue;
            }

            final record =
                recordsById[change.doc.id] ?? DocumentRecord.fromSnapshot(
                  change.doc,
                );
            final createdAt = record.createdAt;
            if (createdAt.isAfter(latestSeen)) {
              latestSeen = createdAt;
            }

            if (isInitialSnapshot) {
              if (record.createdBy != uid && createdAt.isAfter(lastSeen)) {
                await _notifyDocumentAdded(record);
              }
              _knownDocumentIds.add(documentId);
              continue;
            }

            if (_localDocumentIds.remove(documentId)) {
              _knownDocumentIds.add(documentId);
              continue;
            }

            if (_knownDocumentIds.contains(documentId)) {
              continue;
            }
            _knownDocumentIds.add(documentId);

            if (change.type != DocumentChangeType.added) {
              continue;
            }

            if (record.createdBy == uid) {
              continue;
            }

            await _notifyDocumentAdded(record);
          }

          if (latestSeen.isAfter(lastSeen)) {
            _lastDocumentSeenAt = latestSeen;
            await _saveLastDocumentSeenAt(uid: uid, value: latestSeen);
          }
        });
  }

  Future<void> _logUpcomingDocumentReminders(
    List<DocumentRecord> documents,
  ) async {
    final now = DateTime.now();
    _pruneReminderLogKeys(now);
    bool dirty = false;

    for (final doc in documents) {
      final expiresAt = doc.expiresAt;
      final interval = doc.reminderInterval;
      if (expiresAt == null || interval == null) continue;

      final upcoming = _documentReminders.previewUpcoming(
        expiresAt: expiresAt,
        interval: interval,
        now: now,
        window: const Duration(hours: 26),
        max: 2,
      );

      for (final scheduledAt in upcoming) {
        final key = _reminderLogKey(doc.id, scheduledAt);
        if (_loggedReminderKeys.contains(key)) continue;

        _loggedReminderKeys.add(key);
        dirty = true;

        final timeText =
            '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';
        final formattedExpiry = _formatDate(expiresAt);

        await addNotification(
          type: AppNotificationType.document,
          title: 'Pengingat dokumen: ${doc.title}',
          body: 'Jadwal $timeText • Kedaluwarsa $formattedExpiry',
          data: <String, dynamic>{
            'documentId': doc.id,
            'scheduledAt': scheduledAt.toIso8601String(),
            'expiresAt': expiresAt.toIso8601String(),
            'kind': 'document_reminder',
          },
          markUnread: true,
          showLocalNotification: false,
          showInAppBanner: false,
          payload: doc.id,
          timestamp: scheduledAt,
        );
      }
    }

    if (dirty) {
      await _saveReminderLogKeys();
    }
  }

  Future<void> _notifyDocumentAdded(DocumentRecord record) async {
    final title = record.title.trim().isNotEmpty
        ? record.title.trim()
        : 'Dokumen baru';
    final fileName = record.originalFileName?.trim();
    final body = fileName != null && fileName.isNotEmpty
        ? 'Admin menambahkan dokumen "$title" ($fileName) ke akun Anda.'
        : 'Admin menambahkan dokumen "$title" ke akun Anda.';

    await addNotification(
      type: AppNotificationType.document,
      title: 'Dokumen baru ditambahkan',
      body: body,
      data: <String, dynamic>{
        'documentId': record.id,
        'title': title,
        if (fileName != null && fileName.isNotEmpty) 'fileName': fileName,
      },
      markUnread: true,
      showLocalNotification: true,
      showInAppBanner: true,
      payload: record.id,
    );
  }

  Future<void> _loadNotificationsFromPrefs(String? uid) async {
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKeyFor(uid));
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      final loaded =
          decoded
              .whereType<Map<String, dynamic>>()
              .map(AppNotificationEntry.fromJson)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _entries.assignAll(loaded);
      _recalculateUnread();
      for (final item in loaded) {
        final eventId = item.data['eventId'];
        if (eventId is String) {
          _knownEventIds.add(eventId);
        }
      }
      await _loadReminderLogKeys(uid);
    } catch (_) {
      // ignore malformed cache
    }
  }

  Future<void> _saveNotificationsToPrefs({String? overrideUid}) async {
    final uid = overrideUid ?? _currentUserId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = _entries
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await prefs.setString(_prefsKeyFor(uid), jsonEncode(payload));
  }

  Future<void> _loadReminderLogKeys(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKeyForReminderLog(uid));
      if (raw != null) {
        _loggedReminderKeys
          ..clear()
          ..addAll(raw);
      }
      _pruneReminderLogKeys(DateTime.now());
    } catch (_) {
      _loggedReminderKeys.clear();
    }
  }

  Future<void> _saveReminderLogKeys({String? overrideUid}) async {
    final uid = overrideUid ?? _currentUserId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKeyForReminderLog(uid),
      _loggedReminderKeys.toList(growable: false),
    );
  }

  Future<DateTime?> _loadLastDocumentSeenAt(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKeyForDocumentSeen(uid));
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastDocumentSeenAt({
    required String uid,
    required DateTime value,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyForDocumentSeen(uid),
        value.toIso8601String(),
      );
    } catch (_) {
      // ignore persistence errors
    }
  }

  String _buildEntryId(AppNotificationType type) {
    final timePart = DateTime.now().microsecondsSinceEpoch;
    return '${type.name}-$timePart';
  }

  void _trimEntries() {
    if (_entries.length <= _maxStoredNotifications) return;
    _entries.removeRange(_maxStoredNotifications, _entries.length);
  }

  void _recalculateUnread() {
    _unreadCount.value = _entries.where((element) => !element.isRead).length;
  }

  String _prefsKeyFor(String uid) => '$_prefsKeyPrefix-$uid';
  String _prefsKeyForDocumentSeen(String uid) =>
      '$_prefsLastDocumentSeenAtKey-$uid';
  String _prefsKeyForReminderLog(String uid) =>
      '$_prefsReminderLogKeyPrefix-$uid';

  String _reminderLogKey(String documentId, DateTime scheduledAt) {
    return '$documentId|${scheduledAt.millisecondsSinceEpoch}';
  }

  void _pruneReminderLogKeys(DateTime now) {
    final cutoff = now.subtract(const Duration(days: 2));
    _loggedReminderKeys.removeWhere((key) {
      final millisPart = key.split('|').last;
      final millis = int.tryParse(millisPart);
      if (millis == null) return true;
      final time = DateTime.fromMillisecondsSinceEpoch(millis);
      return time.isBefore(cutoff);
    });
  }

  bool _isEventVisible(CalendarEvent event) {
    if (event.divisions.isEmpty || event.divisions.contains(CalendarDivision.all)) {
      return true;
    }
    if (_userDivisions.isEmpty || _userDivisions.contains(CalendarDivision.all)) {
      // When the user's division isn't known, show the notification rather than dropping it.
      return true;
    }
    for (final division in event.divisions) {
      if (_userDivisions.contains(division)) return true;
    }
    return false;
  }

  String _buildCalendarBody(CalendarEvent event) {
    final dateText = _formatDate(event.date);
    final timeText = event.timeText?.trim() ?? '';
    final location = event.location?.trim() ?? '';
    final details = [
      timeText,
      location,
    ].where((value) => value.isNotEmpty).join(' • ');
    if (details.isEmpty) {
      return 'Tanggal $dateText';
    }
    return '$details • $dateText';
  }

  String _formatDate(DateTime value) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final local = value.toLocal();
    final month = months[(local.month - 1).clamp(0, months.length - 1)];
    return '${local.day} $month ${local.year}';
  }

  void _showInAppBanner({
    required String title,
    required String body,
    required AppNotificationType type,
  }) {
    final context = Get.overlayContext;
    if (context == null) return;
    if (Get.isSnackbarOpen == true) {
      Get.back();
    }

    final icon = _iconForBanner(type);

    Get.showSnackbar(
      GetSnackBar(
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        backgroundColor: const Color.fromRGBO(15, 25, 48, 0.88),
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        messageText: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white70, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForBanner(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.calendar:
        return Icons.event_available_rounded;
      case AppNotificationType.attendance:
        return Icons.fingerprint_rounded;
      case AppNotificationType.leave:
        return Icons.assignment_turned_in_rounded;
      case AppNotificationType.material:
        return Icons.inventory_2_rounded;
      case AppNotificationType.document:
        return Icons.insert_drive_file_rounded;
      case AppNotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }
}
