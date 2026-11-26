import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyLandingContent {
  const CompanyLandingContent({
    required this.hero,
    required this.about,
    required this.visionMission,
    required this.contact,
    required this.organization,
    this.updatedAt,
  });

  factory CompanyLandingContent.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return CompanyLandingContent(
      hero: HeroSectionContent.fromMap(
        Map<String, dynamic>.from(data['hero'] ?? const {}),
      ),
      about: AboutSectionContent.fromMap(
        Map<String, dynamic>.from(data['about'] ?? const {}),
      ),
      visionMission: VisionMissionContent.fromMap(
        Map<String, dynamic>.from(data['visionMission'] ?? const {}),
      ),
      contact: ContactSectionContent.fromMap(
        Map<String, dynamic>.from(data['contact'] ?? const {}),
      ),
      organization: OrganizationSectionContent.fromMap(
        Map<String, dynamic>.from(data['organization'] ?? const {}),
      ),
      updatedAt: _asDate(data['updatedAt']),
    );
  }

  final HeroSectionContent hero;
  final AboutSectionContent about;
  final VisionMissionContent visionMission;
  final ContactSectionContent contact;
  final OrganizationSectionContent organization;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'hero': hero.toMap(),
      'about': about.toMap(),
      'visionMission': visionMission.toMap(),
      'contact': contact.toMap(),
      'organization': organization.toMap(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    }..removeWhere((key, value) => value == null);
  }

  CompanyLandingContent copyWith({
    HeroSectionContent? hero,
    AboutSectionContent? about,
    VisionMissionContent? visionMission,
    ContactSectionContent? contact,
    OrganizationSectionContent? organization,
    DateTime? updatedAt,
  }) {
    return CompanyLandingContent(
      hero: hero ?? this.hero,
      about: about ?? this.about,
      visionMission: visionMission ?? this.visionMission,
      contact: contact ?? this.contact,
      organization: organization ?? this.organization,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static CompanyLandingContent defaults() => CompanyLandingContent(
        hero: HeroSectionContent.defaults(),
        about: AboutSectionContent.defaults(),
        visionMission: VisionMissionContent.defaults(),
        contact: ContactSectionContent.defaults(),
        organization: OrganizationSectionContent.defaults(),
        updatedAt: DateTime.now(),
      );
}

class HeroSectionContent {
  const HeroSectionContent({
    required this.badgeLabel,
    required this.titleLine1,
    required this.titleLine2,
    required this.subtitle,
    required this.featureHighlights,
    required this.stats,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
  });

  factory HeroSectionContent.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) return HeroSectionContent.defaults();
    return HeroSectionContent(
      badgeLabel: _asString(map['badgeLabel']) ?? '',
      titleLine1: _asString(map['titleLine1']) ?? '',
      titleLine2: _asString(map['titleLine2']) ?? '',
      subtitle: _asString(map['subtitle']) ?? '',
      featureHighlights: _stringList(map['featureHighlights']),
      stats: _list(map['stats'])
          .map((item) =>
              HeroStatEntry.fromMap(Map<String, dynamic>.from(item ?? {})))
          .toList(growable: false),
      primaryCtaLabel: _asString(map['primaryCtaLabel']) ?? '',
      secondaryCtaLabel: _asString(map['secondaryCtaLabel']) ?? '',
    );
  }

  final String badgeLabel;
  final String titleLine1;
  final String titleLine2;
  final String subtitle;
  final List<String> featureHighlights;
  final List<HeroStatEntry> stats;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;

  Map<String, dynamic> toMap() {
    return {
      'badgeLabel': badgeLabel,
      'titleLine1': titleLine1,
      'titleLine2': titleLine2,
      'subtitle': subtitle,
      'featureHighlights': featureHighlights,
      'stats': stats.map((stat) => stat.toMap()).toList(growable: false),
      'primaryCtaLabel': primaryCtaLabel,
      'secondaryCtaLabel': secondaryCtaLabel,
    };
  }

  static HeroSectionContent defaults() => HeroSectionContent(
        badgeLabel: 'Futuristic Glass Ecosystem',
        titleLine1: 'Transformasi Digital',
        titleLine2: 'untuk Perusahaan Modern',
        subtitle:
            'Kami membantu organisasi menghadirkan pengalaman digital futuristik '
            'dengan sentuhan desain glassmorphism, integrasi cloud, dan otomasi cerdas.',
        featureHighlights: const [
          'Keamanan Enterprise',
          'AI & Otomasi',
          'Integrasi Sistem',
          'Skalabilitas Cloud',
        ],
        stats: const [
          HeroStatEntry(
            value: '12+',
            label: 'Produk Internal',
            description: 'Platform modul admin, absensi, dan field force.',
          ),
          HeroStatEntry(
            value: '98%',
            label: 'Kepuasan Klien',
            description: 'Delivery tepat waktu dan dukungan konsultatif.',
          ),
          HeroStatEntry(
            value: '4-8',
            label: 'Minggu Implementasi',
            description: 'Discovery hingga peluncuran modul prioritas.',
          ),
        ],
        primaryCtaLabel: 'Diskusikan Proyek',
        secondaryCtaLabel: 'Jadwalkan Demo',
      );
}

