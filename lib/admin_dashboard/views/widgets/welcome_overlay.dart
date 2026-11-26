import 'dart:math' as math;

import 'package:flutter/material.dart';

class WelcomeOverlay extends StatefulWidget {
  const WelcomeOverlay({
    super.key,
    required this.name,
    required this.onDismiss,
    this.duration = const Duration(milliseconds: 2800),
  });

  final String name;
  final VoidCallback onDismiss;
  final Duration duration;

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _glowController;
  late final AnimationController _contentController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _textOpacity;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardOffset;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    _textOpacity = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutExpo),
    );

    _cardOpacity = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );
    _cardOffset = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Curves.easeOutCubic,
      ),
    );

    _glowScale = Tween<double>(begin: 0.85, end: 1.35).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOutSine,
      ),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.65).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOutSine,
      ),
    );

    _fadeController.forward();
    _glowController.repeat(reverse: true);
    _contentController.forward();
    _scheduleAutoDismiss();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _glowController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _beginDismiss,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: const Color(0xFF070B1C).withOpacity(0.92),
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_glowController, _fadeController]),
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _glowScale.value,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF38BDF8)
                                  .withOpacity(_glowOpacity.value),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                    _AnimatedRings(controller: _glowController),
                    FadeTransition(
                      opacity: _cardOpacity,
                      child: SlideTransition(
                        position: _cardOffset,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 48,
                                  width: 48,
                                  child: Image.asset(
                                    'lib/app/assets/images/cvm.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Portal Admin CVM',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF60A5FA), Color(0xFF38BDF8)],
                              ).createShader(bounds),
                              child: const Text(
                                'Selamat Datang',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.name.isEmpty
                                  ? 'Administrator'
                                  : widget.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _PulseIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Ketuk atau tunggu sejenak untuk melanjutkan',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _scheduleAutoDismiss() async {
    await Future.delayed(widget.duration);
    if (!mounted) return;
    await _beginDismiss();
  }

  Future<void> _beginDismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    _glowController.stop();
    await Future.wait([
      _contentController.reverse(),
      _fadeController.reverse(),
    ]);
    if (!mounted) return;
    widget.onDismiss();
  }
}

class _AnimatedRings extends StatelessWidget {
  const _AnimatedRings({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingsPainter(animation: controller),
      size: const Size(420, 420),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const ringCount = 5;
    final maxRadius = size.shortestSide / 2.15;
    for (var i = 0; i < ringCount; i++) {
      final progress = (animation.value + (i / ringCount)) % 1.0;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      paint.shader = RadialGradient(
        colors: [
          const Color(0xFF60A5FA).withOpacity(0.25 * opacity),
          const Color(0xFF1D4ED8).withOpacity(0.08 * opacity),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
      final radius = maxRadius * (.35 + progress);
      canvas.drawCircle(center, radius, paint);
    }

    final sweepPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.8;
    final angleSpan = math.pi / 5.5;
    final radius = maxRadius * 0.78;
    for (var i = 0; i < 8; i++) {
      final startAngle =
          animation.value * 2 * math.pi + i * math.pi / 4 + math.pi / 8;
      final path = Path()
        ..addArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          angleSpan,
        );
      canvas.drawPath(path, sweepPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) => true;
}

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.95 + (_controller.value * 0.35);
        final glowOpacity = 0.2 + (0.45 * (1 - _controller.value));
        final coreOpacity = 0.6 + (0.25 * (1 - _controller.value));
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF38BDF8).withOpacity(glowOpacity),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF60A5FA).withOpacity(coreOpacity),
                        const Color(0xFF818CF8).withOpacity(coreOpacity),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF60A5FA).withOpacity(0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
