import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/news_model.dart';
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

  static const _collection = 'news';

  CollectionReference<Map<String, dynamic>> get _news =>
      _firestore.collection(_collection);

  @override
  Stream<List<NewsModel>> watchPublishedNews() {
    return _news.where('isPublished', isEqualTo: true).snapshots().map(
          _mapPublishedSnapshot,
        );
  }

  @override
  Stream<List<NewsModel>> watchAllNews() {
    return _news.snapshots().map(_mapAllNewsSnapshot);
  }

  List<NewsModel> _mapPublishedSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = _parseDocuments(snapshot.docs);
    return items
        .where((item) => Helpers.isEventUpcoming(item.eventDate))
        .toList(growable: false)
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
  }

  List<NewsModel> _mapAllNewsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = _parseDocuments(snapshot.docs);
    return items..sort((a, b) => b.eventDate.compareTo(a.eventDate));
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
      await _storage.ref().child('news/$id/cover.jpg').delete();
    } catch (_) {
      // Cover may not exist.
    }
  }
}
