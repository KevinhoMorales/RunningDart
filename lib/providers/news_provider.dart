import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/news_model.dart';
import '../services/news_service.dart';

class NewsProvider extends ChangeNotifier {
  NewsProvider(this._newsService);

  final NewsService _newsService;

  StreamSubscription<List<NewsModel>>? _subscription;

  List<NewsModel> _news = [];
  bool _isLoading = false;
  String? _error;

  List<NewsModel> get news => _news;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isListening => _subscription != null;

  void startListening() {
    if (_subscription != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _newsService.watchPublishedNews().listen(
      (news) {
        _news = news;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'No se pudieron cargar las noticias.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    stopListening();
    final completer = Completer<void>();

    _isLoading = _news.isEmpty;
    _error = null;
    notifyListeners();

    _subscription = _newsService.watchPublishedNews().listen(
      (news) {
        _news = news;
        _isLoading = false;
        _error = null;
        if (!completer.isCompleted) {
          completer.complete();
        }
        notifyListeners();
      },
      onError: (_) {
        _error = 'No se pudieron cargar las noticias.';
        _isLoading = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        notifyListeners();
      },
    );

    return completer.future;
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<NewsModel?> getNewsById(String id) {
    return _newsService.getNewsById(id);
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
