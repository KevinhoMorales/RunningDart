import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';

abstract class PostService {
  /// [includeHidden] solo puede pedirlo un administrador: las reglas rechazan
  /// la consulta entera si devuelve una publicación oculta que no le toca ver.
  Stream<List<PostModel>> watchFeed({int limit = 50, bool includeHidden = false});

  /// Igual que [watchFeed], pero aquí el autor también puede pedir las suyas
  /// ocultas para enterarse de por qué salieron del feed.
  Stream<List<PostModel>> watchUserPosts(
    String userId, {
    bool includeHidden = false,
  });
  Future<PostModel?> getPostById(String id);
  Future<PostModel> createPost({
    required PostModel post,
    required XFile image,
  });
  Future<void> deletePost(String id);

  /// Saca la publicación de la vista de la comunidad. Solo la ven su autor,
  /// con el motivo, y los administradores.
  Future<void> hidePost(
    String id, {
    required PostHiddenReason reason,
    required String moderatorId,
    String? note,
  });

  Future<void> unhidePost(String id);
}
