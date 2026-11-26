import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../admin_dashboard/widgets/glass.dart';
import '../../shared/models/company_landing_content.dart';

class CompanyOrganizationPage extends StatefulWidget {
  const CompanyOrganizationPage({super.key, required this.content});

  final OrganizationSectionContent content;

  static Route<void> route(OrganizationSectionContent content) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) =>
          CompanyOrganizationPage(content: content),
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
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  @override
  State<CompanyOrganizationPage> createState() =>
      _CompanyOrganizationPageState();
}

class _CompanyOrganizationPageState extends State<CompanyOrganizationPage> {
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
    final defaults = OrganizationSectionContent.defaults();
    final metricEntries = widget.content.metrics.isNotEmpty
        ? widget.content.metrics
        : defaults.metrics;
    final leadershipEntries = widget.content.leadership.isNotEmpty
        ? widget.content.leadership
        : defaults.leadership;
    final divisionEntries = widget.content.divisions.isNotEmpty
        ? widget.content.divisions
        : defaults.divisions;
    final supportEntries = widget.content.supportUnits.isNotEmpty
        ? widget.content.supportUnits
        : defaults.supportUnits;

    final metrics = [
      for (var entry in metricEntries) _OrgMetric.fromEntry(entry),
    ];
    final leadership = [
      for (var i = 0; i < leadershipEntries.length; i++)
        _LeadershipRole.fromEntry(leadershipEntries[i], i),
    ];
    final divisions = [
      for (var i = 0; i < divisionEntries.length; i++)
        _OrgDivision.fromEntry(divisionEntries[i], i),
    ];
    final supportUnits = [
      for (var i = 0; i < supportEntries.length; i++)
        _SupportUnit.fromEntry(supportEntries[i], i),
    ];

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
                      Icons.account_tree_rounded,
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
                          widget.content.heroTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.content.heroSubtitle,
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
          const _OrganizationBackground(),
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 128, 24, 80),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FadeSlideIn(child: _PageHero(metrics: metrics)),
                      const SizedBox(height: 40),
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: _SectionHeader(
                          title: 'Manajemen Puncak',
                          subtitle:
                              'Tim leaders yang menjaga arah strategis, budaya, dan keberlanjutan ekosistem glass kami.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        child: _LeadershipGrid(roles: leadership),
                      ),
                      const SizedBox(height: 42),
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 260),
                        child: _SectionHeader(
                          title: 'Divisi Strategis',
                          subtitle:
                              'Empat tribe utama yang mengorkestrasi delivery solusi end-to-end bagi klien dan mitra.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 320),
                        child: _DivisionGrid(divisions: divisions),
                      ),
                      const SizedBox(height: 42),
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 380),
                        child: _SectionHeader(
                          title: 'Unit Pendukung',
                          subtitle:
                              'Chapter yang memperkuat growth, governance, dan pengalaman karyawan CVM Digital.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 440),
                        child: _SupportGrid(units: supportUnits),
                      ),
                      const SizedBox(height: 46),
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 500),
                        child: const _OperatingRhythm(),
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

class _PageHero extends StatelessWidget {
  const _PageHero({required this.metrics});

  final List<_OrgMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 32,
      padding: const EdgeInsets.all(32),
      gradientColors: [
        Colors.white.withOpacity(0.22),
        Colors.white.withOpacity(0.08),
      ],
      borderColor: Colors.white.withOpacity(0.16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.28),
          blurRadius: 38,
          spreadRadius: -18,
          offset: const Offset(0, 28),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Struktur Organisasi CVM Digital',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Struktur ini memastikan setiap squad bergerak adaptif namun tetap selaras terhadap North Star kami: menghadirkan ekosistem glass yang human-centric dan berdampak.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.78),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 18.0;
              final maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.of(context).size.width;
              int perRow;
              if (maxWidth >= 1180) {
                perRow = metrics.length;
              } else if (maxWidth >= 760) {
                perRow = metrics.length >= 2 ? 2 : metrics.length;
              } else {
                perRow = 1;
              }
              perRow = perRow.clamp(1, metrics.length);
              final gapCount = perRow > 1 ? perRow - 1 : 0;
              final double childWidth = perRow == 1
                  ? maxWidth
                  : (maxWidth - (gapCount * spacing)) / perRow;

