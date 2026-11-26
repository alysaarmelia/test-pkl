import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin_dashboard/widgets/glass.dart';
import '../../firebase_options.dart';
import '../../shared/models/company_landing_content.dart';
import '../../shared/models/company_profile.dart';
import '../../shared/services/company_landing_content_repository.dart';
import '../../shared/services/company_profile_repository.dart';
import '../data/company_profiles_demo.dart';
import 'company_detail_page.dart';
import 'organization_page.dart';
import 'projects_page.dart';

class CompanyHomePage extends StatefulWidget {
  const CompanyHomePage({super.key});

  @override
  State<CompanyHomePage> createState() => _CompanyHomePageState();
}

class _CompanyHomePageState extends State<CompanyHomePage> {
  late final ScrollController _scrollController;
  late final ValueNotifier<double> _scrollOffset;
  late final List<_SectionEntry> _sections;
  CompanyProfileRepository? _companyProfileRepository;
  Stream<List<CompanyProfileData>>? _profilesStream;
  bool _forceDemoProfiles = false;
  String? _profilesInitError;
  CompanyLandingContentRepository? _landingContentRepository;
  Stream<CompanyLandingContent>? _landingContentStream;
  bool _useLandingFallback = false;
  String? _landingContentError;

  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _visionMissionKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollOffset = ValueNotifier<double>(0);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollOffset.value = _scrollController.offset,
    );
    _sections = [
      _SectionEntry('Beranda', _heroKey),
      _SectionEntry('Tentang', _aboutKey),
      _SectionEntry('Layanan', _servicesKey),
      _SectionEntry('Visi & Misi', _visionMissionKey),
      _SectionEntry('Kontak', _contactKey),
    ];
    _prepareData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _handleScroll() {
    _scrollOffset.value = _scrollController.offset;
  }

  Future<void> _prepareData() async {
    final ready = await _ensureFirebase();
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _forceDemoProfiles = true;
        _profilesInitError = 'Firebase belum siap.';
        _useLandingFallback = true;
        _landingContentError = 'Firebase belum siap.';
      });
      return;
    }
    _initLandingContentStream();
    _initProfilesStream();
  }

  void _initProfilesStream() {
    try {
      _companyProfileRepository = CompanyProfileRepository();
      final stream = _companyProfileRepository!.watchPublishedProfiles();
      setState(() {
        _profilesStream = stream;
        _forceDemoProfiles = false;
        _profilesInitError = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '⚠️ Company profile fallback activated: $error\n$stackTrace',
      );
      setState(() {
        _profilesInitError = error.toString();
        _forceDemoProfiles = true;
        _profilesStream = null;
      });
    }
  }

  void _initLandingContentStream() {
    try {
      _landingContentRepository = CompanyLandingContentRepository();
      final stream = _landingContentRepository!.watchContent();
      setState(() {
        _landingContentStream = stream;
        _useLandingFallback = false;
        _landingContentError = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '⚠️ Landing content fallback activated: $error\n$stackTrace',
      );
      setState(() {
        _landingContentError = error.toString();
        _useLandingFallback = true;
        _landingContentStream = null;
      });
    }
  }

  Future<bool> _ensureFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return true;
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'duplicate-app') {
        return true;
      }
      debugPrint('Firebase init error: $error\n$stackTrace');
      return false;
    } catch (error, stackTrace) {
      debugPrint('Firebase init error: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeInOutCubic,
      alignment: 0.05,
    );
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'hello@cvmdigital.id',
      queryParameters: {'subject': 'Informasi Layanan CVM Digital'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openProfileDetail(CompanyProfileData profile) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      CompanyProfileDetailPage.route(profile),
    );
  }

  Widget _buildCompanyMenu() {
    final stream = _profilesStream;
    if (stream == null || _forceDemoProfiles) {
      final helper = _profilesInitError != null
          ? 'Data demo dipakai karena Firebase belum siap.'
          : 'Data demo siap dipilih untuk presentasi.';
      return _NavDropdownButton(
        label: 'Perusahaan',
        profiles: demoCompanyProfiles,
        helperText: helper,
        onSelected: _openProfileDetail,
      );
    }
    return StreamBuilder<List<CompanyProfileData>>(
      stream: stream,
      builder: (context, snapshot) {
        final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
        final streamError = snapshot.hasError;
        final shouldUseFallback = streamError || (!hasData && snapshot.hasData);
        final profiles = shouldUseFallback
            ? demoCompanyProfiles
            : (snapshot.data ?? const <CompanyProfileData>[]);
        final helperText = shouldUseFallback
            ? streamError
                ? 'Data demo ditampilkan karena Firestore error.'
                : 'Data demo ditampilkan sementara.'
            : null;
        final isLoadingProfiles =
            snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;
        final errorText = !shouldUseFallback && streamError
            ? 'Gagal memuat data profil perusahaan'
            : null;
        return _NavDropdownButton(
          label: 'Perusahaan',
          profiles: profiles,
          isLoading: isLoadingProfiles,
          errorText: errorText,
          helperText: helperText,
          onSelected: _openProfileDetail,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final landingStream = _landingContentStream;
    final fallbackContent = CompanyLandingContent.defaults();
    if (_useLandingFallback || landingStream == null) {
      return _buildHomeScaffold(
        context,
        fallbackContent,
        landingHelper: _landingContentError,
      );
    }
    return StreamBuilder<CompanyLandingContent>(
      stream: landingStream,
      builder: (context, snapshot) {
        final content = snapshot.data ?? fallbackContent;
        final helper = snapshot.hasError
            ? 'Konten default digunakan sementara data terbaru dimuat.'
            : null;
        return _buildHomeScaffold(
          context,
          content,
          landingHelper: helper,
        );
      },
    );
  }

  Widget _buildHomeScaffold(
    BuildContext context,
    CompanyLandingContent landingContent, {
    String? landingHelper,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final navSpacing = screenWidth < 980 ? 6.0 : 12.0;
    final brandPadding = screenWidth < 980 ? 28.0 : 40.0;
    final showTagline = screenWidth > 720;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 92,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 0,
        titleSpacing: 0,
        actionsIconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            gradientColors: [
              Colors.white.withOpacity(0.24),
              Colors.white.withOpacity(0.08),
            ],
            borderColor: Colors.white.withOpacity(0.12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 30,
                offset: const Offset(0, 22),
                spreadRadius: -18,
              ),
            ],
            child: const SizedBox.expand(),
          ),
        ),
        title: Padding(
          padding: EdgeInsets.only(left: brandPadding),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'lib/app/assets/images/cvm.png',
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cipta Vera Mandiri Digital',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: Colors.white,
                    ),
                  ),
                  if (showTagline)
                    Text(
                      landingContent.hero.badgeLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white.withOpacity(0.72),
                        letterSpacing: 0.3,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(width: navSpacing),
          for (final entry in _sections)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: navSpacing / 2),
              child: _NavButton(
                label: entry.label,
                onPressed: () => _scrollTo(entry.key),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: navSpacing / 2),
            child: _buildCompanyMenu(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: navSpacing / 2),
            child: _NavButton(
              label: 'Struktur',
              onPressed: () {
                Navigator.of(context).push(
                  CompanyOrganizationPage.route(
                    landingContent.organization,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: navSpacing / 2),
            child: _NavButton(
              label: 'Proyek',
              onPressed: () {
                Navigator.of(context).push(CompanyProjectsPage.route());
              },
            ),
          ),
          SizedBox(width: navSpacing + 4),
          Padding(
            padding: EdgeInsets.only(right: brandPadding),
            child: _NavCtaButton(onPressed: _launchEmail),
          ),
          const SizedBox(width: 6),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          const _BackgroundLayer(),
          Positioned(
            top: -120,
            right: -60,
            child: GlassOrb(
              size: 360,
              colors: [Colors.blueAccent.withOpacity(0.20), Colors.transparent],
            ),
          ),
          Positioned(
            bottom: -140,
            left: -80,
            child: GlassOrb(
              size: 420,
              colors: [
                Colors.purpleAccent.withOpacity(0.14),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            top: 320,
            left: 200,
            child: GlassOrb(
              size: 220,
              colors: [Colors.tealAccent.withOpacity(0.16), Colors.transparent],
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 80),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (landingHelper != null) ...[
                        GlassContainer(
                          borderRadius: 22,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          gradientColors: [
                            Colors.white.withOpacity(0.16),
                            Colors.white.withOpacity(0.06),
                          ],
                          borderColor: Colors.white.withOpacity(0.12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  landingHelper,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                      _HeroSection(
                        key: _heroKey,
                        onContact: _launchEmail,
                        scrollNotifier: _scrollOffset,
                        content: landingContent.hero,
                      ),
                      const SizedBox(height: 84),
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        slideOffset: const Offset(0, 0.12),
                        child: _AboutSection(
                          key: _aboutKey,
                          content: landingContent.about,
                        ),
                      ),
                      const SizedBox(height: 84),
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        slideOffset: const Offset(0, 0.12),
                        child: _ServicesSection(
                          key: _servicesKey,
                          scrollNotifier: _scrollOffset,
                        ),
                      ),
                      const SizedBox(height: 84),
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        slideOffset: const Offset(0, 0.12),
                        child: _VisionMissionSection(
                          key: _visionMissionKey,
                          scrollNotifier: _scrollOffset,
                          content: landingContent.visionMission,
                        ),
                      ),
                      const SizedBox(height: 84),
                      _ScrollReveal(
                        scrollNotifier: _scrollOffset,
                        slideOffset: const Offset(0, 0.12),
                        child: _ContactSection(
                          key: _contactKey,
                          onContact: _launchEmail,
                          content: landingContent.contact,
                        ),
                      ),
                      const SizedBox(height: 120),
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

class _NavButton extends StatefulWidget {
  const _NavButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      colors: [
        theme.colorScheme.secondary.withValues(alpha: 0.72),
        theme.colorScheme.primary.withValues(alpha: 0.72),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressed = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: _hovering ? gradient : null,
          color: !_hovering
              ? Colors.white.withOpacity(_pressed ? 0.14 : 0.08)
              : null,
          border: Border.all(
            color: Colors.white.withOpacity(_hovering ? 0.45 : 0.18),
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.26),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                    spreadRadius: -6,
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.12),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDropdownButton extends StatefulWidget {
  const _NavDropdownButton({
    required this.label,
    required this.profiles,
    required this.onSelected,
    this.isLoading = false,
    this.errorText,
    this.helperText,
  });

  final String label;
  final List<CompanyProfileData> profiles;
  final ValueChanged<CompanyProfileData> onSelected;
  final bool isLoading;
  final String? errorText;
  final String? helperText;

  @override
  State<_NavDropdownButton> createState() => _NavDropdownButtonState();
}

class _NavDropdownButtonState extends State<_NavDropdownButton> {
  bool _hovering = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      colors: [
        theme.colorScheme.secondary.withValues(alpha: 0.72),
        theme.colorScheme.primary.withValues(alpha: 0.72),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final hasProfiles = widget.profiles.isNotEmpty;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final helperText = widget.helperText;
    final interactive = hasProfiles && !widget.isLoading && !hasError;
    final showGradient = interactive && (_hovering || _menuOpen);
    final tooltipMessage = widget.errorText ??
        helperText ??
        (interactive
            ? 'Pilih perusahaan'
            : hasProfiles
                ? 'Profil perusahaan siap dipilih'
                : 'Profil perusahaan belum tersedia');

    Widget trailing;
    if (widget.isLoading) {
      trailing = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    } else if (hasError) {
      trailing = const Icon(
        Icons.error_outline_rounded,
        size: 18,
        color: Colors.amberAccent,
      );
    } else if (hasProfiles) {
      trailing = const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: Colors.white,
      );
    } else {
      trailing = Icon(
        Icons.av_timer_outlined,
        size: 18,
        color: Colors.white.withValues(alpha: 0.75),
      );
    }

    final showHelperIndicator = helperText != null && interactive;

    final shell = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: showGradient ? gradient : null,
        color: showGradient ? null : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: Colors.white.withValues(alpha: showGradient ? 0.45 : 0.18),
        ),
        boxShadow: showGradient
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.26),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                  spreadRadius: -6,
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
                ),
                const SizedBox(width: 8),
                if (showHelperIndicator) ...[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                ],
                trailing,
              ],
            ),
          ),
    );

    if (!interactive) {
      return Tooltip(
        message: tooltipMessage,
        child: shell,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) {
        if (!_menuOpen) {
          setState(() => _hovering = false);
        }
      },
      child: PopupMenuButton<CompanyProfileData>(
        tooltip: tooltipMessage,
        enabled: interactive,
        offset: const Offset(0, 12),
        position: PopupMenuPosition.under,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: const Color(0xFF121A28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        constraints: const BoxConstraints(minWidth: 280),
        onOpened: () => setState(() {
          _menuOpen = true;
          _hovering = true;
        }),
        onCanceled: () => setState(() {
          _menuOpen = false;
          _hovering = false;
        }),
        onSelected: (profile) {
          widget.onSelected(profile);
          setState(() {
            _menuOpen = false;
            _hovering = false;
          });
        },
        itemBuilder: (context) => [
          if (helperText != null)
            PopupMenuItem<CompanyProfileData>(
              enabled: false,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                helperText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          for (final profile in widget.profiles)
            PopupMenuItem<CompanyProfileData>(
              value: profile,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.displayName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.25,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.legalType,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: shell,
      ),
    );
  }
}

class _NavCtaButton extends StatefulWidget {
  const _NavCtaButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_NavCtaButton> createState() => _NavCtaButtonState();
}

class _NavCtaButtonState extends State<_NavCtaButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: gradient,
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                    spreadRadius: -6,
                  ),
                ]
              : [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 10),
                    spreadRadius: -8,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withOpacity(0.18),
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mail_outline, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Hubungi Kami',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionEntry {
  const _SectionEntry(this.label, this.key);

  final String label;
  final GlobalKey key;
}

