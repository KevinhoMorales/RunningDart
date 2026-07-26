import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_paths.dart';
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

  Future<List<String>> getFollowerIds(String userId) async {
    final snapshot =
        await _follows.where('followedId', isEqualTo: userId).get();
    return snapshot.docs
        .map((doc) => doc.data()['followerId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> getFollowingIds(String userId) async {
    final snapshot =
        await _follows.where('followerId', isEqualTo: userId).get();
    return snapshot.docs
        .map((doc) => doc.data()['followedId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
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

  Future<List<PublicProfile>> getPostLikeProfiles(
    String postId, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _postLikes
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final ids = snapshot.docs
          .map((doc) => doc.data()['userId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      return getPublicProfilesByIds(ids);
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
  Stream<List<PostReportModel>> watchReports({int limit = 200}) {
    return _reports
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(PostReportModel.fromFirestore)
              .where((report) => report.postId.isNotEmpty)
              .toList(growable: false),
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

  /// Prefix search sobre `usernameLower` y `displayNameLower`.
  ///
  /// Con la consulta vacia devuelve los perfiles actualizados mas recientes
  /// como sugeridos.
  Future<List<PublicProfile>> searchProfiles(
    String query, {
    int limit = 20,
  }) async {
    final term = query.trim().toLowerCase().replaceFirst('@', '');

    try {
      if (term.isEmpty) {
        final snapshot = await _publicProfiles
            .orderBy('updatedAt', descending: true)
            .limit(30)
            .get();
        return snapshot.docs
            .map(PublicProfile.fromFirestore)
            .toList(growable: false);
      }

      final results = await Future.wait([
        _prefixQuery('usernameLower', term, limit),
        _prefixQuery('displayNameLower', term, limit),
      ]);

      final byId = <String, PublicProfile>{};
      for (final profiles in results) {
        for (final profile in profiles) {
          byId.putIfAbsent(profile.id, () => profile);
        }
      }
      return byId.values.take(limit).toList(growable: false);
    } on FirebaseException catch (e) {
      throw SocialServiceException(UserMessages.firestore(e));
    }
  }

  Future<List<PublicProfile>> _prefixQuery(
    String field,
    String term,
    int limit,
  ) async {
    final snapshot = await _publicProfiles
        .orderBy(field)
        .where(field, isGreaterThanOrEqualTo: term)
        .where(field, isLessThanOrEqualTo: '$term\uf8ff')
        .limit(limit)
        .get();
    return snapshot.docs
        .map(PublicProfile.fromFirestore)
        .toList(growable: false);
  }

  Future<PublicProfile?> getPublicProfile(String userId) async {
    final doc = await _publicProfiles.doc(userId).get();
    if (!doc.exists) {
      return null;
    }
    return PublicProfile.fromFirestore(doc);
  }
}
