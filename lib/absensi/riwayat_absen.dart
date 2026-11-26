// lib/absensi/riwayat_absen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/leave_requests_repository.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/attendance_record.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/leave_request.dart';
import 'package:cipta_vera_mandiri_digital/view_models/attendance_history_view_model.dart';
import 'package:cipta_vera_mandiri_digital/view_models/leave_request_card_view_model.dart';

/// =================== UI PAGE ===================

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({
    super.key,
    this.leaveRepository,
    this.viewModel,
  });
  static const routeName = '/attendance-history';

  final LeaveRequestsRepository? leaveRepository;
  final AttendanceHistoryViewModel? viewModel;

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  late final AttendanceHistoryViewModel _viewModel;
  late final String _viewModelTag;

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  List<Widget> _buildLeaveSection({
    required String title,
    required IconData icon,
    required List<LeaveRequest> items,
    bool isLoading = false,
    Object? error,
  }) {
    if (items.isEmpty && !isLoading && error == null) return const [];
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    ];
    if (isLoading && items.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
      return widgets;
    }
    final errorText = error?.toString();
    if (errorText != null && errorText.isNotEmpty && items.isEmpty) {
      widgets.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                'Gagal memuat $title: $errorText',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
      return widgets;
    }
    for (var i = 0; i < items.length; i++) {
      widgets.add(
        _LeaveRequestCard(
          request: items[i],
          icon: icon,
          repository: widget.leaveRepository,
        ),
      );
      if (i != items.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }
    return widgets;
  }

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'attendance-history-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            AttendanceHistoryViewModel(leaveRepository: widget.leaveRepository),
        tag: _viewModelTag,
    );
    _viewModel.init();
  }

  void _refresh() {
    _viewModel.refreshData();
  }

  @override
  void dispose() {
    if (Get.isRegistered<AttendanceHistoryViewModel>(tag: _viewModelTag)) {
      Get.delete<AttendanceHistoryViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceHistoryViewModel>(
      tag: _viewModelTag,
      builder: (_) {
        final userUid = _viewModel.currentUserUid;
        final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        );
        final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.85),
        );

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
        title: const Text(
          'Riwayat Absen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
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
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
          body: HomeGlassTheme.background(
            child: SafeArea(
              child: userUid == null || userUid.isEmpty
                  ? const _SignInNotice()
                  : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Riwayat Kehadiran', style: titleStyle),
                      const SizedBox(height: 6),
                      Text(
                        'Lihat histori absen, cuti, dan izin terbaru Anda.',
                        style: subtitleStyle,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: FutureBuilder<List<AttendanceRecord>>(
                          future: _viewModel.attendanceFuture,
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            }
                            if (snap.hasError) {
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: _glassCard(
                                    child: Text(
                                      'Gagal memuat riwayat: ${snap.error}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final attendanceItems = snap.data ?? [];
                            final sections = _viewModel.buildSections(
                              attendanceItems,
                            );
                            final waitingCuti =
                                _viewModel.loadingCuti &&
                                _viewModel.cutiRequests.isEmpty;
                            final waitingIzin =
                                _viewModel.loadingIzin &&
                                _viewModel.izinRequests.isEmpty;
                            final hasAny =
                                sections.isNotEmpty ||
                                _viewModel.cutiRequests.isNotEmpty ||
                                _viewModel.izinRequests.isNotEmpty;

                            if (!hasAny) {
                              if (waitingCuti || waitingIzin) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              }
                              final errorMessage =
                                  (_viewModel.cutiError ?? _viewModel.izinError)
                                      ?.toString();
                              if (errorMessage != null &&
                                  errorMessage.isNotEmpty) {
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                    ),
                                    child: _glassCard(
                                      child: Text(
                                        'Gagal memuat riwayat cuti/izin: $errorMessage',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: _glassCard(
                                    child: const Text(
                                      'Belum ada riwayat absen, cuti, atau izin.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final listChildren = <Widget>[];

                            for (final section in sections) {
                              listChildren.add(
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    section.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                              for (var i = 0; i < section.items.length; i++) {
                                listChildren.add(
                                  _HistoryCard(rec: section.items[i]),
                                );
                                if (i != section.items.length - 1) {
                                  listChildren.add(const SizedBox(height: 12));
                                }
                              }
                              listChildren.add(const SizedBox(height: 12));
                            }

                            listChildren.addAll(
                              _buildLeaveSection(
                                title: 'Riwayat Cuti',
                                icon: Icons.beach_access,
                                items: _viewModel.cutiRequests,
                                isLoading: waitingCuti,
                                error: _viewModel.cutiError,
                              ),
                            );

                            listChildren.addAll(
                              _buildLeaveSection(
                                title: 'Riwayat Izin',
                                icon: Icons.assignment_turned_in,
                                items: _viewModel.izinRequests,
                                isLoading: waitingIzin,
                                error: _viewModel.izinError,
                              ),
                            );

                            return ListView(
                              padding: const EdgeInsets.only(bottom: 12),
                              physics: const BouncingScrollPhysics(),
                              children: listChildren,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _PoweredBy(),
                    ],
                  ),
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _SignInNotice extends StatelessWidget {
  const _SignInNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 44,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 14),
            const Text(
              'Silakan masuk untuk melihat riwayat kehadiran.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Powered by',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('lib/app/assets/images/cvm.png', height: 18),
            const SizedBox(width: 6),
            const Text(
              'Cipta Vera Mandiri Digital',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.rec});
  final AttendanceRecord rec;

  String _fmtDate(DateTime d) {
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
    final day = d.day.toString().padLeft(2, '0');
    final month = months[(d.month - 1).clamp(0, 11)];
    final year = d.year.toString().padLeft(2, '0').substring(2);
    return '$day $month $year';
  }

  String _fmtTime(DateTime? d) {
    if (d == null) return '-';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final ci = rec.checkInAt;
    final co = rec.checkOutAt;
    final checkedIn = ci != null;
    final statusLabel = checkedIn ? 'Hadir' : 'Belum Absen';
    final statusColor = checkedIn ? Colors.greenAccent : Colors.orangeAccent;
    final loc = (rec.lat != null && rec.lon != null)
        ? '${rec.lat!.toStringAsFixed(5)}, ${rec.lon!.toStringAsFixed(5)}'
        : '-';
    final proj = rec.project ?? '-';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color.fromARGB(220, 11, 15, 30),
                Color.fromARGB(190, 15, 22, 40),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBadge(statusColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmtDate(rec.date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            proj == '-' ? 'Tidak ada proyek' : proj,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _statusChip(statusLabel, statusColor),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow(Icons.access_time, 'Masuk: ${_fmtTime(ci)}'),
                if (co != null && co != ci) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.logout, 'Pulang: ${_fmtTime(co)}'),
                ],
                const SizedBox(height: 8),
                _infoRow(Icons.place, 'Lokasi: $loc'),
                const SizedBox(height: 8),
                if ((rec.note ?? '').isNotEmpty)
                  _infoRow(Icons.notes, rec.note!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBadge(Color color) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _LeaveRequestCard extends StatefulWidget {
  const _LeaveRequestCard({
    required this.request,
    required this.icon,
    this.repository,
  });

  final LeaveRequest request;
  final IconData icon;
  final LeaveRequestsRepository? repository;

  @override
  State<_LeaveRequestCard> createState() => _LeaveRequestCardState();
}

class _LeaveRequestCardState extends State<_LeaveRequestCard> {
  late final LeaveRequestCardViewModel _viewModel;
  late final String _viewModelTag;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'leave-request-card-${identityHashCode(this)}';
    _viewModel = Get.put(
      LeaveRequestCardViewModel(
        initialRequest: widget.request,
        repository: widget.repository,
      ),
      tag: _viewModelTag,
    );
  }

  @override
  void didUpdateWidget(covariant _LeaveRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _viewModel.updateFromParent(widget.request);
  }

  @override
  void dispose() {
    if (Get.isRegistered<LeaveRequestCardViewModel>(tag: _viewModelTag)) {
      Get.delete<LeaveRequestCardViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
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
    final day = local.day.toString().padLeft(2, '0');
    final month = months[(local.month - 1).clamp(0, 11)];
    final year = local.year
        .toString()
        .padLeft(4, '0')
        .substring(2); // two-digit year
    return '$day $month $year';
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatRange(LeaveRequest request) {
    if (request.isLeave) {
      final start = _formatDate(request.startAt);
      final end = _formatDate(request.endAt);
      return start == end ? start : '$start - $end';
    }
    final date = _formatDate(request.startAt);
    final start = _formatTime(request.startAt);
    final end = _formatTime(request.endAt);
    return '$date • $start - $end';
  }

  String? _durationLabel(LeaveRequest request) {
    if (request.isLeave) {
      final start = DateTime(
        request.startAt.year,
        request.startAt.month,
        request.startAt.day,
      );
      final end = DateTime(
        request.endAt.year,
        request.endAt.month,
        request.endAt.day,
      );
      final days = end.difference(start).inDays.abs() + 1;
      if (days <= 0) return null;
      return '$days hari';
    }
    final diff = request.endAt.difference(request.startAt).inMinutes;
    if (diff <= 0) return null;
    final hours = diff ~/ 60;
    final minutes = diff % 60;
    if (hours > 0 && minutes > 0) {
      return '$hours jam $minutes mnt';
    } else if (hours > 0) {
      return '$hours jam';
    } else {
      return '$minutes menit';
    }
  }

  Color _statusColor(LeaveRequestStatus status) {
    switch (status) {
      case LeaveRequestStatus.approved:
        return const Color(0xFF4CAF50); // green
      case LeaveRequestStatus.rejected:
        return const Color(0xFFE53935); // red
      case LeaveRequestStatus.pending:
        return const Color(0xFFFFB300); // amber
    }
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tautan lampiran tidak valid.')),
      );
      return;
    }
    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka lampiran.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka lampiran.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LeaveRequestCardViewModel>(
      tag: _viewModelTag,
      builder: (_) {
        final request = _viewModel.request;
        final statusColor = _statusColor(request.status);
        final statusLabel = leaveRequestStatusLabel(request.status);
        final appliedAt =
            '${_formatDate(request.createdAt)} • ${_formatTime(request.createdAt)}';
        final applicantDisplay = _viewModel.requesterName.isNotEmpty
            ? _viewModel.requesterName
            : request.uid;
        final processedBy = _viewModel.approverName;
        final kindLabel = request.isLeave ? 'Cuti' : 'Izin';
        final durationText = _durationLabel(request);

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color.fromARGB(230, 12, 16, 32),
                Color.fromARGB(210, 18, 24, 44),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBadge(widget.icon, statusColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicantDisplay,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pengajuan ${request.isLeave ? 'Cuti' : 'Izin'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _pill(statusLabel, statusColor),
                            const SizedBox(width: 6),
                            _pill(kindLabel, Colors.tealAccent),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _infoRow(
                          Icons.schedule,
                          appliedAt,
                          accent: Colors.white70,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow(
                  Icons.date_range,
                  _formatRange(request),
                  accent: statusColor.withValues(alpha: 0.55),
                  trailing: durationText != null
                      ? Text(
                          'Durasi: $durationText',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                _reasonBlock(
                  request.reason.isEmpty
                      ? 'Tidak ada keterangan tambahan.'
                      : request.reason,
                ),
                if (request.attachments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _attachmentRow(request.attachments),
                ],
                if (processedBy.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoRow(Icons.verified_user, 'Diproses oleh $processedBy'),
                ],
                if ((request.decisionNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.comment,
                    'Catatan: ${request.decisionNote!.trim()}',
                  ),
                ],
              ],
            ),
          ),
            ),
          ),
        );
      },
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _reasonBlock(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keterangan',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _attachmentRow(List<LeaveAttachment> attachments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.attach_file, color: Colors.white70, size: 16),
            SizedBox(width: 6),
            Text(
              'Lampiran',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: attachments
              .map(
                (att) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _attachmentChip(att, expanded: true),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _attachmentChip(LeaveAttachment attachment, {bool expanded = false}) {
    final name = attachment.name.isNotEmpty ? attachment.name : 'Lampiran';
    final button = OutlinedButton.icon(
      onPressed: () => _openAttachment(attachment.url),
      icon: const Icon(Icons.download_rounded, size: 16),
      label: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.left,
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _infoRow(
    IconData icon,
    String text, {
    Widget? trailing,
    Color? accent,
    bool compact = false,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(icon, color: accent ?? Colors.white, size: 16),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 11.5 : 12.5,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