class _ScrollReveal extends StatefulWidget {
  const _ScrollReveal({
    required this.child,
    required this.scrollNotifier,
    this.index = 0,
    this.staggerDelay = const Duration(milliseconds: 90),
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.slideOffset = const Offset(0, 0.18),
    this.minOpacity = 0.0,
    this.triggerFraction = 0.25,
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
  State<_ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<_ScrollReveal>
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
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: widget.minOpacity, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(curved);

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
  void didUpdateWidget(covariant _ScrollReveal oldWidget) {
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
      _controller.animateTo(target, duration: duration, curve: widget.curve);
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
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF040910),
            Color(0xFF071227),
            Color(0xFF112541),
            Color(0xFF050B18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    super.key,
    required this.onContact,
    required this.scrollNotifier,
    required this.content,
  });

  final VoidCallback onContact;
  final ValueListenable<double> scrollNotifier;
  final HeroSectionContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 960;

        final headline = _HeroHeadline(content: content);
        final subtitle = Text(
          content.subtitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white70,
            height: 1.6,
          ),
        );

        const featureIcons = <IconData>[
          Icons.security,
          Icons.auto_awesome,
          Icons.layers,
          Icons.public,
        ];
        final featureItems = [
          for (var i = 0; i < content.featureHighlights.length; i++)
            (
              icon: featureIcons[i % featureIcons.length],
              label: content.featureHighlights[i],
            ),
        ];

