// Black Box UC-05 (riwayat), UC-06 (cuti), UC-07 (izin).
// Halaman nyata (LeavePage, PermissionPage, AttendanceHistoryPage) dengan
// Firestore/Storage/Auth emulator. Dialog tanggal/jam diisi lewat UI;
// pemilih berkas native diganti FakeFilePicker.
import 'package:cipta_vera_mandiri_digital/absensi/cuti.dart';
import 'package:cipta_vera_mandiri_digital/absensi/izin.dart';
import 'package:cipta_vera_mandiri_digital/absensi/riwayat_absen.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/attendance_history_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/emulator.dart';
import 'support/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Emu.setup();
  });

  /// Dokumen leave_requests milik [uid].
  Future<List<Map<String, dynamic>>> leaveDocs(String uid) =>
      docsOf('leave_requests', field: 'uid', value: uid);

  Map<String, dynamic> leaveSeed(
    TestAccount a, {
    required String kind,
    required String status,
    required String reason,
  }) {
    final now = DateTime.now();
    return <String, dynamic>{
      'uid': a.uid,
      'kind': kind,
      'reason': reason,
      'startAt': DateTime(now.year, now.month, now.day),
      'endAt': DateTime(now.year, now.month, now.day, 23, 59, 59),
      'status': status,
      'createdAt': now,
      'updatedAt': now,
      'requesterName': a.name,
      'requesterEmail': a.email,
    };
  }

  // ---------------------------------------------------------------- UC-06
  bbTest('BB-21', 'Cuti lengkap + lampiran PDF -> tersimpan berstatus Menunggu (juga tampil di Riwayat)',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb21');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    final pdf = await createTempPlatformFile('surat_sakit.pdf');
    FilePicker.platform = FakeFilePicker(<PlatformFile>[pdf]);

    await pumpApp(tester, const LeavePage());

    await tapVisible(tester, find.text('Tanggal mulai'));
    await acceptPickerDialog(tester);
    await tapVisible(tester, find.text('Tanggal selesai'));
    await acceptPickerDialog(tester);

    await enterInto(tester, find.byType(TextFormField).first,
        'Menghadiri acara keluarga');

    await tapVisible(tester, find.text('Tambah Lampiran'));
    await pumpUntil(tester, find.text('surat_sakit.pdf'));

    await tapVisible(tester, find.text('Ajukan Cuti'));
    await pumpUntil(tester, find.textContaining('Pengajuan cuti dikirim'),
        timeout: const Duration(seconds: 40));

    final docs = await leaveDocs(acc.uid);
    expect(docs, hasLength(1));
    final d = docs.single;
    expect(d['kind'], 'cuti');
    expect(d['status'], 'pending');
    expect(d['reason'], 'Menghadiri acara keluarga');
    final attachments = d['attachments'] as List<dynamic>;
    expect(attachments, hasLength(1));
    expect((attachments.single as Map<String, dynamic>)['name'],
        'surat_sakit.pdf');

    // Status "Menunggu" harus terlihat di halaman Riwayat.
    await pumpApp(tester, const AttendanceHistoryPage());
    await pumpUntil(tester, find.text('Riwayat Cuti'));
    expect(find.text('Menunggu'), findsWidgets);
    expect(find.text('Menghadiri acara keluarga'), findsWidgets);
  });

  bbTest('BB-22', 'Cuti tanpa alasan -> pesan "Lengkapi data cuti terlebih dahulu", tidak tersimpan',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb22');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    await pumpApp(tester, const LeavePage());
    await tapVisible(tester, find.text('Ajukan Cuti'));
    await pumpUntil(
        tester, find.text('Lengkapi data cuti terlebih dahulu'));
    expect(find.text('Wajib diisi'), findsWidgets);

    expect(await leaveDocs(acc.uid), isEmpty);
  });

  // ---------------------------------------------------------------- UC-07
  bbTest('BB-23', 'Izin lengkap (tanggal, jam mulai & selesai, alasan) -> tersimpan berstatus Menunggu',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb23');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    await pumpApp(tester, const PermissionPage());

    // Tanggal sudah terisi hari ini (initState). Jam mulai: terima 08:00.
    await tapVisible(tester, find.text('Jam mulai'));
    await acceptPickerDialog(tester);

    // Jam selesai: pindah ke mode ketik lalu isi 09:30 (harus > jam mulai).
    await tapVisible(tester, find.text('Jam selesai'));
    await pumpUntil(tester, find.text('OK'));
    await _switchTimePickerToInput(tester);
    final dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), '9');
    await tester.enterText(dialogFields.at(1), '30');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('OK'));
    await settle(tester);

    await enterInto(tester, find.byType(TextFormField).first,
        'Mengurus dokumen kendaraan');
    await tapVisible(tester, find.text('Ajukan Izin'));
    await pumpUntil(
      tester,
      find.text('Pengajuan izin dikirim. Menunggu persetujuan.'),
      timeout: const Duration(seconds: 40),
    );

    final docs = await leaveDocs(acc.uid);
    expect(docs, hasLength(1));
    final d = docs.single;
    expect(d['kind'], 'izin');
    expect(d['status'], 'pending');
    expect(d['reason'], 'Mengurus dokumen kendaraan');
    expect(d['startMinutes'], 8 * 60);
    expect(d['endMinutes'], 9 * 60 + 30);

    await pumpApp(tester, const AttendanceHistoryPage());
    await pumpUntil(tester, find.text('Riwayat Izin'));
    expect(find.text('Menunggu'), findsWidgets);
  });

  bbTest('BB-24', 'Izin tanpa alasan -> pesan "Lengkapi data izin terlebih dahulu", tidak tersimpan',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb24');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    await pumpApp(tester, const PermissionPage());
    await tapVisible(tester, find.text('Ajukan Izin'));
    await pumpUntil(
        tester, find.text('Lengkapi data izin terlebih dahulu'));

    expect(await leaveDocs(acc.uid), isEmpty);
  });

  // ---------------------------------------------------------------- UC-05
  bbTest('BB-19', 'Riwayat setelah check-in -> kehadiran, cuti, dan izin tampil beserta statusnya',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb19');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    // Riwayat kehadiran disimpan lokal (SharedPreferences) oleh aplikasi saat
    // check-in. Check-in sungguhan butuh kamera/GPS -> catatan disiapkan lewat
    // service milik aplikasi sendiri.
    final now = DateTime.now();
    await AttendanceHistory.saveRecord(
      uid: acc.uid,
      date: now,
      checkInAt: now,
      lat: -3.3194,
      lon: 114.5908,
      project: 'Proyek Uji Riwayat',
    );
    await Emu.seedDoc(
      'leave_requests',
      'seed-cuti-bb19',
      leaveSeed(acc, kind: 'cuti', status: 'pending', reason: 'Cuti uji BB19'),
    );
    await Emu.seedDoc(
      'leave_requests',
      'seed-izin-bb19',
      leaveSeed(acc, kind: 'izin', status: 'approved', reason: 'Izin uji BB19'),
    );

    try {
      await pumpApp(tester, const AttendanceHistoryPage());
      await pumpUntil(tester, find.text('Riwayat Cuti'));
      await pumpUntil(tester, find.text('Riwayat Izin'));

      expect(find.text('Hadir'), findsWidgets);
      expect(find.text('Proyek Uji Riwayat'), findsWidgets);
      expect(find.text('Cuti uji BB19'), findsWidgets);
      expect(find.text('Menunggu'), findsWidgets);
      expect(find.text('Izin uji BB19'), findsWidgets);
      expect(find.text('Disetujui'), findsWidgets);
    } finally {
      await AttendanceHistory.clearAll(uid: acc.uid);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
    }
  });

  bbTest('BB-20', 'Riwayat akun baru tanpa data -> tampil keadaan kosong',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb20');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);
    await AttendanceHistory.clearAll(uid: acc.uid);

    await pumpApp(tester, const AttendanceHistoryPage());
    await pumpUntil(
      tester,
      find.text('Belum ada riwayat absen, cuti, atau izin.'),
    );
  });
}

/// Pada dialog showTimePicker (mode dial), tekan ikon papan ketik agar
/// jam/menit bisa diketik. Ikon berbeda antar versi Material.
Future<void> _switchTimePickerToInput(WidgetTester tester) async {
  final candidates = <Finder>[
    find.byIcon(Icons.keyboard_outlined),
    find.byIcon(Icons.keyboard),
    find.byTooltip('Switch to text input mode'),
  ];
  for (final f in candidates) {
    if (f.evaluate().isNotEmpty) {
      await tester.tap(f.first);
      await settle(tester);
      return;
    }
  }
  fail('Tombol pindah ke mode ketik pada time picker tidak ditemukan');
}
