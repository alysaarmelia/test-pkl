import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<String?> downloadFileImpl({
  required String url,
  required String fileName,
}) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode >= 400) {
    throw HttpException(
      'Gagal mengunduh file (status ${response.statusCode})',
      uri: Uri.parse(url),
    );
  }

  final directory = await getApplicationDocumentsDirectory();
  final sanitizedName = _sanitizeFileName(fileName);
  final file = File('${directory.path}/$sanitizedName');
  await file.writeAsBytes(response.bodyBytes);
  return file.path;
}

String _sanitizeFileName(String value) {
  final trimmed = value.trim();
  final cleaned = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (cleaned.isEmpty) {
    return 'file_${DateTime.now().millisecondsSinceEpoch}.dat';
  }
  return cleaned;
}
