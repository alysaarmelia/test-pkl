import 'dart:html' as html;

Future<String?> downloadFileImpl({
  required String url,
  required String fileName,
}) async {
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..target = '_blank';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return null;
}
