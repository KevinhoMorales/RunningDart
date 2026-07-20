import '../models/news_model.dart';

abstract class NewsService {
  Stream<List<NewsModel>> watchPublishedNews();
  Stream<List<NewsModel>> watchAllNews();
  Future<NewsModel?> getNewsById(String id);
  Future<String> createNews(NewsModel news);
  Future<void> updateNews(NewsModel news);
  Future<void> deleteNews(String id);
}
