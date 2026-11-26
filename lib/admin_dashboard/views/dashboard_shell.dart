import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/admin_material_requests_page.dart';
import 'package:cipta_vera_mandiri_digital/admin_dashboard/services/admin_notification_service.dart';
import '../../app/widgets/glass_snack_bar.dart';
import '../widgets/glass.dart';
import '../widgets/glass_popup_menu.dart';
import 'widgets/welcome_overlay.dart';
import 'pages/attendance_page.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/attendance_window_repository.dart';
import 'pages/calendar_page.dart';
import 'pages/overview_page.dart';
import 'pages/request_page.dart';
import 'pages/documents_page.dart';
import 'pages/users_page.dart';
import 'pages/company_profiles_page.dart';
const Map<int, String?> _tabPermissionKeys = {
  0: null,
  1: 'attendance',
  2: 'requests',
  3: 'calendar',
  4: 'documents',
  5: 'material',
  6: 'users',
  7: 'companyProfile',
};
const List<String> _moduleRoleKeys = [
  'attendance',
  'requests',
  'calendar',
  'documents',
  'material',
  'users',
  'companyProfile',
];
class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key, required this.onLogout});
  final Future<void> Function() onLogout;
  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}
class _AdminNotificationsDialog extends StatefulWidget {
  const _AdminNotificationsDialog({
    required this.service,
    this.onNavigateToPage,
  });
  final AdminNotificationService service;
  final ValueChanged<int>? onNavigateToPage;
  @override
  State<_AdminNotificationsDialog> createState() =>
      _AdminNotificationsDialogState();
}
class _AdminNotificationsDialogState extends State<_AdminNotificationsDialog> {
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

