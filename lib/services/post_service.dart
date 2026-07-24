import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';

abstract class PostService {
  Stream<List<PostModel>> watchFeed({int limit = 50});
  Stream<List<PostModel>> watchUserPosts(String userId);
  Future<PostModel?> getPostById(String id);
  Future<PostModel> createPost({
    required PostModel post,
    required XFile image,
  });
  Future<void> deletePost(String id);
}
