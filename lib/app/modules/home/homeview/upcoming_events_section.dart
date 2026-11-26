import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/controllers/home_controller.dart';
import 'home_theme.dart';
// sesuaikan path model Event

class UpcomingEventsSection extends StatelessWidget {
  final void Function(int) onMenuSelected;
  const UpcomingEventsSection({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Acara Mendatang',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: HomeGlassTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                onMenuSelected(2);
              },
              style: TextButton.styleFrom(
                foregroundColor: HomeGlassTheme.textSecondary,
              ),
              child: const Text('Lihat Kalender'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(() {
          final data = controller.upcomingEvents;
          if (data.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: const Center(
                child: Text(
                  'Tidak ada acara mendatang',
                  style: TextStyle(
                    color: HomeGlassTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            );
          } else {
            return _buildEventsList(data);
          }
        }),
      ],
    );
  }

  Widget _buildEventsList(List<Event> data) {
    return Column(
      children: data.map((event) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: HomeGlassTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: HomeGlassTheme.surfaceBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4C6CFF), Color(0xFF7B8CFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${event.date.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _bulan(event.date.month),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: HomeGlassTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final parts = [
                              event.time.trim(),
                              event.location.trim(),
                            ].where((value) => value.isNotEmpty).toList();
                            final details = parts.join('\n');
                            return Text(
                              details.isEmpty ? '-' : details,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: HomeGlassTheme.textSecondary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

String _bulan(int bulan) {
  const bulanStr = [
    '',
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
  if (bulan >= 1 && bulan <= 12) {
    return bulanStr[bulan];
  }
  return '';
}
