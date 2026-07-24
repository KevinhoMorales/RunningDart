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
  Stream<List<PostModel>> watchFeed({int limit = 50}) async* {
    yield List.unmodifiable(_posts);
  }

  @override
  Stream<List<PostModel>> watchUserPosts(String userId) async* {
    yield _posts.where((p) => p.authorId == userId).toList(growable: false);
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
}
