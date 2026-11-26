import 'xlsx_saver_stub.dart'
    if (dart.library.html) 'xlsx_saver_web.dart';

Future<bool> saveXlsxFile({
  required String filename,
  required List<int> bytes,
}) {
  return saveXlsxFileImpl(filename: filename, bytes: bytes);
}
