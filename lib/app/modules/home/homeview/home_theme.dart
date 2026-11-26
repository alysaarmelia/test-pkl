import 'package:flutter/material.dart';

class HomeGlassTheme {
  const HomeGlassTheme._();

  static const List<Color> backgroundGradient = <Color>[
    Color(0xFF101529),
    Color(0xFF1C2844),
  ];

  static const Color surfaceStrong = Color.fromRGBO(255, 255, 255, 0.18);
  static const Color surfaceSoft = Color.fromRGBO(255, 255, 255, 0.12);
  static const Color surfaceBorder = Color.fromRGBO(255, 255, 255, 0.35);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color.fromRGBO(255, 255, 255, 0.74);

  static const List<Color> orbBlue = <Color>[
    Color.fromRGBO(82, 148, 255, 0.38),
    Color.fromRGBO(82, 148, 255, 0),
  ];
  static const List<Color> orbPurple = <Color>[
    Color.fromRGBO(141, 83, 255, 0.32),
    Color.fromRGBO(141, 83, 255, 0),
  ];
  static const List<Color> orbMint = <Color>[
    Color.fromRGBO(72, 233, 205, 0.26),
    Color.fromRGBO(72, 233, 205, 0),
  ];

  static Widget background({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: backgroundGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const _GlassBackgroundLayer(),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  static Widget orb({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double diameter,
    required List<Color> colors,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors, stops: const [0.0, 1.0]),
          ),
        ),
      ),
    );
  }
}

class _GlassBackgroundLayer extends StatelessWidget {
  const _GlassBackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
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
        ],
      ),
    );
  }
}
