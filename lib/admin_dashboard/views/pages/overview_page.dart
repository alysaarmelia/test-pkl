import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../data/attendance_repository.dart';
import '../../widgets/overview_cards.dart';
import '../../widgets/glass.dart';
import '../../../shared/models/leave_request.dart';
import '../../../shared/services/leave_request_repository.dart';

enum _AttendanceCategory { present, late, absent }

enum _ChartDisplayMode { stackedBar, pie }

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final AdminAttendanceRepository _attendanceRepository =
      AdminAttendanceRepository();
  final LeaveRequestRepository _leaveRepository = LeaveRequestRepository();
  final Map<String, AdminUserSummary?> _userCache =
      <String, AdminUserSummary?>{};
  final Set<String> _pendingUserLoads = <String>{};
  _ChartDisplayMode _chartDisplayMode = _ChartDisplayMode.stackedBar;

  static const List<String> _monthNames = <String>[
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

  static const List<String> _presentTokens = <String>[
    'hadir',
    'present',
    'checkin',
    'masuk',
    'in',
    'onsite',
  ];

  static const List<String> _lateTokens = <String>[
    'late',
    'terlambat',
    'lambat',
  ];

  static const List<String> _absenceTokens = <String>[
    'alpha',
    'absen',
    'absent',
    'tidakhadir',
    'tidak hadir',
    'mangkir',
    'leave',
    'sakit',
    'izin',
    'cuti',
  ];

  void _scheduleUserFetch(Iterable<String> uids) {
    final missing = uids
        .map((uid) => uid.trim())
        .where(
          (uid) =>
              uid.isNotEmpty &&
              !_userCache.containsKey(uid) &&
              !_pendingUserLoads.contains(uid),
        )
        .toSet();
    if (missing.isEmpty) return;
    _pendingUserLoads.addAll(missing);
    Future.wait(
      missing.map((uid) async {
        try {
          final summary = await _attendanceRepository.fetchUserSummary(uid);
          return MapEntry(uid, summary);
        } catch (_) {
          return MapEntry<String, AdminUserSummary?>(uid, null);
        }
      }),
    ).then((entries) {
      if (!mounted) return;
      setState(() {
        for (final entry in entries) {
          _userCache[entry.key] = entry.value;
        }
        _pendingUserLoads.removeAll(missing);
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _pendingUserLoads.removeAll(missing);
      });
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _statusMatches(String? status, Iterable<String> tokens) {
    if (status == null) return false;
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final token in tokens) {
      if (normalized.contains(token)) {
        return true;
      }
    }
    return false;
  }

  _AttendanceCategory _categorizeRecord(AdminAttendanceRecord record) {
    final candidates = <String?>[
      record.status,
      record.type,
      record.raw['status']?.toString(),
      record.raw['statusLabel']?.toString(),
      record.raw['type']?.toString(),
      record.raw['action']?.toString(),
      record.raw['attendanceStatus']?.toString(),
      record.raw['category']?.toString(),
      record.raw['reason']?.toString(),
      record.raw['notes']?.toString(),
      record.raw['leaveType']?.toString(),
    ];
    final lateFlag = record.raw['late'] == true ||
        record.raw['isLate'] == true ||
        record.raw['wasLate'] == true ||
        candidates.any((value) => _statusMatches(value, _lateTokens));
    final absentFlag =
        candidates.any((value) => _statusMatches(value, _absenceTokens));
    final presentFlag =
        candidates.any((value) => _statusMatches(value, _presentTokens));

    if (lateFlag) return _AttendanceCategory.late;
    if (absentFlag) return _AttendanceCategory.absent;
    if (presentFlag) return _AttendanceCategory.present;
    return _AttendanceCategory.present;
  }

  bool _isLeaveOrPermission(AdminAttendanceRecord record) {
    final candidates = <String?>[
      record.status,
      record.type,
      record.raw['status']?.toString(),
      record.raw['statusLabel']?.toString(),
      record.raw['type']?.toString(),
      record.raw['action']?.toString(),
      record.raw['attendanceStatus']?.toString(),
      record.raw['category']?.toString(),
      record.raw['reason']?.toString(),
      record.raw['notes']?.toString(),
      record.raw['leaveType']?.toString(),
    ];
    return candidates.any(
      (value) => _statusMatches(
        value,
        const ['cuti', 'izin', 'leave', 'permission'],
      ),
    );
  }

  List<_DailyAttendanceStat> _buildDailyStats(
    List<AdminAttendanceRecord> records,
  ) {
    if (records.isEmpty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final statsMap = <DateTime, _DailyAttendanceStat>{};
    for (var i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      statsMap[date] = _DailyAttendanceStat(date: date);
    }

    for (final record in records) {
      final dateTime = record.effectiveDateTime;
      if (dateTime == null) continue;
      final local = dateTime.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      if (date.isBefore(start) || date.isAfter(today)) continue;
      final stat = statsMap[date]!;
      switch (_categorizeRecord(record)) {
        case _AttendanceCategory.present:
          stat.present += 1;
          break;
        case _AttendanceCategory.late:
          stat.late += 1;
          break;
      case _AttendanceCategory.absent:
        stat.absent += 1;
        break;
      }
    }

    return statsMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh.$mm';
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    if (_isSameDay(localStart, localEnd)) {
      return _formatFullDate(localStart);
    }
    if (localStart.year == localEnd.year) {
      return '${_formatShortDate(localStart)} – ${_formatFullDate(localEnd)}';
    }
    return '${_formatFullDate(localStart)} – ${_formatFullDate(localEnd)}';
  }

  String _formatFullDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = _monthNames[value.month - 1];
    return '$day $month ${value.year}';
  }

  String _formatShortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = _monthNames[value.month - 1];
    return '$day $month';
  }

  String _prettifyIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Tanpa Nama';
    if (trimmed.contains('@')) {
      final prefix = trimmed.split('@').first;
      return _titleCase(prefix.replaceAll(RegExp(r'[._\-]+'), ' '));
    }
    return _titleCase(trimmed.replaceAll(RegExp(r'[._\-]+'), ' '));
  }

  String _titleCase(String value) {
    final words = value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .toList();
    return words.isEmpty ? value : words.join(' ');
  }

  String _extractNameFromRaw(Map<String, dynamic> raw) {
    for (final key in const [
      'employeeName',
      'name',
      'fullName',
      'displayName',
      'username',
      'userName',
      'requesterName',
    ]) {
      final value = raw[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _displayNameForRecord(AdminAttendanceRecord record) {
    final summary = _userCache[record.uid];
    final rawName = _extractNameFromRaw(record.raw);
    final candidates = [
      summary?.displayName,
      rawName,
      record.raw['requesterName']?.toString(),
      record.uid,
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return _titleCase(candidate.trim());
      }
    }
    return 'Tanpa Nama';
  }

  String _subtitleForRecord(AdminAttendanceRecord record) {
    final summary = _userCache[record.uid];
    final candidates = [
      summary?.department,
      summary?.team,
      summary?.role,
      record.project,
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return '—';
  }

  String _statusLabel(AdminAttendanceRecord record) {
    final candidates = [
      record.status,
      record.type,
      record.raw['statusLabel']?.toString(),
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return _titleCase(candidate.trim());
      }
    }
    return 'Aktivitas';
  }

  _AttendanceViewData _mapAttendanceRecord(AdminAttendanceRecord record) {
    return _AttendanceViewData(
      displayName: _displayNameForRecord(record),
      subtitle: _subtitleForRecord(record),
      timeLabel: _formatTime(record.effectiveDateTime),
      statusLabel: _statusLabel(record),
    );
  }

  _RequestViewData _mapLeaveRequest(LeaveRequest request) {
    final summary = _userCache[request.uid];
    final candidates = [
      request.requesterName,
      summary?.displayName,
      request.requesterEmail,
      request.uid,
    ];
    String displayName = 'Tanpa Nama';
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        displayName = _prettifyIdentifier(candidate);
        break;
      }
    }

    final typeLabel = request.isLeave
        ? 'Cuti'
        : request.isPermission
            ? 'Izin'
            : _titleCase(request.kind);

    final reason = request.reason.trim().isEmpty
        ? 'Tanpa keterangan'
        : request.reason.trim();

    return _RequestViewData(
      employeeName: displayName,
      typeLabel: typeLabel,
      dateRange: _formatDateRange(request.startAt, request.endAt),
      reason: reason,
      statusLabel: leaveRequestStatusLabel(request.status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseText = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final subtleText = baseText.withValues(alpha: 0.72);

    return StreamBuilder<List<AdminAttendanceRecord>>(
      stream: _attendanceRepository.watchRecentAttendance(limit: 400),
      builder: (context, attendanceSnapshot) {
        if (attendanceSnapshot.hasError) {
          return _buildErrorMessage(
            context,
            'Gagal memuat data kehadiran: ${attendanceSnapshot.error}',
          );
        }

        final attendanceRecords =
            attendanceSnapshot.data ?? const <AdminAttendanceRecord>[];
        final DateTime today = DateTime.now();
        final todayRecords = attendanceRecords
            .where(
              (record) =>
                  record.effectiveDateTime != null &&
                  _isSameDay(record.effectiveDateTime!.toLocal(), today),
            )
            .toList();

        return StreamBuilder<List<LeaveRequest>>(
          stream: _leaveRepository.watchRequests(
            status: LeaveRequestStatus.pending,
            limit: 200,
          ),
          builder: (context, leaveSnapshot) {
            if (leaveSnapshot.hasError) {
              return _buildErrorMessage(
                context,
                'Gagal memuat permohonan: ${leaveSnapshot.error}',
              );
            }

            final pendingRequests =
                leaveSnapshot.data ?? const <LeaveRequest>[];

            final uidSet = {
              ...todayRecords.map((record) => record.uid),
              ...pendingRequests.map((request) => request.uid),
            };
            _scheduleUserFetch(uidSet);

            var presentCount = 0;
            var lateCount = 0;
            var leaveCount = 0;
            var absentCount = 0;
            for (final record in todayRecords) {
              switch (_categorizeRecord(record)) {
                case _AttendanceCategory.present:
                  presentCount++;
                  break;
                case _AttendanceCategory.late:
                  lateCount++;
                  break;
                case _AttendanceCategory.absent:
                  if (_isLeaveOrPermission(record)) {
                    leaveCount++;
                  } else {
                    absentCount++;
                  }
                  break;
              }
            }
            final pendingCount = pendingRequests.length;
            final weeklyStats = _buildDailyStats(attendanceRecords);
            final totalPresent = weeklyStats.fold<int>(
              0,
              (sum, stat) => sum + stat.present,
            );
            final totalAbsent = weeklyStats.fold<int>(
              0,
              (sum, stat) => sum + stat.absent,
            );
            final totalLate = weeklyStats.fold<int>(
              0,
              (sum, stat) => sum + stat.late,
            );
            final bestDay = weeklyStats.isEmpty
                ? null
                : weeklyStats.reduce(
                    (a, b) => a.net >= b.net ? a : b,
                  );

            final attendanceItems = List<AdminAttendanceRecord>.from(
              todayRecords,
            )
              ..sort(
                (a, b) {
                  final aTime = a.effectiveDateTime ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = b.effectiveDateTime ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                },
              );
            final requestItems = List<LeaveRequest>.from(pendingRequests)
              ..sort(
                (a, b) => b.createdAt.compareTo(a.createdAt),
              );

            final attendanceView =
                attendanceItems.map(_mapAttendanceRecord).toList();
            final requestView =
                requestItems.map(_mapLeaveRequest).toList();

            final isLoading = (attendanceSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    attendanceSnapshot.data == null) ||
                (leaveSnapshot.connectionState == ConnectionState.waiting &&
                    leaveSnapshot.data == null);

            if (isLoading &&
                attendanceView.isEmpty &&
                requestView.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final twoColumn = constraints.maxWidth > 1200;
                final horizontalPadding = twoColumn ? 32.0 : 20.0;
                final availableWidth =
                    (constraints.maxWidth - horizontalPadding * 2)
                        .clamp(240.0, constraints.maxWidth)
                        .toDouble();
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    34,
                    horizontalPadding,
                    52,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portal Admin',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: baseText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pantau kehadiran, cuti, izin, dan permintaan tim secara real-time.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subtleText,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (weeklyStats.isNotEmpty) ...[
                        GlassContainer(
                          borderRadius: 28,
                          padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
                          gradientColors: const [
                            Color.fromARGB(122, 24, 32, 76),
                            Color.fromARGB(82, 16, 22, 52),
                          ],
                          borderColor: Colors.white.withValues(alpha: 0.18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tren Kehadiran 7 Hari',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: baseText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Bar hijau menandakan dominasi kehadiran, bar merah menandakan izin/cuti.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: subtleText,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _TrendSummaryRow(
                                present: totalPresent,
                                late: totalLate,
                                absent: totalAbsent,
                                bestDayLabel: bestDay == null
                                    ? '-'
                                    : _formatFullDate(bestDay.date),
                                bestDayNet: bestDay?.net ?? 0,
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Bar'),
                                      selected: _chartDisplayMode ==
                                          _ChartDisplayMode.stackedBar,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _chartDisplayMode =
                                                _ChartDisplayMode.stackedBar;
                                          });
                                        }
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Pie'),
                                      selected:
                                          _chartDisplayMode == _ChartDisplayMode.pie,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _chartDisplayMode =
                                                _ChartDisplayMode.pie;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _chartDisplayMode ==
                                        _ChartDisplayMode.stackedBar
                                    ? GlassContainer(
                                        key: const ValueKey('stacked'),
                                        borderRadius: 24,
                                        padding: const EdgeInsets.all(18),
                                        gradientColors: const [
                                          Color.fromARGB(136, 34, 48, 104),
                                          Color.fromARGB(94, 20, 28, 62),
                                        ],
                                        borderColor: Colors.white
                                            .withValues(alpha: 0.16),
                                        child: SizedBox(
                                          height: 260,
                                          child: _AttendanceSyncfusionChart(
                                            stats: weeklyStats,
                                            theme: theme,
                                          ),
                                        ),
                                      )
                                    : GlassContainer(
                                        key: const ValueKey('pie'),
                                        borderRadius: 24,
                                        padding: const EdgeInsets.all(22),
                                        gradientColors: const [
                                          Color.fromARGB(146, 42, 32, 88),
                                          Color.fromARGB(88, 26, 24, 62),
                                        ],
                                        borderColor: Colors.white
                                            .withValues(alpha: 0.16),
                                        child: SizedBox(
                                          height: 320,
                                          child: _AttendancePieChart(
                                            totalPresent: totalPresent,
                                            totalLate: totalLate,
                                            totalAbsent: totalAbsent,
                                            theme: theme,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 80,
                                child: _AttendanceSparklineChart(
                                  stats: weeklyStats,
                                  theme: theme,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: _buildMetricCards(
                          availableWidth: availableWidth,
                          presentCount: presentCount,
                          lateCount: lateCount,
                          pendingCount: pendingCount,
                          leaveCount: leaveCount,
                          absentCount: absentCount,
                        ),
                      ),
                      const SizedBox(height: 32),
                      twoColumn
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _DataCard(
                                    title: 'Kehadiran Terbaru',
                                    subtitle: 'Log kehadiran karyawan hari ini',
                                    child: _AttendanceList(
                                      records: attendanceView,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 2,
                                  child: _DataCard(
                                    title: 'Permohonan Pending',
                                    subtitle: 'Susun prioritas persetujuan',
                                    child: _PendingRequestList(
                                      items: requestView,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DataCard(
                                  title: 'Kehadiran Terbaru',
                                  subtitle: 'Log kehadiran karyawan hari ini',
                                  child: _AttendanceList(
                                    records: attendanceView,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                _DataCard(
                                  title: 'Permohonan Pending',
                                  subtitle: 'Susun prioritas persetujuan',
                                  child: _PendingRequestList(
                                    items: requestView,
                                  ),
                                ),
                              ],
                            ),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildErrorMessage(BuildContext context, String message) {
    final theme = Theme.of(context);
    final baseText = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassContainer(
          borderRadius: 26,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: baseText.withValues(alpha: 0.7),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: baseText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMetricCards({
    required double availableWidth,
    required int presentCount,
    required int lateCount,
    required int pendingCount,
    required int leaveCount,
    required int absentCount,
  }) {
    final metrics = <_OverviewMetric>[
      _OverviewMetric(
        title: 'Hadir Hari Ini',
        value: presentCount,
        icon: Icons.verified_user_outlined,
      ),
      _OverviewMetric(
        title: 'Terlambat',
        value: lateCount,
        icon: Icons.timer_outlined,
        deltaIsPositive: lateCount == 0,
      ),
      _OverviewMetric(
        title: 'Izin / Cuti',
        value: leaveCount,
        icon: Icons.airplane_ticket_outlined,
        deltaIsPositive: leaveCount == 0,
      ),
      _OverviewMetric(
        title: 'Tidak Hadir',
        value: absentCount,
        icon: Icons.person_off_outlined,
        deltaIsPositive: absentCount == 0,
      ),
      _OverviewMetric(
        title: 'Permohonan Pending',
        value: pendingCount,
        icon: Icons.assignment_outlined,
      ),
    ];

    final columns = _resolveColumnCount(availableWidth, metrics.length);
    final spacing = 18.0;
    final width = columns <= 1
        ? availableWidth
        : (availableWidth - spacing * (columns - 1)) / columns;

    return metrics
        .map(
          (metric) => SizedBox(
            width: width.clamp(200.0, availableWidth).toDouble(),
            child: OverviewCard(
              title: metric.title,
              value: metric.value.toString(),
              icon: metric.icon,
              deltaIsPositive: metric.deltaIsPositive,
            ),
          ),
        )
        .toList();
  }

  int _resolveColumnCount(double availableWidth, int itemCount) {
    if (itemCount <= 1) return 1;
    if (availableWidth >= 1500) {
      return itemCount >= 4 ? 4 : itemCount;
    }
    if (availableWidth >= 1100) {
      return itemCount >= 3 ? 3 : itemCount;
    }
    if (availableWidth >= 820) {
      return itemCount >= 2 ? 2 : itemCount;
    }
    return 1;
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseText = colorScheme.brightness == Brightness.dark
        ? Colors.white
        : colorScheme.onSurface;
    final subtle = baseText.withValues(alpha: 0.7);

    return GlassContainer(
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: baseText,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: subtle),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({required this.records});

  final List<_AttendanceViewData> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseText = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final subtle = baseText.withValues(alpha: 0.65);

    if (records.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline,
        message: 'Belum ada log kehadiran hari ini',
      );
    }

    return Column(
      children: [
        for (final record in records.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GlassContainer(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    child: Text(
                      record.displayName.isNotEmpty
                          ? record.displayName[0]
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: baseText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.displayName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: baseText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        record.timeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StatusChip(label: record.statusLabel),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PendingRequestList extends StatelessWidget {
  const _PendingRequestList({required this.items});

  final List<_RequestViewData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseText = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final subtle = baseText.withValues(alpha: 0.65);

    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.assignment_turned_in_outlined,
        message: 'Tidak ada permohonan yang menunggu persetujuan.',
      );
    }

    return Column(
      children: [
        for (final item in items.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: GlassContainer(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: _badgeColor(context, item.typeLabel),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _badgeColor(
                            context,
                            item.typeLabel,
                          ).withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.employeeName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: baseText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.typeLabel} • ${item.dateRange}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.reason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(label: item.statusLabel),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _badgeColor(BuildContext context, String typeLabel) {
    final lower = typeLabel.toLowerCase();
    final scheme = Theme.of(context).colorScheme;
    if (lower.contains('cuti')) return scheme.primary;
    if (lower.contains('izin')) return scheme.secondary;
    return scheme.tertiary;
  }
}


class _TrendSummaryRow extends StatelessWidget {
  const _TrendSummaryRow({
    required this.present,
    required this.late,
    required this.absent,
    required this.bestDayLabel,
    required this.bestDayNet,
  });

  final int present;
  final int late;
  final int absent;
  final String bestDayLabel;
  final int bestDayNet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final baseText = cs.brightness == Brightness.dark
        ? Colors.white
        : cs.onSurface;
    final subtle = baseText.withValues(alpha: 0.68);

    Widget buildStat({
      required IconData icon,
      required Color color,
      required String label,
      required String value,
      String? caption,
    }) {
      return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.14),
                color.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: baseText,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(color: subtle),
                ),
              ],
            ],
          ),
        );
    }

    final netSign = bestDayNet >= 0 ? '+' : '−';
    final netValue = bestDayNet.abs();

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 680;
        final stats = <Widget>[
          buildStat(
            icon: Icons.trending_up,
            color: cs.secondary,
            label: 'Total Hadir',
            value: present.toString(),
            caption: 'Akumulasi 7 hari',
          ),
          buildStat(
            icon: Icons.timelapse,
            color: cs.tertiary,
            label: 'Terlambat',
            value: late.toString(),
            caption: 'Termasuk pulang cepat',
          ),
          buildStat(
            icon: Icons.event_busy,
            color: cs.error,
            label: 'Izin / Cuti',
            value: absent.toString(),
            caption: '$bestDayLabel · ${netSign}Selisih $netValue',
          ),
        ];

        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final stat in stats) ...[
                stat,
                const SizedBox(height: 8),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final stat in stats) Expanded(child: stat),
          ],
        );
      },
    );
  }
}

class _AttendanceSyncfusionChart extends StatelessWidget {
  const _AttendanceSyncfusionChart({required this.stats, required this.theme});

  final List<_DailyAttendanceStat> stats;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(
        child: Text('Belum ada data kehadiran untuk ditampilkan.'),
      );
    }

    final points = stats
        .map(
          (stat) => _ChartPoint(
            label: '${stat.date.day}/${stat.date.month}',
            net: stat.net,
            present: stat.present,
            late: stat.late,
            absent: stat.absent,
          ),
        )
        .toList(growable: false);

    double maxTotal = points
        .map<double>((p) => p.total.toDouble())
        .fold<double>(0, (prev, element) => math.max(prev, element));
    if (maxTotal <= 0) {
      maxTotal = 1;
    }
    final double axisPadding = maxTotal * 0.2;
    final double axisMax = maxTotal + axisPadding;

    final Color presentColor = const Color(0xFF2ECC71);
    final Color lateColor = const Color(0xFF8E44AD);
    final Color absenceColor = const Color(0xFFE74C3C);

    final tooltip = TooltipBehavior(
      enable: true,
      header: '',
      color: Colors.transparent,
      builder: (dynamic data, dynamic point, dynamic series, int pointIndex,
          int seriesIndex) {
        final chartPoint = points[pointIndex];
        final textStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(72, 9, 12, 26),
                blurRadius: 18,
                spreadRadius: -8,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tanggal: ${chartPoint.label}', style: textStyle),
              const SizedBox(height: 4),
              Text('Hadir: ${chartPoint.present}', style: textStyle),
              Text('Terlambat: ${chartPoint.late}', style: textStyle),
              Text('Izin/Cuti: ${chartPoint.absent}', style: textStyle),
              Text('Total: ${chartPoint.total}', style: textStyle),
            ],
          ),
        );
      },
    );

    return SfCartesianChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      plotAreaBorderWidth: 0,
      tooltipBehavior: tooltip,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: axisMax,
        axisLine: const AxisLine(width: 0),
        majorGridLines: MajorGridLines(
          width: 0.6,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
        labelStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      series: <CartesianSeries<_ChartPoint, String>>[
        StackedColumnSeries<_ChartPoint, String>(
          legendItemText: 'Hadir',
          dataSource: points,
          xValueMapper: (point, _) => point.label,
          yValueMapper: (point, _) => point.present,
          color: presentColor,
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
        StackedColumnSeries<_ChartPoint, String>(
          legendItemText: 'Terlambat',
          dataSource: points,
          xValueMapper: (point, _) => point.label,
          yValueMapper: (point, _) => point.late,
          color: lateColor,
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
        StackedColumnSeries<_ChartPoint, String>(
          legendItemText: 'Izin / Cuti',
          dataSource: points,
          xValueMapper: (point, _) => point.label,
          yValueMapper: (point, _) => point.absent,
          color: absenceColor,
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
      ],
    );
  }
}
class _AttendancePieChart extends StatelessWidget {
  const _AttendancePieChart({
    required this.totalPresent,
    required this.totalLate,
    required this.totalAbsent,
    required this.theme,
  });

  final int totalPresent;
  final int totalLate;
  final int totalAbsent;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final data = <_PieSlice>[
      _PieSlice('Hadir', totalPresent, const Color(0xFF2ECC71)),
      _PieSlice('Terlambat', totalLate, const Color(0xFF8E44AD)),
      _PieSlice('Izin / Cuti', totalAbsent, const Color(0xFFE74C3C)),
    ]..removeWhere((slice) => slice.value == 0);

    if (data.isEmpty) {
      return const Center(child: Text('Belum ada data.'));
    }

    final chartKey = data
        .map((slice) => '${slice.label}:${slice.value}')
        .join('|');

    final chartWidget = SfCircularChart(
      key: ValueKey<String>(chartKey),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <PieSeries<_PieSlice, String>>[
        PieSeries<_PieSlice, String>(
          dataSource: data,
          xValueMapper: (slice, _) => slice.label,
          yValueMapper: (slice, _) => slice.value,
          pointColorMapper: (slice, _) => slice.color,
          dataLabelMapper: (slice, _) => '${slice.label} (${slice.value})',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
          ),
          explode: false,
          startAngle: -90,
          endAngle: 270,
          animationDuration: 0,
        ),
      ],
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>('pie-$chartKey'),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) {
          final progress = Curves.easeInOutSine.transform(value.clamp(0.0, 1.0));
          final scale = 0.8 + 0.2 * progress;
          final opacity = 0.4 + 0.6 * progress;
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: ClipPath(
                clipper: _SweepClipper(progress),
                child: child,
              ),
            ),
          );
        },
        child: chartWidget,
      ),
    );
  }
}

class _SweepClipper extends CustomClipper<Path> {
  _SweepClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    if (progress >= 1) {
      return Path()..addRect(Offset.zero & size);
    }
    if (progress <= 0) {
      return Path();
    }
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 + 24;
    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, startAngle, sweepAngle, false)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_SweepClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _PieSlice {
  const _PieSlice(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class _AttendanceSparklineChart extends StatelessWidget {
  const _AttendanceSparklineChart({required this.stats, required this.theme});

  final List<_DailyAttendanceStat> stats;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(child: Text('Belum ada data.'));
    }

    final values = stats.map((stat) => stat.net.toDouble()).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SparklinePainter(
            values: values,
            theme: theme,
            positiveColor: const Color(0xFF2ECC71),
            negativeColor: const Color(0xFFE74C3C),
          ),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.theme,
    required this.positiveColor,
    required this.negativeColor,
  });

  final List<double> values;
  final ThemeData theme;
  final Color positiveColor;
  final Color negativeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    double minValue = values.reduce(math.min);
    double maxValue = values.reduce(math.max);
    minValue = math.min(minValue, 0);
    maxValue = math.max(maxValue, 0);
    double range = maxValue - minValue;
    if (range == 0) {
      range = 1;
      minValue -= 1;
      maxValue += 1;
    }

    final double dx = size.width / (values.length - 1);
    final double baselineY = size.height -
        ((0 - minValue) / range) * size.height;

    final Path linePath = Path();
    final Path fillPath = Path()..moveTo(0, baselineY);

    for (var i = 0; i < values.length; i++) {
      final double x = dx * i;
      final double y = size.height -
          ((values[i] - minValue) / range) * size.height;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, baselineY);
    fillPath.close();

    final Rect gradientRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          positiveColor.withValues(alpha: 0.25),
          positiveColor.withValues(alpha: 0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(gradientRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, areaPaint);

    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      Paint()
        ..color = theme.colorScheme.onSurface.withValues(alpha: 0.15)
        ..strokeWidth = 1,
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = positiveColor.withValues(alpha: 0.8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    for (var i = 0; i < values.length; i++) {
      final double x = dx * i;
      final double y = size.height -
          ((values[i] - minValue) / range) * size.height;
      final Color pointColor = values[i] >= 0 ? positiveColor : negativeColor;
      canvas.drawCircle(
        Offset(x, y),
        3.4,
        Paint()..color = theme.colorScheme.surface.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        Offset(x, y),
        2.4,
        Paint()..color = pointColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) {
        return true;
      }
    }
    return oldDelegate.theme.colorScheme != theme.colorScheme ||
        oldDelegate.positiveColor != positiveColor ||
        oldDelegate.negativeColor != negativeColor;
  }
}

class _DailyAttendanceStat {
  _DailyAttendanceStat({required this.date});

  final DateTime date;
  int present = 0;
  int late = 0;
  int absent = 0;

  int get negativeTotal => late + absent;
  int get total => present + late + absent;
  int get net => present - negativeTotal;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _DailyAttendanceStat &&
        other.date == date &&
        other.present == present &&
        other.late == late &&
        other.absent == absent;
  }

  @override
  int get hashCode => Object.hash(date, present, late, absent);
}

class _ChartPoint {
  _ChartPoint({
    required this.label,
    required this.net,
    required this.present,
    required this.late,
    required this.absent,
  });

  final String label;
  final int net;
  final int present;
  final int late;
  final int absent;

  int get total => present + late + absent;
}

class _OverviewMetric {
  const _OverviewMetric({
    required this.title,
    required this.value,
    required this.icon,
    this.deltaIsPositive = true,
  });

  final String title;
  final int value;
  final IconData icon;
  final bool deltaIsPositive;
}

class _AttendanceViewData {
  const _AttendanceViewData({
    required this.displayName,
    required this.subtitle,
    required this.timeLabel,
    required this.statusLabel,
  });

  final String displayName;
  final String subtitle;
  final String timeLabel;
  final String statusLabel;
}

class _RequestViewData {
  const _RequestViewData({
    required this.employeeName,
    required this.typeLabel,
    required this.dateRange,
    required this.reason,
    required this.statusLabel,
  });

  final String employeeName;
  final String typeLabel;
  final String dateRange;
  final String reason;
  final String statusLabel;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lower = label.toLowerCase();
    Color fg;
    if (lower.contains('pending')) {
      fg = colorScheme.secondary;
    } else if (lower.contains('setuju') || lower.contains('approved')) {
      fg = colorScheme.primary;
    } else if (lower.contains('tolak') || lower.contains('reject')) {
      fg = colorScheme.error;
    } else {
      fg = colorScheme.tertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [fg.withValues(alpha: 0.20), fg.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseText = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final subtle = baseText.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: baseText.withValues(alpha: 0.5), size: 34),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
          ),
        ],
      ),
    );
  }
}
