import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'bottom_nav_constants.dart';

class IosNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const IosNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 110 + bottomInset,
      child: Stack(
        children: [
          // ── CNTabBar native, mentok ke bawah ──
          Positioned(
            left: 10,
            right: 10,
            bottom: 0,
            child: CNTabBar(
              backgroundColor: Colors.transparent,
              tint: const Color(0xFF48D9F3),
              currentIndex: currentIndex,
              onTap: onTap ?? (i) {},
              items: const [
                CNTabBarItem(icon: CNSymbol('house'), label: 'Home'),
                CNTabBarItem(
                  icon: CNSymbol('bubble.left.and.bubble.right'),
                  label: 'Chat',
                ),
                CNTabBarItem(icon: CNSymbol('calendar'), label: 'Kalender'),
                CNTabBarItem(
                  icon: CNSymbol('person.crop.circle'),
                  label: 'Profil',
                ),
                CNTabBarItem(icon: CNSymbol('gearshape'), label: 'Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
