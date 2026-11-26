import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/app_notification_service.dart';
import 'home_theme.dart';

class CalendarNotificationsPage extends StatefulWidget {
  const CalendarNotificationsPage({super.key});

  @override
  State<CalendarNotificationsPage> createState() =>
      _CalendarNotificationsPageState();
}

class _CalendarNotificationsPageState extends State<CalendarNotificationsPage> {
  final AppNotificationService _service = AppNotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Notifikasi'),
        centerTitle: true,
        actions: [
          Obx(() {
            final unread = _service.unreadCount.value;
            if (unread <= 0) {
              return const SizedBox.shrink();
            }
            return TextButton(
              onPressed: () => _service.markAllAsRead(),
              child: const Text(
                'Tandai selesai',
                style: TextStyle(color: Colors.white),
              ),
            );
          }),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101529), Color(0xFF1C2844)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Obx(() {
              final items = _service.notifications;
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color.fromRGBO(255, 255, 255, 0.08),
                          border: Border.all(
                            color: const Color.fromRGBO(255, 255, 255, 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 32,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Belum ada notifikasi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Notifikasi akan muncul di sini ketika ada aktivitas terbaru.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.redAccent.withOpacity(0.75),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _service.removeNotification(item.id),
                    child: _NotificationTile(entry: item),
                  );
                },
              );
            }),
          ),
        ),
      ),
      floatingActionButton: Obx(() {
        final hasItems = _service.notifications.isNotEmpty;
        if (!hasItems) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          backgroundColor: const Color.fromRGBO(255, 255, 255, 0.18),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.delete_sweep_rounded),
          label: const Text('Bersihkan semua'),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                return _GlassConfirmDialog(
                  onCancel: () => Navigator.of(ctx).pop(false),
                  onConfirm: () => Navigator.of(ctx).pop(true),
                );
              },
            );
            if (confirm == true) {
              await _service.clearNotifications();
            }
          },
        );
      }),
    );
  }
}

class _GlassConfirmDialog extends StatelessWidget {
  const _GlassConfirmDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: HomeGlassTheme.surfaceStrong,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: HomeGlassTheme.surfaceBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(4, 12, 28, 0.34),
                  offset: Offset(0, 20),
                  blurRadius: 42,
                  spreadRadius: -16,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hapus semua notifikasi?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Daftar notifikasi akan dikosongkan. Tindakan ini tidak dapat dibatalkan.',
                    style: TextStyle(
                      color: HomeGlassTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: HomeGlassTheme.textSecondary,
                        ),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: onConfirm,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          backgroundColor:
                              const Color.fromRGBO(255, 77, 77, 0.32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: Color.fromRGBO(255, 77, 77, 0.55),
                            ),
                          ),
                        ),
                        child: const Text('Hapus'),
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
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.entry});

  final AppNotificationEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !entry.isRead;
    final icon = _iconForType(entry.type);
    final accent = _accentForType(entry.type);
    final subtitle = _subtitleForEntry(entry);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnread
              ? const Color.fromRGBO(255, 255, 255, 0.45)
              : const Color.fromRGBO(255, 255, 255, 0.28),
        ),
        color: isUnread
            ? const Color.fromRGBO(255, 255, 255, 0.22)
            : const Color.fromRGBO(255, 255, 255, 0.16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.18),
            offset: Offset(0, 18),
            blurRadius: 38,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.18),
                  border: Border.all(color: accent.withOpacity(0.45)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color.fromRGBO(255, 255, 255, 0.92),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A7A), Color(0xFFFF4D4D)],
                    ),
                  ),
                  child: const Text(
                    'Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color.fromRGBO(255, 255, 255, 0.18),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.32),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color.fromRGBO(255, 255, 255, 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.calendar:
        return Icons.event_rounded;
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

  Color _accentForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.calendar:
        return const Color(0xFF66D5FF);
      case AppNotificationType.attendance:
        return const Color(0xFF7CFF8F);
      case AppNotificationType.leave:
        return const Color(0xFFFFB14C);
      case AppNotificationType.material:
        return const Color(0xFFFF7A88);
      case AppNotificationType.document:
        return const Color(0xFFB28DFF);
      case AppNotificationType.general:
        return const Color(0xFF9AD0FF);
    }
  }

  String _subtitleForEntry(AppNotificationEntry entry) {
    final timestampText = _formatTimestamp(entry.timestamp);
    if (entry.type == AppNotificationType.calendar) {
      final eventDateRaw = entry.data['eventDate'];
      final eventDate = eventDateRaw is String
          ? DateTime.tryParse(eventDateRaw)?.toLocal()
          : null;
      if (eventDate != null) {
        return '${_formatCalendarDate(eventDate)} • $timestampText';
      }
    }
    return timestampText;
  }

  String _formatCalendarDate(DateTime date) {
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
    final local = date.toLocal();
    final month = months[(local.month - 1).clamp(0, months.length - 1)];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month ${local.year} $hour:$minute';
  }

  String _formatTimestamp(DateTime value) {
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
    final local = value.toLocal();
    final month = months[(local.month - 1).clamp(0, months.length - 1)];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month ${local.year} $hour:$minute';
  }
}
