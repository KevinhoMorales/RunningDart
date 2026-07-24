import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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

  StreamSubscription<List<PostModel>>? _feedSubscription;
  StreamSubscription<List<PostModel>>? _myPostsSubscription;
  StreamSubscription<Set<String>>? _blockedSubscription;
  StreamSubscription<Set<String>>? _likedSubscription;

  String? _userId;
  List<PostModel> _posts = [];
  List<PostModel> _myPosts = [];
  Set<String> _blockedIds = {};
  Set<String> _likedPostIds = {};
  final Map<String, _PendingLike> _pendingLikes = {};
  bool _isLoading = false;
  bool _isLoadingMyPosts = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isLoadingMyPosts => _isLoadingMyPosts;
  String? get error => _error;

  List<PostModel> get posts => _posts
      .where((post) => !_blockedIds.contains(post.authorId))
      .toList(growable: false);

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

  void start(String userId) {
    if (_userId == userId && _feedSubscription != null) {
      return;
    }
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _feedSubscription?.cancel();
    _feedSubscription = _postService.watchFeed().listen(
      (posts) {
        _posts = posts;
        _isLoading = false;
        _error = null;
        _prunePendingLikes();
        notifyListeners();
      },
      onError: (_) {
        _error = 'No se pudo cargar la comunidad.';
        _isLoading = false;
        notifyListeners();
      },
    );

    _listenMyPosts(userId);
    _listenLikes(userId);

    _blockedSubscription?.cancel();
    _blockedSubscription = _socialService.watchBlockedIds(userId).listen(
      (ids) {
        _blockedIds = ids;
        notifyListeners();
      },
      onError: (_) {},
    );
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
      for (final post in _posts) post.id: post.likesCount,
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
    _myPostsSubscription = _postService.watchUserPosts(userId).listen(
      (posts) {
        _myPosts = posts;
        _isLoadingMyPosts = false;
        _prunePendingLikes();
        notifyListeners();
      },
      onError: (_) {
        _isLoadingMyPosts = false;
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

    _isLoading = _posts.isEmpty;
    _error = null;
    notifyListeners();

    _listenMyPosts(userId);
    _listenLikes(userId);

    _feedSubscription?.cancel();
    _feedSubscription = _postService.watchFeed().listen(
      (posts) {
        _posts = posts;
        _isLoading = false;
        _error = null;
        _prunePendingLikes();
        if (!completer.isCompleted) {
          completer.complete();
        }
        notifyListeners();
      },
      onError: (_) {
        _error = 'No se pudo cargar la comunidad.';
        _isLoading = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        notifyListeners();
      },
    );

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
