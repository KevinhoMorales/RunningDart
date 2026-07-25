import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_paths.dart';
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
  Stream<List<PostModel>> watchFeed({
    int limit = 50,
    bool includeHidden = false,
  }) {
    return _visible(_posts, includeHidden)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_parseSnapshot);
  }

  @override
  Stream<List<PostModel>> watchUserPosts(
    String userId, {
    bool includeHidden = false,
  }) {
    return _visible(_posts.where('authorId', isEqualTo: userId), includeHidden)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_parseSnapshot);
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
