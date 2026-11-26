import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../data/attendance_repository.dart';
import '../../widgets/attachment_image_builder.dart';
import '../../widgets/glass.dart';
import '../../../shared/services/attendance_window_repository.dart';
import '../../../shared/models/attendance_window.dart';
import '../../utils/xlsx_builder.dart';
import '../../utils/xlsx_saver.dart';

const LatLng _defaultMapCenter = LatLng(-2.548926, 118.0148634);
const double _defaultMapZoom = 4.6;
const List<String> _googleTileSubdomains = ['mt0', 'mt1', 'mt2', 'mt3'];

class _StatusFilterOption {
  const _StatusFilterOption({required this.label, this.tokens = const []});

  final String label;
  final List<String> tokens;

  bool get isAll => tokens.isEmpty;
}

class _MapStyleToggle extends StatelessWidget {
  const _MapStyleToggle({required this.isSatellite, required this.onChanged});

  final bool isSatellite;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.25),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modeButton(
                context,
                label: 'Map',
                selected: !isSatellite,
                onTap: () => onChanged(false),
              ),
              _modeButton(
                context,
                label: 'Sat',
                selected: isSatellite,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.26) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

const List<_StatusFilterOption> _statusOptions = [
  _StatusFilterOption(label: 'Semua'),
  _StatusFilterOption(label: 'Check-in', tokens: ['checkin', 'hadir']),
  _StatusFilterOption(label: 'Pulang', tokens: ['checkout', 'pulang']),
  _StatusFilterOption(label: 'Izin', tokens: ['izin']),
  _StatusFilterOption(label: 'Cuti', tokens: ['cuti', 'leave']),
  _StatusFilterOption(label: 'Terlambat', tokens: ['terlambat', 'late']),
  _StatusFilterOption(
    label: 'Tidak Hadir',
    tokens: ['tidakhadir', 'alpha', 'absen', 'mangkir'],
  ),
];

enum _AttachmentKind { face, location }

