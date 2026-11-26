// Black Box UC-12 (permintaan material), UC-13 (tracking), UC-14 (barang diterima).
// Halaman nyata + Firestore/Storage/Auth emulator. Unduh/buka PDF (BB-41)
// tidak diotomasi (url_launcher / penyimpanan perangkat).
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/menu_grid.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/material_request_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/pages/material_request_tracking_page.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/emulator.dart';
import 'support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Emu.setup();
  });

  Future<List<Map<String, dynamic>>> requestsOf(String uid) =>
      docsOf('material_requests', field: 'requesterUid', value: uid);

  /// Dokumen material_requests persis seperti yang ditulis aplikasi
  /// (MaterialRequestDraft.toFirestorePayload). Seluruh field, termasuk yang
  /// bernilai null, harus ada agar aturan update pemohon (security rules)
  /// tidak menganggapnya "addedKeys".
  Future<String> seedRequest(
    TestAccount a, {
    required String status,
    String project = 'Proyek Jembatan A',
  }) {
    final now = DateTime.now();
    final approved = status != 'pending';
    final itemStatus = approved ? 'approved' : 'pending';
    return Emu.seedDocAuto('material_requests', <String, dynamic>{
      'companyName': 'Pt. Cipta vera mandiri',
      'projectName': project,
      'requestDate': now,
      'requesterName': a.name,
      'requesterUid': a.uid,
      'approverName': approved ? 'Sari Logistik' : '',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'no': 1,
          'name': 'Semen Portland',
          'quantity': '20 sak',
          'status': itemStatus,
        },
        <String, dynamic>{
          'no': 2,
          'name': 'Besi 12mm',
          'quantity': '50 batang',
          'status': itemStatus,
        },
      ],
      'createdAt': now,
      'updatedAt': now,
      'status': status,
      'approvedBy': approved ? 'Sari Logistik' : null,
      'approvedByUid': approved ? 'uid-admin-logistik' : null,
      'approvedAt': approved ? now : null,
      'receivedBy': null,
      'receivedByUid': null,
      'receivedAt': null,
      'documentFileName': 'order.docx',
      'pdfFileName': 'order.pdf',
    });
  }

  /// Tunggu nama pengorder (otomatis dari profil) terisi di formulir.
  Future<void> waitRequesterName(WidgetTester tester, String name) async {
    // Kolom berada di bagian bawah ListView (dibangun malas): gulirkan dulu.
    await pumpFor(tester, const Duration(seconds: 1));
    await reveal(tester, byHint('Tuliskan nama pengorder lapangan'));
    await pumpUntil(tester, find.text(name),
        reason: 'Nama pengorder tidak terisi otomatis');
  }

  Future<void> openMaterialForm(WidgetTester tester, TestAccount acc) async {
    await pumpApp(
      tester,
      const Launcher(builder: _materialPageBuilder),
    );
    await openFromLauncher(tester);
    await waitRequesterName(tester, acc.name);
  }

  // ---------------------------------------------------------------- UC-12
  bbTest('BB-36', 'Permintaan lengkap (PT/CV, proyek, tanggal, 2 item) -> tersimpan Pending + DOCX & PDF dibuat',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb36');
    await Emu.seedUserProfile(acc, role: 'Purchasing and Logistik');
    await Emu.signIn(acc);

    await openMaterialForm(tester, acc);

    await enterInto(tester, byHint('Tuliskan nama proyek'), 'Proyek Jalan Tol X');
    await enterInto(tester, byHint('Jenis material').at(0), 'Semen Portland');
    await enterInto(tester, byHint('Jumlah / satuan').at(0), '20 sak');
    await tapVisible(tester, find.text('Tambah Material'));
    await pumpUntil(tester, byHint('Jenis material').at(1));
    await enterInto(tester, byHint('Jenis material').at(1), 'Besi 12mm');
    await enterInto(tester, byHint('Jumlah / satuan').at(1), '50 batang');

    await tapVisible(tester, find.text('Kirim Permintaan'));
    // Sukses -> halaman ditutup -> kembali ke layar pembuka.
    await pumpUntil(tester, find.text(Launcher.buttonLabel),
        timeout: const Duration(seconds: 90),
        reason: 'Halaman tidak tertutup: pengiriman gagal/lambat');

    final docs = await requestsOf(acc.uid);
    expect(docs, hasLength(1));
    final d = docs.single;
    expect(d['status'], 'pending');
    expect(d['companyName'], 'Pt. Cipta vera mandiri');
    expect(d['projectName'], 'Proyek Jalan Tol X');
    final items = d['items'] as List<dynamic>;
    expect(items, hasLength(2));
    expect((items[0] as Map<String, dynamic>)['name'], 'Semen Portland');
    expect((items[0] as Map<String, dynamic>)['quantity'], '20 sak');
    expect((items[1] as Map<String, dynamic>)['name'], 'Besi 12mm');
    expect((items[0] as Map<String, dynamic>)['status'], 'pending');

    // Dokumen Order Bahan (DOCX + PDF) terunggah ke Storage emulator.
    expect((d['documentStoragePath'] as String?) ?? '', endsWith('.docx'));
    expect((d['pdfStoragePath'] as String?) ?? '', endsWith('.pdf'));
    final docMeta = await FirebaseStorage.instance
        .ref(d['documentStoragePath'] as String)
        .getMetadata();
    final pdfMeta = await FirebaseStorage.instance
        .ref(d['pdfStoragePath'] as String)
        .getMetadata();
    expect(docMeta.size, greaterThan(0));
    expect(pdfMeta.size, greaterThan(0));
    expect((d['documentUrl'] as String?) ?? '', isNotEmpty);
    expect((d['pdfUrl'] as String?) ?? '', isNotEmpty);
  });

  bbTest('BB-37', 'Permintaan tanpa item -> "Tambah minimal satu item material."',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb37');
    await Emu.seedUserProfile(acc, role: 'Purchasing and Logistik');
    await Emu.signIn(acc);

    await openMaterialForm(tester, acc);
    await enterInto(tester, byHint('Tuliskan nama proyek'), 'Proyek Tanpa Item');
    await tapVisible(tester, find.text('Kirim Permintaan'));
    await pumpUntil(tester, find.text('Tambah minimal satu item material.'));

    expect(await requestsOf(acc.uid), isEmpty);
  });

  bbTest('BB-38', 'Item tanpa jumlah -> "Lengkapi nama dan jumlah untuk setiap material."',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb38');
    await Emu.seedUserProfile(acc, role: 'Purchasing and Logistik');
    await Emu.signIn(acc);

    await openMaterialForm(tester, acc);
    await enterInto(tester, byHint('Tuliskan nama proyek'), 'Proyek Tanpa Jumlah');
    await enterInto(tester, byHint('Jenis material').at(0), 'Pasir');
    await tapVisible(tester, find.text('Kirim Permintaan'));
    await pumpUntil(
      tester,
      find.text('Lengkapi nama dan jumlah untuk setiap material.'),
    );

    expect(await requestsOf(acc.uid), isEmpty);
  });

  bbTest('BB-39', 'Menu Material dari divisi Finance -> ditolak, muncul pesan pembatasan akses',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb39');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MenuGrid(onMenuSelected: (_) {}),
        ),
      ),
    );
    // Beri waktu stream profil (users/{uid}) mengalir ke MenuGridViewModel.
    await pumpFor(tester, const Duration(seconds: 3));

    await tapVisible(tester, find.text('Material'));
    await pumpUntil(tester, find.textContaining('Akses hanya untuk'));
    expect(find.text('Permintaan Material'), findsNothing,
        reason: 'Halaman Permintaan Material tidak boleh terbuka');
  });

  bbTest('BB-39 (pembanding)', 'Menu Material dari divisi Purchasing and Logistik -> halaman terbuka',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb39p');
    await Emu.seedUserProfile(acc, role: 'Purchasing and Logistik');
    await Emu.signIn(acc);

    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MenuGrid(onMenuSelected: (_) {}),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));

    await tapVisible(tester, find.text('Material'));
    await pumpUntil(tester, find.text('Permintaan Material'));
  });

  // ---------------------------------------------------------------- UC-13
  bbTest('BB-40', 'Tracking -> daftar permintaan tampil dengan status dan item',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb40');
    await Emu.seedUserProfile(acc, role: 'Purchasing and Logistik');
    await seedRequest(acc, status: 'pending', project: 'Proyek Pending');
    await Emu.signIn(acc);

    await pumpApp(tester, const MaterialRequestTrackingPage());
    await pumpUntil(tester, find.text('Permintaan aktif'));

    expect(find.text('Menunggu persetujuan'), findsWidgets);
    expect(find.text('1. Semen Portland'), findsWidgets);
    expect(find.text('Jumlah: 20 sak'), findsWidgets);
    expect(find.text('2. Besi 12mm'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Pengorder: ${acc.name}'), findsWidgets);
  });

  // ---------------------------------------------------------------- UC-14
  bbTest('BB-42', 'Permintaan Disetujui -> "Barang diterima" mengubah status jadi Diterima (nama + waktu)',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb42');
    await Emu.seedUserProfile(acc, role: 'Purchasing and Logistik');
    final id = await seedRequest(acc, status: 'approved');
    await Emu.signIn(acc);

    await pumpApp(tester, const MaterialRequestTrackingPage());
    await pumpUntil(tester, find.text('Menunggu barang'));
    // Tombol aksi tersedia hanya untuk status disetujui.
    expect(find.text('Barang diterima'), findsOneWidget);

    await tapVisible(tester, find.text('Barang diterima'));
    await pumpUntil(tester, find.text('Riwayat permintaan'),
        timeout: const Duration(seconds: 30));

    // Setelah diterima: lencana status "Barang diterima" (bukan tombol),
    // nama penerima dan waktu penerimaan tampil.
    expect(find.text('Barang diterima'), findsOneWidget);
    await pumpUntil(
        tester, find.textContaining('Barang diterima oleh: ${acc.name}'));
    expect(find.textContaining('Diterima pada'), findsOneWidget);

    final d = await Emu.getDoc('material_requests', id);
    expect(d!['status'], 'delivered');
    expect(d['receivedBy'], acc.name);
    expect(d['receivedByUid'], acc.uid);
    expect(d['receivedAt'], isNotNull);
  });

  bbTest('BB-43', 'Permintaan masih Pending -> tombol "Barang diterima" tidak tersedia',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb43');
    await Emu.seedUserProfile(acc, role: 'Purchasing and Logistik');
    await seedRequest(acc, status: 'pending');
    await Emu.signIn(acc);

    await pumpApp(tester, const MaterialRequestTrackingPage());
    await pumpUntil(tester, find.text('Menunggu persetujuan'));

    expect(find.text('Barang diterima'), findsNothing);
  });
}

Widget _materialPageBuilder(BuildContext context) =>
    const MaterialRequestPage();
