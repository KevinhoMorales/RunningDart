import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/models/post_comment_model.dart';

void main() {
  test('trims nothing in toFirestore beyond what the caller already cleaned', () {
    final comment = PostCommentModel(
      id: 'c1',
      postId: 'p1',
      postAuthorId: 'author',
      authorId: 'me',
      authorName: 'Ana',
      authorPhotoUrl: 'https://example.com/a.jpg',
      text: 'Gran rodada',
      createdAt: DateTime(2026, 3, 1, 10),
    );

    final data = comment.toFirestore();
    expect(data['postId'], 'p1');
    expect(data['postAuthorId'], 'author');
    expect(data['authorId'], 'me');
    expect(data['authorName'], 'Ana');
    expect(data['authorPhotoUrl'], 'https://example.com/a.jpg');
    expect(data['text'], 'Gran rodada');
    expect(data.containsKey('createdAt'), isTrue);
  });

  test('omits an empty photo url from Firestore', () {
    final data = PostCommentModel(
      id: 'c1',
      postId: 'p1',
      postAuthorId: 'author',
      authorId: 'me',
      authorName: 'Ana',
      authorPhotoUrl: '',
      text: 'Hola',
      createdAt: DateTime(2026, 3, 1),
    ).toFirestore();

    expect(data.containsKey('authorPhotoUrl'), isFalse);
  });

  test('round-trips through json', () {
    final original = PostCommentModel(
      id: 'c1',
      postId: 'p1',
      postAuthorId: 'author',
      authorId: 'me',
      authorName: 'Ana',
      text: 'Hola',
      createdAt: DateTime(2026, 3, 1, 12, 30),
    );

    final restored = PostCommentModel.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.postId, original.postId);
    expect(restored.postAuthorId, original.postAuthorId);
    expect(restored.authorId, original.authorId);
    expect(restored.authorName, original.authorName);
    expect(restored.text, original.text);
    expect(restored.createdAt, original.createdAt);
  });

  test('enforces a max length constant for rules and UI', () {
    expect(PostCommentModel.maxTextLength, 500);
  });
}
