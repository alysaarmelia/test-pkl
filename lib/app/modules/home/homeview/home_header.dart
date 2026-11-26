import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/app_notification_service.dart';
import 'home_theme.dart';
import 'calendar_notifications_page.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback onLogout;
  HomeHeader({super.key, required this.onLogout});

  final AppNotificationService _notificationService = AppNotificationService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('lib/app/assets/images/cvm.png', height: 38),
                const SizedBox(width: 5),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HomeGlassTheme.textPrimary,
                    ),
                    children: [
                      TextSpan(text: 'CIPTA '),
                      TextSpan(
                        text: 'VERA',
                        style: TextStyle(color: Color(0xFF66D5FF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Obx(() {
                  final unread = _notificationService.unreadCount.value;
                  final hasUnread = unread > 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _GlassIconButton(
                        icon: Icons.notifications_none,
                        onTap: () {
                          Get.to(() => const CalendarNotificationsPage());
                        },
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF7A88), Color(0xFFFF4D6D)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: HomeGlassTheme.surfaceBorder,
                                width: 0.8,
                              ),
                            ),
                            constraints: const BoxConstraints(minWidth: 18),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(width: 10),
                _GlassIconButton(icon: Icons.logout, onTap: onLogout),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: HomeGlassTheme.surfaceSoft,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: const Color.fromARGB(20, 255, 255, 255),
            highlightColor: const Color.fromARGB(12, 255, 255, 255),
            child: SizedBox(
              height: 44,
              width: 44,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
