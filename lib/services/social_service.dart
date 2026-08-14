import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_paths.dart';
import '../models/page_result.dart';
import '../models/post_comment_model.dart';
import '../models/post_report_model.dart';
import '../models/public_profile.dart';
import '../models/user_model.dart';
import '../utils/user_messages.dart';

class SocialServiceException implements Exception {
  SocialServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SocialService {
  SocialService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _follows =>
      FirebasePaths.collection(_firestore, 'follows');

  CollectionReference<Map<String, dynamic>> get _blocks =>
      FirebasePaths.collection(_firestore, 'blocks');

  CollectionReference<Map<String, dynamic>> get _reports =>
      FirebasePaths.collection(_firestore, 'post_reports');

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      FirebasePaths.collection(_firestore, 'public_profiles');

  CollectionReference<Map<String, dynamic>> get _postLikes =>
      FirebasePaths.collection(_firestore, 'post_likes');

  CollectionReference<Map<String, dynamic>> get _postComments =>
      FirebasePaths.collection(_firestore, 'post_comments');

  String _followId(String followerId, String followedId) =>
      '${followerId}_$followedId';

  String _blockId(String blockerId, String blockedId) =>
      '${blockerId}_$blockedId';

  String _likeId(String postId, String userId) => '${postId}_$userId';

  // --- Follows ---

  Future<void> follow({
    required String followerId,
    required String followedId,
  }) async {
    try {
      await _follows.doc(_followId(followerId, followedId)).set({
        'followerId': followerId,
        'followedId': followedId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Future<void> unfollow({
    required String followerId,
    required String followedId,
  }) async {
    try {
      await _follows.doc(_followId(followerId, followedId)).delete();
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Future<bool> isFollowing({
    required String followerId,
    required String followedId,
  }) async {
    final doc = await _follows.doc(_followId(followerId, followedId)).get();
    return doc.exists;
  }

  Stream<Set<String>> watchFollowingIds(String followerId) {
    return _follows
        .where('followerId', isEqualTo: followerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['followedId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet());
  }

  Future<int> followersCount(String userId) async {
    final snapshot = await _follows
        .where('followedId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> followingCount(String userId) async {
    final snapshot = await _follows
        .where('followerId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Página de seguidores (más recientes primero).
  /// No hay `getFollowerIds`/`getFollowingIds` unbounded: la UI usa estas
  /// páginas, y los contadores usan `count()`.
  static const followListPageSize = 30;

  Future<PageResult<PublicProfile>> fetchFollowersPage(
    String userId, {
    Object? startAfter,
    int limit = followListPageSize,
  }) {
    return _fetchFollowProfilesPage(
      field: 'followedId',
      idField: 'followerId',
      userId: userId,
      startAfter: startAfter,
      limit: limit,
    );
  }

  Future<PageResult<PublicProfile>> fetchFollowingPage(
    String userId, {
    Object? startAfter,
    int limit = followListPageSize,
  }) {
    return _fetchFollowProfilesPage(
      field: 'followerId',
      idField: 'followedId',
      userId: userId,
      startAfter: startAfter,
      limit: limit,
    );
  }

  Future<PageResult<PublicProfile>> _fetchFollowProfilesPage({
    required String field,
    required String idField,
    required String userId,
    Object? startAfter,
    required int limit,
  }) async {
    try {
      var query = _follows
          .where(field, isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
        query = query.startAfterDocument(startAfter);
      } else if (startAfter != null) {
        throw ArgumentError('Cursor de lista de follows inválido.');
      }

      final snapshot = await query.get();
      final ids = snapshot.docs
          .map((doc) => doc.data()[idField] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final profiles = await getPublicProfilesByIds(ids);
      final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
      return PageResult<PublicProfile>(
        items: profiles,
        hasMore: snapshot.docs.length >= limit,
        cursor: lastDoc,
      );
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Future<List<PublicProfile>> getPublicProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return const [];
    }
    final uniqueIds = ids.toSet().toList(growable: false);
    final docs = await Future.wait(
      uniqueIds.map((id) => _publicProfiles.doc(id).get()),
    );
    final byId = <String, PublicProfile>{};
    for (var i = 0; i < uniqueIds.length; i++) {
      final id = uniqueIds[i];
      final doc = docs[i];
      if (doc.exists) {
        byId[id] = PublicProfile.fromFirestore(doc);
      } else {
        byId[id] = PublicProfile(id: id, displayName: 'Miembro SAINTS');
      }
    }
    return ids
        .map((id) => byId[id] ?? PublicProfile(id: id, displayName: 'Miembro SAINTS'))
        .toList(growable: false);
  }

  // --- Blocks ---

  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _blocks.doc(_blockId(blockerId, blockedId)).set({
        'blockerId': blockerId,
        'blockedId': blockedId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _blocks.doc(_blockId(blockerId, blockedId)).delete();
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Stream<Set<String>> watchBlockedIds(String blockerId) {
    return _blocks
        .where('blockerId', isEqualTo: blockerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['blockedId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet());
  }

  // --- Likes ---

  /// Cuántos likes recientes se siguen para pintar el corazón. El feed muestra
  /// las últimas publicaciones de la comunidad, así que este corte solo deja
  /// fuera likes viejos que ya no están a la vista.
  static const likedPostsWindow = 500;

  /// Página de la hoja "Me gusta" de una publicación.
  static const likesPageSize = 40;

  /// Página de la cola de reportes en admin.
  static const reportsPageSize = 40;

  Future<void> likePost({
    required String postId,
    required String userId,
    required String postAuthorId,
  }) async {
    try {
      await _postLikes.doc(_likeId(postId, userId)).set({
        'postId': postId,
        'userId': userId,
        'postAuthorId': postAuthorId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Future<void> unlikePost({
    required String postId,
    required String userId,
  }) async {
    try {
      await _postLikes.doc(_likeId(postId, userId)).delete();
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Stream<Set<String>> watchLikedPostIds(String userId) {
    return _postLikes
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(likedPostsWindow)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['postId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet());
  }

  Future<PageResult<PublicProfile>> fetchPostLikeProfiles(
    String postId, {
    Object? startAfter,
    int limit = likesPageSize,
  }) async {
    try {
      var query = _postLikes
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
        query = query.startAfterDocument(startAfter);
      } else if (startAfter != null) {
        throw ArgumentError('Cursor de likes inválido.');
      }

      final snapshot = await query.get();
      final ids = snapshot.docs
          .map((doc) => doc.data()['userId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final profiles = await getPublicProfilesByIds(ids);
      final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
      return PageResult<PublicProfile>(
        items: profiles,
        hasMore: snapshot.docs.length >= limit,
        cursor: lastDoc,
      );
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  /// Primera página de likes (compat). Preferir [fetchPostLikeProfiles].
  Future<List<PublicProfile>> getPostLikeProfiles(
    String postId, {
    int limit = likesPageSize,
  }) async {
    final page = await fetchPostLikeProfiles(postId, limit: limit);
    return page.items;
  }

  // --- Comments ---

  /// Página de comentarios: los más recientes, en orden ASC para el hilo.
  ///
  /// Usa `limitToLast` sobre `createdAt ASC` (índice existente). Un `.limit`
  /// plano devolvía los *más viejos* y escondía los nuevos cuando había más
  /// de N comentarios.
  static const commentsPageSize = 30;

  Stream<PageResult<PostCommentModel>> watchPostComments(
    String postId, {
    int limit = commentsPageSize,
  }) {
    return _postComments
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snapshot) => _commentsPageFromSnapshot(snapshot, limit));
  }

  /// Comentarios más viejos que [endBefore] (cursor = doc más antiguo ya
  /// visible). También en ASC vía `limitToLast`.
  Future<PageResult<PostCommentModel>> fetchOlderPostComments(
    String postId, {
    required Object endBefore,
    int limit = commentsPageSize,
  }) async {
    if (endBefore is! DocumentSnapshot<Map<String, dynamic>>) {
      throw ArgumentError('Cursor de comentarios inválido.');
    }
    try {
      final snapshot = await _postComments
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .endBeforeDocument(endBefore)
          .limitToLast(limit)
          .get();
      return _commentsPageFromSnapshot(snapshot, limit);
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  PageResult<PostCommentModel> _commentsPageFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    final items = <PostCommentModel>[];
    for (final doc in snapshot.docs) {
      try {
        items.add(PostCommentModel.fromFirestore(doc));
      } catch (_) {
        // Skip malformed documents.
      }
    }
    // Cursor = doc más antiguo de la página → endBefore para cargar más viejos.
    final oldestDoc = snapshot.docs.isEmpty ? null : snapshot.docs.first;
    return PageResult<PostCommentModel>(
      items: items,
      hasMore: snapshot.docs.length >= limit,
      cursor: oldestDoc,
    );
  }

  Future<PostCommentModel> addComment({
    required String postId,
    required String postAuthorId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw SocialServiceException('Escribe un comentario.');
    }
    if (trimmed.length > PostCommentModel.maxTextLength) {
      throw SocialServiceException(
        'El comentario es demasiado largo (máx. ${PostCommentModel.maxTextLength}).',
      );
    }

    try {
      final docRef = _postComments.doc();
      final comment = PostCommentModel(
        id: docRef.id,
        postId: postId,
        postAuthorId: postAuthorId,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        text: trimmed,
        createdAt: DateTime.now(),
      );
      await docRef.set(comment.toFirestore());
      return comment;
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _postComments.doc(commentId).delete();
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  // --- Reports ---

  Future<void> reportPost({
    required String postId,
    required String reportedByUserId,
    String? reason,
  }) async {
    try {
      await _reports.add({
        'postId': postId,
        'reportedByUserId': reportedByUserId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        'status': PostReportStatus.pending.firestoreValue,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  /// Cola de moderación, de la más reciente a la más antigua. El filtro por
  /// estado se hace en memoria: así basta el índice de un solo campo y los
  /// reportes viejos, que no traen `status`, siguen apareciendo.
  ///
  /// Primera página en vivo; [fetchReportsPage] trae las siguientes.
  Stream<PageResult<PostReportModel>> watchReports({
    int limit = reportsPageSize,
  }) {
    return _reportsQuery(limit: limit).snapshots().map(
          (snapshot) => _reportsPageFromSnapshot(snapshot, limit),
        );
  }

  Future<PageResult<PostReportModel>> fetchReportsPage({
    Object? startAfter,
    int limit = reportsPageSize,
  }) async {
    var query = _reportsQuery(limit: limit);
    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    } else if (startAfter != null) {
      throw ArgumentError('Cursor de reportes inválido.');
    }
    try {
      final snapshot = await query.get();
      return _reportsPageFromSnapshot(snapshot, limit);
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Query<Map<String, dynamic>> _reportsQuery({required int limit}) {
    return _reports.orderBy('createdAt', descending: true).limit(limit);
  }

  PageResult<PostReportModel> _reportsPageFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    final items = snapshot.docs
        .map(PostReportModel.fromFirestore)
        .where((report) => report.postId.isNotEmpty)
        .toList(growable: false);
    final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
    return PageResult<PostReportModel>(
      items: items,
      hasMore: snapshot.docs.length >= limit,
      cursor: lastDoc,
    );
  }

  Future<void> setReportStatus({
    required String reportId,
    required PostReportStatus status,
    required String reviewedByUserId,
  }) async {
    try {
      await _reports.doc(reportId).update({
        'status': status.firestoreValue,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedByUserId,
      });
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  // --- Public profiles ---

  Future<void> upsertPublicProfile({
    required String userId,
    required String displayName,
    String? photoUrl,
    String? bio,
    String? username,
  }) async {
    try {
      final profile = PublicProfile(
        id: userId,
        displayName: displayName,
        photoUrl: photoUrl,
        bio: bio,
        username: username,
      );
      await _publicProfiles.doc(userId).set(
            profile.toFirestore(),
            SetOptions(merge: true),
          );
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  /// Publica el perfil de varios usuarios de una sola vez.
  ///
  /// Sirve para los miembros registrados antes de que existiera
  /// `public_profiles`, que sin esto aparecen como "Miembro SAINTS". Solo un
  /// admin puede escribir perfiles ajenos.
  Future<int> backfillPublicProfiles(List<UserModel> users) async {
    if (users.isEmpty) {
      return 0;
    }

    const chunkSize = 400;
    try {
      for (var start = 0; start < users.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, users.length);
        final batch = _firestore.batch();
        for (final user in users.sublist(start, end)) {
          final profile = PublicProfile(
            id: user.id,
            displayName: user.displayName,
            photoUrl: user.photoUrl,
            bio: user.bio,
            username: user.username,
          );
          batch.set(
            _publicProfiles.doc(user.id),
            profile.toFirestore(),
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
      return users.length;
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  /// Prefijos sobre `usernameLower` / `displayNameLower`, o browse reciente
  /// cuando la consulta está vacía.
  ///
  /// Página de [discoverPageSize]. Pasar [startAfter] del [PageResult.cursor]
  /// anterior; al cambiar el texto de búsqueda hay que pedir de nuevo sin cursor.
  static const discoverPageSize = 20;

  Future<PageResult<PublicProfile>> searchProfilesPage(
    String query, {
    Object? startAfter,
    int limit = discoverPageSize,
  }) async {
    final term = query.trim().toLowerCase().replaceFirst('@', '');

    try {
      if (term.isEmpty) {
        return await _browseProfilesPage(startAfter: startAfter, limit: limit);
      }
      return await _prefixSearchPage(term, startAfter: startAfter, limit: limit);
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  /// Primera página (compat). Preferir [searchProfilesPage].
  Future<List<PublicProfile>> searchProfiles(
    String query, {
    int limit = discoverPageSize,
  }) async {
    final page = await searchProfilesPage(query, limit: limit);
    return page.items;
  }

  Future<PageResult<PublicProfile>> _browseProfilesPage({
    Object? startAfter,
    required int limit,
  }) async {
    var query = _publicProfiles
        .orderBy('updatedAt', descending: true)
        .limit(limit);
    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    } else if (startAfter != null) {
      throw ArgumentError('Cursor de Conoce inválido.');
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map(PublicProfile.fromFirestore)
        .toList(growable: false);
    final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
    return PageResult<PublicProfile>(
      items: items,
      hasMore: snapshot.docs.length >= limit,
      cursor: lastDoc,
    );
  }

  Future<PageResult<PublicProfile>> _prefixSearchPage(
    String term, {
    Object? startAfter,
    required int limit,
  }) async {
    final previous = startAfter is _PrefixSearchCursor
        ? startAfter
        : (startAfter == null
            ? null
            : (throw ArgumentError('Cursor de búsqueda inválido.')));

    final usernameFuture = previous?.usernameDone == true
        ? Future.value(const _PrefixLeg(items: [], lastDoc: null, done: true))
        : _prefixQueryLeg(
            'usernameLower',
            term,
            limit: limit,
            startAfter: previous?.usernameDoc,
          );
    final displayNameFuture = previous?.displayNameDone == true
        ? Future.value(const _PrefixLeg(items: [], lastDoc: null, done: true))
        : _prefixQueryLeg(
            'displayNameLower',
            term,
            limit: limit,
            startAfter: previous?.displayNameDoc,
          );

    final legs = await Future.wait([usernameFuture, displayNameFuture]);
    final usernameLeg = legs[0];
    final displayNameLeg = legs[1];

    final byId = <String, PublicProfile>{};
    for (final profile in [...usernameLeg.items, ...displayNameLeg.items]) {
      byId.putIfAbsent(profile.id, () => profile);
    }

    final usernameDone = usernameLeg.done;
    final displayNameDone = displayNameLeg.done;
    final hasMore = !usernameDone || !displayNameDone;
    final cursor = hasMore
        ? _PrefixSearchCursor(
            usernameDoc: usernameLeg.lastDoc ?? previous?.usernameDoc,
            displayNameDoc: displayNameLeg.lastDoc ?? previous?.displayNameDoc,
            usernameDone: usernameDone,
            displayNameDone: displayNameDone,
          )
        : null;

    return PageResult<PublicProfile>(
      items: byId.values.toList(growable: false),
      hasMore: hasMore,
      cursor: cursor,
    );
  }

  Future<_PrefixLeg> _prefixQueryLeg(
    String field,
    String term, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    var query = _publicProfiles
        .orderBy(field)
        .where(field, isGreaterThanOrEqualTo: term)
        .where(field, isLessThanOrEqualTo: '$term\uf8ff')
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return _PrefixLeg(
      items: snapshot.docs
          .map(PublicProfile.fromFirestore)
          .toList(growable: false),
      lastDoc: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      done: snapshot.docs.length < limit,
    );
  }

  Future<PublicProfile?> getPublicProfile(String userId) async {
    final doc = await _publicProfiles.doc(userId).get();
    if (!doc.exists) {
      return null;
    }
    return PublicProfile.fromFirestore(doc);
  }
}

/// Cursor interno de búsqueda por prefijo (dos consultas en paralelo).
class _PrefixSearchCursor {
  const _PrefixSearchCursor({
    this.usernameDoc,
    this.displayNameDoc,
    this.usernameDone = false,
    this.displayNameDone = false,
  });

  final DocumentSnapshot<Map<String, dynamic>>? usernameDoc;
  final DocumentSnapshot<Map<String, dynamic>>? displayNameDoc;
  final bool usernameDone;
  final bool displayNameDone;
}

class _PrefixLeg {
  const _PrefixLeg({
    required this.items,
    required this.lastDoc,
    required this.done,
  });

  final List<PublicProfile> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool done;
}
