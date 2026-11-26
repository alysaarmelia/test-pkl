import 'package:flutter/foundation.dart';

Future<bool> saveXlsxFileImpl({
  required String filename,
  required List<int> bytes,
}) async {
  debugPrint('XLSX export is not supported on this platform.');
  return false;
}