class HeroStatEntry {
  const HeroStatEntry({
    required this.value,
    required this.label,
    required this.description,
  });

  factory HeroStatEntry.fromMap(Map<String, dynamic> map) {
    return HeroStatEntry(
      value: _asString(map['value']) ?? '',
      label: _asString(map['label']) ?? '',
      description: _asString(map['description']) ?? '',
    );
  }

  final String value;
  final String label;
  final String description;

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'label': label,
      'description': description,
    };
  }
}

class AboutSectionContent {
  const AboutSectionContent({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.timeline,
    required this.values,
  });

  factory AboutSectionContent.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) return AboutSectionContent.defaults();
    return AboutSectionContent(
      title: _asString(map['title']) ?? '',
      subtitle: _asString(map['subtitle']) ?? '',
      description: _asString(map['description']) ?? '',
      timeline: _list(map['timeline'])
          .map((item) => TimelineEntry.fromMap(
              Map<String, dynamic>.from(item ?? const {})))
          .toList(growable: false),
      values: _list(map['values'])
          .map((item) => ValueEntry.fromMap(
              Map<String, dynamic>.from(item ?? const {})))
          .toList(growable: false),
    );
  }

  final String title;
  final String subtitle;
  final String description;
  final List<TimelineEntry> timeline;
  final List<ValueEntry> values;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'timeline': timeline.map((entry) => entry.toMap()).toList(),
      'values': values.map((value) => value.toMap()).toList(),
    };
  }

  static AboutSectionContent defaults() => AboutSectionContent(
        title: 'Tentang Kami',
        subtitle:
            'Partner transformasi digital dengan pendekatan desain, inovasi, dan data.',
        description:
            'Cipta Vera Mandiri Digital (CVM Digital) fokus membangun platform digital '
            'yang berdampak bagi operasi bisnis. Kami memadukan strategis bisnis '
            'dengan desain modern untuk menciptakan solusi yang mudah diterapkan.',
        timeline: const [
          TimelineEntry(
            title: '2012',
            description: 'Berdiri sebagai konsultan sistem internal',
          ),
          TimelineEntry(
            title: '2016',
            description: 'Meluncurkan platform absensi berbasis AI',
          ),
          TimelineEntry(
            title: '2021',
            description: 'Ekspansi ke solusi cloud multi-bisnis',
          ),
        ],
        values: const [
          ValueEntry(
            title: 'Inovasi Berkelanjutan',
            description:
                'Selalu mengembangkan modul baru berdasarkan feedback pengguna.',
          ),
          ValueEntry(
            title: 'Kolaborasi Transparan',
            description:
                'Melibatkan stakeholder sejak awal hingga peluncuran sistem.',
          ),
          ValueEntry(
            title: 'Kualitas Enterprise',
            description:
                'Setiap fitur melewati pengujian keamanan dan performa ketat.',
          ),
        ],
      );
}

