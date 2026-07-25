import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/models/post_model.dart';
import 'package:running_dart/widgets/post_card.dart';

PostModel _post({int likesCount = 0, List<PostLikePreview> recentLikes = const []}) {
  return PostModel(
    id: 'post-1',
    authorId: 'author',
    authorName: 'Autor',
    imageUrl: 'https://example.com/a.jpg',
    createdAt: DateTime(2026, 1, 1),
    likesCount: likesCount,
    recentLikes: recentLikes,
  );
}

PostLikePreview _like(String name) =>
    PostLikePreview(userId: name.toLowerCase(), displayName: name);

/// El resumen mezcla nombres en negrita con el resto en tono suave, así que su
/// texto vive en varios spans.
Finder _summary(String text) => find.text(text, findRichText: true);

Future<void> _pumpCard(
  WidgetTester tester, {
  required PostModel post,
  bool isLiked = false,
  VoidCallback? onToggleLike,
  VoidCallback? onOpenLikes,
  VoidCallback? onOpenPost,
}) {
  // La tarjeta lleva una foto cuadrada, así que necesita más alto que la
  // ventana de prueba por defecto para caber completa.
  tester.view.physicalSize = const Size(500, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: post,
          currentUserId: 'me',
          isAdmin: false,
          onOpenAuthor: () {},
          onAction: (_) {},
          isLiked: isLiked,
          likesCount: post.likesCount,
          onToggleLike: onToggleLike ?? () {},
          onOpenLikes: onOpenLikes ?? () {},
          onOpenPost: onOpenPost ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows an outlined heart that fills when liked', (tester) async {
    await _pumpCard(tester, post: _post());
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await _pumpCard(tester, post: _post(), isLiked: true);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('tapping the heart toggles the like', (tester) async {
    var taps = 0;
    await _pumpCard(tester, post: _post(), onToggleLike: () => taps++);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('double tapping the photo adds the like once', (tester) async {
    var taps = 0;
    await _pumpCard(tester, post: _post(), onToggleLike: () => taps++);

    await tester.tap(find.byType(LikeableImage));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(LikeableImage));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('double tapping an already liked photo does not unlike it',
      (tester) async {
    var taps = 0;
    await _pumpCard(
      tester,
      post: _post(likesCount: 1),
      isLiked: true,
      onToggleLike: () => taps++,
    );

    await tester.tap(find.byType(LikeableImage));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(LikeableImage));
    await tester.pumpAndSettle();

    expect(taps, 0);
  });

  testWidgets('names the people when there are only a few', (tester) async {
    await _pumpCard(
      tester,
      post: _post(likesCount: 1, recentLikes: [_like('Ana')]),
    );
    expect(_summary('Le gusta a Ana'), findsOneWidget);

    await _pumpCard(
      tester,
      post: _post(likesCount: 2, recentLikes: [_like('Ana'), _like('Luis')]),
    );
    expect(_summary('Les gusta a Ana y Luis'), findsOneWidget);
  });

  testWidgets('shows only the number when there are many', (tester) async {
    await _pumpCard(
      tester,
      post: _post(
        likesCount: 24,
        recentLikes: [_like('Ana'), _like('Luis'), _like('Sofía')],
      ),
    );

    expect(_summary('24 Me gusta'), findsOneWidget);
  });

  testWidgets('falls back to the number when there are no names yet',
      (tester) async {
    await _pumpCard(tester, post: _post(likesCount: 2));

    expect(_summary('2 Me gusta'), findsOneWidget);
  });

  testWidgets('hides the summary when nobody liked the post', (tester) async {
    await _pumpCard(tester, post: _post());

    expect(find.byType(LikesSummary), findsNothing);
  });

  testWidgets('opens the list when the summary is tapped', (tester) async {
    var opened = 0;
    await _pumpCard(
      tester,
      post: _post(likesCount: 12),
      onOpenLikes: () => opened++,
    );

    await tester.tap(_summary('12 Me gusta'));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('a single tap on the photo opens the post without liking it',
      (tester) async {
    var likes = 0;
    var opened = 0;
    await _pumpCard(
      tester,
      post: _post(),
      onToggleLike: () => likes++,
      onOpenPost: () => opened++,
    );

    await tester.tap(find.byType(LikeableImage));
    // El toque simple se resuelve al vencer el margen del doble tap.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(likes, 0);
  });
}
