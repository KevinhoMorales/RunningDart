import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/utils/user_messages.dart';

void main() {
  group('UserMessages.auth', () {
    test('maps invalid credential codes to Spanish login message', () {
      for (final code in [
        'not-found',
        'user-not-found',
        'invalid-credential',
        'invalid-login-credentials',
        'wrong-password',
      ]) {
        expect(
          UserMessages.auth(_authException(code: code)),
          'Correo o contraseña incorrectos.',
        );
      }
    });

    test('maps email-already-in-use to Spanish', () {
      expect(
        UserMessages.auth(_authException(code: 'email-already-in-use')),
        'Ya existe una cuenta con este correo.',
      );
    });
  });

  group('UserMessages.errorFromRaw', () {
    test('maps NOT FOUND to Spanish', () {
      expect(
        UserMessages.errorFromRaw(
          'NOT FOUND',
          fallback: UserMessages.unexpectedError,
        ),
        'No se encontró la información solicitada.',
      );
    });

    test('maps invalid login credentials message to Spanish', () {
      expect(
        UserMessages.errorFromRaw(
          'INVALID_LOGIN_CREDENTIALS',
          fallback: UserMessages.unexpectedError,
        ),
        'Correo o contraseña incorrectos.',
      );
    });

    test('keeps already localized Spanish messages', () {
      const message = 'Tu perfil no está disponible en SAINTS Dev.';
      expect(
        UserMessages.errorFromRaw(
          message,
          fallback: UserMessages.unexpectedError,
        ),
        message,
      );
    });

    test('replaces technical English with fallback', () {
      expect(
        UserMessages.errorFromRaw(
          'Something went wrong on the server',
          fallback: UserMessages.unexpectedError,
        ),
        UserMessages.unexpectedError,
      );
    });
  });

  group('UserMessages.functions', () {
    test('does not pass through raw English function messages', () {
      expect(
        UserMessages.functions(
          FirebaseFunctionsException(
            code: 'unknown',
            message: 'NOT FOUND',
            details: null,
          ),
        ),
        'No se encontró la información solicitada.',
      );
    });
  });

  group('UserMessages.firestore', () {
    test('maps permission-denied to Spanish', () {
      expect(
        UserMessages.firestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'PERMISSION_DENIED',
          ),
        ),
        'No tienes permisos para completar esta acción.',
      );
    });
  });
}

FirebaseAuthException _authException({
  required String code,
  String? message,
}) {
  return FirebaseAuthException(
    code: code,
    message: message,
  );
}
