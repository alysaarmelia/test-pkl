import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cipta_vera_mandiri_digital/shared/models/leave_request.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/material_request.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/leave_request_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/material_request_repository.dart';

enum AdminNotificationType { leave, permission, material, document }

class AdminNotificationEntry {
  AdminNotificationEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.targetPageIndex,
    Map<String, dynamic>? data,
  }) : data = data ?? const <String, dynamic>{};

  factory AdminNotificationEntry.fromJson(Map<String, dynamic> json) {
    final typeString = (json['type'] as String?) ?? 'leave';
    return AdminNotificationEntry(
      id: (json['id'] as String?) ?? '',
      type: AdminNotificationType.values.firstWhere(
        (value) => value.name == typeString,
        orElse: () => AdminNotificationType.leave,
      ),
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
      targetPageIndex: json['targetPageIndex'] is int
          ? json['targetPageIndex'] as int
          : (json['targetPageIndex'] is double
                ? (json['targetPageIndex'] as double).toInt()
                : null),
      data:
          (json['data'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          const <String, dynamic>{},
    );
  }

  final String id;
  final AdminNotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final int? targetPageIndex;
  final Map<String, dynamic> data;

  AdminNotificationEntry copyWith({bool? isRead}) {
    return AdminNotificationEntry(
      id: id,
      type: type,
      title: title,
      body: body,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      targetPageIndex: targetPageIndex,
      data: data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'targetPageIndex': targetPageIndex,
      'data': data,
    };
  }
}

class AdminNotificationService {
  AdminNotificationService._();

  static final AdminNotificationService _instance =
      AdminNotificationService._();
  factory AdminNotificationService() => _instance;

  static const String _prefsKeyPrefix = 'admin_notifications';
  static const int _maxStoredNotifications = 60;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<AdminNotificationEntry> _entries = <AdminNotificationEntry>[];

  final ValueNotifier<List<AdminNotificationEntry>> notifications =
      ValueNotifier<List<AdminNotificationEntry>>(
        const <AdminNotificationEntry>[],
      );

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _leaveSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _materialSubscription;
  StreamSubscription<User?>? _authSubscription;

  bool _leaveInitialSnapshotConsumed = false;
  bool _materialInitialSnapshotConsumed = false;

  final Set<String> _knownLeaveRequestIds = <String>{};
  final Set<String> _knownMaterialRequestIds = <String>{};

  bool _canListenLeave = false;
  bool _canListenMaterial = false;
  String? _currentUserId;

  Future<void>? _startFuture;

  Future<void> start() {
    _startFuture ??= _initialize();
    return _startFuture!;
  }

  void dispose() {
    _leaveSubscription?.cancel();
    _materialSubscription?.cancel();
    _leaveSubscription = null;
    _materialSubscription = null;
    _leaveInitialSnapshotConsumed = false;
    _materialInitialSnapshotConsumed = false;
    _startFuture = null;
    _canListenLeave = false;
    _canListenMaterial = false;
    _knownLeaveRequestIds.clear();
    _knownMaterialRequestIds.clear();
    _authSubscription?.cancel();
    _authSubscription = null;
    _currentUserId = null;
  }

  void updateAccess({
    required bool canListenLeave,
    required bool canListenMaterial,
  }) {
    final normalizedLeave = canListenLeave;
    final normalizedMaterial = canListenMaterial;

    if (normalizedLeave != _canListenLeave) {
      _canListenLeave = normalizedLeave;
      _leaveSubscription?.cancel();
      _leaveSubscription = null;
      _leaveInitialSnapshotConsumed = false;
      _knownLeaveRequestIds.clear();
      if (_canListenLeave) {
        _subscribeToLeaveRequests();
      }
    }

    if (normalizedMaterial != _canListenMaterial) {
      _canListenMaterial = normalizedMaterial;
      _materialSubscription?.cancel();
      _materialSubscription = null;
      _materialInitialSnapshotConsumed = false;
      _knownMaterialRequestIds.clear();
      if (_canListenMaterial) {
        _subscribeToMaterialRequests();
      }
    }
  }

  Future<void> markAllAsRead() async {
    bool changed = false;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (!entry.isRead) {
        _entries[i] = entry.copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      _refreshNotifiers();
      await _saveToPrefs();
    }
  }

  Future<void> markAsRead(String id) async {
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].id == id && !_entries[i].isRead) {
        _entries[i] = _entries[i].copyWith(isRead: true);
        _refreshNotifiers();
        await _saveToPrefs();
        break;
      }
    }
  }

  Future<void> clearAll() async {
    if (_entries.isEmpty) return;
    _entries.clear();
    _refreshNotifiers();
    await _saveToPrefs();
  }

  Future<void> _initialize() async {
    _currentUserId = _auth.currentUser?.uid;
    await _loadFromPrefs(_currentUserId);
    _authSubscription ??= _auth.authStateChanges().listen((user) async {
      final newUid = user?.uid;
      if (newUid != _currentUserId) {
        await _switchUser(newUid);
      }
    });
    if (_canListenLeave) {
      _subscribeToLeaveRequests();
    }
    if (_canListenMaterial) {
      _subscribeToMaterialRequests();
    }
  }

  Future<void> _switchUser(String? newUid) async {
    final previousUid = _currentUserId;
    if (previousUid != null && previousUid != newUid) {
      await _saveToPrefs(overrideUid: previousUid);
    }

    _leaveSubscription?.cancel();
    _materialSubscription?.cancel();
    _leaveSubscription = null;
    _materialSubscription = null;
    _leaveInitialSnapshotConsumed = false;
    _materialInitialSnapshotConsumed = false;
    _knownLeaveRequestIds.clear();
    _knownMaterialRequestIds.clear();
    _entries.clear();
    _refreshNotifiers();

    _currentUserId = newUid;

    if (newUid != null) {
      await _loadFromPrefs(newUid);
      if (_canListenLeave) {
        _subscribeToLeaveRequests();
      }
      if (_canListenMaterial) {
        _subscribeToMaterialRequests();
      }
    }
  }

  void _subscribeToLeaveRequests() {
    if (!_canListenLeave) return;
    _leaveSubscription?.cancel();
    final collection = LeaveRequestRepository.collectionName;
    _leaveSubscription = _firestore
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .listen(
          (snapshot) {
            if (!_leaveInitialSnapshotConsumed) {
              for (final doc in snapshot.docs) {
                _knownLeaveRequestIds.add(doc.id);
              }
              _leaveInitialSnapshotConsumed = true;
              return;
            }
            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added) continue;
              final doc = change.doc;
              if (!_knownLeaveRequestIds.add(doc.id)) {
                continue;
              }
              _handleLeaveRequestAdded(doc);
            }
          },
          onError: (error, stack) {
            debugPrint('Failed to listen leave requests: $error');
            debugPrint(stack.toString());
          },
        );
  }

  void _subscribeToMaterialRequests() {
    if (!_canListenMaterial) return;
    _materialSubscription?.cancel();
    final collection = MaterialRequestRepository.collectionName;
    _materialSubscription = _firestore
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .listen(
          (snapshot) {
            if (!_materialInitialSnapshotConsumed) {
              for (final doc in snapshot.docs) {
                _knownMaterialRequestIds.add(doc.id);
              }
              _materialInitialSnapshotConsumed = true;
              return;
            }
            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added) continue;
              final doc = change.doc;
              if (!_knownMaterialRequestIds.add(doc.id)) {
                continue;
              }
              _handleMaterialRequestAdded(doc);
            }
          },
          onError: (error, stack) {
            debugPrint('Failed to listen material requests: $error');
            debugPrint(stack.toString());
          },
        );
  }

  void _handleLeaveRequestAdded(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return;
    final status = leaveRequestStatusFromString(_asString(data['status']));
    if (status != LeaveRequestStatus.pending) {
      return;
    }

    final rawKind =
        _asString(data['kind']) ?? _asString(data['type']) ?? 'cuti';
    final normalizedKind = rawKind.toLowerCase().trim();
    final isPermission =
        normalizedKind == 'izin' || normalizedKind == 'permission';
    final type = isPermission
        ? AdminNotificationType.permission
        : AdminNotificationType.leave;
    final requester =
        _firstNonEmpty([
          data['requesterName'],
          data['applicantName'],
          data['name'],
          data['displayName'],
          data['username'],
        ]) ??
        'Karyawan';
    final reason = _asString(data['reason']) ?? 'Tanpa alasan';
    final startAt =
        _asDate(data['startAt']) ??
        _asDate(data['startDate']) ??
        _asDate(data['startDateTime']);
    final endAt =
        _asDate(data['endAt']) ??
        _asDate(data['endDate']) ??
        _asDate(data['endDateTime']) ??
        startAt;
    final createdAt = _asDate(data['createdAt']) ?? DateTime.now();
    final dateRangeText = _formatDateRange(startAt, endAt);

    final bodyBuffer = StringBuffer()
      ..write(requester)
      ..write(' mengajukan ')
      ..write(isPermission ? 'izin' : 'cuti');
    if (dateRangeText.isNotEmpty) {
      bodyBuffer
        ..write(' untuk ')
        ..write(dateRangeText);
    }
    if (reason.isNotEmpty) {
      bodyBuffer
        ..write('. Alasan: ')
        ..write(reason);
    } else {
      bodyBuffer.write('.');
    }

    final entry = AdminNotificationEntry(
      id: '${type.name}:${doc.id}',
      type: type,
      title: isPermission ? 'Pengajuan izin baru' : 'Pengajuan cuti baru',
      body: bodyBuffer.toString(),
      timestamp: createdAt,
      targetPageIndex: 2,
      data: {
        'requestId': doc.id,
        'kind': normalizedKind,
        'requesterName': requester,
      },
    );
    _addNotification(entry);
  }

  void _handleMaterialRequestAdded(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return;
    final status = (_asString(data['status']) ?? '').toLowerCase().trim();
    if (status.isNotEmpty && status != MaterialRequestStatus.pending) {
      return;
    }

    final requester =
        _firstNonEmpty([
          data['requesterName'],
          data['submittedBy'],
          data['name'],
        ]) ??
        'Karyawan';
    final projectName = _asString(data['projectName']) ?? 'proyek';
    final createdAt = _asDate(data['createdAt']) ?? DateTime.now();
    final itemCount = (data['items'] is List)
        ? (data['items'] as List).length
        : null;

    final bodyBuffer = StringBuffer()
      ..write(requester)
      ..write(' mengajukan permintaan material');
    if (projectName.isNotEmpty) {
      bodyBuffer
        ..write(' untuk ')
        ..write(projectName);
    }
    if (itemCount != null && itemCount > 0) {
      bodyBuffer
        ..write(' (')
        ..write(itemCount)
        ..write(' item)');
    }
    bodyBuffer.write('.');

    final entry = AdminNotificationEntry(
      id: 'material:${doc.id}',
      type: AdminNotificationType.material,
      title: 'Permintaan material baru',
      body: bodyBuffer.toString(),
      timestamp: createdAt,
      targetPageIndex: 5,
      data: {
        'requestId': doc.id,
        'projectName': projectName,
        'requesterName': requester,
      },
    );
    _addNotification(entry);
  }

  void _addNotification(AdminNotificationEntry entry) {
    if (_entries.any((existing) => existing.id == entry.id)) {
      return;
    }
    _entries.insert(0, entry);
    if (_entries.length > _maxStoredNotifications) {
      _entries.removeRange(_maxStoredNotifications, _entries.length);
    }
    _refreshNotifiers();
    unawaited(_saveToPrefs());
  }

  /// Public helper to push a new admin notification entry (e.g. documents page).
  Future<void> addNotification(AdminNotificationEntry entry) async {
    _addNotification(entry);
    // Ensure the notification is persisted for the current user context.
    await _saveToPrefs();
  }

  Future<void> _loadFromPrefs(String? uid) async {
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKeyFor(uid));
      if (stored == null || stored.isEmpty) {
        _refreshNotifiers();
        return;
      }
      final entries = stored
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .map((item) {
            try {
              final json = jsonDecode(item);
              if (json is Map<String, dynamic>) {
                return AdminNotificationEntry.fromJson(json);
              }
            } catch (_) {}
            return null;
          })
          .whereType<AdminNotificationEntry>()
          .toList();
      if (entries.isNotEmpty) {
        _entries
          ..clear()
          ..addAll(entries..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
      }
      _refreshNotifiers();
    } catch (e, stack) {
      debugPrint('Failed to load admin notifications: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> _saveToPrefs({String? overrideUid}) async {
    final uid = overrideUid ?? _currentUserId;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _entries
          .map((entry) => jsonEncode(entry.toJson()))
          .toList(growable: false);
      await prefs.setStringList(_prefsKeyFor(uid), data);
    } catch (e, stack) {
      debugPrint('Failed to persist admin notifications: $e');
      debugPrint(stack.toString());
    }
  }

  String _prefsKeyFor(String uid) => '$_prefsKeyPrefix-$uid';

  void _refreshNotifiers() {
    notifications.value = List<AdminNotificationEntry>.unmodifiable(_entries);
    unreadCount.value = _entries.where((entry) => !entry.isRead).length;
  }
}

String? _asString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value == null) return null;
  return value.toString();
}

DateTime? _asDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) {
    if (value <= 0) return null;
    if (value > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _asString(value);
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String _formatDateRange(DateTime? start, DateTime? end) {
  if (start == null && end == null) {
    return '';
  }
  final startText = _formatShortDate(start ?? end!);
  if (end == null ||
      start == null ||
      start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
    return startText;
  }
  final endText = _formatShortDate(end);
  return '$startText - $endText';
}

String _formatShortDate(DateTime date) {
  const monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final day = date.day.toString().padLeft(2, '0');
  final month = monthNames[date.month - 1];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day $month ${date.year} $hour:$minute';
}
