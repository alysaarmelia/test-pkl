import 'dart:async';

import 'package:flutter/material.dart';

import '../../admin_dashboard/widgets/glass.dart';
import '../../shared/models/company_profile.dart';

class CompanyProfileDetailPage extends StatefulWidget {
  const CompanyProfileDetailPage({super.key, required this.profile});

  final CompanyProfileData profile;

  static Route<void> route(CompanyProfileData profile) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) =>
          CompanyProfileDetailPage(profile: profile),
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
  State<CompanyProfileDetailPage> createState() =>
      _CompanyProfileDetailPageState();
}

class _CompanyProfileDetailPageState extends State<CompanyProfileDetailPage> {
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
    final theme = Theme.of(context);
    final profile = widget.profile;
    final highlightColor =
        profile.brandColor ?? theme.colorScheme.primary.withValues(alpha: 0.86);

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
                Colors.white.withValues(alpha: 0.26),
                Colors.white.withValues(alpha: 0.06),
              ],
              borderColor: Colors.white.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
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
                          highlightColor,
                          highlightColor.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.apartment_outlined,
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
                          profile.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.tagline,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
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
          _ProfileBackground(accent: highlightColor),
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
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        index: 0,
                        child: _ProfileHero(profile: profile),
                      ),
                      const SizedBox(height: 32),
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        index: 1,
                        child: _ProfileSummary(profile: profile),
                      ),
                      const SizedBox(height: 32),
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        index: 2,
                        child: _ProfileValues(profile: profile),
                      ),
                      const SizedBox(height: 32),
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        index: 3,
                        child: _ProfileFocus(profile: profile),
                      ),
                      const SizedBox(height: 32),
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        index: 4,
                        child: _ProfileHistory(profile: profile),
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
}

class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF050B18),
                Color(0xFF060A15),
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -120,
          child: GlassOrb(
            size: 360,
            colors: [
              accent.withValues(alpha: 0.26),
              Colors.transparent,
            ],
          ),
        ),
        Positioned(
          bottom: -120,
          left: -120,
          child: GlassOrb(
            size: 420,
            colors: [
              accent.withValues(alpha: 0.20),
              Colors.transparent,
            ],
          ),
        ),
      ],
    );
  }
}

class _ScrollReveal extends StatefulWidget {
  const _ScrollReveal({
    required this.scrollNotifier,
    required this.index,
    required this.child,
  });

  final ValueNotifier<double> scrollNotifier;
  final int index;
  final Widget child;

  @override
  State<_ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<_ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_opacity);
    widget.scrollNotifier.addListener(_handleScroll);
    Future.microtask(_handleScroll);
  }

  void _handleScroll() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_controller.status == AnimationStatus.completed) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.scrollNotifier.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _offset,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final CompanyProfileData profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        profile.brandColor ?? theme.colorScheme.primary.withValues(alpha: 0.9);

    return GlassContainer(
      borderRadius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 42),
      gradientColors: [
        Colors.white.withValues(alpha: 0.18),
        Colors.white.withValues(alpha: 0.05),
      ],
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 48,
          spreadRadius: -16,
          offset: const Offset(0, 26),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.displayName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              _ChipHighlight(
                icon: Icons.balance_outlined,
                label: profile.legalType,
              ),
              _ChipHighlight(
                icon: Icons.flag_rounded,
                label: profile.tagline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final CompanyProfileData profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 36,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 34),
      gradientColors: [
        Colors.white.withValues(alpha: 0.16),
        Colors.white.withValues(alpha: 0.06),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Perusahaan',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            profile.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.7,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileValues extends StatelessWidget {
  const _ProfileValues({required this.profile});

  final CompanyProfileData profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 36,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 34),
      gradientColors: [
        Colors.white.withValues(alpha: 0.16),
        Colors.white.withValues(alpha: 0.05),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nilai Inti',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              for (final value in profile.coreValues)
                _TagPill(
                  label: value,
                  icon: Icons.auto_awesome_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileFocus extends StatelessWidget {
  const _ProfileFocus({required this.profile});

  final CompanyProfileData profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 36,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 34),
      gradientColors: [
        Colors.white.withValues(alpha: 0.16),
        Colors.white.withValues(alpha: 0.05),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fokus Utama',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final focus in profile.focusAreas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: Color(0xFF34D399),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          focus,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.7,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHistory extends StatelessWidget {
  const _ProfileHistory({required this.profile});

  final CompanyProfileData profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 36,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 34),
      gradientColors: [
        Colors.white.withValues(alpha: 0.16),
        Colors.white.withValues(alpha: 0.05),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sejarah Singkat',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            profile.history,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.7,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipHighlight extends StatelessWidget {
  const _ChipHighlight({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      gradientColors: [
        Colors.white.withValues(alpha: 0.20),
        Colors.white.withValues(alpha: 0.08),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.88)),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      gradientColors: [
        Colors.white.withValues(alpha: 0.18),
        Colors.white.withValues(alpha: 0.08),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.88)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
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
        Colors.white.withValues(alpha: 0.22),
        Colors.white.withValues(alpha: 0.08),
      ],
      borderColor: Colors.white.withValues(alpha: 0.12),
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
