import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';
import 'post_service.dart';

class MockPostService implements PostService {
  final List<PostModel> _posts = [
    PostModel(
      id: 'post-001',
      authorId: 'user-mock-1',
      authorName: 'Comunidad SAINTS',
      caption: 'Bienvenidos a la comunidad. Comparte tu próxima carrera.',
      imageUrl: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  Stream<List<PostModel>> watchFeed({
    int limit = 50,
    bool includeHidden = false,
  }) async* {
    yield _visible(_posts, includeHidden).take(limit).toList(growable: false);
  }

  @override
  Stream<List<PostModel>> watchUserPosts(
    String userId, {
    bool includeHidden = false,
  }) async* {
    yield _visible(
      _posts.where((post) => post.authorId == userId),
      includeHidden,
    ).toList(growable: false);
  }

  Iterable<PostModel> _visible(Iterable<PostModel> posts, bool includeHidden) {
    return includeHidden ? posts : posts.where((post) => !post.isHidden);
  }

  @override
  Future<PostModel?> getPostById(String id) async {
    try {
      return _posts.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PostModel> createPost({
    required PostModel post,
    required XFile image,
  }) async {
    throw UnsupportedError('MockPostService does not support create.');
  }

  @override
  Future<void> deletePost(String id) async {
    throw UnsupportedError('MockPostService does not support delete.');
  }

  @override
  Future<void> hidePost(
    String id, {
    required PostHiddenReason reason,
    required String moderatorId,
    String? note,
  }) async {
    _replace(
      id,
      (post) => post.copyWith(
        hiddenReason: reason,
        hiddenNote: note,
        hiddenAt: DateTime.now(),
        hiddenBy: moderatorId,
      ),
    );
  }

  @override
  Future<void> unhidePost(String id) async {
    _replace(
      id,
      (post) => PostModel(
        id: post.id,
        authorId: post.authorId,
        authorName: post.authorName,
        createdAt: post.createdAt,
        authorPhotoUrl: post.authorPhotoUrl,
        imageUrl: post.imageUrl,
        caption: post.caption,
        likesCount: post.likesCount,
        recentLikes: post.recentLikes,
        commentsCount: post.commentsCount,
      ),
    );
  }

  void _replace(String id, PostModel Function(PostModel post) update) {
    final index = _posts.indexWhere((post) => post.id == id);
    if (index != -1) {
      _posts[index] = update(_posts[index]);
    }
  }
}