enum _AdminStatusAction { hadir, tidakHadir, izin, cuti }

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AdminAttendanceRepository _repository = AdminAttendanceRepository();
  final AttendanceWindowRepository _windowRepository =
      AttendanceWindowRepository();
  final MapController _mapController = MapController();
  final ScrollController _tableScrollController = ScrollController();
  final ScrollController _dailyTableScrollController = ScrollController();

  final Map<String, AdminUserSummary?> _userCache = {};
  final Set<String> _pendingUserLoads = {};
  final Map<String, String?> _attachmentUrlCache = {};
  final Set<String> _statusUpdating = <String>{};
  final Map<String, _StatusUpdatePayload> _statusOverrides =
      <String, _StatusUpdatePayload>{};

  String _searchTerm = '';
  _StatusFilterOption _statusFilter = _statusOptions.first;
  DateTime? _selectedDate;
  String? _selectedRecordId;
  Timer? _midnightTimer;
  bool _followToday = true;
  Timer? _autoCloseTimer;
  String? _autoCloseKey;
  bool _autoCloseExecuted = false;
  bool _exportingXlsx = false;
  final Map<String, DateTime> _lastAttendanceSignalAt = {};

  bool _mapReady = false;
  bool _satelliteView = false;
  String? _lastCameraSignature;
  List<AdminAttendanceRecord> _latestLocatedRecords = const [];
  StreamSubscription<AttendanceWindow?>? _windowSubscription;
  AttendanceWindow? _attendanceWindow;
  bool _attendanceWindowLoading = true;
  Object? _attendanceWindowError;
  DateTime? _pendingOpenTime;
  DateTime? _pendingCloseTime;
  bool _isActivatingWindow = false;
  final ScrollController _mainScrollController = ScrollController();

  List<AdminAttendanceRecord>? _lastFetchedRecords;
  List<AdminUserSummary>? _lastFetchedUsers;
  List<_DailySummary>? _lastDailySummaries;
  List<_DailySummary>? _lastVisibleDaySummaries;
  List<AdminAttendanceRecord>? _lastFilteredRecords;
  List<AdminAttendanceRecord>? _lastLocatedCache;

  @override
  void initState() {
    super.initState();
    _selectedDate = _today();
    _scheduleMidnightReset();
    _refreshWindowSubscription();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _windowSubscription?.cancel();
    _autoCloseTimer?.cancel();
    _mainScrollController.dispose();
    _mapController.dispose();
    _tableScrollController.dispose();
    _dailyTableScrollController.dispose();
    super.dispose();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateValue(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatTimeValue(DateTime? date) {
    if (date == null) return '';
    return DateFormat('HH:mm').format(date);
  }

  String _formatDouble(double? value) {
    if (value == null) return '';
    return value.toStringAsFixed(6);
  }

  String _formatCoordinate(double? lat, double? lon) {
    if (lat == null || lon == null) return '';
    return '${_formatDouble(lat)}, ${_formatDouble(lon)}';
  }

  String _monthName(int month) {
    const months = [
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
    return months[(month - 1).clamp(0, months.length - 1)];
  }

  TileLayer _buildBaseTileLayer() {
    if (_satelliteView) {
      return TileLayer(
        urlTemplate: 'https://{s}.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
        subdomains: _googleTileSubdomains,
        userAgentPackageName: 'com.cvm.admin',
        tileProvider: CancellableNetworkTileProvider(),
      );
    }
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.cvm.admin',
      tileProvider: CancellableNetworkTileProvider(),
    );
  }

  Future<Map<String, AdminUserSummary?>> _ensureUserSummaries(
    Set<String> uids,
  ) async {
    final result = <String, AdminUserSummary?>{};
    for (final uid in uids) {
      if (uid.isEmpty) continue;
      var summary = _userCache[uid];
      summary ??= await _repository.fetchUserSummary(uid);
      if (summary != null) {
        _userCache[uid] = summary;
      }
      result[uid] = summary;
    }
    return result;
  }

  Future<void> _exportMonthlyXlsx() async {
    setState(() => _exportingXlsx = true);
    try {
      final baseDate = _selectedDate ?? _today();
      final start = DateTime(baseDate.year, baseDate.month, 1);
      final end = DateTime(baseDate.year, baseDate.month + 1, 1);
      final records = await _repository.fetchAttendanceForRange(
        start: start,
        end: end,
      );
      if (!mounted) return;
      if (records.isEmpty) {
        _showWindowSnack(context, 'Tidak ada data absensi bulan ini.');
        return;
      }

      final summaries = await _ensureUserSummaries(
        records.map((e) => e.uid).toSet(),
      );

      final rows = <List<String>>[
        [
          'Tanggal',
          'Waktu',
          'Nama',
          'PIN',
          'Divisi/Tim',
          'Status',
          'Tipe',
          'Keterangan',
          'Lokasi (Lat, Long)',
        ],
      ];

      for (final record in records) {
        final summary = summaries[record.uid];
        final dt =
            record.effectiveDateTime ??
            record.date ??
            record.createdAt ??
            DateTime.now();
        final name = (summary?.displayName?.trim().isNotEmpty ?? false)
            ? summary!.displayName
            : (record.uid.isNotEmpty ? record.uid : 'Tanpa Nama');
        rows.add([
          _formatDateValue(dt),
          _formatTimeValue(dt),
          name,
          summary?.pin ?? '',
          summary?.department ?? summary?.team ?? '',
          record.status ?? '',
          record.type ?? '',
          record.project ?? '',
          _formatCoordinate(record.latitude, record.longitude),
        ]);
      }

      final title =
          'Rekap Absensi ${_monthName(baseDate.month)} ${baseDate.year}';
      final bytes = SimpleXlsxBuilder(
        rows: rows,
        sheetName: 'Absensi',
        title: title,
      ).build();

      final fileName =
          'absensi_${baseDate.year}-${baseDate.month.toString().padLeft(2, '0')}.xlsx';
      final ok = await saveXlsxFile(filename: fileName, bytes: bytes);
      if (!mounted) return;
      if (ok) {
        _showWindowSnack(
          context,
          'XLSX bulan ${_monthName(baseDate.month)} tersimpan: $fileName',
        );
      } else {
        _showWindowSnack(context, 'Gagal menyimpan XLSX di platform ini.');
      }
    } catch (e) {
      if (mounted) {
        _showWindowSnack(context, 'Gagal export XLSX: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _exportingXlsx = false);
      }
    }
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, _handleMidnightTick);
  }

  void _handleMidnightTick() {
    if (!mounted) return;
    if (_followToday) {
      setState(() {
        _selectedDate = _today();
        _resetSelection();
      });
      _refreshWindowSubscription();
    }
    _scheduleMidnightReset();
  }

  void _handleMapReady() {
    _mapReady = true;
    _maybeFitCamera(_latestLocatedRecords);
  }

  void _resetSelection() {
    _selectedRecordId = null;
    _lastCameraSignature = null;
  }

  void _refreshWindowSubscription() {
    final targetDate = _selectedDate ?? _today();
    _windowSubscription?.cancel();
    _handleWindowAutoClose(null);
    setState(() {
      _attendanceWindowLoading = true;
      _attendanceWindowError = null;
    });
    _windowSubscription = _windowRepository
        .watchWindow(targetDate)
        .listen(
          (window) {
            if (!mounted) return;
            setState(() {
              _attendanceWindow = window;
              _attendanceWindowLoading = false;
              _attendanceWindowError = null;
              _pendingOpenTime = null;
              _pendingCloseTime = null;
              _isActivatingWindow = false;
            });
            _handleWindowAutoClose(window);
          },
          onError: (error, stack) {
            if (!mounted) return;
            setState(() {
              _attendanceWindow = null;
              _attendanceWindowLoading = false;
              _attendanceWindowError = error;
              _isActivatingWindow = false;
            });
            _handleWindowAutoClose(null);
          },
        );
  }

  void _resetPendingWindowSelection() {
    if (_pendingOpenTime == null && _pendingCloseTime == null) {
      return;
    }
    setState(() {
      _pendingOpenTime = null;
      _pendingCloseTime = null;
    });
  }

  void _handleWindowAutoClose(AttendanceWindow? window) {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = null;
    if (window == null) {
      _autoCloseKey = null;
      _autoCloseExecuted = false;
      return;
    }
    final today = _today();
    if (!_isSameDate(window.date, today)) {
      _autoCloseKey = null;
      _autoCloseExecuted = false;
      return;
    }
    final key =
        '${window.date.millisecondsSinceEpoch}|'
        '${window.closeAt.millisecondsSinceEpoch}|'
        '${window.lateGraceMinutes}';
    if (_autoCloseKey != key) {
      _autoCloseKey = key;
      _autoCloseExecuted = false;
    }
    if (_autoCloseExecuted) {
      return;
    }
    final now = DateTime.now();
    final deadline = window.closeGraceDeadline();
    final delay = deadline.difference(now);
    if (delay <= Duration.zero) {
      _triggerAutoClose(window);
      return;
    }
    _autoCloseTimer = Timer(delay + const Duration(seconds: 1), () {
      _triggerAutoClose(window);
    });
  }

  Future<void> _triggerAutoClose(AttendanceWindow window) async {
    if (_autoCloseExecuted || window.isDefault) return;
    _autoCloseTimer?.cancel();
    _autoCloseTimer = null;
    final current = _attendanceWindow;
    if (current == null) return;
    if (!_isSameDate(current.date, window.date)) return;
    if (current.closeAt != window.closeAt ||
        current.lateGraceMinutes != window.lateGraceMinutes) {
      return;
    }
    if (!window.isAfterClose(DateTime.now())) {
      _handleWindowAutoClose(window);
      return;
    }
    _autoCloseExecuted = true;
    try {
      await _windowRepository.deleteWindow(window.date);
      if (!mounted) return;
      unawaited(_sendAttendanceSignal('attendance_close'));
    } catch (e, st) {
      debugPrint('Failed to auto-close attendance window: $e');
      debugPrintStack(stackTrace: st);
      _autoCloseExecuted = false;
      _handleWindowAutoClose(window);
    }
  }

  Widget _buildScheduleSegments({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 720;
        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Future<void> _activateAttendanceWindow(BuildContext context) async {
    final openAt = _pendingOpenTime;
    final closeAt = _pendingCloseTime;
    if (openAt == null || closeAt == null) return;
    setState(() {
      _isActivatingWindow = true;
    });
    try {
      final date = _selectedDate ?? _today();
      await _windowRepository.setWindow(
        date: date,
        openAt: openAt,
        closeAt: closeAt,
      );
      if (!mounted) return;
      _showWindowSnack(context, 'Jadwal absen dibuka.');
      unawaited(_sendAttendanceSignal('attendance_open'));
      setState(() {
        _pendingOpenTime = null;
        _pendingCloseTime = null;
      });
    } catch (e, st) {
      debugPrint('Failed to activate attendance window: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        _showWindowSnack(
          context,
          'Gagal membuka absen. Coba lagi.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingWindow = false;
        });
      }
    }
  }

  void _scheduleUserFetch(Set<String> uids) {
    final missing = uids
        .where(
          (uid) =>
              uid.isNotEmpty &&
              !_userCache.containsKey(uid) &&
              !_pendingUserLoads.contains(uid),
        )
        .toList(growable: false);
    if (missing.isEmpty) return;
    _pendingUserLoads.addAll(missing);

    Future.wait(
          missing.map((uid) async {
            try {
              final summary = await _repository.fetchUserSummary(uid);
              return MapEntry(uid, summary);
            } catch (_) {
              return MapEntry<String, AdminUserSummary?>(uid, null);
            }
          }),
        )
        .then((entries) {
          if (!mounted) return;
          setState(() {
            for (final entry in entries) {
              _userCache[entry.key] = entry.value;
            }
          });
        })
        .whenComplete(() {
          _pendingUserLoads.removeAll(missing);
        });
  }

  List<AdminAttendanceRecord> _filterRecords(
    List<AdminAttendanceRecord> records, {
    bool ignoreStatus = false,
    int daysBack = 0,
  }) {
    final search = _searchTerm.trim().toLowerCase();
    final normalizedStatusTokens = _statusFilter.tokens
        .map(_normalizeStatus)
        .where((token) => token.isNotEmpty)
        .toSet();
    final filterStatus = !ignoreStatus && normalizedStatusTokens.isNotEmpty;
    DateTime? start;
    DateTime? end;
    if (_selectedDate != null) {
      start = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      ).subtract(Duration(days: daysBack));
      end = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        23,
        59,
        59,
        999,
      );
    }

    final startDate = start;
    final endDate = end;

    bool matchesDate(AdminAttendanceRecord record) {
      if (startDate == null || endDate == null) return true;
      final date = record.effectiveDateTime ?? record.date ?? record.createdAt;
      if (date == null) return false;
      final local = date.toLocal();
      return !local.isBefore(startDate) && !local.isAfter(endDate);
    }

    bool matchesStatus(AdminAttendanceRecord record) {
      if (!filterStatus) return true;
      final recordStatus = _normalizeStatus(record.status ?? '');
      final recordType = _normalizeStatus(record.type ?? '');
      for (final token in normalizedStatusTokens) {
        if (recordStatus.contains(token) || recordType.contains(token)) {
          return true;
        }
      }
      return false;
    }

    return records.where((record) {
      if (!matchesDate(record) || !matchesStatus(record)) return false;
      if (search.isEmpty) return true;
      final summary = _userCache[record.uid];
      final name = (summary?.displayName ?? '').toLowerCase();
      final division = (summary?.secondaryLabel ?? '').toLowerCase();
      final uid = record.uid.toLowerCase();
      final project = (record.project ?? '').toLowerCase();
      final status = '${record.status ?? ''} ${record.type ?? ''}'
          .toLowerCase();
      final location = record.hasLocation
          ? '${record.latitude!.toStringAsFixed(5)},${record.longitude!.toStringAsFixed(5)}'
                .toLowerCase()
          : '';
      return name.contains(search) ||
          division.contains(search) ||
          uid.contains(search) ||
          project.contains(search) ||
          status.contains(search) ||
          location.contains(search);
    }).toList()..sort((a, b) {
      final aDate =
          a.effectiveDateTime ??
          a.date ??
          a.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.effectiveDateTime ??
          b.date ??
          b.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  }

  List<_DailySummary> _buildDailySummaries(
    List<AdminAttendanceRecord> records,
    List<AdminUserSummary> allUsers,
  ) {
    final Map<String, _DailySummary> summaries = {};
    for (final record in records) {
      final timestamp =
          record.effectiveDateTime ?? record.createdAt ?? record.date;
      if (timestamp == null) continue;
      final local = timestamp.toLocal();
      final dayKey = DateTime(local.year, local.month, local.day);
      final key = '${record.uid}_${dayKey.millisecondsSinceEpoch}';
      final summary = summaries.putIfAbsent(
        key,
        () => _DailySummary(uid: record.uid, date: dayKey),
      );

      final override = _statusOverrides[record.id];
      String combinedRaw;
      String normalized;
      if (override != null) {
        final combinedOverride = '${override.status} ${override.type}';
        combinedRaw = combinedOverride.toLowerCase();
        normalized = _normalizeStatus(combinedOverride);
      } else {
        final baseCombined = '${record.status ?? ''} ${record.type ?? ''}';
        combinedRaw = baseCombined.toLowerCase();
        normalized = _normalizeStatus(record.status ?? record.type ?? '');
      }

      summary.registerRecord(
        record: record,
        timestamp: local,
        normalizedStatus: normalized,
        combinedRawStatus: combinedRaw,
        fallbackName: _extractNameFromRecord(record),
        fallbackDivision: _extractDivisionFromRecord(record),
      );
    }

    // Add missing users if a specific date is selected
    if (_selectedDate != null && allUsers.isNotEmpty) {
      final search = _searchTerm.trim().toLowerCase();
      final dayKey = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );
      for (final user in allUsers) {
        final key = '${user.uid}_${dayKey.millisecondsSinceEpoch}';
        if (!summaries.containsKey(key)) {
          // Check if user matches search term
          final name = user.displayName.toLowerCase();
          final division = (user.department ?? user.team ?? '').toLowerCase();
          final uid = user.uid.toLowerCase();

          if (search.isNotEmpty &&
              !name.contains(search) &&
              !division.contains(search) &&
              !uid.contains(search)) {
            continue;
          }

          final summary = _DailySummary(uid: user.uid, date: dayKey);
          summary.fallbackName = user.displayName;
          summary.fallbackDivision = user.department ?? user.team ?? '';
          summary.fallbackEmail = user.email;
          summaries[key] = summary;
        }
      }
    }

    final list = summaries.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _changeDailyStatus(
    _DailySummary summary,
    String newStatus,
  ) async {
    String statusValue = '';
    String typeValue = '';
    String label = '';

    if (newStatus == 'hadir') {
      statusValue = 'checkin';
      typeValue = 'masuk';
      label = 'Hadir';
    } else if (newStatus == 'alpha') {
      statusValue = 'mangkir';
      typeValue = 'alpha';
      label = 'Tidak Hadir';
    } else if (newStatus == 'izin') {
      statusValue = 'izin';
      typeValue = 'izin';
      label = 'Izin';
    } else if (newStatus == 'cuti') {
      statusValue = 'cuti';
      typeValue = 'cuti';
      label = 'Cuti';
    }

    if (label.isEmpty) return;

    try {
      if (summary.records.isNotEmpty) {
        // Update existing record
        await _repository.updateAttendanceStatus(
          summary.records.first,
          status: statusValue,
          type: typeValue,
          label: label,
        );
      } else {
        // Create new manual record
        await _repository.createManualAttendanceRecord(
          uid: summary.uid,
          userName: summary.fallbackName,
          userEmail: summary.fallbackEmail,
          status: statusValue,
          type: typeValue,
          label: label,
          date: summary.date,
        );
      }
      if (mounted) {
        _showWindowSnack(
          context,
          'Status ${summary.fallbackName ?? 'karyawan'} berhasil diubah ke $label',
        );
      }
    } catch (e) {
      if (mounted) {
        _showWindowSnack(context, 'Gagal mengubah status: $e', error: true);
      }
    }
  }

  void _maybeFitCamera(List<AdminAttendanceRecord> locatedRecords) {
    _latestLocatedRecords = locatedRecords;
    if (!_mapReady) return;
    if (_selectedRecordId != null) return;
    if (locatedRecords.isEmpty) return;
    final signature = _cameraSignature(locatedRecords);
    if (_lastCameraSignature == signature) return;
    _lastCameraSignature = signature;

    Future.microtask(() {
      if (!_mapReady || locatedRecords.isEmpty) return;
      if (locatedRecords.length == 1) {
        final record = locatedRecords.first;
        _mapController.move(LatLng(record.latitude!, record.longitude!), 16);
        return;
      }

      final bounds = LatLngBounds.fromPoints(
        locatedRecords
            .map((record) => LatLng(record.latitude!, record.longitude!))
            .toList(growable: false),
      );

      try {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(72)),
        );
      } catch (_) {
        final record = locatedRecords.first;
        _mapController.move(LatLng(record.latitude!, record.longitude!), 15);
      }
    });
  }

  void _focusOnRecord(AdminAttendanceRecord record) {
    if (!record.hasLocation) return;
    setState(() {
      _selectedRecordId = record.id;
    });
    if (_mapReady) {
      _mapController.move(LatLng(record.latitude!, record.longitude!), 17);
    }
  }

  String _cameraSignature(List<AdminAttendanceRecord> records) {
    final ids =
        records
            .map(
              (record) => '${record.id}:${record.latitude}:${record.longitude}',
            )
            .toList()
          ..sort();
    return ids.join('|');
  }

  String _displayName(AdminAttendanceRecord record) {
    final summary = _userCache[record.uid];
    if (summary != null && summary.displayName.trim().isNotEmpty) {
      return summary.displayName;
    }
    final rawName =
        (record.raw['name'] ?? record.raw['displayName'])?.toString() ?? '';
    if (rawName.trim().isNotEmpty) return rawName.trim();
    return record.uid;
  }

  String _divisionLabel(AdminAttendanceRecord record) {
    final summary = _userCache[record.uid];
    return summary?.secondaryLabel ?? '-';
  }

  String _formatDate(AdminAttendanceRecord record) {
    final dt = record.effectiveDateTime ?? record.date ?? record.createdAt;
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _formatTime(AdminAttendanceRecord record) {
    final dt = record.effectiveDateTime ?? record.date ?? record.createdAt;
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}.${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatClock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _formatDateLabel(DateTime value) {
    const monthNames = [
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
    final month = monthNames[value.month - 1];
    return '${value.day.toString().padLeft(2, '0')} $month ${value.year}';
  }

  Future<void> _pickOpenTime(BuildContext context) async {
    final date = _selectedDate ?? _today();
    final initialSource =
        _attendanceWindow?.openAt ?? _pendingOpenTime ?? DateTime.now();
    final initialTime = TimeOfDay(
      hour: initialSource.hour,
      minute: initialSource.minute,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: Theme.of(ctx).colorScheme.primary),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;

    final openAt = DateTime(
      date.year,
      date.month,
      date.day,
      picked.hour,
      picked.minute,
    );

    if (_attendanceWindow == null) {
      setState(() {
        _pendingOpenTime = openAt;
        if (_pendingCloseTime != null && _pendingCloseTime!.isBefore(openAt)) {
          _pendingCloseTime = _pendingCloseTime!.add(const Duration(days: 1));
        }
      });
      _showWindowSnack(
        context,
        'Jam buka disiapkan. Lanjutkan dengan jam tutup.',
      );
      return;
    }

    try {
      final existingClose = _attendanceWindow!.closeAt;
      final shouldExtendClose = existingClose.isBefore(openAt);
      await _windowRepository.updateTimes(
        date: date,
        openAt: openAt,
        closeAt: shouldExtendClose
            ? existingClose.add(const Duration(days: 1))
            : null,
      );
      if (!mounted) return;
      _showWindowSnack(
        context,
        shouldExtendClose
            ? 'Jam buka diperbarui. Jam tutup digeser ke hari berikutnya.'
            : 'Jam buka diperbarui.',
      );
    } catch (e, st) {
      debugPrint('Failed to update open time: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      _showWindowSnack(
        context,
        'Gagal menyimpan jam buka. Coba lagi.',
        error: true,
      );
    }
  }

  Future<void> _pickCloseTime(BuildContext context) async {
    final date = _selectedDate ?? _today();
    final window = _attendanceWindow;

    if (window == null) {
      final open = _pendingOpenTime;
      if (open == null) {
        _showWindowSnack(
          context,
          'Tetapkan jam buka terlebih dahulu.',
          error: true,
        );
        return;
      }
      final base = _pendingCloseTime ?? open.add(const Duration(hours: 1));
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(
              ctx,
            ).colorScheme.copyWith(primary: Theme.of(ctx).colorScheme.primary),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (picked == null) return;

      var closeAt = DateTime(
        date.year,
        date.month,
        date.day,
        picked.hour,
        picked.minute,
      );
      final rolledToNextDay = closeAt.isBefore(open);
      if (rolledToNextDay) {
        closeAt = closeAt.add(const Duration(days: 1));
      }
      setState(() {
        _pendingCloseTime = closeAt;
      });
      _showWindowSnack(
        context,
        rolledToNextDay
            ? 'Jam tutup disiapkan untuk hari berikutnya. Tekan Buka Absen untuk menerapkan.'
            : 'Jam tutup disiapkan. Tekan Buka Absen untuk menerapkan.',
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: window.closeAt.hour,
        minute: window.closeAt.minute,
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: Theme.of(ctx).colorScheme.primary),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;

    var closeAt = DateTime(
      date.year,
      date.month,
      date.day,
      picked.hour,
      picked.minute,
    );
    final rolledToNextDay = closeAt.isBefore(window.openAt);
    if (rolledToNextDay) {
      closeAt = closeAt.add(const Duration(days: 1));
    }

    try {
      await _windowRepository.updateTimes(date: date, closeAt: closeAt);
      if (!mounted) return;
      _showWindowSnack(
        context,
        rolledToNextDay
            ? 'Jam tutup diperbarui (hari berikutnya).'
            : 'Jam tutup diperbarui.',
      );
    } catch (e, st) {
      debugPrint('Failed to update close time: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      _showWindowSnack(
        context,
        'Gagal menyimpan jam tutup. Coba lagi.',
        error: true,
      );
    }
  }

  Future<void> _confirmResetWindow(BuildContext context) async {
    if (_attendanceWindow == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                  gradientColors: const [
                    Color.fromRGBO(17, 24, 39, 0.78),
                    Color.fromRGBO(15, 23, 42, 0.62),
                  ],
                  borderColor: Colors.white.withOpacity(0.28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.32),
                      blurRadius: 32,
                      offset: Offset(0, 18),
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.error.withOpacity(0.14),
                          border: Border.all(
                            color: theme.colorScheme.error.withOpacity(0.4),
                          ),
                        ),
                        child: Icon(
                          Icons.delete_forever_rounded,
                          color: theme.colorScheme.error,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Hapus jadwal absen?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Jadwal jam buka dan tutup untuk tanggal ini akan dihapus. '
                        'Karyawan tidak akan dapat melakukan absen sampai Anda menetapkan jam buka baru.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.26),
                                  ),
                                ),
                              ),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                foregroundColor: Colors.white,
                                backgroundColor: theme.colorScheme.error
                                    .withOpacity(0.32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: theme.colorScheme.error.withOpacity(
                                      0.55,
                                    ),
                                  ),
                                ),
                              ),
                              child: const Text('Hapus'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;

    try {
      await _windowRepository.deleteWindow(_selectedDate ?? _today());
      if (!mounted) return;
      _showWindowSnack(context, 'Jadwal absen dihapus.');
      unawaited(_sendAttendanceSignal('attendance_close'));
    } catch (e, st) {
      debugPrint('Failed to delete attendance window: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      _showWindowSnack(
        context,
        'Gagal menghapus jadwal. Coba lagi.',
        error: true,
      );
    }
  }

  void _showWindowSnack(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final theme = Theme.of(context);
    final accent = error ? theme.colorScheme.error : theme.colorScheme.primary;
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        duration: const Duration(seconds: 4),
        content: GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          gradientColors: [accent.withOpacity(0.34), accent.withOpacity(0.12)],
          borderColor: accent.withOpacity(0.46),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.24),
              blurRadius: 32,
              offset: const Offset(0, 18),
              spreadRadius: -18,
            ),
          ],
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendAttendanceSignal(String type) async {
    final now = DateTime.now();
    final last = _lastAttendanceSignalAt[type];
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastAttendanceSignalAt[type] = now;

    final admin = FirebaseAuth.instance.currentUser;
    try {
      await FirebaseFirestore.instance.collection('admin_signals').add({
        'type': type,
        'adminUid': admin?.uid,
        'adminEmail': admin?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'issuedAt': Timestamp.fromDate(now),
      });
    } catch (e, st) {
      debugPrint('Failed to send attendance signal "$type": $e');
      debugPrintStack(stackTrace: st);
    }
  }

  String _formatStatus(AdminAttendanceRecord record) {
    final override = _statusOverrides[record.id];
    if (override != null) {
      _maybeClearOverride(record, override);
      return override.label;
    }
    final raw = (record.status ?? record.type ?? '-').toString();
    final lower = raw.toLowerCase();
    if (lower.contains('checkin') || lower.contains('check_in')) {
      return 'Hadir';
    }
    if (lower.contains('checkout') || lower.contains('check_out')) {
      return 'Pulang';
    }
    if (lower.contains('izin')) return 'Izin';
    if (lower.contains('cuti')) return 'Cuti';
    if (lower.contains('wfh') || lower.contains('wfa')) return 'WFH';
    if (lower.contains('mangkir') ||
        lower.contains('tidakhadir') ||
        lower.contains('alpha')) {
      return 'Tidak Hadir';
    }
    if (lower.contains('terlamb')) return 'Terlambat';
    return raw
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ')
        .trim();
  }

  String _formatLocation(AdminAttendanceRecord record) {
    if (!record.hasLocation) return '-';
    return '${record.latitude!.toStringAsFixed(5)}, ${record.longitude!.toStringAsFixed(5)}';
  }

  String _noteForRecord(AdminAttendanceRecord record) {
    final project = record.project?.trim();
    final rawNote = (record.raw['note'] ?? record.raw['catatan'])
        ?.toString()
        .trim();
    final rawReason = record.raw['lateReason']?.toString().trim();
    final isLate =
        record.raw['late'] == true ||
        ((record.raw['status'] ?? record.raw['type'] ?? '')
            .toString()
            .toLowerCase()
            .contains('terlamb'));

    final parts = <String>[];
    if (project != null && project.isNotEmpty) {
      parts.add(project);
    }
    if (rawReason != null && rawReason.isNotEmpty) {
      parts.add('Terlambat: $rawReason');
    }
    if (rawNote != null && rawNote.isNotEmpty) {
      final normalizedReason = rawReason?.toLowerCase();
      final normalizedNote = rawNote.toLowerCase();
      final duplicatesReason =
          normalizedReason != null &&
          normalizedReason.isNotEmpty &&
          normalizedNote.contains(normalizedReason);
      if (!duplicatesReason) {
        parts.add(rawNote);
      }
    } else if (isLate && (rawReason == null || rawReason.isEmpty)) {
      parts.add('Terlambat');
    }

    if (parts.isEmpty) return '-';
    return parts.join(' • ');
  }

  String _normalizeStatus(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Widget _buildAttachmentCell(AdminAttendanceRecord record) {
    final theme = Theme.of(context);
    final hasFace = record.hasFacePhoto;
    final hasLocation = record.hasLocationPhoto;
    if (!hasFace && !hasLocation) {
      return const Text('-');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFace)
          IconButton(
            tooltip: 'Lihat foto wajah',
            iconSize: 22,
            onPressed: () =>
                _openAttachmentDialog(record, _AttachmentKind.face),
            icon: Icon(
              Icons.face_retouching_natural,
              color: theme.colorScheme.primary,
            ),
          ),
        if (hasLocation) ...[
          if (hasFace) const SizedBox(width: 4),
          IconButton(
            tooltip: 'Lihat foto lokasi',
            iconSize: 22,
            onPressed: () =>
                _openAttachmentDialog(record, _AttachmentKind.location),
            icon: Icon(
              Icons.photo_camera_back_outlined,
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
      ],
    );
  }

  void _openAttachmentDialog(
    AdminAttendanceRecord record,
    _AttachmentKind kind,
  ) {
    final directUrl = kind == _AttachmentKind.face
        ? record.facePhotoUrl
        : record.locationPhotoUrl;
    final storagePath = kind == _AttachmentKind.face
        ? record.facePhotoStoragePath
        : record.locationPhotoStoragePath;
    if (!_canAccessAttachment(directUrl, storagePath)) {
      return;
    }

    final title = kind == _AttachmentKind.face ? 'Foto Wajah' : 'Foto Lokasi';
    final cacheKey = _attachmentCacheKey(record, kind);
    final attachmentFuture = _getAttachmentUrl(
      record,
      kind,
      directUrl,
      storagePath,
    );

    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FutureBuilder<String?>(
                    future: attachmentFuture,
                    builder: (context, snapshot) {
                      final resolvedUrl = snapshot.data;
                      final loading =
                          snapshot.connectionState == ConnectionState.waiting;
                      final resolvedUri = resolvedUrl != null
                          ? Uri.tryParse(resolvedUrl)
                          : null;
                      final hasError = snapshot.hasError;
                      if (hasError) {
                        debugPrint(
                          'Failed to resolve attachment URL for ${record.id} (${kind.name}): ${snapshot.error}',
                        );
                        _attachmentUrlCache.remove(cacheKey);
                      }

                      Widget content;
                      if (loading) {
                        content = const Center(
                          child: CircularProgressIndicator(),
                        );
                      } else if (resolvedUrl != null) {
                        content = buildAttachmentImage(
                          url: resolvedUrl,
                          onError: () => _attachmentUrlCache.remove(cacheKey),
                          errorWidget: _buildAttachmentError(theme),
                        );
                      } else {
                        content = _buildAttachmentError(theme);
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 360,
                            child: content,
                          ),
                          if (hasError) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Gagal mengambil URL lampiran.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: resolvedUri != null
                                ? () => _launchExternalUrl(resolvedUri)
                                : null,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Buka di tab baru'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStatusFeedback({
    required String title,
    required String message,
    bool error = false,
  }) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final accent = error ? theme.colorScheme.error : theme.colorScheme.primary;
    final secondary = error
        ? theme.colorScheme.error.withValues(alpha: 0.65)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.65);
    final icon = error ? Icons.error_outline : Icons.check_circle_outline;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 32,
          ),
          child: GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            gradientColors: [
              secondary.withValues(alpha: 0.45),
              accent.withValues(alpha: 0.18),
            ],
            fullWidth: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                    ),
                    child: Icon(icon, color: accent, size: 28),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _statusActionIcon(_AdminStatusAction action) {
    switch (action) {
      case _AdminStatusAction.hadir:
        return Icons.check_circle_outline;
      case _AdminStatusAction.tidakHadir:
        return Icons.highlight_off_outlined;
      case _AdminStatusAction.izin:
        return Icons.pending_actions_outlined;
      case _AdminStatusAction.cuti:
        return Icons.event_available_outlined;
    }
  }

  String _statusActionLabel(_AdminStatusAction action) {
    switch (action) {
      case _AdminStatusAction.hadir:
        return 'Hadir';
      case _AdminStatusAction.tidakHadir:
        return 'Tidak Hadir';
      case _AdminStatusAction.izin:
        return 'Izin';
      case _AdminStatusAction.cuti:
        return 'Cuti';
    }
  }

  _AdminStatusAction? _currentStatusAction(AdminAttendanceRecord record) {
    final override = _statusOverrides[record.id];
    if (override != null) {
      _maybeClearOverride(record, override);
      return override.action;
    }
    final source = (record.status ?? record.type ?? '').toLowerCase();
    if (source.isEmpty) return null;
    if (source.contains('checkin') || source.contains('hadir')) {
      return _AdminStatusAction.hadir;
    }
    if (source.contains('mangkir') ||
        source.contains('tidakhadir') ||
        source.contains('alpha')) {
      return _AdminStatusAction.tidakHadir;
    }
    if (source.contains('izin')) {
      return _AdminStatusAction.izin;
    }
    if (source.contains('cuti') || source.contains('leave')) {
      return _AdminStatusAction.cuti;
    }
    return null;
  }

  _StatusUpdatePayload _payloadForAction(_AdminStatusAction action) {
    switch (action) {
      case _AdminStatusAction.hadir:
        return const _StatusUpdatePayload(
          action: _AdminStatusAction.hadir,
          status: 'checkin',
          type: 'checkin',
          label: 'Hadir',
        );
      case _AdminStatusAction.tidakHadir:
        return const _StatusUpdatePayload(
          action: _AdminStatusAction.tidakHadir,
          status: 'mangkir',
          type: 'mangkir',
          label: 'Tidak Hadir',
        );
      case _AdminStatusAction.izin:
        return const _StatusUpdatePayload(
          action: _AdminStatusAction.izin,
          status: 'izin',
          type: 'izin',
          label: 'Izin',
        );
      case _AdminStatusAction.cuti:
        return const _StatusUpdatePayload(
          action: _AdminStatusAction.cuti,
          status: 'cuti',
          type: 'cuti',
          label: 'Cuti',
        );
    }
  }

  void _maybeClearOverride(
    AdminAttendanceRecord record,
    _StatusUpdatePayload override,
  ) {
    final status = (record.status ?? '').toLowerCase();
    final type = (record.type ?? '').toLowerCase();
    if (override.status.toLowerCase() == status &&
        override.type.toLowerCase() == type) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_statusOverrides[record.id] == override) {
          setState(() {
            _statusOverrides.remove(record.id);
          });
        }
      });
    }
  }

  Future<void> _changeRecordStatus(
    AdminAttendanceRecord record,
    _AdminStatusAction action,
  ) async {
    final current = _currentStatusAction(record);
    if (current == action) {
      return;
    }
    if (record.path.isEmpty) {
      await _showStatusFeedback(
        title: 'Tidak dapat diproses',
        message: 'Data absensi tidak valid.',
        error: true,
      );
      return;
    }
    final payload = _payloadForAction(action);
    setState(() {
      _statusUpdating.add(record.id);
    });
    try {
      await _repository.updateAttendanceStatus(
        record,
        status: payload.status,
        type: payload.type,
        label: payload.label,
      );
      setState(() {
        _statusOverrides[record.id] = payload;
      });
      await _showStatusFeedback(
        title: 'Status diperbarui',
        message: 'Status diubah menjadi ${payload.label}.',
        error: false,
      );
    } catch (e, st) {
      debugPrint('Failed to update attendance status: $e');
      debugPrint(st.toString());
      await _showStatusFeedback(
        title: 'Gagal memperbarui',
        message: 'Gagal mengubah status. Coba lagi.',
        error: true,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _statusUpdating.remove(record.id);
      });
    }
  }

  Future<void> _openStatusSelector(AdminAttendanceRecord record) async {
    final current = _currentStatusAction(record);
    if (!mounted) return;
    final selected = await showDialog<_AdminStatusAction>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 42,
            vertical: 28,
          ),
          child: GlassContainer(
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            fullWidth: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Pilih status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final action in _AdminStatusAction.values) ...[
                    _StatusActionOption(
                      action: action,
                      label: _statusActionLabel(action),
                      icon: _statusActionIcon(action),
                      selected: action == current,
                      onTap: () => Navigator.of(context).pop(action),
                    ),
                    if (action != _AdminStatusAction.values.last)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await _changeRecordStatus(record, selected);
    }
  }

  Widget _buildStatusCell(AdminAttendanceRecord record) {
    final isUpdating = _statusUpdating.contains(record.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusChip(text: _formatStatus(record)),
        const SizedBox(width: 6),
        if (isUpdating)
          SizedBox(
            width: 18,
            height: 18,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: const CircularProgressIndicator(strokeWidth: 2.2),
            ),
          )
        else
          IconButton(
            tooltip: 'Ubah status kehadiran',
            icon: const Icon(Icons.edit_outlined, size: 20),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              shape: const CircleBorder(),
            ),
            onPressed: () => _openStatusSelector(record),
          ),
      ],
    );
  }

  Future<String?> _getAttachmentUrl(
    AdminAttendanceRecord record,
    _AttachmentKind kind,
    String? directUrl,
    String? storagePath,
  ) async {
    final key = _attachmentCacheKey(record, kind);
    if (_attachmentUrlCache.containsKey(key)) {
      return _attachmentUrlCache[key];
    }
    final resolved = await _resolveAttachmentUrl(directUrl, storagePath);
    if (resolved != null) {
      _attachmentUrlCache[key] = resolved;
    }
    return resolved;
  }

  String _attachmentCacheKey(
    AdminAttendanceRecord record,
    _AttachmentKind kind,
  ) => '${record.id}_${kind.name}';

  Future<String?> _resolveAttachmentUrl(
    String? directUrl,
    String? storagePath,
  ) async {
    if (_isHttpUrl(directUrl)) {
      return directUrl;
    }
    final trimmed = storagePath != null ? storagePath.trim() : null;
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    try {
      final storage = FirebaseStorage.instance;
      final Reference ref;
      if (_isHttpUrl(trimmed) || trimmed.startsWith('gs://')) {
        ref = storage.refFromURL(trimmed);
      } else {
        ref = storage.ref(trimmed);
      }
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e, st) {
      debugPrint('Failed to fetch download URL for $storagePath: $e');
      debugPrint(st.toString());
      return null;
    }
  }

  bool _canAccessAttachment(String? directUrl, String? storagePath) =>
      _isHttpUrl(directUrl) ||
      (storagePath != null && storagePath.trim().isNotEmpty);

  bool _isHttpUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  Future<void> _launchExternalUrl(Uri uri) async {
    final target = uri.hasScheme ? uri : Uri.parse(uri.toString());
    if (await canLaunchUrl(target)) {
      await launchUrl(target, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildAttachmentError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 40),
          const SizedBox(height: 8),
          Text('Gagal memuat gambar', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  String _displayNameForUid(String uid, {String? fallbackName}) {
    final summary = _userCache[uid];
    if (summary != null && summary.displayName.trim().isNotEmpty) {
      return summary.displayName;
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }
    return uid;
  }

  String _divisionForUid(String uid, {String? fallbackDivision}) {
    final summary = _userCache[uid];
    final division = summary?.secondaryLabel;
    if (division != null && division.trim().isNotEmpty) {
      return division;
    }
    if (fallbackDivision != null && fallbackDivision.trim().isNotEmpty) {
      return fallbackDivision;
    }
    return '-';
  }

  String? _extractNameFromRecord(AdminAttendanceRecord record) {
    final raw = record.raw;
    return _pickFirstNonEmpty([
      raw['name'],
      raw['fullName'],
      raw['displayName'],
      raw['userName'],
      raw['username'],
      raw['employeeName'],
      raw['userEmail'],
    ]);
  }

  String? _extractDivisionFromRecord(AdminAttendanceRecord record) {
    final raw = record.raw;
    return _pickFirstNonEmpty([
      raw['department'],
      raw['division'],
      raw['team'],
      raw['role'],
    ]);
  }

  String? _pickFirstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return null;
  }

  String _formatDailyStatus(_DailySummary summary) {
    final statuses = summary.rawStatuses;
    if (statuses.contains('cuti')) return 'Cuti';
    if (statuses.contains('izin')) return 'Izin';
    if (statuses.contains('sakit')) return 'Sakit';
    if (statuses.contains('wfh')) return 'WFH';
    if (statuses.contains('wfo')) return 'WFO';
    if (statuses.contains('pending')) return 'Pending';
    if (statuses.contains('mangkir')) return 'Tidak Hadir';
    if (statuses.contains('terlambat')) return 'Terlambat';
    if (summary.hasCheckIn) return 'Hadir';
    return 'Tidak Hadir';
  }

  String _formatDailyNote(_DailySummary summary) {
    final parts = <String>[];
    if (summary.projects.isNotEmpty) {
      final cleanedProjects = summary.projects
          .map((project) {
            final value = project.trim();
            if (value.isEmpty) return null;
            return value.toLowerCase().contains('kantor') ? 'Kantor' : value;
          })
          .whereType<String>()
          .toList();
      if (cleanedProjects.isNotEmpty) {
        parts.add(cleanedProjects.join(', '));
      }
    }
    final otherStatuses = summary.rawStatuses
        .where(
          (status) => !{
            'cuti',
            'izin',
            'wfh',
            'wfo',
            'mangkir',
            'sakit',
            'terlambat',
            'pending',
          }.contains(status),
        )
        .map((status) => status.replaceAll('_', ' '))
        .where((status) => status.trim().isNotEmpty)
        .toList();
    if (otherStatuses.isNotEmpty) {
      final formatted = otherStatuses
          .map((status) => status[0].toUpperCase() + status.substring(1))
          .join(', ');
      parts.add(formatted);
    }
    if (parts.isEmpty) return '-';
    return parts.join(' • ');
  }

  String _formatDailyDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDailyTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}.${local.minute.toString().padLeft(2, '0')}';
  }

  List<Marker> _buildMarkers(
    BuildContext context,
    List<AdminAttendanceRecord> locatedRecords,
  ) {
    final theme = Theme.of(context);
    return locatedRecords.map((record) {
      final isSelected = record.id == _selectedRecordId;
      final color = isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.secondary.withValues(alpha: 0.9);
      return Marker(
        width: 180,
        height: isSelected ? 120 : 100,
        alignment: Alignment.topCenter,
        point: LatLng(record.latitude!, record.longitude!),
        child: GestureDetector(
          onTap: () => _focusOnRecord(record),
          child: Tooltip(
            message:
                '${_displayName(record)}\n${_formatLocation(record)}\n${_formatDate(record)} • ${_formatTime(record)}',
            preferBelow: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _displayName(record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (isSelected) const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    isSelected ? Icons.place : Icons.location_on,
                    color: Colors.white,
                    size: isSelected ? 28 : 24,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: isSelected ? 0.75 : 0.55,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _displayName(record),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return StreamBuilder<List<AdminUserSummary>>(
          stream: _repository.watchAllUsers(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasData) {
              _lastFetchedUsers = userSnapshot.data;
            }
            final allUsers =
                userSnapshot.data ??
                _lastFetchedUsers ??
                const <AdminUserSummary>[];
            return SingleChildScrollView(
              controller: _mainScrollController,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manajemen Kehadiran',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pantau titik lokasi check-in karyawan secara langsung dan kelola riwayat absensi.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // FILTERS SECTION (Outside data StreamBuilder to prevent flicker)
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Cari nama, divisi, atau UID...',
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.22),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            isDense: true,
                          ),
                          onChanged: (value) => setState(() {
                            _searchTerm = value;
                            _resetSelection();
                          }),
                        ),
                      ),
                      _StatusFilter(
                        value: _statusFilter,
                        options: _statusOptions,
                        onSelected: (option) => setState(() {
                          _statusFilter = option;
                          _resetSelection();
                        }),
                      ),
                      _SingleDateFilter(
                        date: _selectedDate,
                        onSelect: (date) {
                          setState(() {
                            _selectedDate = date;
                            _followToday = _isSameDate(date, _today());
                            _resetSelection();
                          });
                          _refreshWindowSubscription();
                        },
                        onClear: () {
                          setState(() {
                            _selectedDate = null;
                            _followToday = false;
                            _resetSelection();
                          });
                          _refreshWindowSubscription();
                        },
                      ),
                      ElevatedButton.icon(
                        onPressed: _exportingXlsx ? null : _exportMonthlyXlsx,
                        icon: _exportingXlsx
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: Text(
                          _exportingXlsx
                              ? 'Menyiapkan...'
                              : 'Export XLSX Bulanan',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  const SizedBox(height: 16),
                  _buildWindowCard(context),
                  const SizedBox(height: 32),

                  // Summary Header & Date Strip (NOW PERSISTENT)
                  _buildSummaryHeader(context),
                  const SizedBox(height: 24),

                  StreamBuilder<List<AdminAttendanceRecord>>(
                    stream: _selectedDate == null
                        ? _repository.watchRecentAttendance(limit: 600)
                        : _repository.watchAttendanceForRange(
                            start: DateTime(
                              _selectedDate!.year,
                              _selectedDate!.month,
                              _selectedDate!.day,
                            ).subtract(const Duration(days: 7)),
                            end: DateTime(
                              _selectedDate!.year,
                              _selectedDate!.month,
                              _selectedDate!.day,
                              23,
                              59,
                              59,
                              999,
                            ),
                          ),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        _lastFetchedRecords = snapshot.data;
                      }

                      final records =
                          snapshot.data ??
                          _lastFetchedRecords ??
                          const <AdminAttendanceRecord>[];

                      if (records.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scheduleUserFetch(records.map((r) => r.uid).toSet());
                        });
                      }

                      final filtered = _filterRecords(records);
                      final summaryRecords = _filterRecords(
                        records,
                        ignoreStatus: true,
                        daysBack: 7,
                      );
                      final located = filtered
                          .where((record) => record.hasLocation)
                          .toList(growable: false);
                      final dailySummaries = _buildDailySummaries(
                        summaryRecords,
                        allUsers,
                      );

                      final targetDate = _selectedDate ?? _today();
                      final targetDaySummaries = dailySummaries
                          .where((s) => _isSameDate(s.date, targetDate))
                          .toList();

                      if (snapshot.hasData) {
                        _lastFilteredRecords = filtered;
                        _lastLocatedCache = located;
                        if (targetDaySummaries.isNotEmpty) {
                          _lastVisibleDaySummaries = targetDaySummaries;
                        }
                      }

                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;

                      final displayFiltered = (filtered.isEmpty && isLoading)
                          ? (_lastFilteredRecords ?? [])
                          : filtered;
                      final displayLocated = (located.isEmpty && isLoading)
                          ? (_lastLocatedCache ?? [])
                          : located;
                      final displayDaySummaries =
                          (targetDaySummaries.isEmpty && isLoading)
                          ? (_lastVisibleDaySummaries ?? [])
                          : targetDaySummaries;

                      _maybeFitCamera(displayLocated);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Menampilkan ${displayFiltered.length} data (${displayLocated.length} memiliki titik lokasi).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildMapSection(context, displayLocated, isLoading),
                          const SizedBox(height: 32),
                          _buildAttendanceTable(
                            context,
                            displayFiltered,
                            constraints.maxWidth,
                            isLoading,
                          ),
                          const SizedBox(height: 32),
                          _buildSummaryGrid(
                            context,
                            displayDaySummaries,
                            constraints.maxWidth,
                            isLoading,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWindowCard(BuildContext context) {
    final theme = Theme.of(context);
    final date = _selectedDate ?? _today();
    final dateLabel = _formatDateLabel(date);

    return GlassContainer(
      borderRadius: 26,
      blur: 22,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      gradientColors: const [
        Color.fromARGB(150, 18, 20, 36),
        Color.fromARGB(92, 11, 13, 28),
      ],
      borderColor: const Color.fromARGB(65, 255, 255, 255),
      fullWidth: true,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jadwal Absen • $dateLabel',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_attendanceWindowLoading) ...[
              const SizedBox(height: 12),
              Shimmer.fromColors(
                baseColor: Colors.white.withValues(alpha: 0.08),
                highlightColor: Colors.white.withValues(alpha: 0.15),
                child: Column(
                  children: [
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_attendanceWindowError != null ||
                _attendanceWindow == null) ...[
              _buildWindowSetupContent(
                context,
                showError: _attendanceWindowError != null,
              ),
            ] else ...[
              Builder(
                builder: (_) {
                  final window = _attendanceWindow!;
                  final now = DateTime.now();
                  final openLabel = _formatClock(window.openAt);
                  final closeLabel = _formatClock(window.closeAt);
                  final threshold = window.lateThreshold();
                  final thresholdLabel = _formatClock(threshold);
                  final closeGraceLabel = _formatClock(
                    window.closeGraceDeadline(),
                  );
                  final toleranceMinutes = window.lateGraceMinutes
                      .clamp(0, 999)
                      .toInt();
                  final toleranceMessage =
                      'Toleransi keterlambatan $toleranceMinutes menit '
                      '(penutupan toleransi $closeGraceLabel)';

                  String statusText;
                  Color statusColor;
                  if (window.isBeforeOpen(now)) {
                    statusText = 'Belum dibuka • Mulai $openLabel';
                    statusColor = theme.colorScheme.error;
                  } else if (window.isAfterClose(now)) {
                    statusText = 'Sudah ditutup • Ditutup $closeLabel';
                    statusColor = theme.colorScheme.error;
                  } else if (window.isLate(now)) {
                    final remainingTolerance = window
                        .closeGraceDeadline()
                        .difference(now)
                        .inMinutes
                        .clamp(0, toleranceMinutes)
                        .toInt();
                    statusText =
                        'Sedang dibuka • Terlambat $toleranceMinutes menit (sisa toleransi $remainingTolerance menit, tutup $closeGraceLabel)';
                    statusColor = const Color(0xFF8E24AA);
                  } else {
                    final remainingUntilClose = threshold
                        .difference(now)
                        .inMinutes
                        .clamp(0, 999)
                        .toInt();
                    statusText =
                        'Sedang dibuka • Tutup $thresholdLabel (sisa $remainingUntilClose menit, toleransi $toleranceMinutes menit)';
                    statusColor = theme.colorScheme.primary;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: statusColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                statusText,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WindowScheduleStrip(
                        openLabel: openLabel,
                        closeLabel: closeLabel,
                        thresholdLabel: thresholdLabel,
                        graceMinutes: window.lateGraceMinutes,
                        detailText: toleranceMessage,
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final primaryButtons = Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _glassActionButton(
                                context: context,
                                icon: Icons.edit_calendar_outlined,
                                label: 'Ubah Jam Buka',
                                onTap: () => _pickOpenTime(context),
                              ),
                              _glassActionButton(
                                context: context,
                                icon: Icons.event_busy_outlined,
                                label: 'Ubah Jam Tutup',
                                onTap: () => _pickCloseTime(context),
                              ),
                            ],
                          );

                          final closeButton = _glassActionButton(
                            context: context,
                            icon: Icons.delete_outline,
                            label: 'Tutup Absen',
                            onTap: () => _confirmResetWindow(context),
                            danger: true,
                          );

                          if (constraints.maxWidth < 620) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                primaryButtons,
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: closeButton,
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: primaryButtons,
                                ),
                              ),
                              const SizedBox(width: 12),
                              closeButton,
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _glassActionButton({
    required BuildContext context,
    required String label,
    VoidCallback? onTap,
    IconData? icon,
    Widget? leading,
    bool danger = false,
    bool enabled = true,
    bool stretch = false,
    EdgeInsetsGeometry? padding,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final baseColor =
        color ?? (danger ? theme.colorScheme.error : theme.colorScheme.primary);
    final isEnabled = enabled && onTap != null;
    final activeColor = baseColor;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.32);
    final tone = isEnabled ? activeColor : inactiveColor;
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      color: isEnabled ? Colors.white : Colors.white70,
      fontWeight: FontWeight.w600,
    );

    final textWidget = Text(
      label,
      style: textStyle,
      textAlign: TextAlign.center,
    );

    final isStretching = stretch;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: GlassContainer(
          borderRadius: 18,
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          gradientColors: [
            tone.withOpacity(isEnabled ? 0.34 : 0.22),
            tone.withOpacity(isEnabled ? 0.14 : 0.08),
          ],
          borderColor: tone.withOpacity(isEnabled ? 0.45 : 0.26),
          boxShadow: [
            BoxShadow(
              color: tone.withOpacity(isEnabled ? 0.20 : 0.08),
              offset: const Offset(0, 14),
              blurRadius: 32,
              spreadRadius: -18,
            ),
          ],
          child: Row(
            mainAxisSize: isStretching ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: isEnabled ? Colors.white : Colors.white70,
                    size: 18,
                  ),
                  child: leading,
                ),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  color: isEnabled ? Colors.white : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
              ],
              if (isStretching) Expanded(child: textWidget) else textWidget,
            ],
          ),
        ),
      ),
    );

    if (stretch) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildWindowSetupContent(
    BuildContext context, {
    required bool showError,
  }) {
    final theme = Theme.of(context);
    final pendingOpen = _pendingOpenTime;
    final pendingClose = _pendingCloseTime;
    final bool canActivate =
        pendingOpen != null && pendingClose != null && !_isActivatingWindow;

    String openValue() =>
        pendingOpen != null ? _formatClock(pendingOpen) : 'Belum dipilih';
    String closeValue() {
      if (pendingClose != null) return _formatClock(pendingClose);
      if (pendingOpen == null) return 'Menunggu jam buka';
      return 'Belum dipilih';
    }

    final hasOpen = pendingOpen != null;
    final hasClose = pendingClose != null;
    final openLabel = openValue();
    final closeLabel = closeValue();
    late final String stripDetail;
    late final IconData stripIcon;
    if (!hasOpen) {
      stripDetail = 'Pilih jam buka untuk mulai menjadwalkan absen.';
      stripIcon = Icons.lock_clock_outlined;
    } else if (!hasClose) {
      stripDetail = 'Pilih jam tutup setelah jam buka ditetapkan.';
      stripIcon = Icons.timelapse_outlined;
    } else {
      stripDetail = 'Jadwal siap dibuka untuk karyawan.';
      stripIcon = Icons.play_circle_outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showError
              ? 'Jadwal absensi sebelumnya tidak dapat dimuat. Silakan tetapkan jadwal baru.'
              : 'Tetapkan jam buka dan jam tutup sebelum membuka absen.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _WindowScheduleStrip(
          openLabel: openLabel,
          closeLabel: closeLabel,
          detailText: stripDetail,
          detailIcon: stripIcon,
        ),
        const SizedBox(height: 22),
        GlassContainer(
          borderRadius: 30,
          blur: 28,
          gradientColors: const [
            Color.fromARGB(150, 18, 20, 36),
            Color.fromARGB(92, 11, 13, 28),
          ],
          borderColor: const Color.fromARGB(65, 255, 255, 255),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          fullWidth: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 720;
              final step1Controls = [
                _WindowInfoTile(
                  icon: Icons.login_rounded,
                  title: 'Jam buka',
                  value: openValue(),
                ),
                _glassActionButton(
                  context: context,
                  icon: Icons.schedule_outlined,
                  label: pendingOpen != null
                      ? 'Ubah jam buka'
                      : 'Pilih jam buka',
                  onTap: _isActivatingWindow
                      ? null
                      : () => _pickOpenTime(context),
                  enabled: !_isActivatingWindow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  stretch: true,
                ),
              ];
              final step2Controls = [
                _WindowInfoTile(
                  icon: Icons.logout_rounded,
                  title: 'Jam tutup',
                  value: closeValue(),
                ),
                _glassActionButton(
                  context: context,
                  icon: Icons.timelapse_outlined,
                  label: pendingClose != null
                      ? 'Ubah jam tutup'
                      : 'Pilih jam tutup',
                  onTap: (_pendingOpenTime == null || _isActivatingWindow)
                      ? null
                      : () => _pickCloseTime(context),
                  enabled: _pendingOpenTime != null && !_isActivatingWindow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  stretch: true,
                ),
              ];

              final step1 = _WindowSetupStep(
                title: 'Langkah 1 • Jam buka',
                controls: step1Controls,
              );
              final step2 = _WindowSetupStep(
                title: 'Langkah 2 • Jam tutup',
                controls: step2Controls,
                helperText: _pendingOpenTime == null
                    ? 'Pilih jam buka terlebih dahulu.'
                    : null,
              );

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    step1,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Divider(
                        height: 24,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    step2,
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: step1),
                    Container(
                      width: 1.4,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Expanded(child: step2),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final bukaButton = _glassActionButton(
              context: context,
              label: _isActivatingWindow ? 'Membuka...' : 'Buka Absen',
              leading: _isActivatingWindow
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline),
              onTap: canActivate
                  ? () => _activateAttendanceWindow(context)
                  : null,
              enabled: canActivate,
              stretch: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            );

            final resetEnabled =
                !((_pendingOpenTime == null && _pendingCloseTime == null) ||
                    _isActivatingWindow);

            final resetButton = _glassActionButton(
              context: context,
              icon: Icons.refresh,
              label: 'Reset pilihan',
              onTap: resetEnabled ? _resetPendingWindowSelection : null,
              enabled: resetEnabled,
              color: theme.colorScheme.tertiary,
              stretch: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            );

            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [bukaButton, const SizedBox(height: 12), resetButton],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: bukaButton),
                const SizedBox(width: 16),
                Expanded(child: resetButton),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMapSection(
    BuildContext context,
    List<AdminAttendanceRecord> locatedRecords,
    bool isLoading,
  ) {
    final theme = Theme.of(context);
    final markers = _buildMarkers(context, locatedRecords);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Peta Check-in',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 28,
          padding: EdgeInsets.zero,
          fullWidth: true,
          child: SizedBox(
            height: 380,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FlutterMap(
                    key: const ValueKey('attendance_map_main'),
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _defaultMapCenter,
                      initialZoom: _defaultMapZoom,
                      onMapReady: _handleMapReady,
                      onTap: (tapPosition, point) {
                        if (_selectedRecordId != null) {
                          setState(() {
                            _selectedRecordId = null;
                          });
                        }
                      },
                    ),
                    children: [
                      _buildBaseTileLayer(),
                      MarkerLayer(
                        key: const ValueKey('map_marker_layer'),
                        markers: markers,
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            _satelliteView
                                ? '© Google'
                                : '© OpenStreetMap contributors',
                            onTap: null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _MapStyleToggle(
                      isSatellite: _satelliteView,
                      onChanged: (value) {
                        setState(() {
                          _satelliteView = value;
                        });
                      },
                    ),
                  ),
                  if (isLoading)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        minHeight: 3,
                      ),
                    ),
                  if (!isLoading && locatedRecords.isEmpty)
                    Center(
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        borderRadius: 20,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              size: 32,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada data lokasi',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Colors.white38,
    letterSpacing: 1.2,
  );

  Widget _buildModernAttendanceRow(BuildContext context, AdminAttendanceRecord record) {
    final theme = Theme.of(context);
    final name = _displayName(record);
    final division = _divisionLabel(record);
    final isSelected = record.id == _selectedRecordId;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      key: ValueKey('attendance_row_${record.id}'),
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _focusOnRecord(record),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            key: ValueKey('attendance_row_anim_${record.id}'),
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isSelected 
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: isSelected 
                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PEGAWAI
                SizedBox(
                  width: 280,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (division != '-')
                              Text(
                                division,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // WAKTU & TANGGAL
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.white54),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(record),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatDate(record),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                // STATUS
                SizedBox(
                  width: 160,
                  child: Center(child: _buildStatusCell(record)),
                ),
                // LOKASI
                SizedBox(
                  width: 220,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.white38),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _formatLocation(record),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // LAMPIRAN & CATATAN
                SizedBox(
                  width: 300,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAttachmentCell(record),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          _noteForRecord(record),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTable(
    BuildContext context,
    List<AdminAttendanceRecord> records,
    double maxWidth,
    bool isLoading,
  ) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.85)
        : theme.colorScheme.onSurface;

    return GlassContainer(
      key: const ValueKey('attendance_table_main'),
      borderRadius: 26,
      blur: 24,
      constraints: const BoxConstraints(minHeight: 180),
      gradientColors: const [
        Color.fromARGB(150, 18, 20, 36),
        Color.fromARGB(92, 11, 13, 28),
      ],
      borderColor: const Color.fromARGB(70, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(60, 6, 10, 30),
          offset: Offset(0, 24),
          blurRadius: 48,
          spreadRadius: -20,
        ),
      ],
      padding: records.isEmpty
          ? const EdgeInsets.symmetric(vertical: 32, horizontal: 24)
          : const EdgeInsets.only(bottom: 12),
      fullWidth: true,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: records.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      Shimmer.fromColors(
                        baseColor: Colors.white.withValues(alpha: 0.08),
                        highlightColor: Colors.white.withValues(alpha: 0.15),
                        child: Column(
                          children: List.generate(
                            3,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                height: 48,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        'Tidak ada data sesuai filter.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                        ),
                      ),
                  ],
                ),
              )
            : Scrollbar(
                controller: _tableScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _tableScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MODERN HEADER
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 280, child: Text('PEGAWAI', style: _headerStyle)),
                              const SizedBox(width: 180, child: Center(child: Text('WAKTU & TANGGAL', style: _headerStyle))),
                              const SizedBox(width: 160, child: Center(child: Text('STATUS', style: _headerStyle))),
                              const SizedBox(width: 220, child: Center(child: Text('LOKASI', style: _headerStyle))),
                              const SizedBox(width: 300, child: Center(child: Text('LAMPIRAN & CATATAN', style: _headerStyle))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // TABLE ROWS
                        ...records.map((record) => _buildModernAttendanceRow(context, record)),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ringkasan Kehadiran Harian',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih tanggal di bawah untuk melihat ringkasan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDateStrip(context),
      ],
    );
  }

  Widget _buildSummaryGrid(
    BuildContext context,
    List<_DailySummary> displaySummaries,
    double maxWidth,
    bool isLoading,
  ) {
    final theme = Theme.of(context);
    final targetDate = _selectedDate ?? _today();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: (displaySummaries.isEmpty && isLoading)
                ? ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 160),
                    child: GridView.builder(
                      key: const ValueKey('shimmer_grid'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: maxWidth > 1200
                            ? 3
                            : (maxWidth > 800 ? 2 : 1),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 140,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        return Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.08),
                          highlightColor: Colors.white.withValues(alpha: 0.15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : displaySummaries.isEmpty
                ? GlassContainer(
                    key: const ValueKey('empty_grid'),
                    borderRadius: 26,
                    blur: 24,
                    constraints: const BoxConstraints(minHeight: 160),
                    gradientColors: const [
                      Color.fromARGB(150, 18, 20, 36),
                      Color.fromARGB(92, 11, 13, 28),
                    ],
                    borderColor: const Color.fromARGB(70, 255, 255, 255),
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    fullWidth: true,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada data ringkasan untuk tanggal ${_formatDailyDate(targetDate)}.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ConstrainedBox(
                    key: const ValueKey('real_grid'),
                    constraints: const BoxConstraints(minHeight: 160),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: maxWidth > 1200
                            ? 3
                            : (maxWidth > 800 ? 2 : 1),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 140,
                      ),
                      itemCount: displaySummaries.length,
                      itemBuilder: (context, index) {
                        final summary = displaySummaries[index];
                        return _buildSummaryCard(context, summary);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateStrip(BuildContext context) {
    final theme = Theme.of(context);
    final targetDate = _selectedDate ?? _today();

    final List<DateTime> dates =
        List.generate(14, (i) {
              return _today().subtract(Duration(days: i));
            })
            .where((date) {
              return date.weekday != DateTime.friday &&
                  date.weekday != DateTime.sunday;
            })
            .take(7)
            .toList()
            .reversed
            .toList();

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        itemCount: dates.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _isSameDate(date, targetDate);
          final dayName = _getDayName(date);
          final dayNum = date.day.toString();
          final monthName = _getMonthName(date);

          return InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              setState(() {
                _selectedDate = date;
                _followToday = _isSameDate(date, _today());
                _resetSelection();
              });
              _refreshWindowSubscription();
            },
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white38,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayNum,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isSelected ? Colors.white : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.primary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getMonthName(DateTime date) {
    final names = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MEI',
      'JUN',
      'JUL',
      'AGU',
      'SEP',
      'OKT',
      'NOV',
      'DES',
    ];
    return names[date.month - 1];
  }

  String _getDayName(DateTime date) {
    final names = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
    return names[date.weekday - 1];
  }

  Widget _buildSummaryCard(BuildContext context, _DailySummary summary) {
    final theme = Theme.of(context);
    final name = _displayNameForUid(
      summary.uid,
      fallbackName: summary.fallbackName,
    );
    final division = _divisionForUid(
      summary.uid,
      fallbackDivision: summary.fallbackDivision,
    );
    final checkIn = _formatDailyTime(summary.firstCheckIn);
    final status = _formatDailyStatus(summary);

    return StatefulBuilder(
      builder: (context, setCardState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setCardState(() => isHovered = true),
          onExit: (_) => setCardState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [],
            ),
            child: GlassContainer(
              borderRadius: 22,
              blur: 20,
              padding: const EdgeInsets.all(16),
              gradientColors: isHovered
                  ? [
                      const Color.fromARGB(180, 26, 28, 48),
                      const Color.fromARGB(120, 15, 18, 36),
                    ]
                  : [
                      const Color.fromARGB(140, 20, 22, 38),
                      const Color.fromARGB(80, 12, 14, 30),
                    ],
              borderColor: isHovered
                  ? theme.colorScheme.primary.withOpacity(0.35)
                  : Colors.white.withOpacity(0.12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.1,
                        ),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              division,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Ubah status',
                        offset: const Offset(0, 40),
                        onSelected: (value) =>
                            _changeDailyStatus(summary, value),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'hadir', child: Text('Hadir')),
                          PopupMenuItem(
                            value: 'alpha',
                            child: Text('Tidak Hadir'),
                          ),
                          PopupMenuItem(value: 'izin', child: Text('Izin')),
                          PopupMenuItem(value: 'cuti', child: Text('Cuti')),
                        ],
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white.withOpacity(0.4),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHECK-IN',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.login_rounded,
                                size: 12,
                                color: checkIn == '-'
                                    ? Colors.white24
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                checkIn,
                                style: TextStyle(
                                  color: checkIn == '-'
                                      ? Colors.white38
                                      : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _StatusChip(text: status),
                    ],
                  ),
                  if (summary.projects.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary.projects.join(' • '),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusUpdatePayload {
  const _StatusUpdatePayload({
    required this.action,
    required this.status,
    required this.type,
    required this.label,
  });

  final _AdminStatusAction action;
  final String status;
  final String type;
  final String label;
}

class _StatusActionOption extends StatelessWidget {
  const _StatusActionOption({
    required this.action,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final _AdminStatusAction action;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? highlight.withValues(alpha: 0.16)
                : theme.colorScheme.surface.withValues(alpha: 0.08),
            border: Border.all(
              color: selected
                  ? highlight.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? highlight
                    : theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.85,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? highlight
                        : theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: highlight, size: 22)
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowInfoTile extends StatelessWidget {
  const _WindowInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowScheduleStrip extends StatelessWidget {
  const _WindowScheduleStrip({
    required this.openLabel,
    required this.closeLabel,
    this.thresholdLabel,
    this.graceMinutes,
    this.detailText,
    this.detailIcon = Icons.timer_outlined,
  });

  final String openLabel;
  final String closeLabel;
  final String? thresholdLabel;
  final int? graceMinutes;
  final String? detailText;
  final IconData detailIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final computedDetail =
        detailText ??
        ((thresholdLabel != null && graceMinutes != null)
            ? 'Toleransi terlambat ${graceMinutes!} menit (hingga $thresholdLabel)'
            : null);
    final detailColor = theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return GlassContainer(
      borderRadius: 24,
      blur: 28,
      gradientColors: const [
        Color.fromARGB(170, 18, 23, 44),
        Color.fromARGB(100, 11, 14, 31),
      ],
      borderColor: const Color.fromARGB(60, 255, 255, 255),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      fullWidth: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _WindowScheduleEndpoint(
                  icon: Icons.login_rounded,
                  title: 'Jam Buka',
                  value: openLabel,
                ),
              ),
              const _WindowScheduleConnector(),
              Expanded(
                child: _WindowScheduleEndpoint(
                  icon: Icons.logout_rounded,
                  title: 'Jam Tutup',
                  value: closeLabel,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (computedDetail != null) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(detailIcon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    computedDetail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: detailColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WindowScheduleEndpoint extends StatelessWidget {
  const _WindowScheduleEndpoint({
    required this.icon,
    required this.title,
    required this.value,
    this.alignEnd = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelBase =
        theme.textTheme.labelMedium ??
        theme.textTheme.bodySmall ??
        const TextStyle();
    final TextStyle labelStyle = labelBase.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
      fontWeight: FontWeight.w600,
    );
    final valueBase =
        theme.textTheme.headlineMedium ??
        theme.textTheme.headlineSmall ??
        theme.textTheme.titleLarge ??
        theme.textTheme.titleMedium ??
        const TextStyle(fontSize: 24);
    final TextStyle valueStyle = valueBase.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!alignEnd) ...[
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Text(title, style: labelStyle),
            if (alignEnd) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: theme.colorScheme.primary),
            ],
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class _WindowScheduleConnector extends StatelessWidget {
  const _WindowScheduleConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 2,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.26),
              Colors.white.withValues(alpha: 0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}

class _WindowSetupStep extends StatelessWidget {
  const _WindowSetupStep({
    required this.title,
    required this.controls,
    this.helperText,
  });

  final String title;
  final List<Widget> controls;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: controls,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            helperText!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final label = text.trim();
    if (label.isEmpty || label == '-') {
      return const Text('-');
    }

    final theme = Theme.of(context);
    final lower = label.toLowerCase();

    Color baseColor;
    IconData icon;

    if (lower.contains('checkin') || lower.contains('hadir')) {
      baseColor = const Color(0xFF4CAF50); // Green
      icon = Icons.check_circle_outline_rounded;
    } else if (lower.contains('checkout') || lower.contains('pulang')) {
      baseColor = const Color(0xFF2196F3); // Blue
      icon = Icons.exit_to_app_rounded;
    } else if (lower.contains('izin')) {
      baseColor = const Color(0xFFFF9800); // Orange
      icon = Icons.assignment_turned_in_rounded;
    } else if (lower.contains('cuti')) {
      baseColor = const Color(0xFFE91E63); // Pink
      icon = Icons.beach_access_rounded;
    } else if (lower.contains('wfh') || lower.contains('wfa')) {
      baseColor = const Color(0xFF9C27B0); // Purple
      icon = Icons.home_work_rounded;
    } else if (lower.contains('mangkir') || lower.contains('alpha')) {
      baseColor = const Color(0xFFF44336); // Red
      icon = Icons.cancel_outlined;
    } else if (lower.contains('terlamb')) {
      baseColor = const Color(0xFFFFC107); // Amber
      icon = Icons.schedule_rounded;
    } else {
      baseColor = theme.colorScheme.outline;
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: baseColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: baseColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySummary {
  _DailySummary({required this.uid, required this.date});

  final String uid;
  final DateTime date;
  DateTime? firstCheckIn;
  DateTime? lastCheckOut;
  final Set<String> rawStatuses = <String>{};
  final Set<String> projects = <String>{};
  final List<AdminAttendanceRecord> records = []; // Store records
  String? fallbackName;
  String? fallbackDivision;
  String? fallbackEmail;

  bool get hasCheckIn => firstCheckIn != null;
  bool get hasCheckOut => lastCheckOut != null;

  void registerRecord({
    required AdminAttendanceRecord record,
    required DateTime timestamp,
    required String normalizedStatus,
    required String combinedRawStatus,
    String? fallbackName,
    String? fallbackDivision,
  }) {
    this.fallbackName ??= fallbackName;
    this.fallbackDivision ??= fallbackDivision;
    this.records.add(record); // Add to records list

    if (record.project?.trim().isNotEmpty == true) {
      projects.add(record.project!.trim());
    }

    final isCheckIn = normalizedStatus.contains('checkin');
    final isCheckOut =
        normalizedStatus.contains('checkout') ||
        combinedRawStatus.contains('checkout');

    if (isCheckIn) {
      if (firstCheckIn == null || timestamp.isBefore(firstCheckIn!)) {
        firstCheckIn = timestamp;
      }
    }

    if (isCheckOut) {
      if (lastCheckOut == null || timestamp.isAfter(lastCheckOut!)) {
        lastCheckOut = timestamp;
      }
    }

    void addStatusToken(String token, String canonical) {
      if (normalizedStatus.contains(token) ||
          combinedRawStatus.contains(token)) {
        rawStatuses.add(canonical);
      }
    }

    addStatusToken('cuti', 'cuti');
    addStatusToken('izin', 'izin');
    addStatusToken('sakit', 'sakit');
    addStatusToken('wfh', 'wfh');
    addStatusToken('wfo', 'wfo');
    addStatusToken('wfa', 'wfh');
    addStatusToken('mangkir', 'mangkir');
    addStatusToken('alpha', 'mangkir');
    addStatusToken('pending', 'pending');
    addStatusToken('proses', 'pending');
    addStatusToken('terlamb', 'terlambat');
    addStatusToken('telat', 'terlambat');

    if (!isCheckIn && !isCheckOut && rawStatuses.isEmpty) {
      final raw = (record.status ?? record.type ?? '').trim();
      if (raw.isNotEmpty) {
        rawStatuses.add(raw.toLowerCase());
      }
    }
  }

  bool hasStatus(String status) => rawStatuses.contains(status);
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final _StatusFilterOption value;
  final List<_StatusFilterOption> options;
  final ValueChanged<_StatusFilterOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurface.withValues(alpha: 0.9);
    final hintColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return GlassContainer(
      borderRadius: 18,
      blur: 18,
      gradientColors: const [
        Color.fromARGB(150, 18, 20, 36),
        Color.fromARGB(90, 11, 13, 28),
      ],
      borderColor: const Color.fromARGB(65, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(35, 6, 10, 30),
          offset: Offset(0, 12),
          blurRadius: 24,
          spreadRadius: -14,
        ),
      ],
      child: Material(
        color: Colors.transparent,
        child: PopupMenuButton<_StatusFilterOption>(
          tooltip: 'Pilih status',
          initialValue: value,
          onSelected: onSelected,
          padding: EdgeInsets.zero,
          color: const Color.fromARGB(235, 18, 20, 36),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          itemBuilder: (context) {
            return options
                .map(
                  (option) => PopupMenuItem<_StatusFilterOption>(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(growable: false);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt_outlined, size: 18, color: baseColor),
                const SizedBox(width: 6),
                Text(
                  'Status:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: hintColor,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  value.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: baseColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: hintColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleDateFilter extends StatelessWidget {
  const _SingleDateFilter({
    required this.date,
    required this.onSelect,
    required this.onClear,
  });

  final DateTime? date;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onClear;

  String _formatShort(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  DateTime _normalize(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  Widget build(BuildContext context) {
    final selected = date != null ? _normalize(date!) : null;
    final theme = Theme.of(context);

    Future<void> openPicker() async {
      final initial = selected ?? _normalize(DateTime.now());
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) onSelect(_normalize(picked));
    }

    void step(int days) {
      final base = selected ?? _normalize(DateTime.now());
      onSelect(_normalize(base.add(Duration(days: days))));
    }

    Widget buildControl({
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      );
    }

    return GlassContainer(
      borderRadius: 18,
      blur: 18,
      gradientColors: const [
        Color.fromARGB(150, 18, 20, 36),
        Color.fromARGB(90, 11, 13, 28),
      ],
      borderColor: const Color.fromARGB(65, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(35, 6, 10, 30),
          offset: Offset(0, 12),
          blurRadius: 24,
          spreadRadius: -14,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildControl(
              tooltip: 'Tanggal sebelumnya',
              icon: Icons.chevron_left,
              onPressed: () => step(-1),
            ),
            Tooltip(
              message: selected == null
                  ? 'Pilih tanggal'
                  : 'Ketuk untuk ubah, tekan lama untuk hapus filter',
              child: InkWell(
                onTap: openPicker,
                onLongPress: selected != null ? onClear : null,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.9,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selected == null
                            ? 'Semua tanggal'
                            : _formatShort(selected),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            buildControl(
              tooltip: 'Tanggal selanjutnya',
              icon: Icons.chevron_right,
              onPressed: () => step(1),
            ),
          ],
        ),
      ),
    );
  }
}
