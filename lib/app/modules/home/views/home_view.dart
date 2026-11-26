import 'dart:async';

import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_header.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/menu_grid.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/news_section.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/profile_card.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/upcoming_events_section.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeView extends StatelessWidget {
  final void Function(int) onMenuSelected;
  final Future<void> Function() onLogout;

  const HomeView({
    super.key,
    required this.onMenuSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    Get.find<HomeController>();
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: HomeGlassTheme.backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            HomeGlassTheme.orb(
              top: -120,
              left: -80,
              diameter: 320,
              colors: HomeGlassTheme.orbBlue,
            ),
            HomeGlassTheme.orb(
              top: 180,
              right: -140,
              diameter: 360,
              colors: HomeGlassTheme.orbPurple,
            ),
            HomeGlassTheme.orb(
              bottom: -180,
              left: 40,
              diameter: 420,
              colors: HomeGlassTheme.orbMint,
            ),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeader(
                      onLogout: () {
                        unawaited(onLogout());
                      },
                    ),
                    const ProfileCard(),
                    const SizedBox(height: 24),
                    MenuGrid(onMenuSelected: onMenuSelected),
                    const SizedBox(height: 16),
                    const NewsSection(),
                    const SizedBox(height: 16),
                    UpcomingEventsSection(onMenuSelected: onMenuSelected),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
