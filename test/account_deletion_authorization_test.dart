import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/services/biometric_auth_service.dart';
import 'package:running_dart/utils/account_deletion_authorization.dart';

/// Simula un dispositivo sin Face ID ni huella, que es el caso que obliga a
/// caer al respaldo por contraseña.
class _NoBiometrics extends BiometricAuthService {
  @override
  Future<bool> canAuthenticate() async => false;
}

void main() {
  group('AccountDeletionAuthorization.userMessage', () {
    test('stays silent when the user authorized or cancelled', () {
      expect(AccountDeletionAuthorization.authorized.userMessage, isNull);
      expect(AccountDeletionAuthorization.cancelled.userMessage, isNull);
    });

    test('explains that nothing was deleted when verification fails', () {
      expect(
        AccountDeletionAuthorization.wrongPassword.userMessage,
        contains('No se eliminó nada'),
      );
      expect(
        AccountDeletionAuthorization.failed.userMessage,
        contains('No se eliminó nada'),
      );
    });
  });

  group('password fallback dialog', () {
    late AccountDeletionAuthorization? outcome;

    Future<void> runAuthorize(
      WidgetTester tester,
      PasswordVerifier verifyPassword,
    ) async {
      outcome = null;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    outcome = await AccountDeletionAuthorizer(
                      biometricAuth: _NoBiometrics(),
                    ).authorize(
                      context: context,
                      email: 'delete@test.com',
                      verifyPassword: verifyPassword,
                    );
                  },
                  child: const Text('start'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
    }

    testWidgets('authorizes when the password is correct', (tester) async {
      await runAuthorize(
        tester,
        (password) async => password == 'secret' ? null : 'Incorrecta.',
      );

      expect(find.text('Confirma tu identidad'), findsOneWidget);
      expect(find.textContaining('delete@test.com'), findsOneWidget);
      expect(
        find.textContaining('no tiene Face ID ni huella configurada'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), 'secret');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirma tu identidad'), findsNothing);
      expect(outcome, AccountDeletionAuthorization.authorized);
    });

    testWidgets('keeps the dialog open and warns on a wrong password', (
      tester,
    ) async {
      await runAuthorize(tester, (password) async => 'La contraseña no es correcta.');

      await tester.enterText(find.byType(TextFormField), 'nope');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirma tu identidad'), findsOneWidget);
      expect(find.textContaining('Te quedan 2 intentos'), findsOneWidget);
    });

    testWidgets('gives up after the allowed attempts', (tester) async {
      var calls = 0;
      await runAuthorize(tester, (password) async {
        calls++;
        return 'La contraseña no es correcta.';
      });

      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.enterText(find.byType(TextFormField), 'nope');
        await tester.tap(find.text('Autorizar'));
        await tester.pumpAndSettle();
      }

      expect(calls, AccountDeletionAuthorizer.maxPasswordAttempts);
      expect(find.text('Confirma tu identidad'), findsNothing);
      expect(outcome, AccountDeletionAuthorization.wrongPassword);
    });

    testWidgets('cancelling reports that nothing was deleted', (tester) async {
      await runAuthorize(tester, (password) async => null);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirma tu identidad'), findsNothing);
      expect(outcome, AccountDeletionAuthorization.cancelled);
    });

    testWidgets('asks for a password before verifying an empty field', (
      tester,
    ) async {
      var calls = 0;
      await runAuthorize(tester, (password) async {
        calls++;
        return null;
      });

      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.textContaining('Escribe tu contraseña.'), findsOneWidget);
      expect(find.text('Confirma tu identidad'), findsOneWidget);
    });
  });
}
