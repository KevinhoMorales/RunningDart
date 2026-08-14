import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/firebase_paths.dart';
import '../models/news_model.dart';
import '../models/page_result.dart';
import '../utils/helpers.dart';
import 'news_service.dart';

class FirestoreNewsService implements NewsService {
  FirestoreNewsService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _news =>
      FirebasePaths.collection(_firestore, 'news');

  @override
  Stream<PageResult<NewsModel>> watchPublishedNews({
    int limit = NewsService.newsPageSize,
  }) {
    return _publishedQuery(limit: limit).snapshots().map(
          (snapshot) => _pageFromSnapshot(snapshot, limit),
        );
  }

  @override
  Future<PageResult<NewsModel>> fetchPublishedNewsPage({
    Object? startAfter,
    int limit = NewsService.newsPageSize,
  }) async {
    var query = _publishedQuery(limit: limit);
    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    } else if (startAfter != null) {
      throw ArgumentError('Cursor de noticias inválido.');
    }
    final snapshot = await query.get();
    return _pageFromSnapshot(snapshot, limit);
  }

  @override
  Stream<PageResult<NewsModel>> watchAllNews({
    int limit = NewsService.newsPageSize,
  }) {
    return _allQuery(limit: limit).snapshots().map(
          (snapshot) => _pageFromSnapshot(snapshot, limit),
        );
  }

  @override
  Future<PageResult<NewsModel>> fetchAllNewsPage({
    Object? startAfter,
    int limit = NewsService.newsPageSize,
  }) async {
    var query = _allQuery(limit: limit);
    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    } else if (startAfter != null) {
      throw ArgumentError('Cursor de noticias inválido.');
    }
    final snapshot = await query.get();
    return _pageFromSnapshot(snapshot, limit);
  }

  /// Solo próximos (desde hoy), ordenados por fecha de evento.
  Query<Map<String, dynamic>> _publishedQuery({required int limit}) {
    final today = Helpers.startOfDay(DateTime.now());
    return _news
        .where('isPublished', isEqualTo: true)
        .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .orderBy('eventDate')
        .limit(limit);
  }

  Query<Map<String, dynamic>> _allQuery({required int limit}) {
    return _news.orderBy('eventDate', descending: true).limit(limit);
  }

  PageResult<NewsModel> _pageFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    final items = _parseDocuments(snapshot.docs);
    final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
    return PageResult<NewsModel>(
      items: items,
      hasMore: snapshot.docs.length >= limit,
      cursor: lastDoc,
    );
  }

  List<NewsModel> _parseDocuments(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = <NewsModel>[];
    for (final doc in docs) {
      try {
        items.add(NewsModel.fromFirestore(doc));
      } catch (_) {
        // Skip malformed documents so one bad record does not break the list.
      }
    }
    return items;
  }

  @override
  Future<NewsModel?> getNewsById(String id) async {
    final snapshot = await _news.doc(id).get();
    if (!snapshot.exists) {
      return null;
    }
    try {
      return NewsModel.fromFirestore(snapshot);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> createNews(NewsModel news) async {
    final docRef = news.id.isEmpty ? _news.doc() : _news.doc(news.id);
    final now = DateTime.now();
    final payload = news
        .copyWith(
          id: docRef.id,
          createdAt: now,
          updatedAt: now,
        )
        .toFirestore();

    await docRef.set(payload);
    return docRef.id;
  }

  @override
  Future<void> updateNews(NewsModel news) async {
    final payload = news
        .copyWith(updatedAt: DateTime.now())
        .toFirestore();
    await _news.doc(news.id).update(payload);
  }

  @override
  Future<void> deleteNews(String id) async {
    await _news.doc(id).delete();

    try {
      await FirebasePaths.storageRef(
        _storage,
        'news/$id/cover.jpg',
      ).delete();
    } catch (_) {
      // Cover may not exist.
    }
  }
}
