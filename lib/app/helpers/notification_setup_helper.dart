import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// SETUP NOTIFIKASI DOKUMEN - PANDUAN LENGKAP
/// 
/// CARA KERJA:
/// 1. User upload dokumen + set tanggal kedaluwarsa + pilih reminder (30/60/90/180 hari)
/// 2. Sistem calculate kapan mulai mengingatkan = expiresAt - reminderInterval
/// 3. Dari tanggal mulai reminder sampai tanggal kedaluwarsa, sistem schedule notifikasi:
///    - JAM 00:00 (tengah malam)
///    - JAM 12:00 (siang hari)
///    SETIAP HARI tanpa terkecuali
/// 4. Total notifikasi = (jumlah hari × 2) - contoh 90 hari = 180 notifikasi
///
/// CONTOH:
/// - Dokumen kedaluwarsa: 31 Desember 2025
/// - Reminder dipilih: 90 hari
/// - Mulai notifikasi: 2 Oktober 2025 (= 31 Des - 90 hari)
/// - Notifikasi akan muncul SETIAP HARI dari 2 Oktober - 31 Desember (180 notifikasi)
///   * Jam 00:00 (tengah malam)
///   * Jam 12:00 (siang)
///
/// FIX YG SUDAH DILAKUKAN:
/// - Perbaikan logic scheduling di pemberkasan_page.dart
/// - Sekarang notifikasi PASTI muncul jam 00:00 dan 12:00 setiap hari
/// - Tidak ada hari yang terlewat (dulu ada bug dimana hanya hari pertama dan akhir yang di-schedule)

Future<bool> requestNotificationPermission() async {

  final status = await Permission.notification.request();
  
  if (status.isDenied) {
    print('❌ Notification permission denied');
    return false;
  }
  if (status.isPermanentlyDenied) {
    print('⚠️  Notification permission permanently denied - open Settings');
    // Buka app settings
    openAppSettings();
    return false;
  }
  if (status.isGranted) {
    print('✅ Notification permission granted');
    return true;
  }
  
  return false;
}

/// Verify notification setup dan settings
Future<void> verifyNotificationSetup() async {
  print('=== NOTIFICATION SETUP VERIFICATION ===');
  
  // 1. Check permission status
  final permissionStatus = await Permission.notification.status;
  print('1. Permission status: $permissionStatus');
  
  // 2. Check if notifications are enabled on device
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    final bool? result = await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    print('2. Notifications enabled on device: $result');
  } catch (e) {
    print('2. Could not check notification settings: $e');
  }
  
  print('=== END VERIFICATION ===');
}

Future<void> sendTestDocumentReminder() async {
  final plugin = FlutterLocalNotificationsPlugin();
  
  const androidDetails = AndroidNotificationDetails(
    'document_reminders',
    'Pengingat Dokumen',
    channelDescription: 'Test notification',
    importance: Importance.high,
    priority: Priority.high,
  );
  
  const darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  
  const details = NotificationDetails(
    android: androidDetails,
    iOS: darwinDetails,
  );
  
  try {
    await plugin.show(
      999, // ID unik
      '🔔 TEST: Pengingat Dokumen',
      'Ini test notification - jika Anda melihat ini, notif setup sudah benar!',
      details,
      payload: 'test_notification',
    );
    print('✅ Test notification sent');
  } catch (e) {
    print('❌ Failed to send test notification: $e');
  }
}

class NotificationStatusWidget extends StatefulWidget {
  const NotificationStatusWidget({Key? key}) : super(key: key);

  @override
  State<NotificationStatusWidget> createState() =>
      _NotificationStatusWidgetState();
}

class _NotificationStatusWidgetState extends State<NotificationStatusWidget> {
  PermissionStatus? _permissionStatus;
  bool? _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final permission = await Permission.notification.status;
    bool? enabled;
    
    try {
      enabled = await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    } catch (_) {}
    
    setState(() {
      _permissionStatus = permission;
      _notificationsEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification Status', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _StatusRow(
              label: 'Permission',
              status: _permissionStatus?.toString() ?? 'Checking...',
              isOk: _permissionStatus?.isGranted ?? false,
            ),
            const SizedBox(height: 8),
            if (_notificationsEnabled != null)
              _StatusRow(
                label: 'Device Notifications',
                status: _notificationsEnabled! ? 'Enabled' : 'Disabled',
                isOk: _notificationsEnabled!,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final granted = await requestNotificationPermission();
                    if (mounted && granted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Permission granted'),
                        ),
                      );
                      _checkStatus();
                    }
                  },
                  child: const Text('Request Permission'),
                ),
                ElevatedButton(
                  onPressed: sendTestDocumentReminder,
                  child: const Text('Send Test Notification'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.status,
    required this.isOk,
  });

  final String label;
  final String status;
  final bool isOk;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            Icon(
              isOk ? Icons.check_circle : Icons.cancel,
              color: isOk ? Colors.green : Colors.red,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(status),
          ],
        ),
      ],
    );
  }
}
