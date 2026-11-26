import 'dart:ui';

import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.blur = 22,
    this.gradientColors,
    this.borderColor,
    this.boxShadow,
    this.fullWidth = false,
    this.constraints,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final bool fullWidth;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final defaultGradient = <Color>[
      Colors.white.withValues(alpha: 0.20),
      Colors.white.withValues(alpha: 0.06),
    ];
    final defaultShadow = <BoxShadow>[
      const BoxShadow(
        color: Color.fromARGB(28, 15, 23, 42),
        offset: Offset(0, 18),
        blurRadius: 40,
        spreadRadius: -12,
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: padding,
          constraints: constraints,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors ?? defaultGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.16),
            ),
            boxShadow: boxShadow ?? defaultShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassOrb extends StatelessWidget {
  const GlassOrb({super.key, required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            center: Alignment.center,
            radius: 0.92,
          ),
        ),
      ),
    );
  }
}
