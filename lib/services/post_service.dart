import 'package:image_picker/image_picker.dart';

import '../models/page_result.dart';
import '../models/post_model.dart';

abstract class PostService {
  /// Tamaño de página del feed global (Explorar / base de Siguiendo).
  static const feedPageSize = 20;

  /// Tamaño de página de la cuadrícula de perfil (múltiplo de 3).
  static const userPostsPageSize = 21;

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

  /// Primera página en vivo de las publicaciones de un autor (perfil).
  ///
  /// [includeHidden] lo piden el autor y los administradores para ver las
  /// ocultas por moderación.
  Stream<PageResult<PostModel>> watchUserPosts(
    String userId, {
    int limit = userPostsPageSize,
    bool includeHidden = false,
  });

  /// Páginas siguientes del perfil. Mismo cursor opaco que [watchUserPosts].
  Future<PageResult<PostModel>> fetchUserPostsPage(
    String userId, {
    Object? startAfter,
    int limit = userPostsPageSize,
    bool includeHidden = false,
  });

  /// Conteo total para el encabezado del perfil (no el tamaño de la página).
  Future<int> countUserPosts(
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
