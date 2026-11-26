import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> saveXlsxFileImpl({
  required String filename,
  required List<int> bytes,
}) async {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = html.Blob([data], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
