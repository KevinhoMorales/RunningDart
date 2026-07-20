import '../models/news_model.dart';
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

  @override
  Stream<List<NewsModel>> watchPublishedNews() async* {
    yield _mockNews
        .where(
          (item) =>
              item.isPublished && Helpers.isEventUpcoming(item.eventDate),
        )
        .toList(growable: false);
  }

  @override
  Stream<List<NewsModel>> watchAllNews() async* {
    yield List.unmodifiable(_mockNews);
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
