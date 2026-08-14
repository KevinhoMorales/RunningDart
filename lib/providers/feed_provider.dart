import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/page_result.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';

/// Like que ya se pintó en pantalla pero que el servidor todavía no confirma.
///
/// [baselineCount] es el contador que traía el post cuando se tocó el corazón:
/// mientras no cambie, la Cloud Function no ha escrito y hay que seguir
/// mostrando el valor optimista.
class _PendingLike {
  const _PendingLike({required this.liked, required this.baselineCount});

  final bool liked;
  final int baselineCount;
}

class FeedProvider extends ChangeNotifier {
  FeedProvider(this._postService, this._socialService);

  final PostService _postService;
  final SocialService _socialService;

  StreamSubscription<PageResult<PostModel>>? _feedSubscription;
  StreamSubscription<PageResult<PostModel>>? _myPostsSubscription;
  StreamSubscription<Set<String>>? _blockedSubscription;
  StreamSubscription<Set<String>>? _likedSubscription;

  String? _userId;
  bool _isModerator = false;

  /// Primera página en vivo (stream).
  List<PostModel> _livePosts = [];

  /// Páginas siguientes pedidas con [loadMore].
  List<PostModel> _olderPosts = [];

  Object? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  /// Sube en cada refresh / restart para descartar load-more en vuelo.
  int _feedGeneration = 0;

  List<PostModel> _myPosts = [];
  Set<String> _blockedIds = {};
  Set<String> _likedPostIds = {};
  final Map<String, _PendingLike> _pendingLikes = {};
  bool _isLoading = false;
  bool _isLoadingMyPosts = false;
  String? _error;
  String? _myPostsError;
  String? _blockedError;

  bool get isLoading => _isLoading;
  bool get isLoadingMyPosts => _isLoadingMyPosts;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get myPostsError => _myPostsError;

  /// Si la lista de bloqueos no cargó, el feed no puede filtrarla y quien
  /// bloqueó a alguien seguiría viendo sus publicaciones sin saber por qué.
  String? get blockedError => _blockedError;

  List<PostModel> get posts {
    final byId = <String, PostModel>{};
    for (final post in _olderPosts) {
      byId[post.id] = post;
    }
    for (final post in _livePosts) {
      byId[post.id] = post;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged
        .where((post) => !_blockedIds.contains(post.authorId))
        .where(_canSee)
        .toList(growable: false);
  }

  /// Una publicación oculta por moderación solo la ven su autor, para saber por
  /// qué salió del feed, y los administradores, para poder revertirlo.
  bool _canSee(PostModel post) {
    return !post.isHidden || _isModerator || post.authorId == _userId;
  }

  List<PostModel> postsFollowing(Set<String> followingIds) => posts
      .where((post) => followingIds.contains(post.authorId))
      .toList(growable: false);

  /// Historial completo del usuario. Va aparte de [posts] porque el feed está
  /// acotado a las últimas publicaciones de toda la comunidad y dejaría fuera
  /// las mías más antiguas.
  List<PostModel> get myPosts => _myPosts;

  bool isLiked(String postId) {
    final pending = _pendingLikes[postId];
    if (pending != null) {
      return pending.liked;
    }
    return _likedPostIds.contains(postId);
  }

  /// Likes a mostrar: el contador del post más el ajuste optimista mientras la
  /// Cloud Function propaga el valor real.
  int likesFor(PostModel post) {
    final pending = _pendingLikes[post.id];
    if (pending == null || post.likesCount != pending.baselineCount) {
      return post.likesCount;
    }
    final delta = pending.liked ? 1 : -1;
    final total = post.likesCount + delta;
    return total < 0 ? 0 : total;
  }

  Future<void> toggleLike(PostModel post) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    final liked = isLiked(post.id);
    final previous = _pendingLikes[post.id];
    _pendingLikes[post.id] = _PendingLike(
      liked: !liked,
      baselineCount: post.likesCount,
    );
    notifyListeners();

    try {
      if (liked) {
        await _socialService.unlikePost(postId: post.id, userId: userId);
      } else {
        await _socialService.likePost(
          postId: post.id,
          userId: userId,
          postAuthorId: post.authorId,
        );
      }
    } catch (_) {
      if (previous == null) {
        _pendingLikes.remove(post.id);
      } else {
        _pendingLikes[post.id] = previous;
      }
      notifyListeners();
      rethrow;
    }
  }

  void start(String userId, {bool isModerator = false}) {
    if (_userId == userId && _feedSubscription != null) {
      if (_isModerator != isModerator) {
        // El rol decide qué pide la consulta, no solo qué se pinta, así que
        // hay que rehacer la suscripción.
        _isModerator = isModerator;
        _resetOlderPages();
        _listenFeed();
        notifyListeners();
      }
      return;
    }
    _userId = userId;
    _isModerator = isModerator;
    _isLoading = true;
    _error = null;
    _resetOlderPages();
    notifyListeners();

    _listenFeed();
    _listenMyPosts(userId);
    _listenLikes(userId);

    _listenBlocked(userId);
  }

  void _resetOlderPages() {
    _feedGeneration++;
    _olderPosts = [];
    _nextCursor = null;
    _hasMore = true;
    _isLoadingMore = false;
  }

  void _listenBlocked(String userId) {
    _blockedSubscription?.cancel();
    _blockedSubscription = _socialService.watchBlockedIds(userId).listen(
      (ids) {
        _blockedIds = ids;
        _blockedError = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('No se pudo cargar tu lista de bloqueos: $error');
        _blockedError = 'No pudimos aplicar tus bloqueos.';
        notifyListeners();
      },
    );
  }

