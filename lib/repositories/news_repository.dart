import '../app/services/news_service.dart';

class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.link,
    required this.image,
    required this.source,
  });

  final String title;
  final String link;
  final String image;
  final String source;
}

abstract class NewsRepository {
  Uri get allNewsUri;

  Future<List<NewsArticle>> fetchLatestNews();

  String resolveOriginalImageUrl(String url);
}

class NewsRepositoryImpl implements NewsRepository {
  static final Uri _defaultAllNewsUri = Uri.parse(
    'https://banjarmasin.tribunnews.com/',
  );

  @override
  Uri get allNewsUri => _defaultAllNewsUri;

  @override
  Future<List<NewsArticle>> fetchLatestNews() async {
    final raw = await NewsService.fetchBeritaTerbaru();
    return raw
        .map(
          (item) => NewsArticle(
            title: (item['title'] ?? '').trim(),
            link: (item['link'] ?? '').trim(),
            image: (item['image'] ?? '').trim(),
            source: (item['source'] ?? '').trim(),
          ),
        )
        .toList(growable: false);
  }

  @override
  String resolveOriginalImageUrl(String url) {
    return NewsService.getOriginalImageUrl(url);
  }
}
