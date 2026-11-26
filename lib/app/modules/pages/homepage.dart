import 'dart:async';

import 'package:cipta_vera_mandiri_digital/app/modules/home/controllers/home_controller.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/views/home_view.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/widgets/floating_nav_bar.dart';
import 'package:cipta_vera_mandiri_digital/repositories/homepage_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/homepage_view_model.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'calendar_page.dart';
import 'chat_list_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.repository});

  final HomePageRepository? repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomePageViewModel _viewModel;
  late final String _viewModelTag;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'home-page-${identityHashCode(this)}';
    _viewModel = Get.put(
      HomePageViewModel(repository: widget.repository),
      tag: _viewModelTag,
    );
    _viewModel.bindSessionExpiredHandler(() {
      if (!mounted) return;
      Get.offAllNamed(Routes.SPLASH);
    });
    _pages.addAll([
      HomeView(onMenuSelected: _handleNavTap, onLogout: _viewModel.logout),
      const ChatListPage(),
      const CalendarPage(),
      const ProfilePage(),
      SettingsPage(
        onMenuSelected: _handleNavTap,
        profileTabIndex: BottomNav.profile,
      ),
    ]);
  }

  @override
  void dispose() {
    if (Get.isRegistered<HomePageViewModel>(tag: _viewModelTag)) {
      Get.delete<HomePageViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  void _handleNavTap(int index) {
    _viewModel.setCurrentIndex(index);
    if (index == BottomNav.home && Get.isRegistered<HomeController>()) {
      unawaited(Get.find<HomeController>().refreshEvents());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomePageViewModel>(
      tag: _viewModelTag,
      builder: (viewModel) {
        // Deteksi jika ada pop-up atau rute lain di atas HomePage
        final bool isOverlayOpen =
            Get.isOverlaysOpen == true ||
            Get.isBottomSheetOpen == true ||
            Get.isDialogOpen == true;
        final bool isNotCurrentRoute =
            ModalRoute.of(context)?.isCurrent == false;
        final bool shouldHideGradients = isOverlayOpen || isNotCurrentRoute;

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              IndexedStack(index: viewModel.currentIndex, children: _pages),

              // ── Gradasi hitam di atas (Status bar area) ──
              _buildResponsiveGradient(
                top: 0,
                height: 140,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
                hidden: shouldHideGradients,
              ),

              // ── Gradasi hitam di bawah (Navigation bar area) ──
              _buildResponsiveGradient(
                bottom: 0,
                height: 160,
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 1.0],
                hidden: shouldHideGradients,
              ),
            ],
          ),
          bottomNavigationBar: shouldHideGradients
              ? const SizedBox.shrink()
              : CustomBottomNavBar(
                  currentIndex: viewModel.currentIndex,
                  onTap: _handleNavTap,
                ),
        );
      },
    );
  }

  /// Widget pembantu untuk membangun gradasi yang responsif terhadap pop-up
  Widget _buildResponsiveGradient({
    double? top,
    double? bottom,
    required double height,
    required AlignmentGeometry begin,
    required AlignmentGeometry end,
    required List<Color> colors,
    required List<double> stops,
    required bool hidden,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: hidden ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: colors,
                stops: stops,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
