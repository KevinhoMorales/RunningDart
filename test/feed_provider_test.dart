import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:running_dart/models/page_result.dart';
import 'package:running_dart/models/post_model.dart';
import 'package:running_dart/providers/feed_provider.dart';
import 'package:running_dart/services/post_service.dart';
import 'package:running_dart/services/social_service.dart';

const _myId = 'me';

PostModel _post(
  String id,
  String authorId, {
  int likesCount = 0,
  bool hidden = false,
  DateTime? createdAt,
}) {
  return PostModel(
    id: id,
    authorId: authorId,
    authorName: authorId,
    imageUrl: 'https://example.com/$id.jpg',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    likesCount: likesCount,
    hiddenReason: hidden ? PostHiddenReason.offensive : null,
    hiddenAt: hidden ? DateTime(2026, 1, 2) : null,
    hiddenBy: hidden ? 'admin-1' : null,
  );
}

class _FakePostService implements PostService {
  _FakePostService({required this.feed, required this.userPosts});

  final List<PostModel> feed;
  final List<PostModel> userPosts;
  String? requestedUserId;
  int fetchCalls = 0;

  /// Filtra como Firestore, donde la consulta ya excluye las ocultas, y no
  /// como una lista en memoria que las devuelve todas.
  @override
  Stream<PageResult<PostModel>> watchFeed({
    int limit = PostService.feedPageSize,
    bool includeHidden = false,
  }) {
    return Stream.value(_page(_visible(feed, includeHidden), limit: limit));
  }

  @override
  Future<PageResult<PostModel>> fetchFeedPage({
    Object? startAfter,
    int limit = PostService.feedPageSize,
    bool includeHidden = false,
  }) async {
    fetchCalls++;
    final visible = _visible(feed, includeHidden).toList(growable: false);
    var start = 0;
    if (startAfter is String) {
      final index = visible.indexWhere((post) => post.id == startAfter);
      start = index < 0 ? visible.length : index + 1;
    }
    return _page(visible.skip(start).toList(), limit: limit);
  }

  PageResult<PostModel> _page(Iterable<PostModel> source, {required int limit}) {
    final list = source.toList(growable: false);
    final items = list.take(limit).toList(growable: false);
    return PageResult<PostModel>(
      items: items,
      hasMore: list.length > limit,
      cursor: items.isEmpty ? null : items.last.id,
    );
  }

  @override
  Stream<PageResult<PostModel>> watchUserPosts(
    String userId, {
    int limit = PostService.userPostsPageSize,
    bool includeHidden = false,
  }) {
    requestedUserId = userId;
    return Stream.value(
      _page(_visible(userPosts, includeHidden), limit: limit),
    );
  }

  @override
  Future<PageResult<PostModel>> fetchUserPostsPage(
    String userId, {
    Object? startAfter,
    int limit = PostService.userPostsPageSize,
    bool includeHidden = false,
  }) async {
    final visible = _visible(userPosts, includeHidden).toList(growable: false);
    var start = 0;
    if (startAfter is String) {
      final index = visible.indexWhere((post) => post.id == startAfter);
      start = index < 0 ? visible.length : index + 1;
    }
    return _page(visible.skip(start).toList(), limit: limit);
  }

  @override
  Future<int> countUserPosts(
    String userId, {
    bool includeHidden = false,
  }) async {
    return _visible(userPosts, includeHidden).length;
  }

