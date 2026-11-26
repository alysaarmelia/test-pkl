import 'package:get/get.dart';

import '../repositories/news_repository.dart';

class NewsSectionViewModel extends GetxController {
  NewsSectionViewModel({NewsRepository? repository})
    : _repository = repository ?? NewsRepositoryImpl();

  final NewsRepository _repository;
  Future<List<NewsArticle>>? _cachedNewsFuture;

  Uri get allNewsUri => _repository.allNewsUri;

  Future<List<NewsArticle>> loadLatestNews({bool refresh = false}) {
    if (refresh || _cachedNewsFuture == null) {
      _cachedNewsFuture = _repository.fetchLatestNews();
    }
    return _cachedNewsFuture!;
  }

  String resolveOriginalImageUrl(String url) {
    return _repository.resolveOriginalImageUrl(url);
  }
}
