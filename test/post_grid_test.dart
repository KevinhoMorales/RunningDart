import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/models/post_model.dart';
import 'package:running_dart/widgets/post_grid.dart';

PostModel _post(String id, {String? imageUrl = 'https://example.com/a.jpg'}) {
  return PostModel(
    id: id,
    authorId: 'me',
    authorName: 'Yo',
    imageUrl: imageUrl,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required List<PostModel> posts,
  bool isLoading = false,
  void Function(PostModel post)? onOpenPost,
  Future<void> Function(PostModel post)? onDeletePost,
  VoidCallback? onEmptyAction,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            PostGrid(
              posts: posts,
              isLoading: isLoading,
              onOpenPost: onOpenPost ?? (_) {},
              onDeletePost: onDeletePost,
              emptyMessage: 'Aún no has publicado nada',
              emptySubtitle: 'Comparte tu primera carrera.',
              emptyActionLabel: 'Publicar',
              onEmptyAction: onEmptyAction ?? () {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lays the posts out three per row', (tester) async {
    await _pumpGrid(
      tester,
      posts: [_post('1'), _post('2'), _post('3'), _post('4')],
    );

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 3);
    expect(find.byType(Image), findsNWidgets(4));
  });

  testWidgets('opens the tapped post', (tester) async {
    PostModel? opened;
    await _pumpGrid(
      tester,
      posts: [_post('1'), _post('2')],
      onOpenPost: (post) => opened = post,
    );

    await tester.tap(find.byType(Image).at(1));
    await tester.pump();

    expect(opened?.id, '2');
  });

  testWidgets('skips posts without a photo', (tester) async {
    await _pumpGrid(
      tester,
      posts: [_post('1'), _post('2', imageUrl: null)],
    );

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('shows the empty state with its action', (tester) async {
    var tapped = false;
    await _pumpGrid(
      tester,
      posts: const [],
      onEmptyAction: () => tapped = true,
    );

    expect(find.text('Aún no has publicado nada'), findsOneWidget);

    await tester.tap(find.text('Publicar'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    await _pumpGrid(tester, posts: const [], isLoading: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Aún no has publicado nada'), findsNothing);
  });

  testWidgets('long pressing deletes the post after confirming',
      (tester) async {
    final deleted = <String>[];
    await _pumpGrid(
      tester,
      posts: [_post('1'), _post('2')],
      onDeletePost: (post) async => deleted.add(post.id),
    );

    await tester.longPress(find.byType(Image).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Ver publicación'), findsOneWidget);

    await tester.tap(find.text('Eliminar publicación'));
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar publicación?'), findsOneWidget);
    expect(deleted, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(deleted, ['2']);
  });

  testWidgets('cancelling the confirmation keeps the post', (tester) async {
    final deleted = <String>[];
    await _pumpGrid(
      tester,
      posts: [_post('1')],
      onDeletePost: (post) async => deleted.add(post.id),
    );

    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar publicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(deleted, isEmpty);
  });

  testWidgets('the quick menu can open the post instead', (tester) async {
    PostModel? opened;
    await _pumpGrid(
      tester,
      posts: [_post('1')],
      onOpenPost: (post) => opened = post,
      onDeletePost: (_) async {},
    );

    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver publicación'));
    await tester.pumpAndSettle();

    expect(opened?.id, '1');
  });

  testWidgets('long pressing does nothing on someone else\'s posts',
      (tester) async {
    await _pumpGrid(tester, posts: [_post('1')]);

    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar publicación'), findsNothing);
  });
}
