import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AvatarThumbnailCacheService {
  AvatarThumbnailCacheService._();

  static final AvatarThumbnailCacheService instance =
      AvatarThumbnailCacheService._();

  final Map<String, String> _memoryPathCache = <String, String>{};
  final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};

  Future<String?> getOrCreateThumbnailPath({
    required String imageUrl,
    int targetSize = 96,
    int quality = 66,
  }) async {
    final url = imageUrl.trim();
    if (url.isEmpty || !url.startsWith('http')) return null;

    final memoryPath = _memoryPathCache[url];
    if (memoryPath != null && await File(memoryPath).exists()) {
      return memoryPath;
    }

    final localPath = await _buildLocalPath(url);
    final localFile = File(localPath);
    if (await localFile.exists()) {
      _memoryPathCache[url] = localPath;
      return localPath;
    }

    final running = _inFlight[url];
    if (running != null) return running;

    final task = _downloadAndStore(
      url: url,
      localPath: localPath,
      targetSize: targetSize,
      quality: quality,
    );
    _inFlight[url] = task;
    final result = await task;
    _inFlight.remove(url);
    return result;
  }

  Future<void> prefetch({
    required String imageUrl,
    int targetSize = 96,
    int quality = 66,
  }) async {
    await getOrCreateThumbnailPath(
      imageUrl: imageUrl,
      targetSize: targetSize,
      quality: quality,
    );
  }

  Future<String?> _downloadAndStore({
    required String url,
    required String localPath,
    required int targetSize,
    required int quality,
  }) async {
    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      final thumbBytes = _createThumbBytes(
        bytes: resp.bodyBytes,
        targetSize: targetSize,
        quality: quality,
      );
      final file = File(localPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(thumbBytes, flush: true);
      _memoryPathCache[url] = localPath;
      return localPath;
    } catch (_) {
      return null;
    }
  }

  List<int> _createThumbBytes({
    required List<int> bytes,
    required int targetSize,
    required int quality,
  }) {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return bytes;
    final size = math.min(decoded.width, decoded.height);
    final x = ((decoded.width - size) / 2).round();
    final y = ((decoded.height - size) / 2).round();
    final cropped = img.copyCrop(decoded, x: x, y: y, width: size, height: size);
    final resized = img.copyResize(
      cropped,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );
    return img.encodeJpg(resized, quality: quality);
  }

  Future<String> _buildLocalPath(String url) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(p.join(dir.path, 'avatar_thumb_cache'));
    final hash = _stableHash(url);
    return p.join(folder.path, '$hash.jpg');
  }

  String _stableHash(String input) {
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xFFFFFFFFFFFFFFFF;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16);
  }
}
