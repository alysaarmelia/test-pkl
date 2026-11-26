import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cipta_vera_mandiri_digital/shared/models/leave_request.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/leave_request_repository.dart';

import '../../data/attendance_repository.dart';
import '../../widgets/glass.dart';

String _prettyNameFromEmail(String email) {
  final prefix = email.split('@').first;
  final parts =
      prefix.split(RegExp(r'[._\\-]+')).where((segment) => segment.isNotEmpty);
  if (parts.isEmpty) return email;
  return parts
      .map(
        (segment) =>
            segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
      )
      .join(' ');
}

class RequestManagementPage extends StatefulWidget {
  const RequestManagementPage({super.key});

  @override
  State<RequestManagementPage> createState() => _RequestManagementPageState();
}

class _RequestManagementPageState extends State<RequestManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _statusFilter = 'Semua';
  final LeaveRequestRepository _leaveRepository = LeaveRequestRepository();
  final AdminAttendanceRepository _userRepository = AdminAttendanceRepository();
  final Map<String, AdminUserSummary?> _userCache = {};
  final Set<String> _pendingUserLoads = <String>{};
  final Set<String> _updating = <String>{};
  DateTime _today = DateTime.now();
  late DateTime _focusedMonth;
  DateTime? _selectedDate;
  bool _followToday = true;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = _stripTime(_today);
    _focusedMonth = DateTime(_today.year, _today.month);
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  LeaveRequestStatus? _statusFilterEnum() {
    final lower = _statusFilter.toLowerCase();
    if (lower.contains('pending') || lower.contains('menunggu')) {
      return LeaveRequestStatus.pending;
    }
    if (lower.contains('setuju') || lower.contains('approved')) {
      return LeaveRequestStatus.approved;
    }
    if (lower.contains('tolak') || lower.contains('reject')) {
      return LeaveRequestStatus.rejected;
    }
    return null;
  }

  void _scheduleUserFetch(Iterable<String> uids) {
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
          final summary = await _userRepository.fetchUserSummary(uid);
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
      });
    }).whenComplete(() {
      _pendingUserLoads.removeAll(missing);
    });
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, _handleMidnightTick);
  }

  void _handleMidnightTick() {
    if (!mounted) return;
    _today = DateTime.now();
    if (_followToday) {
      setState(() {
        _selectedDate = _stripTime(_today);
        _focusedMonth = DateTime(_today.year, _today.month);
      });
    } else {
      setState(() {});
    }
    _scheduleMidnightReset();
  }

  DateTime _stripTime(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _handleSelectDate(DateTime value) {
    final date = _stripTime(value);
    setState(() {
      _selectedDate = date;
      _followToday = _stripTime(_today) == date;
    });
  }

  void _handlePrevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _handleNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _handleToday() {
    final now = DateTime.now();
    final today = _stripTime(now);
    setState(() {
      _today = now;
      _focusedMonth = DateTime(today.year, today.month);
      _selectedDate = today;
      _followToday = true;
    });
  }

  Future<void> _handleStatusChange(
    BuildContext context,
    LeaveRequest request,
    LeaveRequestStatus status,
  ) async {
    if (_updating.contains(request.id)) return;
    setState(() => _updating.add(request.id));
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? decidedName;
      if (user != null) {
        final summary = await _userRepository.fetchUserSummary(user.uid);
        decidedName = summary?.displayName ?? user.displayName;
        if (summary != null) {
          _userCache[user.uid] = summary;
        }
      }
      decidedName = (decidedName ?? '').trim();
      await _leaveRepository.updateStatus(
        requestId: request.id,
        status: status,
        decidedByUid: user?.uid,
        decidedByEmail: user?.email,
        decidedByName:
            decidedName.isEmpty ? (user?.email ?? 'Admin') : decidedName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status ${request.isLeave ? 'cuti' : 'izin'} diperbarui menjadi ${leaveRequestStatusLabel(status)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updating.remove(request.id));
      } else {
        _updating.remove(request.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Persetujuan Cuti & Izin',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Tinjau, setujui, atau tolak permohonan karyawan.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _RequestCalendar(
            focusedMonth: _focusedMonth,
            today: _stripTime(_today),
            selected: _selectedDate,
            onSelect: _handleSelectDate,
            onPrev: _handlePrevMonth,
            onNext: _handleNextMonth,
            onToday: _handleToday,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GlassContainer(
                  borderRadius: 18,
                  blur: 20,
                  padding: const EdgeInsets.all(4),
                  gradientColors: const [
                    Color.fromARGB(150, 18, 20, 36),
                    Color.fromARGB(92, 11, 13, 28),
                  ],
                  borderColor: const Color.fromARGB(70, 255, 255, 255),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(55, 6, 10, 30),
                      offset: Offset(0, 20),
                      blurRadius: 40,
                      spreadRadius: -18,
                    ),
                  ],
                  child: TabBar(
                    controller: _tabController,
                    padding: EdgeInsets.zero,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).colorScheme.onPrimary,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    tabs: const [
                      Tab(text: 'Cuti'),
                      Tab(text: 'Izin'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _StatusFilter(
                value: _statusFilter,
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _LeaveRequestTab(
                  stream: _leaveRepository.watchRequests(
                    kind: 'cuti',
                    status: _statusFilterEnum(),
                  ),
                  selectedDate: _selectedDate,
                  userCache: _userCache,
                  onFetchUsers: _scheduleUserFetch,
                  onUpdateStatus: _handleStatusChange,
                  updating: _updating,
                  emptyMessage: 'Tidak ada pengajuan cuti untuk filter ini.',
                ),
                _LeaveRequestTab(
                  stream: _leaveRepository.watchRequests(
                    kind: 'izin',
                    status: _statusFilterEnum(),
                  ),
                  selectedDate: _selectedDate,
                  userCache: _userCache,
                  onFetchUsers: _scheduleUserFetch,
                  onUpdateStatus: _handleStatusChange,
                  updating: _updating,
                  emptyMessage: 'Tidak ada pengajuan izin untuk filter ini.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRequestTab extends StatelessWidget {
  const _LeaveRequestTab({
    required this.stream,
    required this.userCache,
    required this.onFetchUsers,
    required this.onUpdateStatus,
    required this.updating,
    required this.emptyMessage,
    required this.selectedDate,
  });

  final Stream<List<LeaveRequest>> stream;
  final DateTime? selectedDate;
  final Map<String, AdminUserSummary?> userCache;
  final void Function(Iterable<String>) onFetchUsers;
  final Future<void> Function(
    BuildContext context,
    LeaveRequest request,
    LeaveRequestStatus status,
  ) onUpdateStatus;
  final Set<String> updating;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<LeaveRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading(theme);
        }
        if (snapshot.hasError) {
          return _buildError(theme, snapshot.error);
        }
        final baseRequests = snapshot.data ?? <LeaveRequest>[];
        final filteredRequests = _applyDateFilter(baseRequests, selectedDate);
        if (filteredRequests.isEmpty) {
          return _buildEmpty(theme, emptyMessage);
        }

        final uidSet = <String>{};
        for (final request in filteredRequests) {
          if (request.uid.isNotEmpty) {
            uidSet.add(request.uid);
          }
          final approverUid = request.approverUid;
          if (approverUid != null && approverUid.trim().isNotEmpty) {
            uidSet.add(approverUid.trim());
          }
        }
        if (uidSet.isNotEmpty) {
          onFetchUsers(uidSet);
        }

        return GlassContainer(
          borderRadius: 26,
          blur: 20,
          gradientColors: const [
            Color.fromARGB(118, 28, 34, 72),
            Color.fromARGB(72, 18, 24, 48),
          ],
          borderColor: const Color.fromARGB(58, 255, 255, 255),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(40, 6, 10, 30),
              offset: Offset(0, 20),
              blurRadius: 42,
              spreadRadius: -18,
            ),
          ],
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: filteredRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final request = filteredRequests[index];
                final summary = userCache[request.uid];
                return _buildRequestCard(
                  context,
                  theme,
                  request,
                  summary,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return GlassContainer(
      borderRadius: 26,
      blur: 20,
      padding: const EdgeInsets.symmetric(vertical: 80),
      gradientColors: const [
        Color.fromARGB(118, 28, 34, 72),
        Color.fromARGB(72, 18, 24, 48),
      ],
      borderColor: const Color.fromARGB(58, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(40, 6, 10, 30),
          offset: Offset(0, 20),
          blurRadius: 42,
          spreadRadius: -18,
        ),
      ],
      child: Center(
        child: SizedBox(
          height: 32,
          width: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme, Object? error) {
    return GlassContainer(
      borderRadius: 26,
      blur: 20,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      gradientColors: const [
        Color.fromARGB(118, 28, 34, 72),
        Color.fromARGB(72, 18, 24, 48),
      ],
      borderColor: const Color.fromARGB(58, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(40, 6, 10, 30),
          offset: Offset(0, 20),
          blurRadius: 42,
          spreadRadius: -18,
        ),
      ],
      child: Center(
        child: Text(
          'Gagal memuat data: ${error ?? 'tidak diketahui'}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.85),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme, String message) {
    return GlassContainer(
      borderRadius: 26,
      blur: 20,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      gradientColors: const [
        Color.fromARGB(118, 28, 34, 72),
        Color.fromARGB(72, 18, 24, 48),
      ],
      borderColor: const Color.fromARGB(58, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(40, 6, 10, 30),
          offset: Offset(0, 20),
          blurRadius: 42,
          spreadRadius: -18,
        ),
      ],
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.82),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  List<LeaveRequest> _applyDateFilter(
    List<LeaveRequest> requests,
    DateTime? selectedDate,
  ) {
    if (selectedDate == null) return requests;
    return requests.where((request) {
      if (request.status == LeaveRequestStatus.pending) {
        return true;
      }
      final start = request.startAt.toLocal();
      final end = request.endAt.toLocal();
      final target = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);
      final withinRange = target.isAtSameMomentAs(startDate) ||
          target.isAtSameMomentAs(endDate) ||
          (target.isAfter(startDate) && target.isBefore(endDate));
      if (request.isPermission) {
        final requestDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        return withinRange || target.isAtSameMomentAs(requestDate);
      }
      return withinRange;
    }).toList();
  }

  Widget _buildRequestCard(
    BuildContext context,
    ThemeData theme,
    LeaveRequest request,
    AdminUserSummary? summary,
  ) {
    final displayName = summary?.displayName ?? request.uid;
    final subtitle = summary?.secondaryLabel;
    final range = _formatRange(request);
    final created = _formatCreated(request.createdAt);
    final duration = _durationLabel(request);
    final isPending = request.status == LeaveRequestStatus.pending;
    final isUpdating = updating.contains(request.id);
    final statusColor = _statusColor(theme, request.status);
    final approverLabel = request.approverEmail ?? request.approverUid;
    final attachments = request.attachments;
    final kindLabel = request.isLeave ? 'Cuti' : 'Izin';

    return GlassContainer(
      borderRadius: 24,
      blur: 18,
      gradientColors: const [
        Color.fromARGB(122, 26, 31, 62),
        Color.fromARGB(72, 20, 26, 50),
      ],
      borderColor: Colors.white.withOpacity(0.24),
      padding: const EdgeInsets.all(22),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(32, 4, 10, 34),
          offset: Offset(0, 18),
          blurRadius: 36,
          spreadRadius: -16,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatarBadge(kindLabel, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    created,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusChip(theme, request.status),
              _kindChip(theme, request),
              Text(
                range,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                ),
              ),
              if (duration != null)
                Text(
                  'Durasi: $duration',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _reasonBlock(theme, request.reason),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildAttachments(theme, attachments),
          ],
          if (request.decisionNote != null &&
              request.decisionNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan: ${request.decisionNote}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.76),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (!isPending &&
                  approverLabel != null &&
                  approverLabel.isNotEmpty)
                Text(
                  'Diproses oleh $approverLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
              const Spacer(),
              if (isPending)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () => onUpdateStatus(
                                context,
                                request,
                                LeaveRequestStatus.rejected,
                              ),
                      icon: const Icon(Icons.close),
                      label: const Text('Tolak'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () => onUpdateStatus(
                                context,
                                request,
                                LeaveRequestStatus.approved,
                              ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Setujui'),
                    ),
                    if (isUpdating)
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                  ],
                )
              else
                Text(
                  leaveRequestStatusLabel(request.status),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(ThemeData theme, LeaveRequestStatus status) {
    final color = _statusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        leaveRequestStatusLabel(status),
        style: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme, LeaveRequestStatus status) {
    final scheme = theme.colorScheme;
    switch (status) {
      case LeaveRequestStatus.approved:
        return scheme.tertiary;
      case LeaveRequestStatus.rejected:
        return scheme.error;
      case LeaveRequestStatus.pending:
      default:
        return scheme.secondary;
    }
  }

  Widget _buildAttachments(
    ThemeData theme,
    List<LeaveAttachment> attachments,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lampiran pendukung',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: attachments
              .map((att) => _attachmentButton(theme, att))
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _attachmentButton(ThemeData theme, LeaveAttachment attachment) {
    final label =
        attachment.name.isNotEmpty ? attachment.name : 'Lampiran';
    final sizeText = _formatSize(attachment.size);
    return OutlinedButton.icon(
      onPressed: () => _openAttachment(attachment.url),
      icon: const Icon(Icons.attach_file, size: 18),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            sizeText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        alignment: Alignment.centerLeft,
        side: BorderSide(color: Colors.white.withOpacity(0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(2)} MB';
    }
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }

  Widget _kindChip(ThemeData theme, LeaveRequest request) {
    final isLeave = request.isLeave;
    final color = isLeave ? Colors.tealAccent : Colors.amberAccent;
    final label = isLeave ? 'Cuti' : 'Izin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _reasonBlock(ThemeData theme, String reason) {
    final text = reason.trim().isEmpty
        ? 'Tidak ada keterangan tambahan.'
        : reason.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarBadge(String text, ThemeData theme) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 88, 133, 255),
            Color.fromARGB(255, 140, 82, 255),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(60, 0, 0, 0),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text.substring(0, 1).toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String _formatRange(LeaveRequest request) {
    if (request.isLeave) {
      final start = _formatDate(request.startAt);
      final end = _formatDate(request.endAt);
      return start == end ? start : '$start - $end';
    }
    final date = _formatDate(request.startAt);
    final startTime = _formatTime(request.startAt);
    final endTime = _formatTime(request.endAt);
    return '$date • $startTime - $endTime';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatCreated(DateTime value) {
    return '${_formatDate(value)} • ${_formatTime(value)}';
  }

  String? _durationLabel(LeaveRequest request) {
    if (request.isLeave) {
      final raw = request.extra['daySpan'];
      int? span;
      if (raw is int) span = raw;
      if (raw is num) span = raw.toInt();
      span ??= request.endAt
              .difference(
                DateTime(
                  request.startAt.year,
                  request.startAt.month,
                  request.startAt.day,
                ),
              )
              .inDays +
          1;
      if (span != null && span > 0) return '$span hari';
      return null;
    }
    final minutes = request.endAt.difference(request.startAt).inMinutes;
    if (minutes <= 0) return null;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}j ${mins}m';
    if (hours > 0) return '${hours} jam';
    return '$mins menit';
  }
}

class _RequestCalendar extends StatelessWidget {
  const _RequestCalendar({
    required this.focusedMonth,
    required this.today,
    required this.selected,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime focusedMonth;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leadingEmpty = (firstDay.weekday + 6) % 7; // Monday first
    final totalCells = ((leadingEmpty + daysInMonth) / 7).ceil() * 7;
    final weekdayLabels = const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return GlassContainer(
      borderRadius: 26,
      blur: 22,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      gradientColors: const [
        Color.fromARGB(140, 18, 20, 36),
        Color.fromARGB(84, 11, 13, 28),
      ],
      borderColor: const Color.fromARGB(70, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(50, 6, 10, 30),
          offset: Offset(0, 20),
          blurRadius: 40,
          spreadRadius: -18,
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _formatMonth(focusedMonth),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: onToday,
                child: const Text('Hari ini'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayNumber = index - leadingEmpty + 1;
              final cellDate = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
              final isCurrentMonth = cellDate.month == focusedMonth.month;
              final isToday = _isSameDay(cellDate, today);
              final isSelected = selected != null && _isSameDay(cellDate, selected!);

              final backgroundColor = isSelected
                  ? theme.colorScheme.primary.withOpacity(0.22)
                  : isToday
                      ? theme.colorScheme.secondary.withOpacity(0.18)
                      : Colors.white.withOpacity(0.04);

              final borderColor = isSelected
                  ? theme.colorScheme.primary.withOpacity(0.6)
                  : isToday
                      ? theme.colorScheme.secondary.withOpacity(0.45)
                      : Colors.white.withOpacity(0.08);

              final textColor = isCurrentMonth
                  ? Colors.white
                  : Colors.white.withOpacity(0.38);

              return GestureDetector(
                onTap: () => onSelect(cellDate),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
                  ),
                  child: Center(
                    child: Text(
                      '${cellDate.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatMonth(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 18,
      blur: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gradientColors: const [
        Color.fromARGB(150, 18, 20, 36),
        Color.fromARGB(90, 11, 13, 28),
      ],
      borderColor: const Color.fromARGB(65, 255, 255, 255),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(45, 6, 10, 30),
          offset: Offset(0, 18),
          blurRadius: 36,
          spreadRadius: -16,
        ),
      ],
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          borderRadius: BorderRadius.circular(18),
          dropdownColor: const Color.fromARGB(220, 18, 20, 36),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          items: const ['Semua', 'Pending', 'Disetujui', 'Ditolak']
              .map(
                (status) =>
                    DropdownMenuItem(value: status, child: Text(status)),
              )
              .toList(),
        ),
      ),
    );
  }
}
