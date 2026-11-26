import 'package:flutter/material.dart';

import '../../../shared/models/company_landing_content.dart';
import '../../../shared/models/company_profile.dart';
import '../../../shared/services/company_landing_content_repository.dart';
import '../../../shared/services/company_profile_repository.dart';
import '../../widgets/glass.dart';

class CompanyProfilesPage extends StatefulWidget {
  const CompanyProfilesPage({super.key});

  @override
  State<CompanyProfilesPage> createState() => _CompanyProfilesPageState();
}

class _CompanyProfilesPageState extends State<CompanyProfilesPage> {
  final CompanyProfileRepository _repository = CompanyProfileRepository();
  final CompanyLandingContentRepository _landingContentRepository =
      CompanyLandingContentRepository();

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  Future<void> _openEditor([CompanyProfileData? profile]) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CompanyProfileEditorDialog(
        repository: _repository,
        profile: profile,
      ),
    );

    if (result == true && mounted) {
      final message =
          profile == null ? 'Profil perusahaan dibuat' : 'Profil diperbarui';
      _messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmDelete(CompanyProfileData profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus profil?'),
        content: Text(
          'Profil "${profile.displayName}" akan dihapus permanen '
          'dari landing page dan riwayat versi tidak tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteProfile(profile.id);
      if (!mounted) return;
      _messenger.showSnackBar(
        SnackBar(content: Text('Profil "${profile.displayName}" dihapus')),
      );
    } catch (error) {
      if (!mounted) return;
      _messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus profil: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Profil Perusahaan'),
      const Tab(text: 'Konten Landing'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            tabs: tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [
                _ProfilesTab(
                  repository: _repository,
                  onCreate: _openEditor,
                  onEdit: _openEditor,
                  onDelete: _confirmDelete,
                  onRetry: () => setState(() {}),
                ),
                _LandingContentEditor(
                  repository: _landingContentRepository,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilesTab extends StatelessWidget {
  const _ProfilesTab({
    required this.repository,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onRetry,
  });

  final CompanyProfileRepository repository;
  final void Function([CompanyProfileData?]) onEdit;
  final ValueChanged<CompanyProfileData> onDelete;
  final VoidCallback onCreate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konten Company Profile',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Kelola daftar entitas, ringkasan, nilai utama, dan fokus layanan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Profil'),
              onPressed: onCreate,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<List<CompanyProfileData>>(
            stream: repository.watchAllProfiles(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorState(
                  message: snapshot.error.toString(),
                  onRetry: onRetry,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final profiles = snapshot.data!;
              if (profiles.isEmpty) {
                return _EmptyState(onCreate: onCreate);
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  return _CompanyProfileCard(
                    profile: profile,
                    onEdit: () => onEdit(profile),
                    onDelete: () => onDelete(profile),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompanyProfileCard extends StatelessWidget {
  const _CompanyProfileCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
  });

  final CompanyProfileData profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = profile.brandColor ?? theme.colorScheme.primary;
    final statusColor = profile.isPublished
        ? Colors.greenAccent.withValues(alpha: 0.2)
        : Colors.amberAccent.withValues(alpha: 0.2);
    final statusText = profile.isPublished ? 'Tayang' : 'Draft';
    final trimmedName = profile.displayName.trim();
    final initial =
        trimmedName.isNotEmpty ? trimmedName.substring(0, 1).toUpperCase() : '?';

    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.8),
                      accentColor.withValues(alpha: 0.5),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                profile.isPublished
                                    ? Icons.public
                                    : Icons.edit_note_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Edit profil',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Hapus profil',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.legalType,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.tagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (profile.coreValues.isNotEmpty) ...[
            Text(
              'Nilai Utama',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.coreValues
                  .map(
                    (value) => Chip(
                      label: Text(value),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
          ],
          if (profile.focusAreas.isNotEmpty) ...[
            Text(
              'Fokus Layanan',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.focusAreas
                  .map(
                    (focus) => Chip(
                      avatar: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      label: Text(focus),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Urutan tampil: ${profile.sortOrder}   ·   ID: ${profile.id}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingContentEditor extends StatefulWidget {
  const _LandingContentEditor({required this.repository});

  final CompanyLandingContentRepository repository;

  @override
  State<_LandingContentEditor> createState() => _LandingContentEditorState();
}

class _LandingContentEditorState extends State<_LandingContentEditor> {
  bool _loading = true;
  bool _saving = false;
  CompanyLandingContent? _content;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final content = await widget.repository.fetchContent();
      if (!mounted) return;
      setState(() => _content = content);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat konten landing: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateContent(
    CompanyLandingContent Function(CompanyLandingContent current) change, {
    String? successMessage,
  }) async {
    final current = _content ?? CompanyLandingContent.defaults();
    final updated = change(current);
    setState(() {
      _content = updated;
      _saving = true;
    });
    try {
      await widget.repository.saveContent(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(successMessage ?? 'Konten landing diperbarui.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _editHero() async {
    final initial = _content?.hero ?? CompanyLandingContent.defaults().hero;
    final result = await showDialog<HeroSectionContent>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HeroSectionEditorDialog(initial: initial),
    );
    if (result != null) {
      await _updateContent(
        (current) => current.copyWith(hero: result),
        successMessage: 'Hero diperbarui.',
      );
    }
  }

  Future<void> _editAbout() async {
    final initial = _content?.about ?? CompanyLandingContent.defaults().about;
    final result = await showDialog<AboutSectionContent>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AboutSectionEditorDialog(initial: initial),
    );
    if (result != null) {
      await _updateContent(
        (current) => current.copyWith(about: result),
        successMessage: 'Section tentang diperbarui.',
      );
    }
  }

  Future<void> _editVisionMission() async {
    final initial = _content?.visionMission ??
        CompanyLandingContent.defaults().visionMission;
    final result = await showDialog<VisionMissionContent>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _VisionMissionEditorDialog(initial: initial),
    );
    if (result != null) {
      await _updateContent(
        (current) => current.copyWith(visionMission: result),
        successMessage: 'Visi & Misi diperbarui.',
      );
    }
  }

  Future<void> _editContact() async {
    final initial =
        _content?.contact ?? CompanyLandingContent.defaults().contact;
    final result = await showDialog<ContactSectionContent>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ContactSectionEditorDialog(initial: initial),
    );
    if (result != null) {
      await _updateContent(
        (current) => current.copyWith(contact: result),
        successMessage: 'Kontak diperbarui.',
      );
    }
  }

  Future<void> _editOrganization() async {
    final initial = _content?.organization ??
        CompanyLandingContent.defaults().organization;
    final result = await showDialog<OrganizationSectionContent>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OrganizationEditorDialog(initial: initial),
    );
    if (result != null) {
      await _updateContent(
        (current) => current.copyWith(organization: result),
        successMessage: 'Struktur organisasi diperbarui.',
      );
    }
  }

  Future<void> _resetSection(
    CompanyLandingContent Function(
      CompanyLandingContent current,
      CompanyLandingContent defaults,
    )
        builder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kembalikan ke default?'),
        content: const Text(
          'Konten akan dikembalikan ke versi bawaan aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, kembalikan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final defaults = CompanyLandingContent.defaults();
    await _updateContent(
      (current) => builder(current, defaults),
      successMessage: 'Konten dikembalikan ke default.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _content == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final content = _content!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _LandingSummaryCard(
                title: 'Beranda (Hero)',
                description: content.hero.subtitle,
                metadata:
                    'Feature ${content.hero.featureHighlights.length} · Statistik ${content.hero.stats.length}',
                onEdit: _editHero,
                onReset: () => _resetSection(
                  (current, defaults) =>
                      current.copyWith(hero: defaults.hero),
                ),
              ),
              _LandingSummaryCard(
                title: 'Tentang',
                description: content.about.description,
                metadata:
                    'Timeline ${content.about.timeline.length} · Nilai ${content.about.values.length}',
                onEdit: _editAbout,
                onReset: () => _resetSection(
                  (current, defaults) =>
                      current.copyWith(about: defaults.about),
                ),
              ),
              _LandingSummaryCard(
                title: 'Visi & Misi',
                description: content.visionMission.subtitle,
                metadata:
                    'Visi ${content.visionMission.visionPoints.length} · Misi ${content.visionMission.missionPoints.length}',
                onEdit: _editVisionMission,
                onReset: () => _resetSection(
                  (current, defaults) =>
                      current.copyWith(visionMission: defaults.visionMission),
                ),
              ),
              _LandingSummaryCard(
                title: 'Kontak',
                description: content.contact.subtitle,
                metadata:
                    'Kanal ${content.contact.channels.length}',
                onEdit: _editContact,
                onReset: () => _resetSection(
                  (current, defaults) =>
                      current.copyWith(contact: defaults.contact),
                ),
              ),
              _LandingSummaryCard(
                title: 'Struktur Organisasi',
                description: content.organization.heroSubtitle,
                metadata:
                    'Metric ${content.organization.metrics.length} · Leadership ${content.organization.leadership.length}',
                onEdit: _editOrganization,
                onReset: () => _resetSection(
                  (current, defaults) => current.copyWith(
                    organization: defaults.organization,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Muat ulang dari server'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LandingSummaryCard extends StatelessWidget {
  const _LandingSummaryCard({
    required this.title,
    required this.description,
    required this.metadata,
    required this.onEdit,
    required this.onReset,
  });

  final String title;
  final String description;
  final String metadata;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassContainer(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        gradientColors: [
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.04),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              metadata,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Reset default'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSectionEditorDialog extends StatefulWidget {
  const _HeroSectionEditorDialog({required this.initial});

  final HeroSectionContent initial;

  @override
  State<_HeroSectionEditorDialog> createState() =>
      _HeroSectionEditorDialogState();
}

class _HeroSectionEditorDialogState
    extends State<_HeroSectionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _badgeController;
  late final TextEditingController _titleLine1Controller;
  late final TextEditingController _titleLine2Controller;
  late final TextEditingController _subtitleController;
  late final TextEditingController _featuresController;
  late final TextEditingController _statsController;
  late final TextEditingController _primaryCtaController;
  late final TextEditingController _secondaryCtaController;

  @override
  void initState() {
    super.initState();
    final hero = widget.initial;
    _badgeController = TextEditingController(text: hero.badgeLabel);
    _titleLine1Controller = TextEditingController(text: hero.titleLine1);
    _titleLine2Controller = TextEditingController(text: hero.titleLine2);
    _subtitleController = TextEditingController(text: hero.subtitle);
    _featuresController =
        TextEditingController(text: hero.featureHighlights.join('\n'));
    _statsController = TextEditingController(
      text: hero.stats
          .map((stat) => '${stat.value} | ${stat.label} | ${stat.description}')
          .join('\n'),
    );
    _primaryCtaController =
        TextEditingController(text: hero.primaryCtaLabel);
    _secondaryCtaController =
        TextEditingController(text: hero.secondaryCtaLabel);
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _titleLine1Controller.dispose();
    _titleLine2Controller.dispose();
    _subtitleController.dispose();
    _featuresController.dispose();
    _statsController.dispose();
    _primaryCtaController.dispose();
    _secondaryCtaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Beranda (Hero)'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildField(_badgeController, 'Badge'),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _titleLine1Controller,
                        'Judul baris 1',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        _titleLine2Controller,
                        'Judul baris 2',
                      ),
                    ),
                  ],
                ),
                _buildField(
                  _subtitleController,
                  'Subjudul / deskripsi',
                  maxLines: 3,
                ),
                _buildField(
                  _featuresController,
                  'Highlight (pisahkan per baris)',
                  maxLines: 4,
                ),
                _buildField(
                  _statsController,
                  'Statistik (format: nilai | label | deskripsi per baris)',
                  maxLines: 4,
                ),
                _buildField(_primaryCtaController, 'Label CTA utama'),
                _buildField(_secondaryCtaController, 'Label CTA kedua'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _handleSubmit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Kolom wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  List<String> _splitLines(String input) {
    return input
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final features = _splitLines(_featuresController.text);
    final stats = _statsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split('|').map((p) => p.trim()).toList();
          if (parts.length < 3) return null;
          return HeroStatEntry(
            value: parts[0],
            label: parts[1],
            description: parts.sublist(2).join(' '),
          );
        })
        .whereType<HeroStatEntry>()
        .toList();
    final hero = HeroSectionContent(
      badgeLabel: _badgeController.text.trim(),
      titleLine1: _titleLine1Controller.text.trim(),
      titleLine2: _titleLine2Controller.text.trim(),
      subtitle: _subtitleController.text.trim(),
      featureHighlights: features,
      stats: stats,
      primaryCtaLabel: _primaryCtaController.text.trim(),
      secondaryCtaLabel: _secondaryCtaController.text.trim(),
    );
    Navigator.of(context).pop(hero);
  }
}
class _AboutSectionEditorDialog extends StatefulWidget {
  const _AboutSectionEditorDialog({required this.initial});

  final AboutSectionContent initial;

  @override
  State<_AboutSectionEditorDialog> createState() =>
      _AboutSectionEditorDialogState();
}

class _AboutSectionEditorDialogState
    extends State<_AboutSectionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _timelineController;
  late final TextEditingController _valuesController;

  @override
  void initState() {
    super.initState();
    final about = widget.initial;
    _titleController = TextEditingController(text: about.title);
    _subtitleController = TextEditingController(text: about.subtitle);
    _descriptionController =
        TextEditingController(text: about.description);
    _timelineController = TextEditingController(
      text: about.timeline
          .map((entry) => '${entry.title} | ${entry.description}')
          .join('\n'),
    );
    _valuesController = TextEditingController(
      text: about.values
          .map((value) => '${value.title} | ${value.description}')
          .join('\n'),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _timelineController.dispose();
    _valuesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Tentang Perusahaan'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildField(_titleController, 'Judul'),
                _buildField(_subtitleController, 'Subjudul'),
                _buildField(
                  _descriptionController,
                  'Deskripsi',
                  maxLines: 4,
                ),
                _buildField(
                  _timelineController,
                  'Timeline (format: tahun / judul | deskripsi per baris)',
                  maxLines: 4,
                ),
                _buildField(
                  _valuesController,
                  'Nilai utama (format: judul | deskripsi per baris)',
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _handleSubmit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Kolom wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final about = AboutSectionContent(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      description: _descriptionController.text.trim(),
      timeline: _timelineController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) {
            final parts = line.split('|').map((e) => e.trim()).toList();
            if (parts.length < 2) return null;
            return TimelineEntry(title: parts[0], description: parts[1]);
          })
          .whereType<TimelineEntry>()
          .toList(growable: false),
      values: _valuesController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) {
            final parts = line.split('|').map((e) => e.trim()).toList();
            if (parts.length < 2) return null;
            return ValueEntry(title: parts[0], description: parts[1]);
          })
          .whereType<ValueEntry>()
          .toList(growable: false),
    );
    Navigator.of(context).pop(about);
  }
}
class _VisionMissionEditorDialog extends StatefulWidget {
  const _VisionMissionEditorDialog({required this.initial});

  final VisionMissionContent initial;

  @override
  State<_VisionMissionEditorDialog> createState() =>
      _VisionMissionEditorDialogState();
}

class _VisionMissionEditorDialogState
    extends State<_VisionMissionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _visionTitleController;
  late final TextEditingController _visionStatementController;
  late final TextEditingController _visionPointsController;
  late final TextEditingController _missionTitleController;
  late final TextEditingController _missionPointsController;
  late final TextEditingController _coreValuesController;

  @override
  void initState() {
    super.initState();
    final content = widget.initial;
    _titleController = TextEditingController(text: content.title);
    _subtitleController = TextEditingController(text: content.subtitle);
    _visionTitleController =
        TextEditingController(text: content.visionTitle);
    _visionStatementController =
        TextEditingController(text: content.visionStatement);
    _visionPointsController = TextEditingController(
      text: content.visionPoints.join('\n'),
    );
    _missionTitleController =
        TextEditingController(text: content.missionTitle);
    _missionPointsController = TextEditingController(
      text: content.missionPoints.join('\n'),
    );
    _coreValuesController =
        TextEditingController(text: content.coreValues.join('\n'));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _visionTitleController.dispose();
    _visionStatementController.dispose();
    _visionPointsController.dispose();
    _missionTitleController.dispose();
    _missionPointsController.dispose();
    _coreValuesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Visi & Misi'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildField(_titleController, 'Judul section'),
                _buildField(_subtitleController, 'Subjudul section'),
                _buildField(_visionTitleController, 'Judul visi'),
                _buildField(
                  _visionStatementController,
                  'Pernyataan visi',
                  maxLines: 3,
                ),
                _buildField(
                  _visionPointsController,
                  'Poin visi (pisahkan per baris)',
                  maxLines: 4,
                ),
                _buildField(_missionTitleController, 'Judul misi'),
                _buildField(
                  _missionPointsController,
                  'Poin misi (pisahkan per baris)',
                  maxLines: 4,
                ),
                _buildField(
                  _coreValuesController,
                  'Nilai inti (pisahkan per baris)',
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _handleSubmit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Kolom wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final content = VisionMissionContent(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      visionTitle: _visionTitleController.text.trim(),
      visionStatement: _visionStatementController.text.trim(),
      visionPoints: _splitLines(_visionPointsController.text),
      missionTitle: _missionTitleController.text.trim(),
      missionPoints: _splitLines(_missionPointsController.text),
      coreValues: _splitLines(_coreValuesController.text),
    );
    Navigator.of(context).pop(content);
  }

  List<String> _splitLines(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}
class _ContactSectionEditorDialog extends StatefulWidget {
  const _ContactSectionEditorDialog({required this.initial});

  final ContactSectionContent initial;

  @override
  State<_ContactSectionEditorDialog> createState() =>
      _ContactSectionEditorDialogState();
}

class _ContactSectionEditorDialogState
    extends State<_ContactSectionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _primaryController;
  late final TextEditingController _secondaryController;
  late final TextEditingController _channelsController;

  @override
  void initState() {
    super.initState();
    final content = widget.initial;
    _titleController = TextEditingController(text: content.title);
    _subtitleController = TextEditingController(text: content.subtitle);
    _primaryController =
        TextEditingController(text: content.primaryActionLabel);
    _secondaryController =
        TextEditingController(text: content.secondaryActionLabel);
    _channelsController = TextEditingController(
      text: content.channels
          .map((channel) => '${channel.label} | ${channel.description}')
          .join('\n'),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _primaryController.dispose();
    _secondaryController.dispose();
    _channelsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Kontak & CTA'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildField(_titleController, 'Judul'),
                _buildField(_subtitleController, 'Subjudul', maxLines: 3),
                _buildField(_primaryController, 'Label CTA utama'),
                _buildField(_secondaryController, 'Label CTA kedua'),
                _buildField(
                  _channelsController,
                  'Daftar kanal (format: label | deskripsi per baris)',
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _handleSubmit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Kolom wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final channels = _channelsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split('|').map((p) => p.trim()).toList();
          if (parts.length < 2) return null;
          return ContactChannel(label: parts[0], description: parts[1]);
        })
        .whereType<ContactChannel>()
        .toList(growable: false);
    final content = ContactSectionContent(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      primaryActionLabel: _primaryController.text.trim(),
      secondaryActionLabel: _secondaryController.text.trim(),
      channels: channels,
    );
    Navigator.of(context).pop(content);
  }
}
class _OrganizationEditorDialog extends StatefulWidget {
  const _OrganizationEditorDialog({required this.initial});

  final OrganizationSectionContent initial;

  @override
  State<_OrganizationEditorDialog> createState() =>
      _OrganizationEditorDialogState();
}

class _OrganizationEditorDialogState
    extends State<_OrganizationEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _heroTitleController;
  late final TextEditingController _heroSubtitleController;
  late final TextEditingController _metricsController;
  late final TextEditingController _leadershipController;
  late final TextEditingController _divisionsController;
  late final TextEditingController _supportUnitsController;
  late final List<TextEditingController> _controllers;
  OrganizationSectionContent? _previewContent;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    final content = widget.initial;
    _heroTitleController = TextEditingController(text: content.heroTitle);
    _heroSubtitleController =
        TextEditingController(text: content.heroSubtitle);
    _metricsController = TextEditingController(
      text: content.metrics
          .map(
            (metric) =>
                '${metric.value} | ${metric.label} | ${metric.caption}',
          )
          .join('\n'),
    );
    _leadershipController = TextEditingController(
      text: content.leadership
          .map(
            (role) =>
                '${role.name} | ${role.title} | ${role.mission} | ${role.focusAreas.join(', ')}',
          )
          .join('\n'),
    );
    _divisionsController = TextEditingController(
      text: content.divisions
          .map(
            (division) =>
                '${division.name} | ${division.mandate} | ${division.lead} | ${division.leadTitle} | ${division.focusAreas.join(', ')} | ${division.squads.join(', ')}',
          )
          .join('\n'),
    );
    _supportUnitsController = TextEditingController(
      text: content.supportUnits
          .map(
            (unit) =>
                '${unit.name} | ${unit.lead} | ${unit.mandate} | ${unit.services.join(', ')}',
          )
          .join('\n'),
    );
    _controllers = [
      _heroTitleController,
      _heroSubtitleController,
      _metricsController,
      _leadershipController,
      _divisionsController,
      _supportUnitsController,
    ];
    for (final controller in _controllers) {
      controller.addListener(_refreshPreview);
    }
    _refreshPreview();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_refreshPreview);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Struktur Organisasi'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildField(
                  _heroTitleController,
                  'Judul section',
                  required: true,
                ),
                _buildField(
                  _heroSubtitleController,
                  'Subjudul section',
                  maxLines: 2,
                  required: true,
                ),
                _buildField(
                  _metricsController,
                  'Metric (format: Nilai | Label | Caption per baris)',
                  maxLines: 5,
                  helperText:
                      'Contoh: 4 | Tribe | Stream utama ...',
                ),
                _buildField(
                  _leadershipController,
                  'Manajemen Puncak (Nama | Jabatan | Misi | Fokus koma)',
                  maxLines: 6,
                  helperText:
                      'Fokus pisahkan dengan koma, misal: Culture, Innovation',
                ),
                _buildField(
                  _divisionsController,
                  'Divisi (Nama | Mandat | Lead | Jabatan Lead | Fokus koma | Squad koma)',
                  maxLines: 6,
                  helperText:
                      'Kosongkan fokus/squad bila tidak ada, tapi pertahankan tanda |',
                ),
                _buildField(
                  _supportUnitsController,
                  'Unit Pendukung (Nama | Lead | Mandat | Layanan koma)',
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                _buildPreviewPanel(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _handleSubmit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    final theme = Theme.of(context);
    if (_previewError != null) {
      return GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        gradientColors: [
          Colors.redAccent.withOpacity(0.25),
          Colors.redAccent.withOpacity(0.08),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _previewError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final preview = _previewContent;
    if (preview == null) {
      return Text(
        'Isi beberapa kolom untuk melihat preview.',
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview realtime',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.heroTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                preview.heroSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const Divider(height: 28),
              if (preview.metrics.isNotEmpty) ...[
                Text(
                  'Metrics',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: preview.metrics
                      .map(
                        (metric) => Chip(
                          label: Text('${metric.value} ${metric.label}'),
                          avatar: const Icon(
                            Icons.stacked_bar_chart_rounded,
                            size: 16,
                          ),
                          backgroundColor:
                              Colors.white.withOpacity(0.08),
                          labelStyle: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
              ],
              if (preview.leadership.isNotEmpty) ...[
                Text(
                  'Manajemen Puncak',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...preview.leadership.take(3).map(
                  (role) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      role.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${role.title}\n${role.mission}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                if (preview.leadership.length > 3)
                  Text(
                    '+ ${preview.leadership.length - 3} peran lainnya',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (preview.divisions.isNotEmpty) ...[
                Text(
                  'Divisi',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...preview.divisions.take(2).map(
                  (division) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          division.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${division.lead} • ${division.leadTitle}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          division.mandate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (preview.divisions.length > 2)
                  Text(
                    '+ ${preview.divisions.length - 2} divisi lainnya',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (preview.supportUnits.isNotEmpty) ...[
                Text(
                  'Unit Pendukung',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: preview.supportUnits
                      .map(
                        (unit) => Chip(
                          label: Text(unit.name),
                          avatar: const Icon(
                            Icons.support_agent_rounded,
                            size: 16,
                          ),
                          backgroundColor:
                              Colors.white.withOpacity(0.08),
                          labelStyle: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool required = false,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Kolom wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final content = _buildContentFromInputs();
      Navigator.of(context).pop(content);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _refreshPreview() {
    try {
      final content = _buildContentFromInputs();
      setState(() {
        _previewContent = content;
        _previewError = null;
      });
    } catch (error) {
      setState(() {
        _previewContent = null;
        _previewError = error.toString();
      });
    }
  }

  OrganizationSectionContent _buildContentFromInputs() {
    return OrganizationSectionContent(
      heroTitle: _heroTitleController.text.trim(),
      heroSubtitle: _heroSubtitleController.text.trim(),
      metrics: _parseMetrics(_metricsController.text),
      leadership: _parseLeadership(_leadershipController.text),
      divisions: _parseDivisions(_divisionsController.text),
      supportUnits: _parseSupportUnits(_supportUnitsController.text),
    );
  }

  List<OrgMetricEntry> _parseMetrics(String raw) {
    final lines = _lines(raw);
    if (lines.isEmpty) return const [];
    final entries = <OrgMetricEntry>[];
    for (var i = 0; i < lines.length; i++) {
      final segments = lines[i].split('|').map((s) => s.trim()).toList();
      if (segments.length < 3 ||
          segments[0].isEmpty ||
          segments[1].isEmpty ||
          segments[2].isEmpty) {
        throw FormatException(
          'Baris ${i + 1} metric harus "Nilai | Label | Caption".',
        );
      }
      entries.add(
        OrgMetricEntry(
          value: segments[0],
          label: segments[1],
          caption: segments[2],
        ),
      );
    }
    return entries;
  }

  List<LeadershipEntry> _parseLeadership(String raw) {
    final lines = _lines(raw);
    if (lines.isEmpty) return const [];
    final entries = <LeadershipEntry>[];
    for (var i = 0; i < lines.length; i++) {
      final segments = lines[i].split('|').map((s) => s.trim()).toList();
      if (segments.length < 3 ||
          segments[0].isEmpty ||
          segments[1].isEmpty ||
          segments[2].isEmpty) {
        throw FormatException(
          'Baris ${i + 1} leadership harus "Nama | Jabatan | Misi | Fokus".',
        );
      }
      final focusRaw = segments.length >= 4 ? segments[3] : '';
      entries.add(
        LeadershipEntry(
          name: segments[0],
          title: segments[1],
          mission: segments[2],
          focusAreas: _splitList(focusRaw),
        ),
      );
    }
    return entries;
  }

  List<OrgDivisionEntry> _parseDivisions(String raw) {
    final lines = _lines(raw);
    if (lines.isEmpty) return const [];
    final entries = <OrgDivisionEntry>[];
    for (var i = 0; i < lines.length; i++) {
      final segments = lines[i].split('|').map((s) => s.trim()).toList();
      if (segments.length < 4 ||
          segments[0].isEmpty ||
          segments[1].isEmpty ||
          segments[2].isEmpty ||
          segments[3].isEmpty) {
        throw FormatException(
          'Baris ${i + 1} divisi harus "Nama | Mandat | Lead | Jabatan Lead | Fokus | Squad".',
        );
      }
      final focusRaw = segments.length >= 5 ? segments[4] : '';
      final squadsRaw = segments.length >= 6 ? segments[5] : '';
      entries.add(
        OrgDivisionEntry(
          name: segments[0],
          mandate: segments[1],
          lead: segments[2],
          leadTitle: segments[3],
          focusAreas: _splitList(focusRaw),
          squads: _splitList(squadsRaw),
        ),
      );
    }
    return entries;
  }

  List<SupportUnitEntry> _parseSupportUnits(String raw) {
    final lines = _lines(raw);
    if (lines.isEmpty) return const [];
    final entries = <SupportUnitEntry>[];
    for (var i = 0; i < lines.length; i++) {
      final segments = lines[i].split('|').map((s) => s.trim()).toList();
      if (segments.length < 3 ||
          segments[0].isEmpty ||
          segments[1].isEmpty ||
          segments[2].isEmpty) {
        throw FormatException(
          'Baris ${i + 1} unit pendukung harus "Nama | Lead | Mandat | Layanan".',
        );
      }
      final servicesRaw = segments.length >= 4 ? segments[3] : '';
      entries.add(
        SupportUnitEntry(
          name: segments[0],
          lead: segments[1],
          mandate: segments[2],
          services: _splitList(servicesRaw),
        ),
      );
    }
    return entries;
  }

  List<String> _lines(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _splitList(String raw) {
    if (raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.layers_outlined,
            size: 56,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada profil perusahaan',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mulai dengan menambahkan entitas baru agar tampil di landing page.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat profil'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Gagal memuat data',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 360,
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _CompanyProfileEditorDialog extends StatefulWidget {
  const _CompanyProfileEditorDialog({
    required this.repository,
    this.profile,
  });

  final CompanyProfileRepository repository;
  final CompanyProfileData? profile;

  @override
  State<_CompanyProfileEditorDialog> createState() =>
      _CompanyProfileEditorDialogState();
}

class _CompanyProfileEditorDialogState
    extends State<_CompanyProfileEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _legalTypeController;
  late final TextEditingController _taglineController;
  late final TextEditingController _summaryController;
  late final TextEditingController _historyController;
  late final TextEditingController _coreValuesController;
  late final TextEditingController _focusAreasController;
  late final TextEditingController _brandColorController;
  late final TextEditingController _sortOrderController;
  bool _isPublished = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController =
        TextEditingController(text: profile?.displayName ?? '');
    _legalTypeController =
        TextEditingController(text: profile?.legalType ?? '');
    _taglineController = TextEditingController(text: profile?.tagline ?? '');
    _summaryController = TextEditingController(text: profile?.summary ?? '');
    _historyController = TextEditingController(text: profile?.history ?? '');
    _coreValuesController = TextEditingController(
      text: profile?.coreValues.join('\n') ?? '',
    );
    _focusAreasController = TextEditingController(
      text: profile?.focusAreas.join('\n') ?? '',
    );
    _brandColorController =
        TextEditingController(text: profile?.brandColorHex ?? '');
    _sortOrderController = TextEditingController(
      text: (profile?.sortOrder ?? 0).toString(),
    );
    _isPublished = profile?.isPublished ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _legalTypeController.dispose();
    _taglineController.dispose();
    _summaryController.dispose();
    _historyController.dispose();
    _coreValuesController.dispose();
    _focusAreasController.dispose();
    _brandColorController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    setState(() => _saving = true);
    try {
      final rawColor = _brandColorController.text.trim();
      final color = rawColor.isEmpty
          ? null
          : CompanyProfileData.colorFromHex(rawColor);
      final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;
      final id = widget.profile?.id ?? widget.repository.generateId();

      final profile = CompanyProfileData(
        id: id,
        displayName: _nameController.text.trim(),
        legalType: _legalTypeController.text.trim(),
        tagline: _taglineController.text.trim(),
        summary: _summaryController.text.trim(),
        history: _historyController.text.trim(),
        coreValues: _splitLines(_coreValuesController.text),
        focusAreas: _splitLines(_focusAreasController.text),
        brandColor: color,
        isPublished: _isPublished,
        sortOrder: sortOrder,
        createdAt: widget.profile?.createdAt,
      );

      await widget.repository.saveProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan profil: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.profile != null;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: const Color(0xFF101522),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isEditing ? 'Edit Profil' : 'Tambah Profil',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Nama Perusahaan *',
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _legalTypeController,
                                label: 'Badan Hukum *',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _taglineController,
                                label: 'Tagline *',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _summaryController,
                          label: 'Ringkasan *',
                          minLines: 2,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _historyController,
                          label: 'Sejarah *',
                          minLines: 2,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _coreValuesController,
                          label: 'Nilai Inti (pisahkan per baris)',
                          minLines: 2,
                          maxLines: 4,
                          validator: null,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _focusAreasController,
                          label: 'Fokus Layanan (pisahkan per baris)',
                          minLines: 2,
                          maxLines: 4,
                          validator: null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _brandColorController,
                                label: 'Warna Brand (hex, contoh #1C63FF)',
                                validator: _validateHexColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _sortOrderController,
                                label: 'Urutan tampil',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tayangkan di landing page'),
                          subtitle: const Text(
                            'Nonaktifkan bila konten masih disiapkan.',
                          ),
                          value: _isPublished,
                          onChanged: (value) =>
                              setState(() => _isPublished = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Batal'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _saving ? null : _handleSubmit,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateHexColor(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll('#', '').trim();
    final regex = RegExp(r'^[0-9a-fA-F]{6}$');
    if (!regex.hasMatch(cleaned)) {
      return 'Gunakan format hex 6 digit, contoh 1C63FF';
    }
    return null;
  }

  TextFormField _buildTextField({
    required TextEditingController controller,
    required String label,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Kolom wajib diisi';
            }
            return null;
          },
    );
  }

  List<String> _splitLines(String input) {
    return input
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}