  late NavigatorState _navigator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.service.markAllAsRead());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context);
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ValueListenableBuilder<List<AdminNotificationEntry>>(
        valueListenable: widget.service.notifications,
        builder: (context, entries, _) {
          final hasItems = entries.isNotEmpty;
          return GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
                minWidth: 340,
                maxHeight: 480,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Notifikasi',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (hasItems)
                        TextButton.icon(
                          onPressed: () {
                            unawaited(widget.service.clearAll());
                            if (_navigator.mounted) {
                              _navigator.pop();
                            }
                          },
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            size: 18,
                          ),
                          label: const Text('Hapus semua'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () {
                          if (_navigator.mounted) {
                            _navigator.pop();
                          }
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!hasItems)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white70,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada notifikasi',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pengajuan cuti, izin, atau material yang baru akan muncul di sini.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _buildEntryTile(context, entry);
                        },
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
  Widget _buildEntryTile(BuildContext context, AdminNotificationEntry entry) {
    final theme = Theme.of(context);
    final accent = _accentForType(entry.type);
    final background = entry.isRead
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.12);
    final borderColor = entry.isRead
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.26);
    return InkWell(
      onTap: () => _handleTap(entry),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
                border: Border.all(color: accent.withValues(alpha: 0.32)),
              ),
              child: Icon(_iconForType(entry.type), color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelative(entry.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.35,
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
  void _handleTap(AdminNotificationEntry entry) {
    unawaited(widget.service.markAsRead(entry.id));
    if (_navigator.mounted) {
      _navigator.pop();
    }
    final index = entry.targetPageIndex;
    if (index != null && widget.onNavigateToPage != null) {
      widget.onNavigateToPage!(index);
    }
  }
  Color _accentForType(AdminNotificationType type) {
    switch (type) {
      case AdminNotificationType.leave:
        return const Color(0xFF5C8DFF);
      case AdminNotificationType.permission:
        return const Color(0xFF4ED4B6);
      case AdminNotificationType.material:
        return const Color(0xFFFFB347);
      case AdminNotificationType.document:
        return const Color(0xFF8B5CF6);
    }
  }
  IconData _iconForType(AdminNotificationType type) {
    switch (type) {
      case AdminNotificationType.leave:
        return Icons.event_busy_rounded;
      case AdminNotificationType.permission:
        return Icons.assignment_turned_in_rounded;
      case AdminNotificationType.material:
        return Icons.inventory_2_rounded;
      case AdminNotificationType.document:
        return Icons.insert_drive_file_rounded;
    }
  }
  String _formatRelative(DateTime timestamp) {
    final now = DateTime.now();
    var difference = now.difference(timestamp);
    if (difference.isNegative) {
      difference = -difference;
    }
    if (difference.inSeconds < 60) return 'Baru saja';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    }
    if (difference.inDays == 1) return 'Kemarin';
    if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    }
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = _monthNames[timestamp.month - 1];
    return '$day $month ${timestamp.year}';
  }
}
class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _selectedIndex = 0;
  bool _showWelcomeOverlay = false;
  bool _welcomeInitialized = false;
  String _adminName = 'Admin';
  Timer? _welcomeTimer;
  final Map<String, _PresenceInfo> _presenceCache = <String, _PresenceInfo>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _presenceSubscription;
  Timer? _presenceTimer;
  final AttendanceWindowRepository _windowRepository =
      AttendanceWindowRepository();
  bool _attendanceWindowEnsured = false;
  int _activeEmployeeCount = 0;
  late final AdminNotificationService _notificationService;
  Map<String, dynamic> _currentRoles = <String, dynamic>{};
  bool _rolesLoaded = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roleSubscription;
  bool _initialPageResolved = false;
  final _titles = const [
    'Portal Admin',
    'Kehadiran',
    'Cuti & Izin',
    'Kalender',
    'Pemberkasan',
    'Permintaan Material',
    'Pengguna',
    'Company Profile',
  ];
  static const _presenceWindow = Duration(minutes: 2);
  @override
  void initState() {
    super.initState();
    _notificationService = AdminNotificationService();
    _notificationService.start();
    _listenToCurrentAdminRoles();
    _prepareWelcomeOverlay();
    _listenToOnlineEmployees();
    _ensureTodayAttendanceWindow();
  }
  void _listenToOnlineEmployees() {
    _presenceSubscription?.cancel();
    _presenceSubscription = FirebaseFirestore.instance
        .collection('users')
        .orderBy('lastSeen', descending: true)
        .limit(500)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          _presenceCache.clear();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final ts = data['lastSeen'];
            DateTime? lastSeen;
            if (ts is Timestamp) {
              lastSeen = ts.toDate();
            }
            final online = data['online'] == true;
            _presenceCache[doc.id] = _PresenceInfo(
              online: online,
              lastSeen: lastSeen,
            );
          }
          _recomputeActiveEmployees();
        });
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _recomputeActiveEmployees(),
    );
  }
  void _recomputeActiveEmployees() {
    final cutoff = DateTime.now().subtract(_presenceWindow);
    final count = _presenceCache.values.where((info) {
      final lastSeen = info.lastSeen;
      final activeByHeartbeat =
          lastSeen != null && lastSeen.isAfter(cutoff);
      final fallbackOnline = info.online && lastSeen == null;
      return activeByHeartbeat || fallbackOnline;
    }).length;
    if (!mounted) {
      _activeEmployeeCount = count;
      return;
    }
    if (_activeEmployeeCount != count) {
      setState(() => _activeEmployeeCount = count);
    }
  }
  Future<void> _ensureTodayAttendanceWindow() async {
    if (_attendanceWindowEnsured) return;
    _attendanceWindowEnsured = true;
    final now = DateTime.now();
    if (now.weekday == DateTime.sunday) {
      return;
    }
    final docId = AttendanceWindowRepository.docIdForDate(now);
    try {
      final holidayDoc = await FirebaseFirestore.instance
          .collection('holidays')
          .doc(docId)
          .get();
      final holidayData = holidayDoc.data();
      final isHoliday = holidayDoc.exists &&
          (holidayData?['isHoliday'] != false ||
              (holidayData?['name'] as String?)?.isNotEmpty == true);
      if (isHoliday) return;

      final existing = await _windowRepository.fetchWindow(now);
      if (existing != null) return;

      final openAt = DateTime(now.year, now.month, now.day, 8, 30);
      final closeAt = DateTime(now.year, now.month, now.day, 9, 30);
      await _windowRepository.setWindow(
        date: now,
        openAt: openAt,
        closeAt: closeAt,
      );
      debugPrint(
        'Auto-created attendance window for $docId (08:30-09:30 local).',
      );
    } catch (e, st) {
      debugPrint('Failed to ensure attendance window: $e');
      debugPrint(st.toString());
      _attendanceWindowEnsured = false;
    }
  }
  void _listenToCurrentAdminRoles() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _rolesLoaded = true;
        _currentRoles = <String, dynamic>{};
      });
      return;
    }
    _roleSubscription?.cancel();
    _roleSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          final roles = _extractRoles(data?['roles']);
          final shouldRedirect = !_canAccessTabWithRoles(roles, _selectedIndex);
          final fallbackIndex = _firstAccessibleIndex(roles);
          var targetIndex = _selectedIndex;
          if (!_initialPageResolved) {
            targetIndex = fallbackIndex;
          } else if (shouldRedirect && fallbackIndex != _selectedIndex) {
            targetIndex = fallbackIndex;
          }
          final superAdmin = _isSuperAdmin(roles);
          _notificationService.updateAccess(
            canListenLeave: superAdmin || roles['requests'] == true,
            canListenMaterial: superAdmin || roles['material'] == true,
          );
          if (!mounted) return;
          setState(() {
            _currentRoles = roles;
            _rolesLoaded = true;
            _selectedIndex = targetIndex;
            _initialPageResolved = true;
          });
        });
  }
  Map<String, dynamic> _extractRoles(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return <String, dynamic>{};
  }
  bool _isSuperAdmin(Map<String, dynamic> roles) =>
      roles['superAdmin'] == true || roles['admin'] == true;
  bool _hasAnyAdminRole(Map<String, dynamic> roles) =>
      _moduleRoleKeys.any((key) => roles[key] == true);
  bool _canAccessTab(int index) => _canAccessTabWithRoles(_currentRoles, index);
  bool _canAccessTabWithRoles(Map<String, dynamic> roles, int index) {
    final key = _tabPermissionKeys[index];
    if (key == null) {
      return _isSuperAdmin(roles);
    }
    if (_isSuperAdmin(roles)) return true;
    return roles[key] == true;
  }
  int _firstAccessibleIndex(Map<String, dynamic> roles) {
    final allowed = _moduleRoleKeys.where((key) => roles[key] == true).toList();
    if (allowed.isEmpty) {
      for (final entry in _tabPermissionKeys.entries) {
        if (_canAccessTabWithRoles(roles, entry.key)) {
          return entry.key;
        }
      }
      return 0;
    }
    allowed.sort((a, b) => _rolePriority(a).compareTo(_rolePriority(b)));
    final primaryKey = allowed.first;
    final targetEntry = _tabPermissionKeys.entries
        .firstWhere(
          (entry) => entry.value == primaryKey,
          orElse: () => const MapEntry(0, null),
        )
        .key;
    return targetEntry;
  }
  int _rolePriority(String key) {
    const priorityOrder = [
      'attendance',
      'requests',
      'calendar',
      'documents',
      'companyProfile',
      'material',
      'users',
    ];
    final index = priorityOrder.indexOf(key);
    return index == -1 ? 999 : index;
  }
  void _handlePageNavigation(int index) {
    if (!_rolesLoaded) {
      setState(() => _selectedIndex = index);
      return;
    }
    if (!_canAccessTab(index)) {
      if (index >= 0 && index < _titles.length) {
        _showRestrictedMessage(_titles[index]);
      }
      return;
    }
    if (_selectedIndex != index) {
      setState(() {
        _initialPageResolved = true;
        _selectedIndex = index;
      });
    }
  }
  void _showRestrictedMessage(String moduleTitle) {
    showGlassSnackBar(
      context,
      message:
          'Akses ke "$moduleTitle" dibatasi. Hubungi Super Admin untuk memberi izin.',
      tone: GlassSnackTone.warning,
    );
  }
  Widget _buildPageContent(int index) {
    if (!_rolesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_canAccessTab(index)) {
      final title = (index >= 0 && index < _titles.length)
          ? _titles[index]
          : 'menu ini';
      return _AccessDeniedView(moduleName: title);
    }
    switch (index) {
      case 0:
        return const OverviewPage();
      case 1:
        return const AttendancePage();
      case 2:
        return const RequestManagementPage();
      case 3:
        return const CalendarPage();
      case 4:
        return const DocumentsPage();
      case 5:
        return const AdminMaterialRequestsPage();
      case 6:
        return const UsersPage();
      case 7:
        return const CompanyProfilesPage();
      default:
        return const OverviewPage();
    }
  }
  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _presenceSubscription?.cancel();
    _presenceTimer?.cancel();
    _roleSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF070B1C), Color(0xFF101B3A), Color(0xFF162245)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -120,
              left: -90,
              child: GlassOrb(
                size: 340,
                colors: [
                  Color.fromARGB(72, 120, 162, 255),
                  Color.fromARGB(34, 212, 239, 255),
                ],
              ),
            ),
            const Positioned(
              bottom: -170,
              right: -60,
              child: GlassOrb(
                size: 440,
                colors: [
                  Color.fromARGB(55, 255, 118, 118),
                  Color.fromARGB(28, 255, 216, 175),
                ],
              ),
            ),
            const Positioned(
              top: 140,
              right: -90,
              child: GlassOrb(
                size: 260,
                colors: [
                  Color.fromARGB(48, 123, 255, 214),
                  Color.fromARGB(28, 123, 197, 255),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 1180;
                final horizontalPadding = wide ? 32.0 : 20.0;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 26,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SideNav(
                        extended: wide,
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _handlePageNavigation,
                        activeEmployeeCount: _activeEmployeeCount,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _TopBar(
                              title: _titles[_selectedIndex],
                              onLogout: widget.onLogout,
                              notificationService: _notificationService,
                              onNavigateToPage: _handlePageNavigation,
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.015, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: KeyedSubtree(
                                  key: ValueKey(_selectedIndex),
                                  child: GlassContainer(
                                    borderRadius: 32,
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      18,
                                      24,
                                      28,
                                    ),
                                    child: _buildPageContent(_selectedIndex),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_showWelcomeOverlay)
              Positioned.fill(
                child: WelcomeOverlay(
                  key: const ValueKey('welcome-overlay'),
                  name: _adminName,
                  onDismiss: _dismissWelcome,
                ),
              ),
          ],
        ),
      ),
    );
  }
  Future<void> _prepareWelcomeOverlay() async {
    if (_welcomeInitialized) return;
    _welcomeInitialized = true;
    final user = FirebaseAuth.instance.currentUser;
    var resolvedName = _deriveName(
      primary: user?.displayName,
      fallbackEmail: user?.email,
    );
    if (!mounted) return;
    setState(() {
      _adminName = resolvedName;
      _showWelcomeOverlay = true;
    });
    _welcomeTimer?.cancel();
    _welcomeTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _showWelcomeOverlay = false);
    });
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        final docName = data?['name'];
        final refinedName = _deriveName(
          primary: docName,
          fallbackEmail: user.email,
        );
        if (!mounted) return;
        if (refinedName != _adminName) {
          setState(() {
            _adminName = refinedName;
          });
        }
      } catch (_) {
        // Ignore failures; fallback name already set.
      }
    }
  }
  void _dismissWelcome() {
    if (!_showWelcomeOverlay) return;
    _welcomeTimer?.cancel();
    if (!mounted) return;
    setState(() => _showWelcomeOverlay = false);
  }
  String _deriveName({dynamic primary, String? fallbackEmail}) {
    if (primary is String) {
      final cleaned = primary.trim();
      if (cleaned.isNotEmpty && cleaned.toLowerCase() != 'null') {
        return _beautifyName(cleaned);
      }
    }
    if (fallbackEmail != null && fallbackEmail.isNotEmpty) {
      final prefix = fallbackEmail.split('@').first;
      return _beautifyName(prefix);
    }
    return 'Admin';
  }
  String _beautifyName(String raw) {
    final normalized = raw
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return 'Admin';
    final buffer = <String>[];
    for (final part in normalized.split(' ')) {
      if (part.isEmpty) continue;
      final lower = part.toLowerCase();
      final capitalized = lower[0].toUpperCase() + lower.substring(1);
      buffer.add(capitalized);
    }
    return buffer.isEmpty ? 'Admin' : buffer.join(' ');
  }
}