class TimelineEntry {
  const TimelineEntry({required this.title, required this.description});

  factory TimelineEntry.fromMap(Map<String, dynamic> map) {
    return TimelineEntry(
      title: _asString(map['title']) ?? '',
      description: _asString(map['description']) ?? '',
    );
  }

  final String title;
  final String description;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
    };
  }
}

class ValueEntry {
  const ValueEntry({required this.title, required this.description});

  factory ValueEntry.fromMap(Map<String, dynamic> map) {
    return ValueEntry(
      title: _asString(map['title']) ?? '',
      description: _asString(map['description']) ?? '',
    );
  }

  final String title;
  final String description;

  Map<String, dynamic> toMap() {
    return {'title': title, 'description': description};
  }
}

class VisionMissionContent {
  const VisionMissionContent({
    required this.title,
    required this.subtitle,
    required this.visionTitle,
    required this.visionStatement,
    required this.visionPoints,
    required this.missionTitle,
    required this.missionPoints,
    required this.coreValues,
  });

  factory VisionMissionContent.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) return VisionMissionContent.defaults();
    return VisionMissionContent(
      title: _asString(map['title']) ?? '',
      subtitle: _asString(map['subtitle']) ?? '',
      visionTitle: _asString(map['visionTitle']) ?? '',
      visionStatement: _asString(map['visionStatement']) ?? '',
      visionPoints: _stringList(map['visionPoints']),
      missionTitle: _asString(map['missionTitle']) ?? '',
      missionPoints: _stringList(map['missionPoints']),
      coreValues: _stringList(map['coreValues']),
    );
  }

  final String title;
  final String subtitle;
  final String visionTitle;
  final String visionStatement;
  final List<String> visionPoints;
  final String missionTitle;
  final List<String> missionPoints;
  final List<String> coreValues;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'visionTitle': visionTitle,
      'visionStatement': visionStatement,
      'visionPoints': visionPoints,
      'missionTitle': missionTitle,
      'missionPoints': missionPoints,
      'coreValues': coreValues,
    };
  }

  static VisionMissionContent defaults() => VisionMissionContent(
        title: 'Visi & Misi',
        subtitle:
            'Kompas strategis kami dalam membangun ekosistem teknologi.',
        visionTitle: 'Visi',
        visionStatement:
            'Menjadi mitra strategis dalam menghadirkan pengalaman operasi digital yang imersif dan berkelanjutan.',
        visionPoints: const [
          'Meningkatkan value chain klien melalui ekosistem produk digital.',
          'Menyelaraskan desain futuristik dengan kesiapan operasional lapangan.',
          'Mengakselerasi transformasi data-driven di setiap unit bisnis.',
        ],
        missionTitle: 'Misi',
        missionPoints: const [
          'Merancang solusi glassmorphism yang adaptif dan intuitif.',
          'Membangun ekosistem AI + automation untuk efisiensi proses.',
          'Mengintegrasikan insight lintas divisi guna meningkatkan keputusan.',
        ],
        coreValues: const [
          'Eksperimen cerdas & terukur',
          'Obsesi pada pengguna & klien',
          'Kolaborasi lintas disiplin',
          'Kecepatan dengan kualitas',
        ],
      );
}

class ContactSectionContent {
  const ContactSectionContent({
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.secondaryActionLabel,
    required this.channels,
  });

