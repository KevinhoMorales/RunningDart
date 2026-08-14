import '../models/news_model.dart';
import '../models/page_result.dart';
import '../utils/helpers.dart';
import 'news_service.dart';

class MockNewsService implements NewsService {
  static final _mockNews = [
    NewsModel(
      id: 'news-001',
      title: 'Encuentro SAINTS',
      summary: 'Reúnete con la comunidad en nuestro próximo evento.',
      body: 'Detalles del encuentro anual de SAINTS con actividades, '
          'beneficios y sorpresas para miembros.',
      eventDate: DateTime.now().add(const Duration(days: 14)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      location: 'Centro de convenciones',
      isPublished: true,
    ),
  ];

  PageResult<NewsModel> _page(
    List<NewsModel> source, {
    required int limit,
    Object? startAfter,
  }) {
    var start = 0;
    if (startAfter is String) {
      final index = source.indexWhere((item) => item.id == startAfter);
      start = index < 0 ? source.length : index + 1;
    }
    final slice = source.skip(start).toList(growable: false);
    final items = slice.take(limit).toList(growable: false);
    return PageResult(
      items: items,
      hasMore: slice.length > limit,
      cursor: items.isEmpty ? null : items.last.id,
    );
  }

  @override
  Stream<PageResult<NewsModel>> watchPublishedNews({
    int limit = NewsService.newsPageSize,
  }) async* {
    final upcoming = _mockNews
        .where(
          (item) =>
              item.isPublished && Helpers.isEventUpcoming(item.eventDate),
        )
        .toList(growable: false)
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    yield _page(upcoming, limit: limit);
  }

  @override
  Future<PageResult<NewsModel>> fetchPublishedNewsPage({
    Object? startAfter,
    int limit = NewsService.newsPageSize,
  }) async {
    final upcoming = _mockNews
        .where(
          (item) =>
              item.isPublished && Helpers.isEventUpcoming(item.eventDate),
        )
        .toList(growable: false)
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return _page(upcoming, limit: limit, startAfter: startAfter);
  }

  @override
  Stream<PageResult<NewsModel>> watchAllNews({
    int limit = NewsService.newsPageSize,
  }) async* {
    final all = List<NewsModel>.from(_mockNews)
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    yield _page(all, limit: limit);
  }

  @override
  Future<PageResult<NewsModel>> fetchAllNewsPage({
    Object? startAfter,
    int limit = NewsService.newsPageSize,
  }) async {
    final all = List<NewsModel>.from(_mockNews)
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return _page(all, limit: limit, startAfter: startAfter);
  }

  @override
  Future<NewsModel?> getNewsById(String id) async {
    try {
      return _mockNews.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> createNews(NewsModel news) async {
    throw UnsupportedError('MockNewsService does not support create.');
  }

  @override
  Future<void> updateNews(NewsModel news) async {
    throw UnsupportedError('MockNewsService does not support update.');
  }

  @override
  Future<void> deleteNews(String id) async {
    throw UnsupportedError('MockNewsService does not support delete.');
  }
}
