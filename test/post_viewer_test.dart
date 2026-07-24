import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/models/post_model.dart';
import 'package:running_dart/widgets/post_viewer.dart';

PostModel _post({String? caption, int likesCount = 0}) {
  return PostModel(
    id: 'post-1',
    authorId: 'me',
    authorName: 'Yo',
    imageUrl: 'https://example.com/a.jpg',
    createdAt: DateTime(2026, 1, 15),
    caption: caption,
    likesCount: likesCount,
  );
}

/// Abre el visor desde una pantalla real para ejercitar la ruta que usa la app.
Future<void> _openViewer(
  WidgetTester tester, {
  required PostModel post,
  Future<void> Function()? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showPostViewer(context, post, onDelete: onDelete),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

double _scale(WidgetTester tester) {
  final viewer = tester.widget<InteractiveViewer>(
    find.byType(InteractiveViewer),
  );
  return viewer.transformationController!.value.getMaxScaleOnAxis();
}

void main() {
  testWidgets('shows the photo with its date and caption', (tester) async {
    await _openViewer(tester, post: _post(caption: 'Rodada del domingo'));

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Rodada del domingo'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('double tapping zooms in and out again', (tester) async {
    await _openViewer(tester, post: _post());

    expect(_scale(tester), 1);

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();

    expect(_scale(tester), greaterThan(1));

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();

    expect(_scale(tester), 1);
  });

  testWidgets('dragging down closes the viewer', (tester) async {
    await _openViewer(tester, post: _post());

    await tester.drag(
      find.byType(InteractiveViewer),
      const Offset(0, PostViewer.dismissDistance + 60),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('a short drag keeps the viewer open', (tester) async {
    await _openViewer(tester, post: _post());

    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 20));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('hides the delete menu on posts that are not mine',
      (tester) async {
    await _openViewer(tester, post: _post());

    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
  });

  testWidgets('shows the delete menu when deleting is allowed', (tester) async {
    await _openViewer(tester, post: _post(), onDelete: () async {});

    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation, closes and reports back',
      (tester) async {
    var deleted = 0;
    await _openViewer(
      tester,
      post: _post(),
      onDelete: () async => deleted++,
    );

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar publicación?'), findsOneWidget);
    expect(deleted, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(deleted, 1);
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('cancelling the confirmation deletes nothing and stays open',
      (tester) async {
    var deleted = 0;
    await _openViewer(
      tester,
      post: _post(),
      onDelete: () async => deleted++,
    );

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(deleted, 0);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