  factory ContactSectionContent.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) return ContactSectionContent.defaults();
    return ContactSectionContent(
      title: _asString(map['title']) ?? '',
      subtitle: _asString(map['subtitle']) ?? '',
      primaryActionLabel: _asString(map['primaryActionLabel']) ?? '',
      secondaryActionLabel: _asString(map['secondaryActionLabel']) ?? '',
      channels: _list(map['channels'])
          .map((item) => ContactChannel.fromMap(
              Map<String, dynamic>.from(item ?? const {})))
          .toList(growable: false),
    );
  }

  final String title;
  final String subtitle;
  final String primaryActionLabel;
  final String secondaryActionLabel;
  final List<ContactChannel> channels;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'primaryActionLabel': primaryActionLabel,
      'secondaryActionLabel': secondaryActionLabel,
      'channels': channels.map((channel) => channel.toMap()).toList(),
    };
  }

  static ContactSectionContent defaults() => const ContactSectionContent(
        title: 'Siap untuk menghadirkan pengalaman digital futuristik?',
        subtitle:
            'Tim kami siap membantu mendesain roadmap transformasi digital '
            'dan mengimplementasikan teknologi glassmorphism yang konsisten '
            'dengan dasbor admin Anda.',
        primaryActionLabel: 'Kirim Email',
        secondaryActionLabel: 'Atur Konsultasi',
        channels: [
          ContactChannel(
            label: 'Alamat',
            description: 'Jl. Budi No. 123, Bandung - Indonesia',
          ),
          ContactChannel(
            label: 'Jam Operasional',
            description: 'Senin - Jumat, 09.00 - 18.00 WIB',
          ),
          ContactChannel(
            label: 'Media Sosial',
            description: '@cvmdigital (LinkedIn, Instagram)',
          ),
        ],
      );
}

class ContactChannel {
  const ContactChannel({
    required this.label,
    required this.description,
  });

  factory ContactChannel.fromMap(Map<String, dynamic> map) {
    return ContactChannel(
      label: _asString(map['label']) ?? '',
      description: _asString(map['description']) ?? '',
    );
  }

  final String label;
  final String description;

  Map<String, dynamic> toMap() {
    return {'label': label, 'description': description};
  }
}

class OrganizationSectionContent {
  const OrganizationSectionContent({
    required this.heroTitle,
    required this.heroSubtitle,
    required this.metrics,
    required this.leadership,
    required this.divisions,
    required this.supportUnits,
  });

