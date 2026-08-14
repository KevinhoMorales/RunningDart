import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/news_model.dart';
import '../models/page_result.dart';
import '../services/news_photo_service.dart';
import '../services/news_service.dart';

class AdminNewsProvider extends ChangeNotifier {
  AdminNewsProvider(
    this._newsService, {
    NewsPhotoService? photoService,
  }) : _photoService = photoService;

  final NewsService _newsService;
  NewsPhotoService? _photoService;

  StreamSubscription<PageResult<NewsModel>>? _subscription;

  List<NewsModel> _live = [];
  List<NewsModel> _older = [];
  Object? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _generation = 0;

  bool _isLoading = false;
  bool _isSaving = false;
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
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return merged;
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get isListening => _subscription != null;

  void startListening() {
    if (_subscription != null) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _newsService.watchAllNews().listen(
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
      final page =
          await _newsService.fetchAllNewsPage(startAfter: _nextCursor);
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
      debugPrint('No se pudieron cargar más noticias admin: $error');
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

    _subscription = _newsService.watchAllNews().listen(
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

  Future<String?> createNews({required NewsModel news}) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      return await _newsService.createNews(news);
    } catch (_) {
      _error = 'No se pudo crear la noticia.';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateNews(NewsModel news) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _newsService.updateNews(news);
      return true;
    } catch (_) {
      _error = 'No se pudo actualizar la noticia.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteNews(String id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _newsService.deleteNews(id);
      return true;
    } catch (_) {
      _error = 'No se pudo eliminar el evento.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> uploadPhoto(
    String newsId, {
    XFile? file,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final photoService = _photoService ??= NewsPhotoService();
      if (file != null) {
        return await photoService.uploadNewsPhoto(newsId, file);
      }
      return await photoService.pickAndUploadNewsPhoto(newsId);
    } on NewsPhotoException catch (e) {
      _error = e.message;
      return null;
    } catch (_) {
      _error = 'No se pudo subir la foto.';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
