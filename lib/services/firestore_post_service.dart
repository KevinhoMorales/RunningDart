import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_paths.dart';
import '../models/page_result.dart';
import '../models/post_model.dart';
import '../utils/user_messages.dart';
import 'post_service.dart';

class PostServiceException implements Exception {
  PostServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirestorePostService implements PostService {
  FirestorePostService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _posts =>
      FirebasePaths.collection(_firestore, 'posts');

  @override
  Stream<PageResult<PostModel>> watchFeed({
    int limit = PostService.feedPageSize,
    bool includeHidden = false,
  }) {
    return _feedQuery(includeHidden: includeHidden, limit: limit)
        .snapshots()
        .map((snapshot) => _pageFromSnapshot(snapshot, limit));
  }

  @override
  Future<PageResult<PostModel>> fetchFeedPage({
    Object? startAfter,
    int limit = PostService.feedPageSize,
    bool includeHidden = false,
  }) async {
    var query = _feedQuery(includeHidden: includeHidden, limit: limit);
    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    } else if (startAfter != null) {
      throw ArgumentError('Cursor de feed inválido.');
    }
    try {
      final snapshot = await query.get();
      return _pageFromSnapshot(snapshot, limit);
    } on FirebaseException catch (e) {
      throw PostServiceException(UserMessages.firestore(e));
    }
  }

  Query<Map<String, dynamic>> _feedQuery({
    required bool includeHidden,
    required int limit,
  }) {
    return _visible(_posts, includeHidden)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  PageResult<PostModel> _pageFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    final items = _parseSnapshot(snapshot);
    final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
    return PageResult<PostModel>(
      items: items,
      hasMore: snapshot.docs.length >= limit,
      cursor: lastDoc,
    );
  }

  @override
  Stream<PageResult<PostModel>> watchUserPosts(
    String userId, {
    int limit = PostService.userPostsPageSize,
    bool includeHidden = false,
  }) {
    return _userPostsQuery(
      userId,
      includeHidden: includeHidden,
      limit: limit,
    ).snapshots().map((snapshot) => _pageFromSnapshot(snapshot, limit));
  }

  @override
  Future<PageResult<PostModel>> fetchUserPostsPage(
    String userId, {
    Object? startAfter,
    int limit = PostService.userPostsPageSize,
    bool includeHidden = false,
  }) async {
    var query = _userPostsQuery(
      userId,
      includeHidden: includeHidden,
      limit: limit,
    );
    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    } else if (startAfter != null) {
      throw ArgumentError('Cursor de publicaciones de perfil inválido.');
    }
    try {
      final snapshot = await query.get();
      return _pageFromSnapshot(snapshot, limit);
    } on FirebaseException catch (e) {
      throw PostServiceException(UserMessages.firestore(e));
    }
  }

  @override
  Future<int> countUserPosts(
    String userId, {
    bool includeHidden = false,
  }) async {
    try {
      final snapshot = await _visible(
        _posts.where('authorId', isEqualTo: userId),
        includeHidden,
      ).count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw PostServiceException(UserMessages.firestore(e));
    }
  }

  Query<Map<String, dynamic>> _userPostsQuery(
    String userId, {
    required bool includeHidden,
    required int limit,
  }) {
    return _visible(
      _posts.where('authorId', isEqualTo: userId),
      includeHidden,
    ).orderBy('createdAt', descending: true).limit(limit);
  }

  /// El filtro va en la consulta, no en memoria: las reglas rechazan un `list`
  /// completo en cuanto uno de los documentos devueltos es una publicación
  /// oculta que quien pregunta no puede ver.
  Query<Map<String, dynamic>> _visible(
    Query<Map<String, dynamic>> query,
    bool includeHidden,
  ) {
    return includeHidden ? query : query.where('isHidden', isEqualTo: false);
  }

  List<PostModel> _parseSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = <PostModel>[];
    for (final doc in snapshot.docs) {
      try {
        items.add(PostModel.fromFirestore(doc));
      } catch (_) {
        // Skip malformed documents.
      }
    }
    return items;
  }

  @override
  Future<PostModel?> getPostById(String id) async {
    final snapshot = await _posts.doc(id).get();
    if (!snapshot.exists) {
      return null;
    }
    try {
      return PostModel.fromFirestore(snapshot);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PostModel> createPost({
    required PostModel post,
    required XFile image,
  }) async {
    try {
      final docRef = post.id.isEmpty ? _posts.doc() : _posts.doc(post.id);
      final postId = docRef.id;

      final file = File(image.path);
      final storageRef =
          FirebasePaths.storageRef(_storage, 'posts/${post.authorId}/$postId.jpg');
      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      final payload = post.copyWith(
        id: postId,
        imageUrl: downloadUrl,
        createdAt: DateTime.now(),
      );

      await docRef.set(payload.toFirestore());
      return payload;
    } on FirebaseException catch (e) {
      throw PostServiceException(UserMessages.storage(e));
    } catch (e) {
      if (e is PostServiceException) {
        rethrow;
      }
      throw PostServiceException(
        'No se pudo publicar. Intenta de nuevo.',
      );
    }
  }

  @override
  Future<void> deletePost(String id) async {
    final snapshot = await _posts.doc(id).get();
    final authorId = snapshot.data()?['authorId'] as String?;

    await _posts.doc(id).delete();

    if (authorId != null) {
      try {
        await FirebasePaths.storageRef(
          _storage,
          'posts/$authorId/$id.jpg',
        ).delete();
      } catch (_) {
        // Image may not exist.
      }
    }
  }

  @override
  Future<void> hidePost(
    String id, {
    required PostHiddenReason reason,
    required String moderatorId,
    String? note,
  }) async {
    final trimmedNote = note?.trim();
    try {
      await _posts.doc(id).update({
        'isHidden': true,
        'hiddenReason': reason.key,
        'hiddenNote': trimmedNote == null || trimmedNote.isEmpty
            ? FieldValue.delete()
            : trimmedNote,
        'hiddenAt': FieldValue.serverTimestamp(),
        'hiddenBy': moderatorId,
      });
    } on FirebaseException catch (e) {
      throw PostServiceException(UserMessages.firestore(e));
    }
  }

  @override
  Future<void> unhidePost(String id) async {
    try {
      await _posts.doc(id).update({
        'isHidden': false,
        'hiddenReason': FieldValue.delete(),
        'hiddenNote': FieldValue.delete(),
        'hiddenAt': FieldValue.delete(),
        'hiddenBy': FieldValue.delete(),
      });
    } on FirebaseException catch (e) {
      throw PostServiceException(UserMessages.firestore(e));
    }
  }
}
