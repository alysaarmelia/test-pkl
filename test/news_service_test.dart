import 'package:cipta_vera_mandiri_digital/app/services/news_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'getOriginalImageUrl menghapus query ukuran dan mengubah path thumbnail',
    () {
      final url =
          'https://example.com/thumb1/image.jpg?w=400&h=300&quality=50&foo=bar';
      final result = NewsService.getOriginalImageUrl(url);
      // Path disesuaikan ke thumbnails/
      expect(result.contains('/thumb'), isTrue);
      expect(result.contains('w='), isFalse);
      expect(result.contains('h='), isFalse);
      expect(result.contains('quality='), isFalse);
      expect(result.contains('foo=bar'), isTrue); // query lain tetap ada
    },
  );
}
