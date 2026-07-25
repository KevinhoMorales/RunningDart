import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/models/post_model.dart';

PostModel _post({
  PostHiddenReason? hiddenReason,
  String? hiddenNote,
  DateTime? hiddenAt,
  String? hiddenBy,
}) {
  return PostModel(
    id: 'post-1',
    authorId: 'author-1',
    authorName: 'Kevin',
    createdAt: DateTime(2026, 1, 15),
    imageUrl: 'https://example.com/a.jpg',
    caption: 'Rodada del domingo',
    likesCount: 4,
    hiddenReason: hiddenReason,
    hiddenNote: hiddenNote,
    hiddenAt: hiddenAt,
    hiddenBy: hiddenBy,
  );
}

void main() {
  test('a post is hidden only once it has a moderation date', () {
    expect(_post().isHidden, isFalse);
    expect(_post(hiddenAt: DateTime(2026, 2, 1)).isHidden, isTrue);
  });

  test('moderation and like fields never travel to Firestore', () {
    final data = _post(
      hiddenReason: PostHiddenReason.offensive,
      hiddenNote: 'Cuida el lenguaje',
      hiddenAt: DateTime(2026, 2, 1),
      hiddenBy: 'admin-1',
    ).toFirestore();

    expect(
      data.keys,
      isNot(contains(anyOf(
        'hiddenReason',
        'hiddenNote',
        'hiddenAt',
        'hiddenBy',
        'likesCount',
        'recentLikes',
      ))),
    );
    expect(data['authorId'], 'author-1');
    expect(data['caption'], 'Rodada del domingo');
  });

  test('publishing writes isHidden so the feed can filter on the server', () {
    expect(_post().toFirestore()['isHidden'], isFalse);
  });

  test('moderation fields survive a round trip through json', () {
    final restored = PostModel.fromJson(
      _post(
        hiddenReason: PostHiddenReason.nudity,
        hiddenNote: 'Foto sin ropa',
        hiddenAt: DateTime(2026, 2, 1),
        hiddenBy: 'admin-1',
      ).toJson(),
    );

    expect(restored.hiddenReason, PostHiddenReason.nudity);
    expect(restored.hiddenNote, 'Foto sin ropa');
    expect(restored.hiddenAt, DateTime(2026, 2, 1));
    expect(restored.hiddenBy, 'admin-1');
    expect(restored.isHidden, isTrue);
  });

  test('an unknown reason key reads as no reason', () {
    expect(PostHiddenReason.fromKey('whatever'), isNull);
    expect(PostHiddenReason.fromKey(null), isNull);
    expect(PostHiddenReason.fromKey('spam'), PostHiddenReason.spam);
  });
}
