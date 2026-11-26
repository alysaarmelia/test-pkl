import 'dart:ui';

import 'package:flutter/material.dart';

enum GlassSnackTone { info, success, warning, error }

Color _toneColor(GlassSnackTone tone) {
  switch (tone) {
    case GlassSnackTone.success:
      return const Color(0xFF2E7D32);
    case GlassSnackTone.warning:
      return const Color(0xFFED6C02);
    case GlassSnackTone.error:
      return const Color(0xFFC62828);
    case GlassSnackTone.info:
    default:
      return const Color(0xFF1565C0);
  }
}

IconData _toneIcon(GlassSnackTone tone) {
  switch (tone) {
    case GlassSnackTone.success:
      return Icons.check_circle_outline;
    case GlassSnackTone.warning:
      return Icons.warning_amber_rounded;
    case GlassSnackTone.error:
      return Icons.error_outline;
    case GlassSnackTone.info:
    default:
      return Icons.info_outline;
  }
}

void showGlassSnackBar(
  BuildContext context, {
  required String message,
  GlassSnackTone tone = GlassSnackTone.info,
  Duration duration = const Duration(seconds: 3),
  IconData? icon,
  bool dismissPrevious = true,
}) {
  if (context is! Element) return;
  final element = context as Element;
  if (!element.mounted) return;

  final scaffold = ScaffoldMessenger.maybeOf(element);
  if (scaffold == null) return;

  if (dismissPrevious) {
    scaffold.hideCurrentSnackBar();
  }

  final color = _toneColor(tone);
  final snackIcon = icon ?? _toneIcon(tone);
  const borderRadius = BorderRadius.all(Radius.circular(20));

  scaffold.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withAlpha(110), color.withAlpha(60)],
                ),
                border: Border.all(
                  color: Colors.white.withAlpha(70),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Icon(snackIcon, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
