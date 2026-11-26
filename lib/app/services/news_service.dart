import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class NewsService {
  static const Map<String, String> _rssHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
    'Referer': 'https://banjarmasin.tribunnews.com/',
    'Cache-Control': 'no-cache',
  };

  static Future<List<Map<String, String>>> fetchBeritaTerbaru() async {
    final List<Map<String, String>> allNews = [];

    // Gunakan sumber tunggal dari Banjarmasin Post
    final sources = [
      {
        'url': 'https://banjarmasin.tribunnews.com/rss',
        'source': 'Banjarmasin Post',
      },
    ];

    for (final source in sources) {
      try {
        final response = await http.get(
          Uri.parse(source['url']!),
          headers: _rssHeaders,
        );
        if (response.statusCode == 200) {
          final document = xml.XmlDocument.parse(response.body);
          final items = document.findAllElements('item');
          for (final item in items) {
            final title = item.getElement('title')?.text ?? '';
            final link = item.getElement('link')?.text ?? '';
            final image = _upgradeImageQuality(_extractImage(item));
            allNews.add({
              'title': title,
              'link': link,
              'image': image,
              'source': source['source']!,
            });
          }
        }
      } catch (e) {
        // Ignore errors for now, could log or handle accordingly
        continue;
      }
    }
    return allNews;
  }

  static String _extractImage(xml.XmlElement item) {
    String? bestUrl;
    int bestWidth = -1;

    // 1) media:content – pilih resolusi terbesar
    for (final mc in item.findAllElements('media:content')) {
      final url = mc.getAttribute('url');
      if (url == null || url.isEmpty) continue;
      final widthStr = mc.getAttribute('width');
      final width = int.tryParse(widthStr ?? '') ?? -1;
      if (width > bestWidth) {
        bestWidth = width;
        bestUrl = url;
      }
    }

    // 2) enclosure fallback
    if (bestUrl == null) {
      final enclosure = item.getElement('enclosure');
      if (enclosure != null && enclosure.getAttribute('url') != null) {
        bestUrl = enclosure.getAttribute('url');
      }
    }

    // 3) media:thumbnail – pilih terbesar jika ada
    if (bestUrl == null) {
      for (final thumb in item.findAllElements('media:thumbnail')) {
        final url = thumb.getAttribute('url');
        if (url == null || url.isEmpty) continue;
        final widthStr = thumb.getAttribute('width');
        final width = int.tryParse(widthStr ?? '') ?? -1;
        if (width > bestWidth) {
          bestWidth = width;
          bestUrl = url;
        }
      }
    }

    // 4) scrape dari description
    if (bestUrl == null) {
      final description = item.getElement('description')?.text ?? '';
      final regex = RegExp(
        r'(https?:\/\/\S+\.(?:jpg|jpeg|png|gif))',
        caseSensitive: false,
      );
      final match = regex.firstMatch(description);
      if (match != null) {
        bestUrl = match.group(0);
      }
    }

    return bestUrl ?? '';
  }

  static String getOriginalImageUrl(String url) {
    if (url.isEmpty) return url;
    try {
      final uri = Uri.parse(url);
      final filteredQuery = Map<String, String>.from(uri.queryParameters)
        ..removeWhere((key, value) {
          final k = key.toLowerCase();
          return k == 'w' ||
              k == 'h' ||
              k == 'width' ||
              k == 'height' ||
              k == 'resize' ||
              k == 'size' ||
              k == 'quality' ||
              k == 'q' ||
              k == 'format' ||
              k == 'crop';
        });
      final originalPath = uri.path
          .replaceFirst(RegExp(r'/images/'), '/thumbnails/')
          .replaceFirst(RegExp(r'/thumb\d?/'), '/thumbnails/');
      final next = uri.replace(path: originalPath, queryParameters: filteredQuery);
      return next.toString();
    } catch (_) {
      return url;
    }
  }

  static String _upgradeImageQuality(String url) {
    if (url.isEmpty) return url;
    try {
      final uri = Uri.parse(url);
      final filteredQuery = Map<String, String>.from(uri.queryParameters)
        ..removeWhere((key, value) {
          final k = key.toLowerCase();
          return k == 'w' ||
              k == 'h' ||
              k == 'width' ||
              k == 'height' ||
              k == 'resize' ||
              k == 'size' ||
              k == 'quality' ||
              k == 'q' ||
              k == 'format' ||
              k == 'crop';
        });

      // 1) Replace thumbnail paths
      String upgradedPath = uri.path
          .replaceFirst(RegExp(r'/thumbnails\d?/'), '/images/')
          .replaceFirst(RegExp(r'/thumb\d?/'), '/images/');

      // 2) Handle Tribunnews / Grid.id crop patterns: /crop/0x0:0x0/700x465/photo/...
      // Stripping the crop part entirely usually leads to the original full-size HD image.
      upgradedPath = upgradedPath.replaceFirst(RegExp(r'/crop/[^/]+/[^/]+/'), '/');

      final highResQuery = Map<String, String>.from(filteredQuery)
        ..addAll({
          'w': '1600', // Requesting even larger size
          'h': '1200',
          'quality': '100',
          'q': '100',
        });

      final next = uri.replace(
        path: upgradedPath,
        queryParameters: highResQuery,
      );
      return next.toString();
    } catch (_) {
      return url;
    }
  }
}