  /// Solo un moderador puede pedir las ocultas: las reglas rechazan la consulta
  /// entera si alguien más las incluye.
  void _listenFeed({Completer<void>? ready}) {
    _feedSubscription?.cancel();
    _feedSubscription = _postService
        .watchFeed(includeHidden: _isModerator)
        .listen(
      (page) {
        _livePosts = page.items;
        // Si todavía no hay páginas viejas, el cursor del stream es el de
        // load-more. Si ya las hay, no lo pisamos: el stream solo refresca la
        // primera página.
        if (_olderPosts.isEmpty) {
          _nextCursor = page.cursor;
          _hasMore = page.hasMore;
        } else {
          final liveIds = page.items.map((post) => post.id).toSet();
          _olderPosts =
              _olderPosts.where((post) => !liveIds.contains(post.id)).toList();
        }
        _isLoading = false;
        _error = null;
        _prunePendingLikes();
        if (ready != null && !ready.isCompleted) {
          ready.complete();
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('No se pudo cargar el feed: $error');
        _error = 'No se pudo cargar la comunidad.';
        _isLoading = false;
        if (ready != null && !ready.isCompleted) {
          ready.complete();
        }
        notifyListeners();
      },
    );
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _nextCursor == null || _isLoading) {
      return;
    }

    final generation = _feedGeneration;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _postService.fetchFeedPage(
        startAfter: _nextCursor,
        includeHidden: _isModerator,
      );
      if (generation != _feedGeneration) {
        return;
      }

      final knownIds = <String>{
        for (final post in _livePosts) post.id,
        for (final post in _olderPosts) post.id,
      };
      final fresh = page.items
          .where((post) => !knownIds.contains(post.id))
          .toList(growable: false);
      _olderPosts = [..._olderPosts, ...fresh];
      _nextCursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (error) {
      if (generation != _feedGeneration) {
        return;
      }
      debugPrint('No se pudo cargar más del feed: $error');
    } finally {
      if (generation == _feedGeneration) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void _listenLikes(String userId) {
    _likedSubscription?.cancel();
    _likedSubscription = _socialService.watchLikedPostIds(userId).listen(
      (ids) {
        _likedPostIds = ids;
        _prunePendingLikes();
        notifyListeners();
      },
      // Sin este aviso, un índice faltante deja los corazones apagados sin
      // ninguna pista de por qué.
      onError: (error) {
        debugPrint('No se pudo escuchar tus me gusta: $error');
      },
    );
  }

  /// Olvida los likes optimistas que el servidor ya confirmó: el post trae un
  /// contador distinto al de partida y la lista de mis likes coincide.
  void _prunePendingLikes() {
    if (_pendingLikes.isEmpty) {
      return;
    }
    final counts = <String, int>{
      for (final post in _myPosts) post.id: post.likesCount,
      for (final post in _livePosts) post.id: post.likesCount,
      for (final post in _olderPosts) post.id: post.likesCount,
    };
    _pendingLikes.removeWhere((postId, pending) {
      final count = counts[postId];
      return count != null &&
          count != pending.baselineCount &&
          _likedPostIds.contains(postId) == pending.liked;
    });
  }

  void _listenMyPosts(String userId) {
    _isLoadingMyPosts = _myPosts.isEmpty;

    _myPostsSubscription?.cancel();
    // Primera página de las propias: basta para el corazón optimista y para
    // enterarse de ocultas recientes. La cuadrícula del perfil pagina por su
    // cuenta (no reutiliza esta lista completa).
    _myPostsSubscription = _postService
        .watchUserPosts(userId, includeHidden: true)
        .listen(
      (page) {
        _myPosts = page.items;
        _isLoadingMyPosts = false;
        _myPostsError = null;
        _prunePendingLikes();
        notifyListeners();
      },
      onError: (error) {
        debugPrint('No se pudieron cargar tus publicaciones: $error');
        _isLoadingMyPosts = false;
        _myPostsError = 'No pudimos cargar tus publicaciones.';
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    final completer = Completer<void>();

    _isLoading = _livePosts.isEmpty && _olderPosts.isEmpty;
    _error = null;
    _myPostsError = null;
    _resetOlderPages();
    notifyListeners();

    _listenMyPosts(userId);
    _listenLikes(userId);
    _listenBlocked(userId);
    _listenFeed(ready: completer);

    return completer.future;
  }

  Future<PostModel> createPost({
    required PostModel post,
    required XFile image,
  }) {
    return _postService.createPost(post: post, image: image);
  }

  Future<void> deletePost(String id) {
    return _postService.deletePost(id);
  }

  Future<void> hidePost(
    String id, {
    required PostHiddenReason reason,
    String? note,
  }) {
    final userId = _userId;
    if (userId == null) {
      throw StateError('No hay sesión activa.');
    }
    return _postService.hidePost(
      id,
      reason: reason,
      moderatorId: userId,
      note: note,
    );
  }

  Future<void> unhidePost(String id) {
    return _postService.unhidePost(id);
  }

  Future<void> reportPost(String postId, {String? reason}) {
    final userId = _userId;
    if (userId == null) {
      throw StateError('No hay sesión activa.');
    }
    return _socialService.reportPost(
      postId: postId,
      reportedByUserId: userId,
      reason: reason,
    );
  }

  @override
  void dispose() {
    _feedSubscription?.cancel();
    _myPostsSubscription?.cancel();
    _blockedSubscription?.cancel();
    _likedSubscription?.cancel();
    super.dispose();
  }
}
