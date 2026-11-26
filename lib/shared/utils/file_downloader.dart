import 'file_downloader_io.dart'
    if (dart.library.html) 'file_downloader_web.dart';

/// Downloads a file from [url] and suggests [fileName] as the saved name.
///
/// Returns the local path when running on IO platforms (mobile/desktop).
/// On web, downloads are handled by the browser so `null` is returned.
Future<String?> downloadFile({
  required String url,
  required String fileName,
}) {
  return downloadFileImpl(url: url, fileName: fileName);
}
