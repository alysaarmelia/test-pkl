// Black Box UC-15 (dokumen pegawai) -- hanya bagian yang bisa diotomasi:
// unggah (form + validasi), tampil di daftar, hapus. Pengingat lokal
// (flutter_local_notifications) dimatikan dengan enableReminders:false, jadi
// penjadwalan/pembatalan pengingat (bagian dari BB-44, BB-46, BB-47) tetap
// manual. BB-45 (cari/filter) tidak ada di halaman ini -> lihat README.
import 'dart:typed_data';

import 'package:cipta_vera_mandiri_digital/app/modules/pages/pemberkasan_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
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

  Future<List<Map<String, dynamic>>> docsFor(String uid) =>
      docsOf('employee_documents', field: 'uid', value: uid);

  Future<void> openAddDialog(WidgetTester tester) async {
    await pumpUntil(tester, find.text('Tambah Dokumen'));
    await tapVisible(tester, find.text('Tambah Dokumen'));
    await pumpUntil(tester, find.text('Nama Dokumen'));
  }

  bbTest('BB-44', 'Unggah dokumen + kedaluwarsa + pengingat 1 bulan -> tampil di daftar (pengingat lokal: manual)',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb44');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    final pdf = await createTempPlatformFile('kontrak_kerja.pdf');
    FilePicker.platform = FakeFilePicker(<PlatformFile>[pdf]);

    await pumpApp(tester, const PemberkasanPage(enableReminders: false));
    await pumpUntil(tester, find.text('Belum ada dokumen pemberkasan.'));
    await openAddDialog(tester);

    await enterInto(tester, byLabel('Nama Dokumen'), 'Kontrak Kerja');
    await enterInto(tester, byLabel('Catatan (opsional)'), 'Kontrak tahun 2026');

    // Tanggal kedaluwarsa: terima tanggal awal (hari ini + 30 hari).
    await tapVisible(tester, find.text('Belum dipilih'));
    await acceptPickerDialog(tester);

    // Masa pengingat: pilih "Setiap 1 bulan".
    await tapVisible(tester, find.byType(DropdownButton<Duration?>));
    await settle(tester);
    await tester.tap(find.text('Setiap 1 bulan').last);
    await settle(tester);

    await tapVisible(tester, find.text('Pilih'));
    await pumpUntil(tester, find.text('kontrak_kerja.pdf'));

    await tapVisible(tester, find.text('Simpan'));
    await pumpUntil(tester, find.text('Dokumen berhasil ditambahkan.'),
        timeout: const Duration(seconds: 40));

    // Dokumen tampil di daftar.
    await pumpUntil(tester, find.text('Kontrak Kerja'));
    expect(find.textContaining('Kedaluwarsa'), findsWidgets);
    expect(find.text('Setiap 1 bulan'), findsWidgets);

    final docs = await docsFor(acc.uid);
    expect(docs, hasLength(1));
    final d = docs.single;
    expect(d['title'], 'Kontrak Kerja');
    expect(d['notes'], 'Kontrak tahun 2026');
    expect(d['reminderIntervalDays'], 30);
    expect(d['expiresAt'], isNotNull);
    expect(d['originalFileName'], 'kontrak_kerja.pdf');
    expect((d['storagePath'] as String), startsWith('pemberkasan/${acc.uid}/'));
    final meta = await FirebaseStorage.instance
        .ref(d['storagePath'] as String)
        .getMetadata();
    expect(meta.size, greaterThan(0));
  });

  bbTest('BB-44 (validasi)', 'Form unggah: nama kosong ditolak; tanpa berkas ditolak',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb44v');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    await pumpApp(tester, const PemberkasanPage(enableReminders: false));
    await openAddDialog(tester);

    // 1) Nama kosong.
    await tapVisible(tester, find.text('Simpan'));
    await pumpUntil(tester, find.text('Nama dokumen wajib diisi'));

    // 2) Nama terisi, berkas belum dipilih.
    await enterInto(tester, byLabel('Nama Dokumen'), 'KTP');
    await dismissSnackBars(tester);
    await tapVisible(tester, find.text('Simpan'));
    await pumpUntil(tester, find.text('Silakan pilih file dokumen.'));

    expect(await docsFor(acc.uid), isEmpty);
  });

  bbTest('BB-46', 'Hapus dokumen milik sendiri -> dokumen & berkas terhapus (pembatalan pengingat: manual)',
      (tester) async {
    final acc = await Emu.createAccount(tag: 'bb46');
    await Emu.seedUserProfile(acc, role: 'Finance');
    await Emu.signIn(acc);

    // Siapkan berkas nyata di Storage emulator + dokumen Firestore (REST admin).
    final path = 'pemberkasan/${acc.uid}/${DateTime.now().millisecondsSinceEpoch}_ktp.pdf';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      Uint8List.fromList('%PDF-1.4 uji hapus'.codeUnits),
      SettableMetadata(contentType: 'application/pdf'),
    );
    final url = await ref.getDownloadURL();
    final docId = await Emu.seedDocAuto('employee_documents', <String, dynamic>{
      'uid': acc.uid,
      'title': 'KTP Budi',
      'storagePath': path,
      'downloadUrl': url,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'createdBy': acc.uid,
      'originalFileName': 'ktp.pdf',
    });

    await pumpApp(tester, const PemberkasanPage(enableReminders: false));
    await pumpUntil(tester, find.text('KTP Budi'));

    await tapVisible(tester, find.byTooltip('Hapus dokumen'));
    await pumpUntil(tester, find.text('Hapus dokumen?'));
    await tester.tap(find.text('Hapus'));
    await pumpUntil(tester, find.text('Dokumen "KTP Budi" dihapus.'),
        timeout: const Duration(seconds: 30));
    await pumpUntil(tester, find.text('Belum ada dokumen pemberkasan.'));

    expect(await Emu.getDoc('employee_documents', docId), isNull);
    await expectLater(
      ref.getMetadata(),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'object-not-found'),
      ),
    );
  });
}