  Iterable<PostModel> _visible(Iterable<PostModel> posts, bool includeHidden) {
    return includeHidden ? posts : posts.where((post) => !post.isHidden);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeSocialService implements SocialService {
  _FakeSocialService({this.blockedIds = const {}, this.failLikes = false});

  final Set<String> blockedIds;
  final bool failLikes;
  final List<String> liked = [];
  final List<String> unliked = [];

  @override
  Stream<Set<String>> watchBlockedIds(String userId) =>
      Stream.value(blockedIds);

  @override
  Stream<Set<String>> watchLikedPostIds(String userId) =>
      Stream.value(const {});

  @override
  Future<void> likePost({
    required String postId,
    required String userId,
    required String postAuthorId,
  }) async {
    if (failLikes) {
      throw SocialServiceException('boom');
    }
    liked.add(postId);
  }

  @override
  Future<void> unlikePost({
    required String postId,
    required String userId,
  }) async {
    if (failLikes) {
      throw SocialServiceException('boom');
    }
    unliked.add(postId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Deja que los streams sincrónicos entreguen su primer valor.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('myPosts only keeps the posts written by the current user', () async {
    final postService = _FakePostService(
      feed: [
        _post('mine-1', _myId),
        _post('theirs-1', 'someone'),
      ],
      userPosts: [_post('mine-1', _myId)],
    );
    final provider = FeedProvider(postService, _FakeSocialService());

    provider.start(_myId);
    await _settle();

    expect(postService.requestedUserId, _myId);
    expect(provider.myPosts.map((p) => p.id), ['mine-1']);
    expect(provider.posts.length, 2);
    expect(provider.isLoadingMyPosts, isFalse);

    provider.dispose();
  });

  test('myPosts keeps older posts that no longer fit in the feed', () async {
    // El feed está acotado, así que una publicación mía antigua queda fuera de
    // `posts`, pero debe seguir apareciendo en mi cuadrícula.
    final oldPost = _post('mine-old', _myId);
    final postService = _FakePostService(
      feed: [_post('theirs-1', 'someone')],
      userPosts: [oldPost],
    );
    final provider = FeedProvider(postService, _FakeSocialService());

    provider.start(_myId);
    await _settle();

    expect(provider.posts.any((p) => p.id == 'mine-old'), isFalse);
    expect(provider.myPosts.map((p) => p.id), ['mine-old']);

    provider.dispose();
  });

  test('blocked authors are filtered out of the feed but not from mine',
      () async {
    final postService = _FakePostService(
      feed: [
        _post('mine-1', _myId),
        _post('blocked-1', 'blocked-user'),
      ],
      userPosts: [_post('mine-1', _myId)],
    );
    final provider = FeedProvider(
      postService,
      _FakeSocialService(blockedIds: const {'blocked-user'}),
    );

    provider.start(_myId);
    await _settle();

    expect(provider.posts.map((p) => p.id), ['mine-1']);
    expect(provider.myPosts.map((p) => p.id), ['mine-1']);

    provider.dispose();
  });

  test('liking a post updates the heart and the counter right away', () async {
    final post = _post('post-1', 'someone', likesCount: 4);
    final social = _FakeSocialService();
    final provider = FeedProvider(
      _FakePostService(feed: [post], userPosts: const []),
      social,
    );

    provider.start(_myId);
    await _settle();

    expect(provider.isLiked(post.id), isFalse);
    expect(provider.likesFor(post), 4);

    await provider.toggleLike(post);

    expect(social.liked, ['post-1']);
    expect(provider.isLiked(post.id), isTrue);
    expect(provider.likesFor(post), 5);

    provider.dispose();
  });

  test('the optimistic like is dropped once the server counter arrives',
      () async {
    final post = _post('post-1', 'someone', likesCount: 4);
    final provider = FeedProvider(
      _FakePostService(feed: [post], userPosts: const []),
      _FakeSocialService(),
    );

    provider.start(_myId);
    await _settle();
    await provider.toggleLike(post);

    // La Cloud Function ya escribió: el post trae el total real y el ajuste
    // local no debe sumarse otra vez.
    final synced = post.copyWith(likesCount: 5);
    expect(provider.likesFor(synced), 5);

    provider.dispose();
  });

  test('a failed like is rolled back', () async {
    final post = _post('post-1', 'someone', likesCount: 2);
    final provider = FeedProvider(
      _FakePostService(feed: [post], userPosts: const []),
      _FakeSocialService(failLikes: true),
    );

    provider.start(_myId);
    await _settle();

    await expectLater(provider.toggleLike(post), throwsA(isA<Exception>()));

    expect(provider.isLiked(post.id), isFalse);
    expect(provider.likesFor(post), 2);

    provider.dispose();
  });

  test('a hidden post of someone else leaves the feed', () async {
    final postService = _FakePostService(
      feed: [
        _post('theirs-hidden', 'someone', hidden: true),
        _post('theirs-1', 'someone'),
      ],
      userPosts: const [],
    );
    final provider = FeedProvider(postService, _FakeSocialService());

    provider.start(_myId);
    await _settle();

    expect(provider.posts.map((p) => p.id), ['theirs-1']);

    provider.dispose();
  });

  test('my hidden post leaves the feed but stays in my posts so I know why',
      () async {
    final mineHidden = _post('mine-hidden', _myId, hidden: true);
    final postService = _FakePostService(
      feed: [mineHidden],
      userPosts: [mineHidden],
    );
    final provider = FeedProvider(postService, _FakeSocialService());

    provider.start(_myId);
    await _settle();

    expect(provider.posts, isEmpty);
    expect(provider.myPosts.map((p) => p.id), ['mine-hidden']);

    provider.dispose();
  });

  test('a moderator sees the hidden posts to be able to restore them',
      () async {
    final postService = _FakePostService(
      feed: [
        _post('theirs-hidden', 'someone', hidden: true),
        _post('theirs-1', 'someone'),
      ],
      userPosts: const [],
    );
    final provider = FeedProvider(postService, _FakeSocialService());

    provider.start(_myId, isModerator: true);
    await _settle();

    expect(provider.posts.map((p) => p.id), ['theirs-hidden', 'theirs-1']);

    provider.dispose();
  });

  test('hidePost carries the reason, the note and who moderated', () async {
    final postService = _RecordingPostService();
    final provider = FeedProvider(postService, _FakeSocialService());

    provider.start(_myId);
    await _settle();
    await provider.hidePost(
      'post-1',
      reason: PostHiddenReason.spam,
      note: 'Publicidad repetida',
    );

    expect(postService.hiddenId, 'post-1');
    expect(postService.hiddenReason, PostHiddenReason.spam);
    expect(postService.hiddenNote, 'Publicidad repetida');
    expect(postService.moderatorId, _myId);

    await provider.unhidePost('post-1');
    expect(postService.unhiddenId, 'post-1');

    provider.dispose();
  });

  test('deletePost is delegated to the post service', () async {
    final postService = _RecordingPostService();
    final provider = FeedProvider(postService, _FakeSocialService());

    await provider.deletePost('post-1');

    expect(postService.deletedId, 'post-1');

    provider.dispose();
  });

  test('loadMore appends the next page without duplicating', () async {
    final feed = List.generate(
      45,
      (i) => _post(
        'p-$i',
        'author',
        createdAt: DateTime(2026, 1, 1).add(Duration(minutes: 45 - i)),
      ),
    );
    final postService = _FakePostService(feed: feed, userPosts: const []);
    final provider = FeedProvider(postService, _FakeSocialService());

    provider.start(_myId);
    await _settle();

    expect(provider.posts.length, PostService.feedPageSize);
    expect(provider.hasMore, isTrue);

    await provider.loadMore();
    expect(postService.fetchCalls, 1);
    expect(provider.posts.length, PostService.feedPageSize * 2);
    expect(provider.posts.map((p) => p.id).toSet().length, provider.posts.length);

    await provider.loadMore();
    expect(provider.posts.length, 45);
    expect(provider.hasMore, isFalse);

    provider.dispose();
  });

  test('refresh discards an in-flight loadMore', () async {
    final feed = List.generate(
      40,
      (i) => _post('p-$i', 'author'),
    );
    final postService = _FakePostService(feed: feed, userPosts: const []);
    final provider = FeedProvider(postService, _FakeSocialService());

    provider.start(_myId);
    await _settle();

    final load = provider.loadMore();
    await provider.refresh();
    await load;
    await _settle();

    expect(provider.posts.length, PostService.feedPageSize);
    expect(provider.isLoadingMore, isFalse);

    provider.dispose();
  });

  test('user posts pages append without duplicating', () async {
    final userPosts = List.generate(
      50,
      (i) => _post(
        'mine-$i',
        _myId,
        createdAt: DateTime(2026, 1, 1).add(Duration(minutes: 50 - i)),
      ),
    );
    final postService = _FakePostService(feed: const [], userPosts: userPosts);

    final first = await postService
        .watchUserPosts(_myId)
        .first;
    expect(first.items.length, PostService.userPostsPageSize);
    expect(first.hasMore, isTrue);

    final second = await postService.fetchUserPostsPage(
      _myId,
      startAfter: first.cursor,
    );
    expect(second.items.length, PostService.userPostsPageSize);
    final ids = {...first.items.map((p) => p.id), ...second.items.map((p) => p.id)};
    expect(ids.length, PostService.userPostsPageSize * 2);

    expect(await postService.countUserPosts(_myId), 50);
  });
}

class _RecordingPostService implements PostService {
  String? deletedId;
  String? hiddenId;
  PostHiddenReason? hiddenReason;
  String? hiddenNote;
  String? moderatorId;
  String? unhiddenId;

  @override
  Future<void> deletePost(String id) async {
    deletedId = id;
  }

  @override
  Future<void> hidePost(
    String id, {
    required PostHiddenReason reason,
    required String moderatorId,
    String? note,
  }) async {
    hiddenId = id;
    hiddenReason = reason;
    hiddenNote = note;
    this.moderatorId = moderatorId;
  }

  @override
  Future<void> unhidePost(String id) async {
    unhiddenId = id;
  }

  @override
  Stream<PageResult<PostModel>> watchFeed({
    int limit = PostService.feedPageSize,
    bool includeHidden = false,
  }) =>
      Stream.value(const PageResult(items: [], hasMore: false));

  @override
  Future<PageResult<PostModel>> fetchFeedPage({
    Object? startAfter,
    int limit = PostService.feedPageSize,
    bool includeHidden = false,
  }) async =>
      const PageResult(items: [], hasMore: false);

  @override
  Stream<PageResult<PostModel>> watchUserPosts(
    String userId, {
    int limit = PostService.userPostsPageSize,
    bool includeHidden = false,
  }) =>
      Stream.value(const PageResult(items: [], hasMore: false));

  @override
  Future<PageResult<PostModel>> fetchUserPostsPage(
    String userId, {
    Object? startAfter,
    int limit = PostService.userPostsPageSize,
    bool includeHidden = false,
  }) async =>
      const PageResult(items: [], hasMore: false);

  @override
  Future<int> countUserPosts(
    String userId, {
    bool includeHidden = false,
  }) async =>
      0;

  @override
  Future<PostModel> createPost({
    required PostModel post,
    required XFile image,
  }) async {
    return post;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
