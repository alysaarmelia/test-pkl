import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:cipta_vera_mandiri_digital/repositories/profile_card_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/profile_card_view_model.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/attendance_window.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/leave_request.dart';

import 'home_theme.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key, this.repository, this.viewModel});

  final ProfileCardRepository? repository;
  final ProfileCardViewModel? viewModel;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard>
    with SingleTickerProviderStateMixin {
  late final ProfileCardViewModel _viewModel;
  late final String _viewModelTag;
  Timer? _statusTimer;

  DateTime get _now => DateTime.now();
  int get _daysInThisMonth => DateTime(_now.year, _now.month + 1, 0).day;

  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    );
    _viewModelTag = 'profile-card-${identityHashCode(this)}';
    _viewModel = Get.put(
      widget.viewModel ?? ProfileCardViewModel(repository: widget.repository),
      tag: _viewModelTag,
    );
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<ProfileCardViewModel>(tag: _viewModelTag)) {
      Get.delete<ProfileCardViewModel>(tag: _viewModelTag, force: true);
    }
    _statusTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileCardViewModel>(
      tag: _viewModelTag,
      builder: (viewModel) {
        final uid = viewModel.currentUserUid;
        if (uid == null || uid.isEmpty) {
          return const SizedBox.shrink();
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: HomeGlassTheme.surfaceStrong,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: HomeGlassTheme.surfaceBorder, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(4, 12, 28, 0.38),
                    offset: Offset(0, 24),
                    blurRadius: 48,
                    spreadRadius: -18,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row for profile info and photo
                  StreamBuilder<ProfileCardUserProfile?>(
                    stream: viewModel.userProfileStream,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return _ProfileHeaderSkeleton(animation: _shimmerAnimation);
                      }
                      final profile = snap.data;
                      final pin = profile?.pin ?? '';
                      final name = profile?.name ?? '';
                      final role = profile?.role ?? '';
                      final photoUrl = profile?.photoUrl ?? '';
                      final hasPhoto = photoUrl.isNotEmpty;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // PIN
                                Text(
                                  pin.isNotEmpty ? pin.toUpperCase() : '-',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Nama (uppercase jika ada)
                                Text(
                                  name.isNotEmpty ? name.toUpperCase() : 'USER',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                // Role/Tim
                                Text(
                                  role.isNotEmpty ? 'Tim: $role' : 'Tim: -',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Profile Picture
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: HomeGlassTheme.surfaceSoft,
                            backgroundImage: hasPhoto
                                ? NetworkImage(photoUrl)
                                : null,
                            child: !hasPhoto
                                ? const Icon(
                                    Icons.person,
                                    color: HomeGlassTheme.textSecondary,
                                    size: 28,
                                  )
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildAttendanceSummary(context),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceSummary(BuildContext context) {
    return StreamBuilder<AttendanceWindow?>(
      stream: _viewModel.windowStream,
      builder: (context, snapWindow) {
        final windowLoading =
            snapWindow.connectionState == ConnectionState.waiting &&
            !snapWindow.hasData;
        final window = snapWindow.data;
        return StreamBuilder<List<ProfileCardAttendanceEntry>>(
          stream: _viewModel.attendanceStream,
          builder: (context, snapA) {
            return StreamBuilder<List<ProfileCardAttendanceEntry>>(
              stream: _viewModel.absenStream,
              builder: (context, snapB) {
                return StreamBuilder<List<ProfileCardAttendanceEntry>>(
                  stream: _viewModel.userAttendanceStream,
                  builder: (context, snapC) {
                    return StreamBuilder<List<LeaveRequest>>(
                      stream: _viewModel.leaveRequestsStream,
                      initialData: const <LeaveRequest>[],
                      builder: (context, snapLeave) {
                        final loading =
                            windowLoading ||
                            (snapA.connectionState == ConnectionState.waiting &&
                                !snapA.hasData) ||
                            (snapB.connectionState == ConnectionState.waiting &&
                                !snapB.hasData) ||
                            (snapC.connectionState == ConnectionState.waiting &&
                                !snapC.hasData) ||
                            (snapLeave.connectionState ==
                                    ConnectionState.waiting &&
                                (snapLeave.data == null ||
                                    snapLeave.data!.isEmpty));

                        if (loading) {
                          return _AttendanceSkeleton(
                            animation: _shimmerAnimation,
                          );
                        }

                        final hadirDays = <DateTime>{};
                        final izinDays = <DateTime>{};
                        final cutiDays = <DateTime>{};
                        final attendanceIzinDays = <DateTime>{};
                        final attendanceCutiDays = <DateTime>{};
                        int izinRequestCount = 0;
                        int cutiRequestCount = 0;
                        final todayDate = DateTime(
                          _now.year,
                          _now.month,
                          _now.day,
                        );
                        bool hasCheckInToday = false;
                        bool hasLateToday = false;

                        final docsA =
                            snapA.data ?? const <ProfileCardAttendanceEntry>[];
                        final docsB =
                            snapB.data ?? const <ProfileCardAttendanceEntry>[];
                        final docsC =
                            snapC.data ?? const <ProfileCardAttendanceEntry>[];

                        DateTime onlyDate(DateTime value) =>
                            DateTime(value.year, value.month, value.day);
                        void addRange(
                          Set<DateTime> target,
                          DateTime from,
                          DateTime to,
                        ) {
                          var cursor = from;
                          while (!cursor.isAfter(to)) {
                            target.add(
                              DateTime(cursor.year, cursor.month, cursor.day),
                            );
                            cursor = cursor.add(const Duration(days: 1));
                          }
                        }

                        final mergedEntries = [...docsA, ...docsB, ...docsC];
                        // Deduplicate by Day, picking the latest record for each day
                        final dayEntriesMap = <DateTime, ProfileCardAttendanceEntry>{};
                        for (final e in mergedEntries) {
                          final day = onlyDate(e.date);
                          final existing = dayEntriesMap[day];
                          // Use the record with the latest timestamp or latest doc creation
                          if (existing == null || e.timestamp >= existing.timestamp) {
                            dayEntriesMap[day] = e;
                          }
                        }
                        final entries = dayEntriesMap.values.toList();

                        for (final entry in entries) {
                          final dt = entry.date;
                          if (dt.year != _now.year || dt.month != _now.month) {
                            continue;
                          }
                          final day = onlyDate(dt);
                          final isToday = day == todayDate;

                          final raw = entry.status.toLowerCase();
                          final s = raw.replaceAll(RegExp(r'[^a-z]'), '');

                          if (s.contains('checkout') || s == 'out') {
                            continue;
                          }
                          if (s.contains('izin') || s.contains('permission')) {
                            izinDays.add(day);
                            attendanceIzinDays.add(day);
                            continue;
                          }
                          if (s.contains('cuti') ||
                              s.contains('leave') ||
                              s.contains('off')) {
                            cutiDays.add(day);
                            attendanceCutiDays.add(day);
                            continue;
                          }
                          if (s.contains('checkin') ||
                              (s.contains('hadir') && !s.contains('tidak')) ||
                              s == 'in' ||
                              s.contains('masuk')) {
                            if (isToday) {
                              hasCheckInToday = true;
                              if (raw.contains('terlambat') ||
                                  raw.contains('late')) {
                                hasLateToday = true;
                              }
                            }
                            hadirDays.add(day);
                          }
                        }

                        final hadir = hadirDays.length;
                        final leaveRequests =
                            snapLeave.data ?? const <LeaveRequest>[];
                        final monthStart = DateTime(_now.year, _now.month, 1);
                        final nextMonth = DateTime(
                          _now.year,
                          _now.month + 1,
                          1,
                        );
                        final lastDayOfMonth = nextMonth.subtract(
                          const Duration(days: 1),
                        );

                        for (final request in leaveRequests) {
                          if (!request.isApproved) continue;
                          final start = onlyDate(request.startAt.toLocal());
                          final end = onlyDate(request.endAt.toLocal());

                          if (request.isLeave) {
                            final overlapsMonth =
                                !end.isBefore(monthStart) &&
                                start.isBefore(nextMonth);
                            if (overlapsMonth) {
                              final rangeStart = start.isBefore(monthStart)
                                  ? monthStart
                                  : start;
                              final rangeEnd = end.isAfter(lastDayOfMonth)
                                  ? lastDayOfMonth
                                  : end;
                              if (!rangeStart.isAfter(rangeEnd)) {
                                addRange(cutiDays, rangeStart, rangeEnd);
                                cutiRequestCount++;
                              }
                            }
                          } else if (request.isPermission) {
                            final overlapsMonth =
                                !end.isBefore(monthStart) &&
                                start.isBefore(nextMonth);
                            if (overlapsMonth) {
                              final rangeStart = start.isBefore(monthStart)
                                  ? monthStart
                                  : start;
                              final rangeEnd = end.isAfter(lastDayOfMonth)
                                  ? lastDayOfMonth
                                  : end;
                              if (!rangeStart.isAfter(rangeEnd)) {
                                addRange(izinDays, rangeStart, rangeEnd);
                                izinRequestCount++;
                              }
                            }
                          }
                        }

                        final izinDaysCount = izinDays.length;
                        final cutiDaysCount = cutiDays.length;
                        final izinValue = izinRequestCount > 0
                            ? izinRequestCount
                            : attendanceIzinDays.length;
                        final cutiValue = cutiRequestCount > 0
                            ? cutiRequestCount
                            : attendanceCutiDays.length;

                        final totalDays = _daysInThisMonth;
                        final hadirProg = totalDays > 0
                            ? (hadir / totalDays).clamp(0.0, 1.0)
                            : 0.0;
                        final izinProg = totalDays > 0
                            ? (izinDaysCount / totalDays).clamp(0.0, 1.0)
                            : 0.0;
                        final cutiProg = totalDays > 0
                            ? (cutiDaysCount / totalDays).clamp(0.0, 1.0)
                            : 0.0;

                        int tidakHadirCount = 0;
                        for (int d = 1; d <= todayDate.day; d++) {
                          final day = DateTime(todayDate.year, todayDate.month, d);
                          
                          // Exclude Sundays (always libur)
                          // Saturday is still a workday (till 12 PM)
                          if (day.weekday == DateTime.sunday) {
                            continue;
                          }

                          if (day == todayDate) {
                            // Only count today as Alpha if it's already past the attendance window closure
                            if (window != null &&
                                window.isAfterClose(_now) &&
                                !hasCheckInToday &&
                                !izinDays.contains(day) &&
                                !cutiDays.contains(day)) {
                              tidakHadirCount++;
                            }
                          } else {
                            // Count as Alpha if there is no record of Hadir, Izin, or Cuti
                            if (!hadirDays.contains(day) &&
                                !izinDays.contains(day) &&
                                !cutiDays.contains(day)) {
                              tidakHadirCount++;
                            }
                          }
                        }
                        final alphaProg = totalDays > 0
                            ? (tidakHadirCount / totalDays).clamp(0.0, 1.0)
                            : 0.0;

                        Widget ringStat({
                          required String label,
                          required int value,
                          required int total,
                          required double progress,
                          required bool showTotal,
                          required Color accentColor,
                          double highlightStart = 0,
                          double highlightProgress = 0,
                          Color? highlightColor,
                        }) {
                          return Column(
                            children: [
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        value: 1,
                                        strokeWidth: 6,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Color.fromRGBO(
                                                255,
                                                255,
                                                255,
                                                0.25,
                                              ),
                                            ),
                                        backgroundColor: Colors.transparent,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 6,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              accentColor,
                                            ),
                                        backgroundColor: Colors.transparent,
                                      ),
                                    ),
                                    if (highlightColor != null &&
                                        highlightProgress > 0) ...[
                                      SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: Transform.rotate(
                                          angle: 2 * math.pi * highlightStart,
                                          child: CircularProgressIndicator(
                                            value: highlightProgress.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            strokeWidth: 6,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  highlightColor,
                                                ),
                                            backgroundColor: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Text(
                                      showTotal ? '$value/$total' : '$value',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          );
                        }

                        final statusChip = Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildAttendanceStatusChip(
                            window: window,
                            loading: windowLoading,
                            hasCheckInToday: hasCheckInToday,
                            hasLateToday: hasLateToday,
                          ),
                        );

                        const baseRingColor = Color(0xFFFFC107);
                        final nowMoment = DateTime.now();
                        Color attendanceRingColor = baseRingColor;
                        double attendanceHighlightStart = 0;
                        double attendanceHighlightProgress = 0;
                        Color? attendanceHighlightColor;
                        if (hasLateToday &&
                            hasCheckInToday &&
                            totalDays > 0 &&
                            hadir > 0) {
                          final previousCount = (hadir - 1).clamp(0, totalDays);
                          final previousProgress = (previousCount / totalDays)
                              .clamp(0.0, 1.0);
                          attendanceHighlightStart = previousProgress;
                          attendanceHighlightProgress =
                              (hadirProg - previousProgress).clamp(0.0, 1.0);
                          attendanceHighlightColor = const Color(0xFF8E24AA);
                        }

                        final statsRow = Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ringStat(
                              label: 'HADIR',
                              value: hadir,
                              total: totalDays,
                              progress: hadirProg,
                              showTotal: true,
                              accentColor: const Color(0xFF4CAF50),
                              highlightStart: attendanceHighlightStart,
                              highlightProgress: attendanceHighlightProgress,
                              highlightColor: attendanceHighlightColor,
                            ),
                            ringStat(
                              label: 'IZIN',
                              value: izinValue,
                              total: totalDays,
                              progress: izinProg,
                              showTotal: false,
                              accentColor: baseRingColor,
                            ),
                            ringStat(
                              label: 'CUTI',
                              value: cutiValue,
                              total: totalDays,
                              progress: cutiProg,
                              showTotal: false,
                              accentColor: baseRingColor,
                            ),
                            ringStat(
                              label: 'ALPHA',
                              value: tidakHadirCount,
                              total: totalDays,
                              progress: alphaProg,
                              showTotal: false,
                              accentColor: const Color(0xFFC62828),
                            ),
                          ],
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [statusChip, statsRow],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceStatusChip({
    required AttendanceWindow? window,
    required bool loading,
    required bool hasCheckInToday,
    required bool hasLateToday,
  }) {
    final now = DateTime.now();
    final isSunday = now.weekday == DateTime.sunday;

    if (isSunday) {
      return _attendanceStatusTile(
        color: const Color(0xFF546E7A),
        icon: Icons.weekend_rounded,
        title: 'Libur Hari Minggu',
        subtitle: 'Tidak ada absen yang diperlukan hari ini.',
      );
    }

    if (loading && window == null) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (hasLateToday) {
      return _attendanceStatusTile(
        color: const Color(0xFF8E24AA),
        icon: Icons.schedule_rounded,
        title: 'Status: Terlambat',
        subtitle: 'Anda sudah absen terlambat hari ini.',
      );
    }

    if (hasCheckInToday) {
      return _attendanceStatusTile(
        color: const Color(0xFF4CAF50),
        icon: Icons.check_circle_outline,
        title: 'Status: Sudah Absen',
        subtitle: 'Selamat bekerja!',
      );
    }

    if (window == null) {
      return _attendanceStatusTile(
        color: const Color(0xFFC62828),
        icon: Icons.lock_clock,
        title: 'Absen tidak tersedia',
        subtitle: 'Hubungi admin untuk jadwal terbaru.',
      );
    }

    if (!window.isConfigured) {
      return _attendanceStatusTile(
        color: const Color(0xFFC62828),
        icon: Icons.info_outline,
        title: 'Jadwal absen belum lengkap',
        subtitle: 'Silakan konfirmasi ke admin.',
      );
    }

    if (window.isBeforeOpen(now)) {
      final openLabel = _formatClock(window.openAt);
      return _attendanceStatusTile(
        color: const Color(0xFF1565C0),
        icon: Icons.lock_open,
        title: 'Absen belum dibuka',
        subtitle: 'Mulai pukul $openLabel.',
      );
    }

    if (window.isAfterClose(now)) {
      return _attendanceStatusTile(
        color: const Color(0xFFC62828),
        icon: Icons.lock_clock,
        title: 'Belum absen',
        subtitle: 'Jadwal absen hari ini sudah ditutup.',
      );
    }

    return _attendanceStatusTile(
      color: const Color(0xFFC62828),
      icon: Icons.error_outline,
      title: 'Belum absen',
      subtitle: 'Segera lakukan absen hari ini.',
    );
  }

  Widget _attendanceStatusTile({
    required Color color,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatClock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.height,
    required this.animation,
    this.width,
    this.borderRadius,
  });

  final double height;
  final double? width;
  final Animation<double> animation;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(height / 2);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = width == null
                  ? constraints.maxWidth
                  : width!.clamp(0.0, double.infinity);
              final shimmerWidth = maxWidth * 0.55;
              final base = Colors.white.withValues(alpha: 0.12);
              final highlight = Colors.white.withValues(alpha: 0.28);
              final dx =
                  (animation.value * (maxWidth + shimmerWidth)) - shimmerWidth;

              return ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    Container(height: height, width: maxWidth, color: base),
                    Positioned(
                      left: dx,
                      top: 0,
                      bottom: 0,
                      width: shimmerWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [base, highlight, base],
                            stops: const [0.1, 0.5, 0.9],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBlock(height: 14, width: 90, animation: animation),
              const SizedBox(height: 8),
              _ShimmerBlock(height: 16, width: 140, animation: animation),
              const SizedBox(height: 8),
              _ShimmerBlock(height: 14, width: 110, animation: animation),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: HomeGlassTheme.surfaceBorder, width: 1),
            color: HomeGlassTheme.surfaceSoft,
          ),
          child: ClipOval(
            child: _ShimmerBlock(
              height: 52,
              width: 52,
              animation: animation,
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceSkeleton extends StatelessWidget {
  const _AttendanceSkeleton({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerBlock(
          height: 52,
          animation: animation,
          borderRadius: BorderRadius.circular(18),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatsSkeletonItem(animation: animation),
            _StatsSkeletonItem(animation: animation),
            _StatsSkeletonItem(animation: animation),
            _StatsSkeletonItem(animation: animation),
          ],
        ),
      ],
    );
  }
}

class _StatsSkeletonItem extends StatelessWidget {
  const _StatsSkeletonItem({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ShimmerBlock(
          height: 60,
          width: 60,
          animation: animation,
          borderRadius: BorderRadius.circular(30),
        ),
        const SizedBox(height: 8),
        _ShimmerBlock(
          height: 12,
          width: 70,
          animation: animation,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}
