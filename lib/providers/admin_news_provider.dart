import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/news_model.dart';
import '../services/news_photo_service.dart';
import '../services/news_service.dart';

class AdminNewsProvider extends ChangeNotifier {
  AdminNewsProvider(
    this._newsService, {
    NewsPhotoService? photoService,
  }) : _photoService = photoService;

  final NewsService _newsService;
  NewsPhotoService? _photoService;

  StreamSubscription<List<NewsModel>>? _subscription;

  List<NewsModel> _news = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<NewsModel> get news => _news;
  bool get isLoading => _isLoading;
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

    _subscription = _newsService.watchAllNews().listen(
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

  Future<String?> uploadPhoto(String newsId) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final photoService = _photoService ??= NewsPhotoService();
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
