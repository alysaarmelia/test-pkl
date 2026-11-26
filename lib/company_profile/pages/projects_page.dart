import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../admin_dashboard/widgets/glass.dart';

class CompanyProjectsPage extends StatefulWidget {
  const CompanyProjectsPage({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const CompanyProjectsPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CompanyProjectsPage> createState() => _CompanyProjectsPageState();
}

class _CompanyProjectsPageState extends State<CompanyProjectsPage> {
  late final ScrollController _scrollController;
  late final ValueNotifier<double> _scrollOffset;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollOffset = ValueNotifier<double>(0);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollOffset.value = _scrollController.offset,
    );
  }

  void _handleScroll() {
    _scrollOffset.value = _scrollController.offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = _ProjectEntry.demo();
    final theme = Theme.of(context);
    final completedCount =
        projects.where((p) => p.status == _ProjectStatus.completed).length;
    final inProgressCount = projects.length - completedCount;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(112),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: GlassContainer(
              borderRadius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              gradientColors: [
                Colors.white.withOpacity(0.26),
                Colors.white.withOpacity(0.06),
              ],
              borderColor: Colors.white.withOpacity(0.12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 34,
                  spreadRadius: -18,
                  offset: const Offset(0, 24),
                ),
              ],
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.secondary,
                          theme.colorScheme.primary,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Proyek Unggulan',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Showcase perjalanan transformasi digital mitra kami',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withOpacity(0.78),
                            letterSpacing: 0.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _CircularGlassButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const _ProjectsBackground(),
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 140, 24, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProjectsReveal(
                        scrollNotifier: _scrollOffset,
                        index: 0,
                        child: _ProjectsHeader(
                          theme: theme,
                          total: projects.length,
                          completed: completedCount,
                          inProgress: inProgressCount,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          for (var i = 0; i < projects.length; i++)
                            SizedBox(
                              width: _cardWidth(context),
                              child: _ProjectsReveal(
                                scrollNotifier: _scrollOffset,
                                index: i + 1,
                                child: _ProjectCard(entry: projects[i]),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _cardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 48;
    if (width > 980) return (1100 - 24) / 2;
    if (width > 640) return (width - 24) / 2;
    return width;
  }
}

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader({
    required this.theme,
    required this.total,
    required this.completed,
    required this.inProgress,
  });

  final ThemeData theme;
  final int total;
  final int completed;
  final int inProgress;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding =
        screenWidth > 900 ? const EdgeInsets.all(38) : const EdgeInsets.all(26);

    return GlassContainer(
      borderRadius: 42,
      padding: padding,
      gradientColors: [
        Colors.white.withOpacity(0.18),
        Colors.white.withOpacity(0.05),
      ],
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.26),
          blurRadius: 40,
          spreadRadius: -18,
          offset: const Offset(0, 28),
        ),
      ],
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.secondary.withOpacity(0.32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Portfolio Transformasi Digital',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Telusuri proyek yang sedang kami kembangkan dan yang telah selesai '
                'untuk beragam klien enterprise di Indonesia.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.76),
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 18,
                runSpacing: 14,
                children: [
                  _StatusSummaryChip(
                    icon: Icons.timelapse_rounded,
                    label: 'Dalam Proses',
                    value: inProgress,
                    accent: theme.colorScheme.secondary,
                  ),
                  _StatusSummaryChip(
                    icon: Icons.verified_outlined,
                    label: 'Selesai',
                    value: completed,
                    accent: const Color(0xFF34D399),
                  ),
                  _StatusSummaryChip(
                    icon: Icons.workspaces_outline,
                    label: 'Total Proyek',
                    value: total,
                    accent: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: const [
                  _FilterTag(label: 'Enterprise Experience'),
                  _FilterTag(label: 'AI & Automasi'),
                  _FilterTag(label: 'Glassmorphism UI'),
                  _FilterTag(label: 'Integrasi Cloud'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularGlassButton extends StatelessWidget {
  const _CircularGlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(6),
      gradientColors: [
        Colors.white.withOpacity(0.22),
        Colors.white.withOpacity(0.08),
      ],
      borderColor: Colors.white.withOpacity(0.12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StatusSummaryChip extends StatelessWidget {
  const _StatusSummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      gradientColors: [
        Colors.white.withOpacity(0.2),
        Colors.white.withOpacity(0.08),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  accent,
                  accent.withOpacity(0.6),
                ],
              ),
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 0.3,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterTag extends StatelessWidget {
  const _FilterTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      gradientColors: [
        Colors.white.withOpacity(0.16),
        Colors.white.withOpacity(0.06),
      ],
      borderColor: Colors.white.withOpacity(0.14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.blur_on_rounded, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectsReveal extends StatefulWidget {
  const _ProjectsReveal({
    required this.child,
    required this.scrollNotifier,
    this.index = 0,
    this.staggerDelay = const Duration(milliseconds: 90),
    this.duration = const Duration(milliseconds: 380),
    this.curve = Curves.easeOutCubic,
    this.slideOffset = const Offset(0, 0.14),
    this.minOpacity = 0.0,
    this.triggerFraction = 0.2,
  });

  final Widget child;
  final ValueListenable<double> scrollNotifier;
  final int index;
  final Duration staggerDelay;
  final Duration duration;
  final Curve curve;
  final Offset slideOffset;
  final double minOpacity;
  final double triggerFraction;

  @override
  State<_ProjectsReveal> createState() => _ProjectsRevealState();
}

class _ProjectsRevealState extends State<_ProjectsReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _staggerTimer;
  bool _listenerAttached = false;
  double _lastTarget = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: widget.minOpacity, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: widget.slideOffset, end: Offset.zero)
        .animate(curved);

    _attachListener();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  void _attachListener() {
    if (_listenerAttached) return;
    widget.scrollNotifier.addListener(_handleScroll);
    _listenerAttached = true;
  }

  void _detachListener() {
    if (!_listenerAttached) return;
    widget.scrollNotifier.removeListener(_handleScroll);
    _listenerAttached = false;
  }

  @override
  void didUpdateWidget(covariant _ProjectsReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollNotifier != widget.scrollNotifier) {
      _detachListener();
      _attachListener();
      _handleScroll();
    }
  }

  void _handleScroll() {
    if (!mounted) return;
    if (context is! Element) return;
    final element = context as Element;
    if (!element.mounted) return;

    final renderObject = element.renderObject;
    if (renderObject is! RenderBox) return;
    if (!renderObject.attached || !renderObject.hasSize) return;

    final topOffset = renderObject.localToGlobal(Offset.zero).dy;
    final height = renderObject.size.height;
    if (height <= 0) return;

    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight <= 0) return;

    final viewportTop = 0.0;
    final viewportBottom = screenHeight;
    final bottomOffset = topOffset + height;

    final visibleTop = topOffset.clamp(viewportTop, viewportBottom);
    final visibleBottom = bottomOffset.clamp(viewportTop, viewportBottom);
    final visibleExtent = (visibleBottom - visibleTop).clamp(0.0, height);

    final fractionVisible = (visibleExtent / height).clamp(0.0, 1.0);
    final threshold = widget.triggerFraction.clamp(0.0, 0.95);
    final normalized = fractionVisible <= threshold
        ? 0.0
        : ((fractionVisible - threshold) / (1 - threshold)).clamp(0.0, 1.0);
    final target = normalized;

    if ((_lastTarget - target).abs() < 0.01) return;
    _lastTarget = target;

    void animate() {
      final delta = (target - _controller.value).abs();
      if (delta < 0.01) return;
      final baseMs = widget.duration.inMilliseconds == 0
          ? 1
          : widget.duration.inMilliseconds;
      final minMs = baseMs >= 120 ? 120 : baseMs;
      final scaledMs = (baseMs * delta).round().clamp(minMs, baseMs);
      final duration = Duration(milliseconds: scaledMs);
      if (!mounted) return;
      _controller.animateTo(
        target,
        duration: duration,
        curve: widget.curve,
      );
    }

    if (target > _controller.value) {
      _staggerTimer?.cancel();
      final delayMs = widget.staggerDelay.inMilliseconds * widget.index;
      _staggerTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) {
          animate();
        }
      });
    } else {
      _staggerTimer?.cancel();
      animate();
    }
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _detachListener();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.entry});

  final _ProjectEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = entry.status;
    final statusInfo = status.info(theme.colorScheme);

    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      gradientColors: [
        Colors.white.withOpacity(0.18),
        Colors.white.withOpacity(0.05),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    entry.imagePath,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.32),
                    colorBlendMode: BlendMode.darken,
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: statusInfo.background,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusInfo.icon,
                              size: 16,
                              color: statusInfo.foreground,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusInfo.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: statusInfo.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            entry.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.business_outlined,
                label: entry.client,
              ),
              _InfoChip(
                icon: Icons.schedule_outlined,
                label: entry.timeline,
              ),
              for (final tag in entry.tags)
                _OutlinedTag(label: tag),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.auto_awesome_mosaic_outlined,
                color: theme.colorScheme.secondary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fokus: ${entry.tags.take(2).join(' • ')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text(
                  'Detail',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedTag extends StatelessWidget {
  const _OutlinedTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _ProjectsBackground extends StatelessWidget {
  const _ProjectsBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF050B18),
                  Color(0xFF101932),
                  Color(0xFF050B18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const Positioned(
            top: -120,
            left: -80,
            child: _BlurOrb(
              diameter: 280,
              colors: [
                Color(0x2E7B61FF),
                Colors.transparent,
              ],
            ),
          ),
          const Positioned(
            bottom: -150,
            right: -100,
            child: _BlurOrb(
              diameter: 320,
              colors: [
                Color(0x2646E6FF),
                Colors.transparent,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.diameter, required this.colors});

  final double diameter;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
        ),
      ),
    );
  }
}

enum _ProjectStatus { inProgress, completed }

class _ProjectStatusInfo {
  const _ProjectStatusInfo({
    required this.label,
    required this.foreground,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData icon;
}

extension on _ProjectStatus {
  _ProjectStatusInfo info(ColorScheme scheme) {
    switch (this) {
      case _ProjectStatus.inProgress:
        return _ProjectStatusInfo(
          label: 'Proses',
          foreground: scheme.onSecondaryContainer,
          background: scheme.secondaryContainer.withOpacity(0.9),
          icon: Icons.timelapse_rounded,
        );
      case _ProjectStatus.completed:
        return _ProjectStatusInfo(
          label: 'Selesai',
          foreground: const Color(0xFF0F5132),
          background: const Color(0xFFA7F3D0),
          icon: Icons.check_circle_rounded,
        );
    }
  }
}

class _ProjectEntry {
  const _ProjectEntry({
    required this.name,
    required this.description,
    required this.client,
    required this.timeline,
    required this.imagePath,
    required this.status,
    required this.tags,
  });

  final String name;
  final String description;
  final String client;
  final String timeline;
  final String imagePath;
  final _ProjectStatus status;
  final List<String> tags;

  static List<_ProjectEntry> demo() {
    return const [
      _ProjectEntry(
        name: 'Platform Absensi Nasional',
        description:
            'Membangun sistem absensi multi-lokasi dengan geofencing dan integrasi payroll otomatis untuk 18 cabang.',
        client: 'PT. Nusantara Prima',
        timeline: 'Q1 2024 - Q3 2024',
        imagePath: 'lib/app/assets/images/cvm.png',
        status: _ProjectStatus.inProgress,
        tags: [
          'Mobile App',
          'Integrasi ERP',
          'Geolocation',
        ],
      ),
      _ProjectEntry(
        name: 'Command Center Operasional',
        description:
            'Pengembangan dashboard glassmorphism untuk monitoring IoT & SCADA di fasilitas manufaktur.',
        client: 'IndoTech Manufacturing',
        timeline: 'Q2 2023 - Q1 2024',
        imagePath: 'lib/app/assets/images/cvm.png',
        status: _ProjectStatus.completed,
        tags: [
          'Dashboard',
          'IoT',
          'AI Insight',
        ],
      ),
      _ProjectEntry(
        name: 'Portal Manajemen Proyek',
        description:
            'Portal kolaborasi lintas divisi dengan integrasi dokumen, komentar, dan otomasi approval.',
        client: 'Arsana Group',
        timeline: 'Q3 2023 - Q2 2024',
        imagePath: 'lib/app/assets/images/cvm.png',
        status: _ProjectStatus.inProgress,
        tags: [
          'Collaboration',
          'Workflow',
          'Glass UI',
        ],
      ),
      _ProjectEntry(
        name: 'Platform Keanggotaan Premium',
        description:
            'Sistem loyalty dengan personalisasi rekomendasi dan dukungan multi-channel communication.',
        client: 'Lux Club Asia',
        timeline: 'Q1 2023 - Q4 2023',
        imagePath: 'lib/app/assets/images/cvm.png',
        status: _ProjectStatus.completed,
        tags: [
          'CRM',
          'Personalisation',
          'Analytics',
        ],
      ),
    ];
  }
}
