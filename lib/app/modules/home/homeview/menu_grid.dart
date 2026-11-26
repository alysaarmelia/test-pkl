import 'dart:ui';

import 'package:cipta_vera_mandiri_digital/absensi/absen.dart';
import 'package:cipta_vera_mandiri_digital/absensi/bindings/attendance_binding.dart';
import 'package:cipta_vera_mandiri_digital/absensi/cuti.dart';
import 'package:cipta_vera_mandiri_digital/absensi/izin.dart';
import 'package:cipta_vera_mandiri_digital/absensi/riwayat_absen.dart';
import 'package:flutter/material.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/pemberkasan_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/material_request_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/material_request_tracking_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/menu_grid_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/menu_grid_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:get/get.dart';
import 'home_theme.dart';

class MenuGrid extends StatefulWidget {
  final void Function(int) onMenuSelected;
  final MenuGridRepository? repository;
  final MenuGridViewModel? viewModel;

  const MenuGrid({
    super.key,
    required this.onMenuSelected,
    this.repository,
    this.viewModel,
  });

  @override
  State<MenuGrid> createState() => _MenuGridState();
}

class _MenuGridState extends State<MenuGrid> {
  late final MenuGridViewModel _viewModel;
  late final String _viewModelTag;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'menu-grid-${identityHashCode(this)}';
    _viewModel = Get.put(
      widget.viewModel ?? MenuGridViewModel(repository: widget.repository),
      tag: _viewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<MenuGridViewModel>(tag: _viewModelTag)) {
      Get.delete<MenuGridViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  void _guardedNavigation({
    required BuildContext context,
    required bool allowed,
    required VoidCallback onAllowed,
    String? deniedMessage,
  }) {
    if (allowed) {
      onAllowed();
      return;
    }
    showGlassSnackBar(
      context,
      message: deniedMessage ?? 'Akses dibatasi untuk fitur ini.',
      tone: GlassSnackTone.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MenuGridAccessState>(
      stream: _viewModel.stateStream,
      initialData: _viewModel.state,
      builder: (context, snapshot) {
        final accessState = snapshot.data ?? _viewModel.state;
        final canAccessMaterial = accessState.canAccessMaterial;
        final canAccessPemberkasan = accessState.canAccessPemberkasan;

        return GridView.count(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          crossAxisCount: 4,
          childAspectRatio: 1.1,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Absen Kehadiran
            GestureDetector(
              onTap: () {
                Get.to(
                  () => const AttendancePage(),
                  binding: AttendanceBinding(),
                );
              },
              child: _MenuIcon(
                icon: Icons.fingerprint,
                label: 'Absen',
                color: Colors.green[400]!,
              ),
            ),
            // Cuti
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeavePage()),
                );
              },
              child: _MenuIcon(
                icon: Icons.beach_access,
                label: 'Cuti',
                color: Colors.orange[400]!,
              ),
            ),
            // Izin
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PermissionPage()),
                );
              },
              child: _MenuIcon(
                icon: Icons.assignment_turned_in,
                label: 'Izin',
                color: Colors.purple[400]!,
              ),
            ),
            // (Absen Pulang dihapus sesuai request)
            // Riwayat Absen
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceHistoryPage(),
                  ),
                );
              },
              child: _MenuIcon(
                icon: Icons.history,
                label: 'Riwayat',
                color: Colors.brown[400]!,
              ),
            ),
            // Kalender
            GestureDetector(
              onTap: () {
                widget.onMenuSelected(2);
              },
              child: _MenuIcon(
                icon: Icons.calendar_today,
                label: 'Kalender',
                color: Colors.blue[300]!,
              ),
            ),
            // Pemberkasan
            GestureDetector(
              onTap: () {
                _guardedNavigation(
                  context: context,
                  allowed: canAccessPemberkasan,
                  deniedMessage:
                      'Akses Pemberkasan hanya untuk ${MenuGridViewModel.allowedPemberkasanLabel}',
                  onAllowed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PemberkasanPage(),
                      ),
                    );
                  },
                );
              },
              child: _MenuIcon(
                icon: Icons.insert_drive_file,
                label: 'Pemberkasan',
                color: Colors.grey[400]!,
                enabled: canAccessPemberkasan,
              ),
            ),
            // Permintaan Material
            GestureDetector(
              onTap: () {
                _guardedNavigation(
                  context: context,
                  allowed: canAccessMaterial,
                  deniedMessage:
                      'Akses hanya untuk ${MenuGridViewModel.allowedMaterialLabel}',
                  onAllowed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaterialRequestPage(),
                      ),
                    );
                  },
                );
              },
              child: _MenuIcon(
                icon: Icons.shopping_cart,
                label: 'Material',
                color: Colors.red[300]!,
                enabled: canAccessMaterial,
              ),
            ),
            // Tracking Material
            GestureDetector(
              onTap: () {
                _guardedNavigation(
                  context: context,
                  allowed: canAccessMaterial,
                  deniedMessage:
                      'Akses hanya untuk ${MenuGridViewModel.allowedMaterialLabel}',
                  onAllowed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaterialRequestTrackingPage(),
                      ),
                    );
                  },
                );
              },
              child: _MenuIcon(
                icon: Icons.track_changes,
                label: 'Tracking',
                color: Colors.indigo[400]!,
                enabled: canAccessMaterial,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;

  const _MenuIcon({
    required this.icon,
    required this.label,
    required this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = enabled
        ? HomeGlassTheme.textSecondary
        : HomeGlassTheme.textSecondary.withValues(alpha: 0.55);
    final fgColor = enabled ? Colors.white : Colors.white.withValues(alpha: 0.6);
    final gradientStart = color.withAlpha(
      (((enabled ? 0.72 : 0.28) * 255)).round(),
    );
    final gradientEnd = color.withAlpha(
      (((enabled ? 0.38 : 0.18) * 255)).round(),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradientStart, gradientEnd],
                ),
                border: Border.all(
                  color: HomeGlassTheme.surfaceBorder,
                  width: 1,
                ),
              ),
              child: Icon(icon, color: fgColor, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