        final featureChips = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < featureItems.length; i++)
              _FeatureChip(
                icon: featureItems[i].icon,
                label: featureItems[i].label,
                index: i,
                scrollNotifier: scrollNotifier,
              ),
          ],
        );

        final stats = _HeroStatsPanel(
          scrollNotifier: scrollNotifier,
          stats: content.stats,
        );

        final ctaRow = Wrap(
          alignment: WrapAlignment.start,
          spacing: 16,
          runSpacing: 12,
          children: [
            _ScrollReveal(
              scrollNotifier: scrollNotifier,
              index: featureItems.length,
              slideOffset: const Offset(0, 0.12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final widthCap = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : screenWidth;
                  double targetWidth;
                  if (screenWidth < 640) {
                    targetWidth = widthCap;
                    if (targetWidth > screenWidth) {
                      targetWidth = screenWidth;
                    }
                    if (targetWidth <= 0) {
                      targetWidth = screenWidth;
                    }
                    if (targetWidth >= 160.0) {
                      targetWidth = targetWidth.clamp(160.0, screenWidth);
                    }
                  } else {
                    targetWidth = 220.0;
                  }
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: targetWidth,
                      maxWidth: targetWidth,
                    ),
                    child: FilledButton(
                      onPressed: onContact,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        content.primaryCtaLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  );
                  
                },
              ),
            ),
            _ScrollReveal(
              scrollNotifier: scrollNotifier,
              index: featureItems.length + 1,
              slideOffset: const Offset(0, 0.12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final widthCap = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : screenWidth;
                  double targetWidth;
                  if (screenWidth < 640) {
                    targetWidth = widthCap;
                    if (targetWidth > screenWidth) {
                      targetWidth = screenWidth;
                    }
                    if (targetWidth <= 0) {
                      targetWidth = screenWidth;
                    }
                    if (targetWidth >= 160.0) {
                      targetWidth = targetWidth.clamp(160.0, screenWidth);
                    }
                  } else {
                    targetWidth = 220.0;
                  }
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: targetWidth,
                      maxWidth: targetWidth,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: onContact,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          content.secondaryCtaLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroBadge(label: content.badgeLabel),
            const SizedBox(height: 22),
            headline,
            const SizedBox(height: 24),
            subtitle,
            const SizedBox(height: 28),
            featureChips,
            const SizedBox(height: 32),
            ctaRow,
            const SizedBox(height: 38),
            stats,
          ],
        );

        final showcase = GlassContainer(
          fullWidth: true,
          borderRadius: 32,
          padding: EdgeInsets.all(isWide ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kenapa CVM Digital?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Menggabungkan desain futuristik, teknologi AI, dan integrasi '
                'sistem untuk pengalaman digital yang memikat.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              _ShowcaseHighlights(scrollNotifier: scrollNotifier),
            ],
          ),
        );

        return GlassContainer(
          fullWidth: true,
          borderRadius: 42,
          padding: EdgeInsets.all(isWide ? 54 : 36),
          gradientColors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
          ],
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftColumn),
                    const SizedBox(width: 48),
                    Expanded(child: showcase),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [leftColumn, const SizedBox(height: 36), showcase],
                ),
        );
      },
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.scrollNotifier,
    required this.index,
  });

  final IconData icon;
  final String label;
  final ValueListenable<double> scrollNotifier;
  final int index;

  @override
  Widget build(BuildContext context) {
    return _ScrollReveal(
      scrollNotifier: scrollNotifier,
      index: index,
      minOpacity: 0.0,
      slideOffset: const Offset(0, 0.16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : screenWidth;
          double targetWidth;
          if (availableWidth <= 200) {
            targetWidth = availableWidth;
          } else if (screenWidth < 600) {
            targetWidth = availableWidth.clamp(180.0, screenWidth);
          } else {
            targetWidth = 220;
          }
          if (targetWidth <= 0) {
            targetWidth = screenWidth < 320 ? screenWidth : 220;
          }
          if (constraints.maxWidth.isFinite &&
              targetWidth > constraints.maxWidth) {
            targetWidth = constraints.maxWidth;
          }

          return ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: targetWidth,
              maxWidth: targetWidth,
            ),
            child: GlassContainer(
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              gradientColors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.04),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroStatData {
  const _HeroStatData({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
}

class _HeroStatsPanel extends StatelessWidget {
  const _HeroStatsPanel({
    required this.scrollNotifier,
    required this.stats,
  });

  final ValueListenable<double> scrollNotifier;
  final List<HeroStatEntry> stats;

  static const List<IconData> _icons = [
    Icons.timeline_outlined,
    Icons.check_circle_outline,
    Icons.speed_outlined,
    Icons.cloud_sync_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final items = <_HeroStatData>[
      for (var i = 0; i < stats.length; i++)
        _HeroStatData(
          label: stats[i].label,
          value: stats[i].value,
          caption: stats[i].description,
          icon: _icons[i % _icons.length],
        ),
    ];
    return GlassContainer(
      borderRadius: 32,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
      gradientColors: [
        Colors.white.withOpacity(0.20),
        Colors.white.withOpacity(0.08),
      ],
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.24),
          blurRadius: 32,
          offset: const Offset(0, 24),
          spreadRadius: -18,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 22.0;
          final maxWidth = constraints.maxWidth;
          final crossAxisCount = maxWidth > 860
              ? 3
              : maxWidth > 560
              ? 2
              : 1;
          final itemWidth = crossAxisCount == 1
              ? maxWidth
              : (maxWidth - (crossAxisCount - 1) * gap) / crossAxisCount;

          return Wrap(
            spacing: gap,
            runSpacing: 20,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: itemWidth,
                  child: _HeroStatCard(
                    data: items[i],
                    scrollNotifier: scrollNotifier,
                    index: i,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({
    required this.data,
    required this.scrollNotifier,
    required this.index,
  });

  final _HeroStatData data;
  final ValueListenable<double> scrollNotifier;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconGradient = LinearGradient(
      colors: [
        theme.colorScheme.secondary.withOpacity(0.9),
        theme.colorScheme.primary.withOpacity(0.9),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const valueGradient = LinearGradient(
      colors: [Color(0xFF8BC5FF), Color(0xFFA086FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return _ScrollReveal(
      scrollNotifier: scrollNotifier,
      index: index,
      slideOffset: const Offset(0, 0.16),
      child: GlassContainer(
        borderRadius: 26,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        gradientColors: [
          Colors.white.withOpacity(0.18),
          Colors.white.withOpacity(0.06),
        ],
        borderColor: Colors.white.withOpacity(0.16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 20),
            spreadRadius: -16,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: iconGradient,
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(data.icon, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(height: 18),
            _GradientHeadlineText(
              text: data.value,
              style:
                  (theme.textTheme.displaySmall ??
                          theme.textTheme.headlineMedium ??
                          const TextStyle(fontSize: 36))
                      .copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                        letterSpacing: -0.6,
                      ),
              gradient: valueGradient,
            ),
            const SizedBox(height: 6),
            Text(
              data.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowcaseHighlights extends StatelessWidget {
  const _ShowcaseHighlights({required this.scrollNotifier});

  final ValueListenable<double> scrollNotifier;

  @override
  Widget build(BuildContext context) {
    const highlightItems = [
      (
        icon: Icons.dashboard_customize_outlined,
        title: 'Platform Admin Terintegrasi',
        description:
            'Dasbor multi-modul untuk memantau operasional harian secara real-time.',
      ),
      (
        icon: Icons.graphic_eq,
        title: 'Visualisasi Data Futuristik',
        description:
            'Komponen glassmorphism dengan animasi halus untuk memperkaya pengalaman.',
      ),
      (
        icon: Icons.lock_clock,
        title: 'Keamanan & Audit Otomatis',
        description:
            'Lapisan keamanan dua faktor, logging terintegrasi, dan audit trail lengkap.',
      ),
      (
        icon: Icons.lock_clock,
        title: 'Keamanan & Audit Otomatis',
        description:
            'Lapisan keamanan dua faktor, logging terintegrasi, dan audit trail lengkap.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 22.0;
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 1024
            ? 3
            : maxWidth >= 720
            ? 2
            : 1;
        final itemWidth = columns == 1
            ? maxWidth
            : (maxWidth - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < highlightItems.length; i++)
              SizedBox(
                width: itemWidth,
                child: _HighlightTile(
                  icon: highlightItems[i].icon,
                  title: highlightItems[i].title,
                  description: highlightItems[i].description,
                  scrollNotifier: scrollNotifier,
                  index: i,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.scrollNotifier,
    required this.index,
  });

  final IconData icon;
  final String title;
  final String description;
  final ValueListenable<double> scrollNotifier;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentGradient = LinearGradient(
      colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return _ScrollReveal(
      scrollNotifier: scrollNotifier,
      index: index,
      slideOffset: const Offset(0, 0.18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: GlassContainer(
          borderRadius: 26,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 35),
          gradientColors: [
            Colors.white.withOpacity(0.16),
            Colors.white.withOpacity(0.06),
          ],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.24),
              blurRadius: 28,
              offset: const Offset(0, 22),
              spreadRadius: -14,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: accentGradient,
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 4,
                width: 98,
                decoration: BoxDecoration(
                  gradient: accentGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key, required this.content});

  final AboutSectionContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 720;
    final horizontalPadding = isCompact ? 28.0 : 40.0;

    return GlassContainer(
      fullWidth: true,
      borderRadius: 38,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isCompact ? 40 : 48,
        horizontalPadding,
        isCompact ? 36 : 44,
      ),
      gradientColors: [
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0.04),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: content.title,
            subtitle: content.subtitle,
          ),
          const SizedBox(height: 36),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 840;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      for (final entry in content.timeline)
                        _TimelineBadge(
                          title: entry.title,
                          description: entry.description,
                        ),
                    ],
                  ),
                ],
              );

              final right = GlassContainer(
                borderRadius: 26,
                padding: const EdgeInsets.all(26),
                gradientColors: [
                  Colors.white.withOpacity(0.16),
                  Colors.white.withOpacity(0.05),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nilai Utama Kami',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...[
                      for (var i = 0; i < content.values.length; i++) ...[
                        _ValueTile(
                          icon: _valueIcons[i % _valueIcons.length],
                          title: content.values[i].title,
                          description: content.values[i].description,
                        ),
                        if (i != content.values.length - 1)
                          const SizedBox(height: 18),
                      ],
                    ],
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 40),
                    SizedBox(width: 380, child: right),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [left, const SizedBox(height: 32), right],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimelineBadge extends StatelessWidget {
  const _TimelineBadge({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.16),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const List<IconData> _valueIcons = [
  Icons.bolt_rounded,
  Icons.people_outline,
  Icons.workspace_premium_outlined,
  Icons.auto_awesome_rounded,
];

class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline({required this.content});

  final HeroSectionContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = const LinearGradient(
      colors: [Color(0xFF8BC5FF), Color(0xFFA086FF), Color(0xFF5C9DFF)],
    );
    final baseStyle =
        (theme.textTheme.displaySmall ??
                theme.textTheme.headlineMedium ??
                const TextStyle(fontSize: 44))
            .copyWith(
              fontWeight: FontWeight.w800,
              height: 1.04,
              letterSpacing: -0.6,
            );
    final subStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.white.withOpacity(0.92),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GradientHeadlineText(
          text: content.titleLine1,
          style: baseStyle,
          gradient: gradient,
        ),
        const SizedBox(height: 8),
        Text(content.titleLine2, style: subStyle),
        const SizedBox(height: 18),
        Container(
          width: 132,
          height: 4,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _GradientHeadlineText extends StatelessWidget {
  const _GradientHeadlineText({
    required this.text,
    required this.style,
    required this.gradient,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout();
    final shader = gradient.createShader(
      Rect.fromLTWH(0, 0, painter.width, painter.height),
    );
    return Text(
      text,
      style: style.copyWith(foreground: Paint()..shader = shader),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ) ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        );

    return GlassContainer(
      borderRadius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      gradientColors: [
        Colors.white.withOpacity(0.22),
        Colors.white.withOpacity(0.08),
      ],
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.24),
          blurRadius: 26,
          offset: const Offset(0, 18),
          spreadRadius: -12,
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
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
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({super.key, required this.scrollNotifier});

  final ValueListenable<double> scrollNotifier;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 720;
    final horizontalPadding = isCompact ? 28.0 : 40.0;
    final verticalPadding = isCompact ? 40.0 : 48.0;

    final services = [
      _ServiceCardData(
        title: 'Pengembangan Platform Admin',
        description:
            'Dashboard glassmorphism responsif untuk operasional perusahaan.',
        icon: Icons.dashboard_outlined,
      ),
      _ServiceCardData(
        title: 'Integrasi Sistem Internal',
        description:
            'Koneksikan HRIS, ERP, dan sistem legacy dengan API tersentral.',
        icon: Icons.hub_outlined,
      ),
      _ServiceCardData(
        title: 'Aplikasi Absensi & Field Force',
        description:
            'Solusi mobile dengan pengenalan wajah dan geofencing real-time.',
        icon: Icons.task_alt_outlined,
      ),
      _ServiceCardData(
        title: 'Automasi Proses Bisnis',
        description:
            'Workflow approval cepat dengan notifikasi multi-channel dan bot.',
        icon: Icons.bolt_outlined,
      ),
      _ServiceCardData(
        title: 'Data Analytics & Insight',
        description:
            'Visualisasi interaktif untuk memantau KPI dan pengambilan keputusan.',
        icon: Icons.auto_graph_outlined,
      ),
      _ServiceCardData(
        title: 'Keamanan & Compliance',
        description:
            'Audit trail, enkripsi berlapis, dan standar ISO/IEC readiness.',
        icon: Icons.verified_user_outlined,
      ),
    ];

    return GlassContainer(
      fullWidth: true,
      borderRadius: 38,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        isCompact ? 40 : 44,
      ),
      gradientColors: [
        Colors.white.withOpacity(0.12),
        Colors.white.withOpacity(0.04),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Layanan Digital',
            subtitle:
                'Solusi ujung-ke-ujung untuk mengakselerasi transformasi digital.',
          ),
          const SizedBox(height: 36),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxis = constraints.maxWidth > 960
                  ? 3
                  : constraints.maxWidth > 720
                  ? 2
                  : 1;
              final cardWidth =
                  (constraints.maxWidth - (crossAxis - 1) * 20) / crossAxis;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (var i = 0; i < services.length; i++)
                    SizedBox(
                      width: cardWidth,
                      child: _ScrollReveal(
                        scrollNotifier: scrollNotifier,
                        index: i,
                        slideOffset: const Offset(0, 0.14),
                        child: _ServiceCard(data: services[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceCardData {
  const _ServiceCardData({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.data});

  final _ServiceCardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardHeight = width > 340 ? 240.0 : 220.0;
        final iconSize = width > 340 ? 56.0 : 52.0;

        return SizedBox(
          height: cardHeight,
          child: GlassContainer(
            borderRadius: 26,
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
            gradientColors: [
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.05),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.primary,
                      ],
                    ),
                  ),
                  child: Icon(
                    data.icon,
                    color: Colors.white,
                    size: iconSize * 0.48,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      data.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.6,
                      ),
                    ),
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

class _VisionMissionSection extends StatelessWidget {
  const _VisionMissionSection({
    super.key,
    required this.scrollNotifier,
    required this.content,
  });

  final ValueListenable<double> scrollNotifier;
  final VisionMissionContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 720;
    final horizontalPadding = isCompact ? 28.0 : 40.0;
    final verticalPadding = isCompact ? 40.0 : 48.0;

    Widget buildVisionCard() {
      return _ScrollReveal(
        scrollNotifier: scrollNotifier,
        index: 0,
        slideOffset: const Offset(0, 0.16),
        child: GlassContainer(
          borderRadius: 36,
          padding: const EdgeInsets.fromLTRB(34, 36, 34, 32),
          gradientColors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.06),
          ],
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              blurRadius: 38,
              offset: const Offset(0, 22),
              spreadRadius: -16,
            ),
          ],
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -58,
                right: -48,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.32),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    gradientColors: [
                      theme.colorScheme.secondary.withValues(alpha: 0.3),
                      theme.colorScheme.primary.withValues(alpha: 0.24),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          content.visionTitle,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    content.visionStatement,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, boxConstraints) {
                      const spacing = 18.0;
                      final isTwoColumn = boxConstraints.maxWidth > 720;
                      final tileWidth = isTwoColumn
                          ? (boxConstraints.maxWidth - spacing) / 2
                          : boxConstraints.maxWidth;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: 16,
                        children: [
                          for (var i = 0;
                              i < content.visionPoints.length;
                              i++)
                            SizedBox(
                              width: tileWidth,
                              child: GlassContainer(
                                borderRadius: 24,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                gradientColors: [
                                  Colors.white.withValues(alpha: 0.16),
                                  Colors.white.withValues(alpha: 0.06),
                                ],
                                borderColor:
                                    Colors.white.withValues(alpha: 0.12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GlassContainer(
                                      borderRadius: 16,
                                      padding: const EdgeInsets.all(8),
                                      gradientColors: [
                                        Colors.white.withValues(alpha: 0.22),
                                        Colors.white.withValues(alpha: 0.08),
                                      ],
                                      child: Icon(
                                        _visionIcons[i % _visionIcons.length],
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        content.visionPoints[i],
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white70,
                                          height: 1.5,
                                        ),
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
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget buildMissionCard() {
      return _ScrollReveal(
        scrollNotifier: scrollNotifier,
        index: 1,
        slideOffset: const Offset(0, 0.16),
        child: GlassContainer(
          borderRadius: 36,
          padding: const EdgeInsets.fromLTRB(34, 36, 34, 32),
          gradientColors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.06),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                gradientColors: [
                  theme.colorScheme.secondary.withValues(alpha: 0.3),
                  theme.colorScheme.primary.withValues(alpha: 0.24),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      content.missionTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  for (var i = 0; i < content.missionPoints.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            i == content.missionPoints.length - 1 ? 0 : 18,
                      ),
                      child: _MissionPoint(
                        number: (i + 1).toString().padLeft(2, '0'),
                        text: content.missionPoints[i],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GlassContainer(
      fullWidth: true,
      borderRadius: 38,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        isCompact ? 40 : 44,
      ),
      gradientColors: [
        Colors.white.withValues(alpha: 0.1),
        Colors.white.withValues(alpha: 0.04),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: content.title,
            subtitle: content.subtitle,
          ),
          const SizedBox(height: 36),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 960;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: buildVisionCard(),
                      ),
                    ),
                    Expanded(child: buildMissionCard()),
                  ],
                );
              }
              return Column(
                children: [
                  buildVisionCard(),
                  const SizedBox(height: 22),
                  buildMissionCard(),
                ],
              );
            },
          ),
          const SizedBox(height: 34),
          _ScrollReveal(
            scrollNotifier: scrollNotifier,
            index: 2,
            slideOffset: const Offset(0, 0.12),
            child: GlassContainer(
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              gradientColors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.05),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nilai Utama',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, boxConstraints) {
                      const spacing = 18.0;
                      final isTwoColumn = boxConstraints.maxWidth > 720;
                      final tileWidth = isTwoColumn
                          ? (boxConstraints.maxWidth - spacing) / 2
                          : boxConstraints.maxWidth;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: 16,
                        children: [
                          for (final value in content.coreValues)
                            SizedBox(
                              width: tileWidth,
                              child: GlassContainer(
                                borderRadius: 24,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                gradientColors: [
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        value,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                              height: 1.4,
                                            ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<IconData> _visionIcons = [
  Icons.explore_outlined,
  Icons.data_exploration_outlined,
  Icons.handshake_outlined,
  Icons.auto_fix_high_outlined,
];

class _MissionPoint extends StatelessWidget {
  const _MissionPoint({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      gradientColors: [
        Colors.white.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0.05),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _ContactSection extends StatelessWidget {
  const _ContactSection({
    super.key,
    required this.onContact,
    required this.content,
  });

  final VoidCallback onContact;
  final ContactSectionContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 720;
    final horizontalPadding = isCompact ? 26.0 : 36.0;
    return GlassContainer(
      fullWidth: true,
      borderRadius: 36,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isCompact ? 32 : 40,
        horizontalPadding,
        isCompact ? 34 : 42,
      ),
      gradientColors: [
        theme.colorScheme.secondary.withOpacity(0.32),
        theme.colorScheme.primary.withOpacity(0.18),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 780;

          final ctaColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                content.subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 18,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.mail_outline),
                    label: Text(
                      content.primaryActionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.phone_outlined),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        content.secondaryActionLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          final contactInfo = GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            gradientColors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.05),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < content.channels.length; i++) ...[
                  _ContactRow(
                    icon: _contactIconFor(content.channels[i].label),
                    title: content.channels[i].label,
                    description: content.channels[i].description,
                  ),
                  if (i != content.channels.length - 1)
                    const SizedBox(height: 18),
                ],
              ],
            ),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ctaColumn),
                const SizedBox(width: 38),
                SizedBox(width: 340, child: contactInfo),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ctaColumn, const SizedBox(height: 32), contactInfo],
          );
        },
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.18),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _contactIconFor(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('alamat')) return Icons.location_on_outlined;
  if (normalized.contains('jam') || normalized.contains('operasional')) {
    return Icons.schedule_outlined;
  }
  if (normalized.contains('media') || normalized.contains('sosial')) {
    return Icons.public_outlined;
  }
  if (normalized.contains('telepon') || normalized.contains('phone')) {
    return Icons.phone_outlined;
  }
  if (normalized.contains('email')) return Icons.email_outlined;
  return Icons.info_outline_rounded;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
