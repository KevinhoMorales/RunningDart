import '../models/news_model.dart';
import '../models/page_result.dart';

abstract class NewsService {
  static const newsPageSize = 20;

  Stream<PageResult<NewsModel>> watchPublishedNews({
    int limit = newsPageSize,
  });

  Future<PageResult<NewsModel>> fetchPublishedNewsPage({
    Object? startAfter,
    int limit = newsPageSize,
  });

  Stream<PageResult<NewsModel>> watchAllNews({
    int limit = newsPageSize,
  });

  Future<PageResult<NewsModel>> fetchAllNewsPage({
    Object? startAfter,
    int limit = newsPageSize,
  });

  Future<NewsModel?> getNewsById(String id);
  Future<String> createNews(NewsModel news);
  Future<void> updateNews(NewsModel news);
  Future<void> deleteNews(String id);
}