  factory OrganizationSectionContent.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) return OrganizationSectionContent.defaults();
    return OrganizationSectionContent(
      heroTitle: _asString(map['heroTitle']) ?? '',
      heroSubtitle: _asString(map['heroSubtitle']) ?? '',
      metrics: _list(map['metrics'])
          .map((item) => OrgMetricEntry.fromMap(
              Map<String, dynamic>.from(item ?? const {})))
          .toList(growable: false),
      leadership: _list(map['leadership'])
          .map((item) => LeadershipEntry.fromMap(
              Map<String, dynamic>.from(item ?? const {})))
          .toList(growable: false),
      divisions: _list(map['divisions'])
          .map((item) => OrgDivisionEntry.fromMap(
              Map<String, dynamic>.from(item ?? const {})))
          .toList(growable: false),
      supportUnits: _list(map['supportUnits'])
          .map((item) => SupportUnitEntry.fromMap(
              Map<String, dynamic>.from(item ?? const {})))
          .toList(growable: false),
    );
  }

  final String heroTitle;
  final String heroSubtitle;
  final List<OrgMetricEntry> metrics;
  final List<LeadershipEntry> leadership;
  final List<OrgDivisionEntry> divisions;
  final List<SupportUnitEntry> supportUnits;

  Map<String, dynamic> toMap() {
    return {
      'heroTitle': heroTitle,
      'heroSubtitle': heroSubtitle,
      'metrics': metrics.map((metric) => metric.toMap()).toList(),
      'leadership': leadership.map((role) => role.toMap()).toList(),
      'divisions': divisions.map((division) => division.toMap()).toList(),
      'supportUnits':
          supportUnits.map((unit) => unit.toMap()).toList(growable: false),
    };
  }

  static OrganizationSectionContent defaults() =>
      const OrganizationSectionContent(
        heroTitle: 'Struktur Organisasi',
        heroSubtitle: 'Blueprint orkestrasi tim CVM Digital',
        metrics: [
          OrgMetricEntry(
            value: '4',
            label: 'Tribe',
            caption:
                'Stream utama yang memimpin discovery, delivery, dan value realisation.',
          ),
          OrgMetricEntry(
            value: '8',
            label: 'Squad',
            caption:
                'Tim lintas-disiplin yang bergerak lincah end-to-end untuk klien.',
          ),
          OrgMetricEntry(
            value: '6',
            label: 'Practice Guild',
            caption:
                'Komunitas kompetensi untuk standarisasi tools, pattern, dan quality.',
          ),
          OrgMetricEntry(
            value: '24',
            label: 'Key People',
            caption:
                'Lead & principal yang menjadi enabler eksekusi dan coaching talent.',
          ),
        ],
        leadership: [
          LeadershipEntry(
            name: 'Vera Ayu Prameswari',
            title: 'Chief Executive Officer',
            mission:
                'Menetapkan North Star perusahaan, menjaga budaya inovasi, serta memimpin kemitraan strategis level nasional.',
            focusAreas: ['Culture', 'Strategic Alliance', 'Innovation'],
          ),
          LeadershipEntry(
            name: 'Reyhan Mahardika',
            title: 'Chief Operating Officer',
            mission:
                'Mengorkestrasi eksekusi lintas tribe, memantau performa OKR, serta memastikan pengelolaan risiko operasional.',
            focusAreas: [
              'Delivery Excellence',
              'Risk Control',
              'Business Continuity',
            ],
          ),
          LeadershipEntry(
            name: 'Fikri Nugraha',
            title: 'Chief Technology Officer',
            mission:
                'Mengarahkan arsitektur platform, keamanan, dan roadmap teknologi untuk menjaga keunggulan produk.',
            focusAreas: [
              'Platform Strategy',
              'Security',
              'Engineering Enablement',
            ],
          ),
          LeadershipEntry(
            name: 'Nayla Iswari',
            title: 'Chief Commercial Officer',
            mission:
                'Mengembangkan proposisi nilai, membina relasi klien, dan menjaga experience omni-channel CVM Digital.',
            focusAreas: [
              'Client Success',
              'Revenue Growth',
              'Brand Experience',
            ],
          ),
        ],
        divisions: [
          OrgDivisionEntry(
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
          ),
          OrgDivisionEntry(
            name: 'Engineering & Platform',
            mandate:
                'Mengembangkan platform glass kami, memastikan reliability, security, dan scalability di seluruh solusi.',
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
          ),
          OrgDivisionEntry(
            name: 'Data & AI Studio',
            mandate:
                'Mengolah data operasional menjadi insight yang actionable dengan mengadopsi AI dan advanced analytics.',
            lead: 'Raras Dwiputri',
            leadTitle: 'Lead of AI Studio',
            focusAreas: [
              'Data Product',
              'AI Enablement',
              'Insight-as-a-Service',
            ],
            squads: [
              'Insight Lab',
              'Applied AI Squad',
              'Data Steward Guild',
            ],
          ),
          OrgDivisionEntry(
            name: 'Commercial & Growth',
            mandate:
                'Membangun relasi kemitraan, mengelola pipeline penawaran, dan memastikan adopsi solusi berkelanjutan.',
            lead: 'Rizky Hartanto',
            leadTitle: 'Head of Commercial',
            focusAreas: [
              'Account Based Marketing',
              'Client Onboarding',
              'Experience Enablement',
            ],
            squads: [
              'Growth Squad',
              'Client Success Circle',
              'Comms & Brand Pod',
            ],
          ),
        ],
        supportUnits: [
          SupportUnitEntry(
            name: 'Finance & Compliance',
            lead: 'Dinda Maulani – Head of Finance & Legal',
            mandate:
                'Menjaga tata kelola laporan, perpajakan, dan compliance project dengan metodologi agile finance.',
            services: [
              'Financial Planning & Analysis',
              'Procurement & Asset',
              'Legal & Compliance Desk',
            ],
          ),
          SupportUnitEntry(
            name: 'People & Culture',
            lead: 'Ratri Kumala – Head of People & Culture',
            mandate:
                'Mengembangkan talenta unggul melalui program hiring, academy, dan engagement lintas tribe.',
            services: [
              'People Operations',
              'Talent Development',
              'Employer Branding',
            ],
          ),
          SupportUnitEntry(
            name: 'Strategic Office',
            lead: 'Yosua Firmansyah – Director of Strategy',
            mandate:
                'Mengawal eksekusi strategi korporat, risk management, dan portofolio inisiatif lintas unit.',
            services: [
              'Strategy Management Office',
              'Risk & Assurance',
              'Transformation Program',
            ],
          ),
        ],
      );
}

