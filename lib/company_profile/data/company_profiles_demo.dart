import 'package:flutter/material.dart';

import '../../shared/models/company_profile.dart';

/// Demo profiles used when Firestore content is unavailable (e.g., offline build).
final List<CompanyProfileData> demoCompanyProfiles =
    List<CompanyProfileData>.unmodifiable([
  CompanyProfileData(
    id: 'pt-cvm-digital',
    displayName: 'PT Cipta Vera Mandiri Digital',
    legalType: 'Perseroan Terbatas',
    tagline: 'Ecosystem Builder untuk Transformasi Digital',
    summary:
        'PT Cipta Vera Mandiri Digital (CVM Digital) merupakan holding technology '
        'yang mengembangkan platform digital untuk mendukung otomasi operasional '
        'perusahaan dengan pendekatan desain futuristik dan berorientasi ke hasil.',
    history:
        'Didirikan pada 2020 di Surabaya sebagai pengembangan dari unit solusi teknologi '
        'internal CVM Group. Sejak 2022, CVM Digital fokus pada ekspansi layanan SaaS '
        'dan pengembangan produk internal yang mendukung efisiensi proses bisnis.',
    coreValues: [
      'Inovasi berkelanjutan',
      'Kolaborasi lintas divisi',
      'Fokus pada pengalaman pengguna',
    ],
    focusAreas: [
      'Pengembangan SaaS internal & eksternal',
      'Integrasi data dan analitik',
      'Desain produk berbasis glassmorphism',
    ],
    brandColor: Color(0xFF1C63FF),
  ),
  CompanyProfileData(
    id: 'pt-vera-integra',
    displayName: 'PT Vera Integra Konstruksi',
    legalType: 'Perseroan Terbatas',
    tagline: 'Solusi Konstruksi Kaca dan Interior Terintegrasi',
    summary:
        'PT Vera Integra Konstruksi menyediakan layanan konstruksi interior '
        'berbasis kaca dan aluminium untuk segmen komersial dan residensial premium.',
    history:
        'Berawal sebagai workshop keluarga di 2012, perusahaan berkembang menjadi kontraktor '
        'spesialis interior modern dengan pendekatan desain modular dan material berkualitas tinggi.',
    coreValues: [
      'Ketepatan eksekusi',
      'Integritas proyek',
      'Kepuasan pelanggan',
    ],
    focusAreas: [
      'Fasad kaca dan curtain wall',
      'Interior komersial modern',
      'Manajemen proyek EPC',
    ],
    brandColor: Color(0xFF7B61FF),
  ),
  CompanyProfileData(
    id: 'cv-cipta-solusi',
    displayName: 'CV Cipta Solusi Mandiri',
    legalType: 'Commanditaire Vennootschap',
    tagline: 'Automasi Proses Bisnis untuk UMKM',
    summary:
        'CV Cipta Solusi Mandiri menghadirkan layanan konsultasi digitalisasi '
        'untuk UMKM, membantu transformasi proses operasional menjadi lebih efisien.',
    history:
        'Terbentuk pada 2016 sebagai tim internal untuk mendukung digitalisasi klien '
        'portofolio, kini menjadi mitra utama untuk implementasi sistem ERP skala kecil-menengah.',
    coreValues: [
      'Pendampingan intensif',
      'Solusi tepat guna',
      'Pengembangan kapasitas klien',
    ],
    focusAreas: [
      'Implementasi ERP ringan',
      'Pelatihan adopsi digital',
      'Integrasi pembayaran online',
    ],
    brandColor: Color(0xFF34D399),
  ),
  CompanyProfileData(
    id: 'cv-atelier-kreatif',
    displayName: 'CV Atelier Kreatif Studio',
    legalType: 'Commanditaire Vennootschap',
    tagline: 'Studio Desain Visual dan Produk Glasir',
    summary:
        'CV Atelier Kreatif Studio menggabungkan seni visual dan teknik manufaktur '
        'kaca untuk menciptakan produk dekoratif dengan sentuhan teknologi modern.',
    history:
        'Didirikan oleh desainer muda pada 2018 sebagai ekspansi lini kreatif CVM Group. '
        'Kini fokus pada kolaborasi dengan brand lifestyle dan hotel butik.',
    coreValues: [
      'Eksperimen artistik',
      'Kualitas produksi tinggi',
      'Kolaborasi komunitas',
    ],
    focusAreas: [
      'Desain instalasi kaca',
      'Produk lifestyle edisi terbatas',
      'Kolaborasi brand & interior',
    ],
    brandColor: Color(0xFFE879F9),
  ),
  CompanyProfileData(
    id: 'unit-kemitraan',
    displayName: 'CVM Digital Venture Lab',
    legalType: 'Inkubator & Kemitraan Strategis',
    tagline: 'Eksplorasi Produk dan Kemitraan Digital Baru',
    summary:
        'Venture Lab berperan sebagai wadah eksplorasi produk digital eksperimental, '
        'menjembatani kolaborasi dengan startup dan mitra B2B.',
    history:
        'Beroperasi sejak 2023 sebagai unit riset terapan untuk menguji ide produk, '
        'menjalankan pilot project, dan membangun spin-off yang siap scale-up.',
    coreValues: [
      'Eksperimentasi cepat',
      'Kemitraan terbuka',
      'Pembelajaran terukur',
    ],
    focusAreas: [
      'Inkubasi produk digital',
      'Kolaborasi dengan startup',
      'Riset teknologi terapan',
    ],
    brandColor: Color(0xFFFFA94D),
  ),
]);