              return Align(
                alignment: Alignment.center,
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  children: [
                    for (final entry in metrics)
                      SizedBox(
                        width: childWidth,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 200),
                          child: _MetricTile(metric: entry),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _OrgMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      gradientColors: [
        Colors.white.withOpacity(0.16),
        Colors.white.withOpacity(0.05),
      ],
      borderColor: Colors.white.withOpacity(0.18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.18),
          blurRadius: 22,
          spreadRadius: -12,
          offset: const Offset(0, 18),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.72),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
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
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.76),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _LeadershipGrid extends StatelessWidget {
  const _LeadershipGrid({required this.roles});

  final List<_LeadershipRole> roles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 18.0;
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final bool twoColumns = availableWidth >= 820;
        final int perRow = twoColumns ? 2 : 1;
        final double cardWidth = perRow == 1
            ? availableWidth
            : (availableWidth - spacing) / perRow;

        return Align(
          alignment: Alignment.center,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: [
              for (final role in roles)
                SizedBox(
                  width: cardWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 320),
                    child: _LeadershipCard(role: role),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LeadershipCard extends StatelessWidget {
  const _LeadershipCard({required this.role});

  final _LeadershipRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 26,
      padding: const EdgeInsets.all(22),
      gradientColors: [
        role.accent.withOpacity(0.36),
        Colors.white.withOpacity(0.08),
      ],
      borderColor: Colors.white.withOpacity(0.18),
      boxShadow: [
        BoxShadow(
          color: role.accent.withOpacity(0.42),
          blurRadius: 24,
          spreadRadius: -14,
          offset: const Offset(0, 20),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [role.accent, role.accent.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(role.icon, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            role.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            role.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.74),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            role.mission,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.76),
              height: 1.6,
            ),
          ),
          if (role.focusAreas.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final focus in role.focusAreas) _OutlinedTag(label: focus),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DivisionGrid extends StatelessWidget {
  const _DivisionGrid({required this.divisions});

  final List<_OrgDivision> divisions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 940;
        final cardWidth = isWide
            ? (constraints.maxWidth - 18) / 2
            : math.min(constraints.maxWidth, 520.0);

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final division in divisions)
              SizedBox(
                width: cardWidth,
                child: _DivisionCard(division: division),
              ),
          ],
        );
      },
    );
  }
}

class _DivisionCard extends StatelessWidget {
  const _DivisionCard({required this.division});

