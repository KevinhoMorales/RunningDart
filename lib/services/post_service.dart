import 'package:image_picker/image_picker.dart';

import '../models/page_result.dart';
import '../models/post_model.dart';

abstract class PostService {
  /// Tamaño de página del feed (primera página en vivo + load-more).
  static const feedPageSize = 20;

  /// [includeHidden] solo puede pedirlo un administrador: las reglas rechazan
  /// la consulta entera si devuelve una publicación oculta que no le toca ver.
  ///
  /// Emite la primera página con cursor para [fetchFeedPage].
  Stream<PageResult<PostModel>> watchFeed({
    int limit = feedPageSize,
    bool includeHidden = false,
  });

  /// Páginas siguientes del feed (más antiguas). Pasar el [cursor] de la
  /// página anterior; no reenviar tras un refresh.
  Future<PageResult<PostModel>> fetchFeedPage({
    Object? startAfter,
    int limit = feedPageSize,
    bool includeHidden = false,
  });

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
