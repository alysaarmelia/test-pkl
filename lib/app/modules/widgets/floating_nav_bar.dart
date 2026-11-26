import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'android_nav_bar.dart';
import 'bottom_nav_constants.dart';
import 'ios_nav_bar.dart';

export 'bottom_nav_constants.dart';

/// Entry point navbar — pilih platform yang tepat.
/// iOS  → IosNavBar (CNTabBar native)
/// Android → AndroidNavBar (custom glass + gesture)
/// Web tidak didukung (sudah ada web admin terpisah).
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return IosNavBar(currentIndex: currentIndex, onTap: onTap);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidNavBar(currentIndex: currentIndex, onTap: onTap);
    }

    // Web / platform lain tidak didukung — kembalikan empty agar tidak error
    return const SizedBox.shrink();
  }
}