  final _OrgDivision division;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 30,
      padding: const EdgeInsets.all(26),
      gradientColors: [
        division.accent.withOpacity(0.3),
        Colors.white.withOpacity(0.06),
      ],
      borderColor: Colors.white.withOpacity(0.18),
      boxShadow: [
        BoxShadow(
          color: division.accent.withOpacity(0.42),
          blurRadius: 28,
          spreadRadius: -16,
          offset: const Offset(0, 24),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      division.accent,
                      division.accent.withOpacity(0.74),
                    ],
                  ),
                ),
                child: Icon(division.icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      division.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${division.lead}\n${division.leadTitle}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.74),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            division.mandate,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
              height: 1.6,
            ),
          ),
          if (division.focusAreas.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final focus in division.focusAreas)
                  _SolidTag(
                    label: focus,
                    foreground: division.accentOnDark,
                    background: division.accent.withOpacity(0.22),
                    border: division.accent.withOpacity(0.46),
                  ),
              ],
            ),
          ],
          if (division.squads.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.16)),
            const SizedBox(height: 14),
            Text(
              'Squad & Chapter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.66),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final squad in division.squads) _OutlinedTag(label: squad),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportGrid extends StatelessWidget {
  const _SupportGrid({required this.units});

  final List<_SupportUnit> units;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 960
            ? (constraints.maxWidth - 18) / 2
            : math.min(constraints.maxWidth, 520.0);

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final unit in units)
              SizedBox(
                width: cardWidth,
                child: _SupportCard(unit: unit),
              ),
          ],
        );
      },
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.unit});

  final _SupportUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      gradientColors: [
        unit.accent.withOpacity(0.28),
        Colors.white.withOpacity(0.08),
      ],
      borderColor: Colors.white.withOpacity(0.18),
      boxShadow: [
        BoxShadow(
          color: unit.accent.withOpacity(0.36),
          blurRadius: 26,
          spreadRadius: -16,
          offset: const Offset(0, 22),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(unit.icon, color: Colors.white, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unit.lead,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.72),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            unit.mandate,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
              height: 1.6,
            ),
          ),
          if (unit.services.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final service in unit.services)
                  _SolidTag(
                    label: service,
                    foreground: unit.accentOnDark,
                    background: unit.accent.withOpacity(0.24),
                    border: unit.accent.withOpacity(0.42),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OperatingRhythm extends StatelessWidget {
  const _OperatingRhythm();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(28),
      gradientColors: [
        Colors.white.withOpacity(0.18),
        Colors.white.withOpacity(0.06),
      ],
      borderColor: Colors.white.withOpacity(0.16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.24),
          blurRadius: 30,
          spreadRadius: -18,
          offset: const Offset(0, 24),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operating Rhythm',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Memastikan aliran informasi dan keputusan berjalan mulus lintas squad dan chapter.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.76),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _RhythmItem(
                title: 'Tribe Sync',
                description:
                    'Sinkronisasi 2 mingguan untuk memetakan capaian OKR, dependency, dan kebutuhan eskalasi lintas tribe.',
              ),
              SizedBox(height: 12),
              _RhythmItem(
                title: 'Guild Forum',
                description:
                    'Forum knowledge sharing bulanan untuk chapter teknis (Engineering, Product, Data, QA) memperkuat standard dan reusable asset.',
              ),
              SizedBox(height: 12),
              _RhythmItem(
                title: 'ExCo Review',
                description:
                    'Sesi strategi triwulan bersama eksekutif dan unit pendukung untuk memutuskan investasi produk, talent, dan kemitraan baru.',
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: const [
              _OutlinedTag(label: 'OKR Based'),
              _OutlinedTag(label: 'Insight Driven'),
              _OutlinedTag(label: 'People First'),
              _OutlinedTag(label: 'Adaptive Governance'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RhythmItem extends StatelessWidget {
  const _RhythmItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.16),
          ),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.76),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
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
        border: Border.all(color: Colors.white.withOpacity(0.22)),
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

class _SolidTag extends StatelessWidget {
  const _SolidTag({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: background,
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _OrganizationBackground extends StatelessWidget {
  const _OrganizationBackground();

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
                  Color(0xFF0E1530),
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
            child: GlassOrb(
              size: 300,
              colors: [Color(0x2E7B61FF), Colors.transparent],
            ),
          ),
          const Positioned(
            bottom: -140,
            right: -60,
            child: GlassOrb(
              size: 340,
              colors: [Color(0x2646E6FF), Colors.transparent],
            ),
          ),
          Positioned(
            top: 220,
            right: -120,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1FF59E0B), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 460),
    this.beginOffset = const Offset(0, 0.18),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class _OrgMetric {
  const _OrgMetric({
    required this.value,
    required this.label,
    required this.caption,
  });

  final String value;
  final String label;
  final String caption;

  factory _OrgMetric.fromEntry(OrgMetricEntry entry) {
    return _OrgMetric(
      value: entry.value,
      label: entry.label,
      caption: entry.caption,
    );
  }

  static List<_OrgMetric> sample() {
    return const [
      _OrgMetric(
        value: '4',
        label: 'Tribe',
        caption:
            'Stream utama yang memimpin discovery, delivery, dan value realisation.',
      ),
      _OrgMetric(
        value: '8',
        label: 'Squad',
        caption:
            'Tim lintas-disiplin yang bergerak lincah end-to-end untuk klien.',
      ),
      _OrgMetric(
        value: '6',
        label: 'Practice Guild',
        caption:
            'Komunitas kompetensi untuk standarisasi tools, pattern, dan quality.',
      ),
      _OrgMetric(
        value: '24',
        label: 'Key People',
        caption:
            'Lead & principal yang menjadi enabler eksekusi dan coaching talent.',
      ),
    ];
  }
}

class _LeadershipRole {
  const _LeadershipRole({
    required this.name,
    required this.title,
    required this.mission,
    required this.icon,
    required this.accent,
    this.focusAreas = const [],
  });

  final String name;
  final String title;
  final String mission;
  final IconData icon;
  final Color accent;
  final List<String> focusAreas;

  factory _LeadershipRole.fromEntry(LeadershipEntry entry, int index) {
    return _LeadershipRole(
      name: entry.name,
      title: entry.title,
      mission: entry.mission,
      icon: _leadIcons[index % _leadIcons.length],
      accent: _leadAccents[index % _leadAccents.length],
      focusAreas: entry.focusAreas,
    );
  }

  static List<_LeadershipRole> sample() {
    return const [
      _LeadershipRole(
        name: 'Vera Ayu Prameswari',
        title: 'Chief Executive Officer',
        mission:
            'Menetapkan North Star perusahaan, menjaga budaya inovasi, serta memimpin kemitraan strategis level nasional.',
        icon: Icons.auto_awesome_rounded,
        accent: Color(0xFF7B61FF),
        focusAreas: ['Culture', 'Strategic Alliance', 'Innovation'],
      ),
      _LeadershipRole(
        name: 'Reyhan Mahardika',
        title: 'Chief Operating Officer',
        mission:
            'Mengorkestrasi eksekusi lintas tribe, memantau performa OKR, serta memastikan pengelolaan risiko operasional.',
        icon: Icons.published_with_changes_rounded,
        accent: Color(0xFF60A5FA),
        focusAreas: [
          'Delivery Excellence',
          'Risk Control',
          'Business Continuity',
        ],
      ),
      _LeadershipRole(
        name: 'Fikri Nugraha',
        title: 'Chief Technology Officer',
        mission:
            'Mengarahkan arsitektur platform, keamanan, dan roadmap teknologi untuk menjaga keunggulan produk.',
        icon: Icons.memory_rounded,
        accent: Color(0xFF34D399),
        focusAreas: ['Platform Strategy', 'Security', 'Engineering Enablement'],
      ),
      _LeadershipRole(
        name: 'Nayla Iswari',
        title: 'Chief Commercial Officer',
        mission:
            'Mengembangkan proposisi nilai, membina relasi klien, dan menjaga experience omni-channel CVM Digital.',
        icon: Icons.handshake_rounded,
        accent: Color(0xFFF472B6),
        focusAreas: ['Client Success', 'Revenue Growth', 'Brand Experience'],
      ),
    ];
  }
}

class _OrgDivision {
  const _OrgDivision({
    required this.name,
    required this.mandate,
    required this.lead,
    required this.leadTitle,
    required this.focusAreas,
    required this.squads,
    required this.icon,
    required this.accent,
    required this.accentOnDark,
  });

  final String name;
  final String mandate;
  final String lead;
  final String leadTitle;
  final List<String> focusAreas;
  final List<String> squads;
  final IconData icon;
  final Color accent;
  final Color accentOnDark;

  factory _OrgDivision.fromEntry(OrgDivisionEntry entry, int index) {
    return _OrgDivision(
      name: entry.name,
      mandate: entry.mandate,
      lead: entry.lead,
      leadTitle: entry.leadTitle,
      focusAreas: entry.focusAreas,
      squads: entry.squads,
      icon: _divisionIcons[index % _divisionIcons.length],
      accent: _divisionAccents[index % _divisionAccents.length],
      accentOnDark:
          _divisionAccentOnDark[index % _divisionAccentOnDark.length],
    );
  }

  static List<_OrgDivision> sample() {
    return const [
      _OrgDivision(
        name: 'Product & Delivery',
        mandate:
            'Menyelaraskan discovery, desain, dan eksekusi roadmap produk berbasis insight untuk seluruh industri prioritas.',
        lead: 'Intan Larasati',
        leadTitle: 'Head of Product Delivery',
        focusAreas: [
          'Discovery Sprint',
          'Experience Design',
          'Portfolio Governance',
        ],
        squads: ['Squad Helios', 'Squad Aurora', 'PMO Lab'],
        icon: Icons.dashboard_customize_rounded,
        accent: Color(0xFF60A5FA),
        accentOnDark: Colors.white,
      ),
      _OrgDivision(
        name: 'Engineering & Platform',
        mandate:
            'Mengembangan platform glass kami, memastikan reliability, security, dan scalability di seluruh solusi.',
        lead: 'Fikri Nugraha',
        leadTitle: 'Head of Engineering',
        focusAreas: [
          'Platform Architecture',
          'Secure DevOps',
          'Performance Engineering',
        ],
        squads: [
          'Platform Core Squad',
          'DevSecOps Chapter',
          'Quality Engineering Guild',
        ],
        icon: Icons.cloud_sync_rounded,
        accent: Color(0xFF34D399),
        accentOnDark: const Color(0xFF0F5132),
      ),
      _OrgDivision(
        name: 'Data & AI Studio',
        mandate:
            'Mengaktifkan data sebagai aset strategis, membangun insight real-time, dan menerapkan AI yang bertanggung jawab.',
        lead: 'Bagas Saputra',
        leadTitle: 'Head of Data Intelligence',
        focusAreas: ['Data Platform', 'AI Experiment', 'Insights & Analytics'],
        squads: ['Insight Lab', 'AI Studio', 'MLOps Chapter'],
        icon: Icons.auto_graph_rounded,
        accent: Color(0xFF7C3AED),
        accentOnDark: Colors.white,
      ),
      _OrgDivision(
        name: 'Business Operations',
        mandate:
            'Memastikan proses internal, compliance, dan layanan pelanggan berjalan seamless dengan mindset continuous improvement.',
        lead: 'Ratri Kumala',
        leadTitle: 'Head of Business Operations',
        focusAreas: [
          'Service Excellence',
          'Process Automation',
          'Vendor Partnership',
        ],
        squads: [
          'Customer Care Center',
          'Process Excellence',
          'Commercial Ops Chapter',
        ],
        icon: Icons.support_agent_rounded,
        accent: Color(0xFFF59E0B),
        accentOnDark: const Color(0xFF78350F),
      ),
    ];
  }
}

class _SupportUnit {
  const _SupportUnit({
    required this.name,
    required this.lead,
    required this.mandate,
    required this.services,
    required this.icon,
    required this.accent,
    required this.accentOnDark,
  });

  final String name;
  final String lead;
  final String mandate;
  final List<String> services;
  final IconData icon;
  final Color accent;
  final Color accentOnDark;

  factory _SupportUnit.fromEntry(SupportUnitEntry entry, int index) {
    return _SupportUnit(
      name: entry.name,
      lead: entry.lead,
      mandate: entry.mandate,
      services: entry.services,
      icon: _supportIcons[index % _supportIcons.length],
      accent: _supportAccents[index % _supportAccents.length],
      accentOnDark:
          _supportAccentOnDark[index % _supportAccentOnDark.length],
    );
  }

  static List<_SupportUnit> sample() {
    return const [
      _SupportUnit(
        name: 'Corporate Services',
        lead: 'Dinda Maulani • Head of People & Finance',
        mandate:
            'Mengelola people experience, finansial, legal, dan procurement untuk mendukung ekspansi CVM Digital.',
        services: [
          'People Operations',
          'Talent Development',
          'Finance & Legal',
          'Procurement',
        ],
        icon: Icons.people_alt_rounded,
        accent: Color(0xFFFB7185),
        accentOnDark: Colors.white,
      ),
      _SupportUnit(
        name: 'Innovation Council',
        lead: 'Yosua Firmansyah • Director of Innovation',
        mandate:
            'Memimpin agenda inovasi, partnership, dan inkubasi produk eksperimental bersama universitas & komunitas.',
        services: ['Venture Lab', 'Innovation Sprint', 'Partner Ecosystem'],
        icon: Icons.lightbulb_circle_rounded,
        accent: Color(0xFF38BDF8),
        accentOnDark: Colors.white,
      ),
      _SupportUnit(
        name: 'Enterprise PMO',
        lead: 'Salsa Pramesti • Principal Portfolio Manager',
        mandate:
            'Menjaga konsistensi eksekusi program strategis, governance, dan tracking impact lintas tribe.',
        services: ['Portfolio Planning', 'Risk Assessment', 'Value Tracking'],
        icon: Icons.track_changes_rounded,
        accent: Color(0xFFA78BFA),
        accentOnDark: const Color(0xFF312E81),
      ),
      _SupportUnit(
        name: 'Customer Office',
        lead: 'Farhan Ariyanto • Head of Customer Experience',
        mandate:
            'Mengelola suara pelanggan, VOC loop, dan program loyalitas untuk meningkatkan retention & advocacy.',
        services: ['Voice of Customer', 'Experience Lab', 'Engagement Program'],
        icon: Icons.headset_mic_rounded,
        accent: Color(0xFFF97316),
        accentOnDark: const Color(0xFF7C2D12),
      ),
    ];
  }
}

const List<IconData> _leadIcons = [
  Icons.auto_awesome_rounded,
  Icons.published_with_changes_rounded,
  Icons.memory_rounded,
  Icons.handshake_rounded,
];

const List<Color> _leadAccents = [
  Color(0xFF7B61FF),
  Color(0xFF60A5FA),
  Color(0xFF34D399),
  Color(0xFFF472B6),
];

const List<IconData> _divisionIcons = [
  Icons.dashboard_customize_rounded,
  Icons.cloud_sync_rounded,
  Icons.auto_graph_rounded,
  Icons.support_agent_rounded,
];

const List<Color> _divisionAccents = [
  Color(0xFF60A5FA),
  Color(0xFF34D399),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
];

const List<Color> _divisionAccentOnDark = [
  Colors.white,
  Color(0xFF0F5132),
  Colors.white,
  Color(0xFF78350F),
];

const List<IconData> _supportIcons = [
  Icons.people_alt_rounded,
  Icons.lightbulb_circle_rounded,
  Icons.track_changes_rounded,
  Icons.headset_mic_rounded,
];

const List<Color> _supportAccents = [
  Color(0xFFFB7185),
  Color(0xFF38BDF8),
  Color(0xFFA78BFA),
  Color(0xFFF97316),
];

const List<Color> _supportAccentOnDark = [
  Colors.white,
  Colors.white,
  Color(0xFF312E81),
  Color(0xFF7C2D12),
];

class _CircularGlassButton extends StatelessWidget {
  const _CircularGlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(12),
        gradientColors: [
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.08),
        ],
        borderColor: Colors.white.withOpacity(0.18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 20,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