class _PresenceInfo {
  const _PresenceInfo({required this.online, this.lastSeen});
  final bool online;
  final DateTime? lastSeen;
}
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.extended,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.activeEmployeeCount,
  });
  final bool extended;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int activeEmployeeCount;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baseText = scheme.brightness == Brightness.dark
        ? Colors.white
        : scheme.onSurface;
    final subtleText = baseText.withValues(alpha: 0.65);
    return SizedBox(
      width: extended ? 264 : 96,
      child: GlassContainer(
        borderRadius: 32,
        blur: 28,
        gradientColors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.06),
        ],
        borderColor: Colors.white.withValues(alpha: 0.22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(28, 15, 23, 42),
            offset: Offset(0, 18),
            blurRadius: 40,
            spreadRadius: -12,
          ),
        ],
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: extended ? 26 : 20),
            child: Column(
              crossAxisAlignment: extended
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'lib/app/assets/images/cvm.png',
                          height: 44,
                          width: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (extended) ...[
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CIPTA VERA ADMIN',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: baseText,
                                ),
                              ),
                              Text(
                                'Dashboard kontrol',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: subtleText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    extended: extended,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    indicatorColor: Colors.white.withValues(alpha: 0.22),
                    labelType: extended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.selected,
                    selectedLabelTextStyle: theme.textTheme.bodyMedium
                        ?.copyWith(
                          color: baseText,
                          fontWeight: FontWeight.w600,
                        ),
                    unselectedLabelTextStyle: theme.textTheme.bodySmall
                        ?.copyWith(color: subtleText),
                    selectedIconTheme: IconThemeData(
                      color: baseText,
                      size: extended ? 26 : 24,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: subtleText,
                      size: extended ? 24 : 22,
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.auto_graph_outlined),
                        selectedIcon: Icon(Icons.auto_graph),
                        label: Text('Portal'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.how_to_reg_outlined),
                        selectedIcon: Icon(Icons.how_to_reg),
                        label: Text('Absensi'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.assignment_ind_outlined),
                        selectedIcon: Icon(Icons.assignment_ind),
                        label: Text('Cuti & Izin'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: Text('Kalender'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.folder_shared_outlined),
                        selectedIcon: Icon(Icons.folder_shared),
                        label: Text('Pemberkasan'),
                      ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_outlined),
                      selectedIcon: Icon(Icons.inventory),
                      label: Text('Material'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt),
                      label: Text('Pengguna'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.web_asset_outlined),
                      selectedIcon: Icon(Icons.web_asset),
                      label: Text('Company Profile'),
                    ),
                  ],
                ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                  child: Column(
                    crossAxisAlignment: extended
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      if (extended)
                        Text(
                          'Total Karyawan',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: extended
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Text(
                            activeEmployeeCount.toString(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: baseText,
                            ),
                          ),
                          if (extended)
                            Text(
                              ' aktif',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: subtleText,
                              ),
                            ),
                        ],
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
}
class _AccessDeniedView extends StatelessWidget {
  const _AccessDeniedView({required this.moduleName});
  final String moduleName;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = Colors.white.withOpacity(0.7);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(Icons.lock_outline, color: subtle, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            'Akses terbatas',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 420,
            child: Text(
              'Menu $moduleName hanya tersedia untuk admin yang telah diberi izin oleh Super Admin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: subtle,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onLogout,
    required this.notificationService,
    this.onNavigateToPage,
  });
  final String title;
  final Future<void> Function() onLogout;
  final AdminNotificationService notificationService;
  final ValueChanged<int>? onNavigateToPage;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baseText = scheme.brightness == Brightness.dark
        ? Colors.white
        : scheme.onSurface;
    final subtleText = baseText.withValues(alpha: 0.7);
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'admin@cvmd.id';
    final uid = user?.uid;
    final authDisplayName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (email.contains('@') ? email.split('@').first : email);
    final authPhotoUrl = user?.photoURL ?? '';
    return GlassContainer(
      borderRadius: 28,
      blur: 24,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        height: 82,
        child: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: baseText,
              ),
            ),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: TextField(
                style: theme.textTheme.bodyMedium?.copyWith(color: baseText),
                cursorColor: baseText,
                decoration: InputDecoration(
                  hintText: 'Cari menu atau karyawan',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: subtleText,
                  ),
                  prefixIcon: Icon(Icons.search, color: subtleText),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.26),
                    ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            ValueListenableBuilder<int>(
              valueListenable: notificationService.unreadCount,
              builder: (context, unread, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notifikasi',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                      ),
                      onPressed: () => _openNotifications(context),
                      icon: Icon(
                        unread > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: subtleText,
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: uid != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .snapshots()
                  : Stream<DocumentSnapshot<Map<String, dynamic>>>.empty(),
              builder: (context, snapshot) {
                String? clean(dynamic value) {
                  if (value is String) {
                    final trimmed = value.trim();
                    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
                      return null;
                    }
                    return trimmed;
                  }
                  return null;
                }
                final data = snapshot.data?.data();
                final docUsername = clean(data?['username']);
                final docName = clean(data?['name']);
                final docFullName = clean(data?['fullName']);
                final docEmail = clean(data?['email']);
                final docPhotoUrl = clean(data?['photoUrl']);
                final resolvedDisplayName =
                    docUsername ?? docName ?? docFullName ?? authDisplayName;
                final resolvedEmail = docEmail ?? email;
                final resolvedPhotoUrl =
                    (docPhotoUrl != null && docPhotoUrl.isNotEmpty)
                    ? docPhotoUrl
                    : authPhotoUrl;
                final resolvedInitials = resolvedDisplayName.trim().isNotEmpty
                    ? resolvedDisplayName
                          .trim()
                          .split(RegExp(r'\s+'))
                          .take(2)
                          .map((e) => e[0])
                          .join()
                          .toUpperCase()
                    : 'AD';
                Future<String?> resolvePhotoUrl() async {
                  if (resolvedPhotoUrl.isEmpty) return null;
                  if (resolvedPhotoUrl.startsWith('http')) {
                    return resolvedPhotoUrl;
                  }
                  try {
                    return await FirebaseStorage.instance
                        .ref(resolvedPhotoUrl)
                        .getDownloadURL();
                  } catch (_) {
                    return null;
                  }
                }
                return FutureBuilder<String?>(
                  future: resolvePhotoUrl(),
                  builder: (context, photoSnapshot) {
                    return PopupMenuButton<String>(
                      tooltip: 'Akun admin',
                      offset: const Offset(0, 12),
                      color: Colors.transparent,
                      elevation: 0,
                      onSelected: (value) {
                        if (value == 'logout') {
                          unawaited(_confirmLogout(context));
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          enabled: false,
                          padding: EdgeInsets.zero,
                          child: GlassPopupMenuEntry<String>(
                            height: 78,
                            textColor: Colors.white,
                            iconColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Text(
                                    resolvedInitials,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        resolvedDisplayName,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        resolvedEmail,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const PopupMenuDivider(height: 6),
                        PopupMenuItem<String>(
                          value: 'logout',
                          padding: EdgeInsets.zero,
                          child: GlassPopupMenuEntry<String>(
                            textColor: Colors.white,
                            iconColor: Colors.redAccent,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.logout),
                                const SizedBox(width: 12),
                                Text('Keluar'),
                              ],
                            ),
                          ),
                        ),
                      ],
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        child: Text(
                          resolvedInitials,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: baseText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.38),
          builder: (dialogContext) {
            return _LogoutConfirmationDialog(
              onConfirm: () => Navigator.of(dialogContext).pop(true),
              onCancel: () => Navigator.of(dialogContext).pop(false),
            );
          },
        ) ??
        false;
    if (!shouldLogout) return;
    try {
      await onLogout();
    } catch (e, st) {
      debugPrint('Failed to logout: $e');
      debugPrint(st.toString());
      if (!context.mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal logout. Silakan coba lagi.',
        tone: GlassSnackTone.error,
      );
    }
  }
  Future<void> _openNotifications(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        return _AdminNotificationsDialog(
          service: notificationService,
          onNavigateToPage: onNavigateToPage,
        );
      },
    );
  }
}
class _LogoutConfirmationDialog extends StatelessWidget {
  const _LogoutConfirmationDialog({
    required this.onConfirm,
    required this.onCancel,
  });
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = Colors.white.withValues(alpha: 0.74);
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 360,
            minWidth: 260,
          ),
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.32),
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Keluar dari portal?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Anda akan keluar dari portal admin. Pastikan perubahan sudah disimpan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtle,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Keluar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
