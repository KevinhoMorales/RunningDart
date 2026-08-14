import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/news_model.dart';
import '../models/page_result.dart';
import '../services/news_service.dart';

class NewsProvider extends ChangeNotifier {
  NewsProvider(this._newsService);

  final NewsService _newsService;

  StreamSubscription<PageResult<NewsModel>>? _subscription;

  List<NewsModel> _live = [];
  List<NewsModel> _older = [];
  Object? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _generation = 0;

  bool _isLoading = false;
  String? _error;

  List<NewsModel> get news {
    final byId = <String, NewsModel>{};
    for (final item in _older) {
      byId[item.id] = item;
    }
    for (final item in _live) {
      byId[item.id] = item;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return merged;
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
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
      (page) {
        _live = page.items;
        if (_older.isEmpty) {
          _nextCursor = page.cursor;
          _hasMore = page.hasMore;
        } else {
          final liveIds = page.items.map((n) => n.id).toSet();
          _older = _older.where((n) => !liveIds.contains(n.id)).toList();
        }
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

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading || _nextCursor == null) {
      return;
    }
    final generation = _generation;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _newsService.fetchPublishedNewsPage(
        startAfter: _nextCursor,
      );
      if (generation != _generation) {
        return;
      }
      final known = <String>{
        for (final n in _live) n.id,
        for (final n in _older) n.id,
      };
      final fresh = page.items.where((n) => !known.contains(n.id)).toList();
      _older = [..._older, ...fresh];
      _nextCursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (error) {
      debugPrint('No se pudieron cargar más noticias: $error');
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    stopListening();
    _generation++;
    _live = [];
    _older = [];
    _nextCursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    final completer = Completer<void>();

    _isLoading = news.isEmpty;
    _error = null;
    notifyListeners();

    _subscription = _newsService.watchPublishedNews().listen(
      (page) {
        _live = page.items;
        _nextCursor = page.cursor;
        _hasMore = page.hasMore;
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
