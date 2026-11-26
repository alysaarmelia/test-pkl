import 'dart:ui';

import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
    this.padding,
    this.opacity = 0.28,
    this.enableBlur = false,
    this.gradient,
    this.borderOpacity,
    this.shadows,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double opacity;
  final bool enableBlur;
  final Gradient? gradient;
  final double? borderOpacity;
  final List<BoxShadow>? shadows;

  static final ImageFilter _defaultBlur = ImageFilter.blur(
    sigmaX: 12,
    sigmaY: 12,
  );

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = Colors.white.withOpacity(
      opacity.clamp(0.0, 1.0),
    );
    final Color borderColor = Colors.white.withOpacity(
      borderOpacity ?? (opacity + 0.15).clamp(0.0, 1.0),
    );

    Widget surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? surfaceColor : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1),
        boxShadow:
            shadows ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(enableBlur ? 0.20 : 0.10),
                blurRadius: 22,
                offset: const Offset(0, 16),
              ),
            ],
      ),
      child: child,
    );

    if (enableBlur) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(filter: _defaultBlur, child: surface),
      );
    } else {
      surface = ClipRRect(borderRadius: borderRadius, child: surface);
    }

    return RepaintBoundary(child: surface);
  }
}
