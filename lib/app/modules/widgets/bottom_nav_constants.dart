import 'package:flutter/material.dart';

/// Konstanta index, ikon, dan label untuk bottom navigation bar.
/// Dipakai bersama oleh iOS dan Android navbar.
class BottomNav {
  static const int home = 0;
  static const int chat = 1;
  static const int calendar = 2;
  static const int profile = 3;
  static const int settings = 4;

  static IconData iconFor(int index) {
    switch (index) {
      case home:
        return Icons.home_outlined;
      case chat:
        return Icons.chat_bubble_outline;
      case calendar:
        return Icons.calendar_month_outlined;
      case profile:
        return Icons.person_outline;
      case settings:
        return Icons.settings_outlined;
      default:
        return Icons.home;
    }
  }

  static String labelFor(int index) {
    switch (index) {
      case home:
        return 'Home';
      case chat:
        return 'Chat';
      case calendar:
        return 'Kalender';
      case profile:
        return 'Profil';
      case settings:
        return 'Settings';
      default:
        return 'Home';
    }
  }
}
