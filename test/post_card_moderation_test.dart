import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/models/post_model.dart';
import 'package:running_dart/widgets/post_card.dart';

const _authorId = 'author';

PostModel _post({
  PostHiddenReason? hiddenReason,
  String? hiddenNote,
  bool hidden = false,
}) {
  return PostModel(
    id: 'post-1',
    authorId: _authorId,
    authorName: 'Autor',
    imageUrl: 'https://example.com/a.jpg',
    createdAt: DateTime(2026, 1, 1),
    hiddenReason: hidden ? (hiddenReason ?? PostHiddenReason.offensive) : null,
    hiddenNote: hidden ? hiddenNote : null,
    hiddenAt: hidden ? DateTime(2026, 1, 2) : null,
    hiddenBy: hidden ? 'admin-1' : null,
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required PostModel post,
  required String currentUserId,
  bool isAdmin = false,
  void Function(PostCardAction action)? onAction,
}) {
  tester.view.physicalSize = const Size(500, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: post,
          currentUserId: currentUserId,
          isAdmin: isAdmin,
          onOpenAuthor: () {},
          onAction: onAction ?? (_) {},
          isLiked: false,
          likesCount: post.likesCount,
          onToggleLike: () {},
          onOpenLikes: () {},
          onOpenPost: () {},
        ),
      ),
    ),
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_horiz_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only the author is offered to delete', (tester) async {
    await _pumpCard(tester, post: _post(), currentUserId: _authorId);
    await _openMenu(tester);

    expect(find.text('Eliminar'), findsOneWidget);
    expect(find.text('Ocultar publicación'), findsNothing);
  });

  testWidgets('the admin can hide but not delete someone else\'s post',
      (tester) async {
    await _pumpCard(
      tester,
      post: _post(),
      currentUserId: 'admin-1',
      isAdmin: true,
    );
    await _openMenu(tester);

    expect(find.text('Ocultar publicación'), findsOneWidget);
    expect(find.text('Eliminar'), findsNothing);
  });

  testWidgets('a regular user gets neither hiding nor deleting',
      (tester) async {
    await _pumpCard(tester, post: _post(), currentUserId: 'someone');
    await _openMenu(tester);

    expect(find.text('Eliminar'), findsNothing);
    expect(find.text('Ocultar publicación'), findsNothing);
    expect(find.text('Reportar'), findsOneWidget);
  });

  testWidgets('an already hidden post offers the admin to restore it',
      (tester) async {
    PostCardAction? action;
    await _pumpCard(
      tester,
      post: _post(hidden: true),
      currentUserId: 'admin-1',
      isAdmin: true,
      onAction: (value) => action = value,
    );
    await _openMenu(tester);

    expect(find.text('Ocultar publicación'), findsNothing);

    await tester.tap(find.text('Volver a mostrar'));
    await tester.pumpAndSettle();

    expect(action, PostCardAction.unhide);
  });

  testWidgets('the author reads why the post was hidden and the note',
      (tester) async {
    await _pumpCard(
      tester,
      post: _post(
        hidden: true,
        hiddenReason: PostHiddenReason.nudity,
        hiddenNote: 'Cuida las fotos que compartes',
      ),
      currentUserId: _authorId,
    );

    expect(find.byType(HiddenPostNotice), findsOneWidget);
    expect(
      find.textContaining('Solo tú puedes ver esta publicación'),
      findsOneWidget,
    );
    expect(
      find.textContaining(PostHiddenReason.nudity.label),
      findsOneWidget,
    );
    expect(find.text('Cuida las fotos que compartes'), findsOneWidget);
  });

  testWidgets('the admin sees that it is hidden from the community',
      (tester) async {
    await _pumpCard(
      tester,
      post: _post(hidden: true),
      currentUserId: 'admin-1',
      isAdmin: true,
    );

    expect(
      find.textContaining('Oculta para la comunidad'),
      findsOneWidget,
    );
  });

  testWidgets('a post that is not hidden shows no notice', (tester) async {
    await _pumpCard(tester, post: _post(), currentUserId: _authorId);

    expect(find.byType(HiddenPostNotice), findsNothing);
  });
}