class OrgMetricEntry {
  const OrgMetricEntry({
    required this.value,
    required this.label,
    required this.caption,
  });

  factory OrgMetricEntry.fromMap(Map<String, dynamic> map) {
    return OrgMetricEntry(
      value: _asString(map['value']) ?? '',
      label: _asString(map['label']) ?? '',
      caption: _asString(map['caption']) ?? '',
    );
  }

  final String value;
  final String label;
  final String caption;

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'label': label,
      'caption': caption,
    };
  }
}

class LeadershipEntry {
  const LeadershipEntry({
    required this.name,
    required this.title,
    required this.mission,
    required this.focusAreas,
  });

  factory LeadershipEntry.fromMap(Map<String, dynamic> map) {
    return LeadershipEntry(
      name: _asString(map['name']) ?? '',
      title: _asString(map['title']) ?? '',
      mission: _asString(map['mission']) ?? '',
      focusAreas: _stringList(map['focusAreas']),
    );
  }

  final String name;
  final String title;
  final String mission;
  final List<String> focusAreas;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'title': title,
      'mission': mission,
      'focusAreas': focusAreas,
    };
  }
}

class OrgDivisionEntry {
  const OrgDivisionEntry({
    required this.name,
    required this.mandate,
    required this.lead,
    required this.leadTitle,
    required this.focusAreas,
    required this.squads,
  });

  factory OrgDivisionEntry.fromMap(Map<String, dynamic> map) {
    return OrgDivisionEntry(
      name: _asString(map['name']) ?? '',
      mandate: _asString(map['mandate']) ?? '',
      lead: _asString(map['lead']) ?? '',
      leadTitle: _asString(map['leadTitle']) ?? '',
      focusAreas: _stringList(map['focusAreas']),
      squads: _stringList(map['squads']),
    );
  }

  final String name;
  final String mandate;
  final String lead;
  final String leadTitle;
  final List<String> focusAreas;
  final List<String> squads;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mandate': mandate,
      'lead': lead,
      'leadTitle': leadTitle,
      'focusAreas': focusAreas,
      'squads': squads,
    };
  }
}

class SupportUnitEntry {
  const SupportUnitEntry({
    required this.name,
    required this.lead,
    required this.mandate,
    required this.services,
  });

  factory SupportUnitEntry.fromMap(Map<String, dynamic> map) {
    return SupportUnitEntry(
      name: _asString(map['name']) ?? '',
      lead: _asString(map['lead']) ?? '',
      mandate: _asString(map['mandate']) ?? _asString(map['mission']) ?? '',
      services: _stringList(map['services']),
    );
  }

  final String name;
  final String lead;
  final String mandate;
  final List<String> services;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lead': lead,
      'mandate': mandate,
      'services': services,
    };
  }
}

String? _asString(dynamic value) {
  if (value is String) return value;
  if (value == null) return null;
  return value.toString();
}

DateTime? _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => _asString(item)?.trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

List<dynamic> _list(dynamic value) {
  if (value is Iterable) return value.toList();
  return const [];
}
