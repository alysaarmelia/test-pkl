// Pembantu UI untuk integration test Black Box.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'emulator.dart';

/// Pengganti `FilePicker.platform` agar tes tidak membuka dialog native.
/// Mengembalikan daftar berkas yang sudah disiapkan (path nyata di emulator).
class FakeFilePicker extends FilePicker {
  FakeFilePicker(this.files);

  final List<PlatformFile> files;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult(files);
  }
}

/// Membuat berkas uji nyata di direktori sementara aplikasi dan
/// mengembalikannya sebagai [PlatformFile] siap pakai untuk [FakeFilePicker].
Future<PlatformFile> createTempPlatformFile(String name) async {
  final Directory dir = await getTemporaryDirectory();
  final File f = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$name');
  // Isi minimal PDF; cukup sebagai payload uji unggah.
  await f.writeAsString('%PDF-1.4\n% berkas uji integration test\n%%EOF\n');
  return PlatformFile(name: name, path: f.path, size: await f.length());
}

/// Bungkus `testWidgets` untuk satu kasus uji Black Box.
/// Nama tes selalu diawali ID dari lembar "Black Box" (mis. "BB-21").
/// Sebelum tiap tes: data emulator dibersihkan. Sesudahnya: pohon widget
/// dibuang dan akun keluar, agar tes berikutnya independen.
void bbTest(
  String id,
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(
    '$id | $description',
    (WidgetTester tester) async {
      await Emu.signOutQuietly();
      await Emu.clearAll();
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
        await Emu.signOutQuietly();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

/// Memasang [home] di dalam GetMaterialApp (dibutuhkan karena halaman memakai
/// GetX). Locale dikunci en_US supaya label dialog bawaan (OK/Cancel) stabil.
Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  List<GetPage<dynamic>> pages = const <GetPage<dynamic>>[],
}) async {
  // Kosongkan dulu agar Navigator/rute lama tidak dipakai ulang (MaterialApp
  // tidak mengganti rute awal bila `home` berubah pada pohon yang sama).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpWidget(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: const <Locale>[Locale('en', 'US')],
      home: home,
      getPages: pages,
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Layar pembuka berisi satu tombol yang mendorong halaman uji ke Navigator.
/// Dipakai agar halaman yang memanggil `Navigator.pop()` punya rute di bawahnya.
class Launcher extends StatelessWidget {
  const Launcher({super.key, required this.builder});

  final WidgetBuilder builder;
  static const String buttonLabel = 'Buka Halaman Uji';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: builder),
          ),
          child: const Text(buttonLabel),
        ),
      ),
    );
  }
}

Future<void> openFromLauncher(WidgetTester tester) async {
  await tester.tap(find.text(Launcher.buttonLabel));
  await tester.pump(const Duration(milliseconds: 500));
  await pumpFor(tester, const Duration(milliseconds: 500));
}

/// Pump berulang (waktu nyata pada binding integration_test) sampai [finder]
/// ditemukan. Tidak memakai pumpAndSettle karena halaman memiliki spinner /
/// listener Firestore yang tidak pernah "settle".
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
  String? reason,
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  await tester.pump(const Duration(milliseconds: 200));
  expect(
    finder,
    findsWidgets,
    reason: reason ?? 'Waktu tunggu habis menunggu: ${finder.description}',
  );
}

/// Pump berulang sampai [condition] bernilai true.
Future<void> pumpUntilTrue(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 25),
  String reason = 'Kondisi tidak terpenuhi dalam batas waktu',
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  expect(condition(), isTrue, reason: reason);
}

/// Pump selama [duration] (waktu nyata) agar stream/async sempat berjalan.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final DateTime end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Gulirkan [finder] ke area terlihat bila berada di dalam Scrollable.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pump(const Duration(milliseconds: 150));
}

/// Gulirkan lalu ketuk [finder].
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

/// TextField berdasarkan teks petunjuk (hintText).
Finder byHint(String hint) => find.byWidgetPredicate(
      (Widget w) => w is TextField && w.decoration?.hintText == hint,
      description: 'TextField dengan hint "$hint"',
    );

/// TextField berdasarkan labelText.
Finder byLabel(String label) => find.byWidgetPredicate(
      (Widget w) => w is TextField && w.decoration?.labelText == label,
      description: 'TextField dengan label "$label"',
    );

Future<void> enterInto(
  WidgetTester tester,
  Finder field,
  String text,
) async {
  await reveal(tester, field);
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Tunggu animasi dialog/overlay selesai tanpa gagal bila ada animasi abadi.
Future<void> settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } catch (_) {
    await pumpFor(tester, const Duration(milliseconds: 600));
  }
}

/// Tutup semua snackbar agar tidak menutupi tombol pada ketukan berikutnya.
Future<void> dismissSnackBars(WidgetTester tester) async {
  final BuildContext ctx = tester.element(find.byType(Scaffold).first);
  ScaffoldMessenger.of(ctx).clearSnackBars();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Menerima dialog showDatePicker dengan tanggal awal (tombol "OK").
Future<void> acceptPickerDialog(WidgetTester tester) async {
  await pumpUntil(tester, find.text('OK'));
  await tester.tap(find.text('OK'));
  await settle(tester);
}

/// Dokumen di koleksi emulator yang field [field]-nya bernilai [value].
Future<List<Map<String, dynamic>>> docsOf(
  String collection, {
  required String field,
  required String value,
}) async {
  final List<Map<String, dynamic>> all = await Emu.listDocs(collection);
  return all.where((Map<String, dynamic> d) => d[field] == value).toList();
}
