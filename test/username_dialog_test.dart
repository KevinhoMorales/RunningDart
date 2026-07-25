import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/widgets/username_dialog.dart';

/// Guarda lo que devuelve el diálogo para poder revisarlo tras cerrarlo.
class _Result {
  String? username;
  bool asked = false;
}

Future<_Result> _pumpOpener(
  WidgetTester tester, {
  String? currentUsername,
}) async {
  final result = _Result();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result.username = await askNewUsername(
                context,
                currentUsername: currentUsername,
              );
              result.asked = true;
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();

  return result;
}

void main() {
  testWidgets('devuelve el nombre normalizado y cierra sin errores',
      (tester) async {
    final result = await _pumpOpener(tester, currentUsername: 'viejo');

    expect(find.text('viejo'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Nuevo.User');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(result.username, 'nuevo.user');
    // El controller vive dentro del diálogo, así que la transición de salida
    // termina sin usar nada destruido.
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('cancelar devuelve null', (tester) async {
    final result = await _pumpOpener(tester, currentUsername: 'viejo');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result.asked, isTrue);
    expect(result.username, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un nombre inválido no cierra el diálogo', (tester) async {
    final result = await _pumpOpener(tester);

    await tester.enterText(find.byType(TextFormField), 'ab');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Mínimo 3 caracteres'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(result.asked, isFalse);
  });
}
