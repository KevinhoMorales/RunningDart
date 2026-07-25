import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/screens/auth/login_screen.dart';
import 'package:running_dart/services/auth_service.dart';

class _PasswordResetAuthService implements AuthService {
  _PasswordResetAuthService({this.failure});

  /// Error que devuelve el servicio, para probar el camino de fallo real
  /// (sin red, demasiados intentos) frente al éxito silencioso.
  final AuthException? failure;

  final requestedEmails = <String>[];

  @override
  Stream<UserModel?> get userChanges => const Stream<UserModel?>.empty();

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<UserModel?> resolveStartupSession() async => null;

  @override
  Future<UserModel?> refreshCurrentUser() async => null;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordReset(String email) async {
    requestedEmails.add(email);
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> deleteAccount() async {}
}

Future<void> _pumpLogin(
  WidgetTester tester,
  AuthProvider authProvider,
) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: authProvider,
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _dialogEmailField() {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextFormField),
  );
}

Future<void> _openResetDialog(WidgetTester tester) async {
  await tester.tap(find.text('¿Olvidaste tu contraseña?'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('envía el enlace con el correo ya escrito en el login', (
    tester,
  ) async {
    final service = _PasswordResetAuthService();
    await _pumpLogin(tester, AuthProvider(service));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'correo electrónico'),
      'socio@saints.com',
    );
    await _openResetDialog(tester);

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller?.text, 'socio@saints.com');

    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(service.requestedEmails, ['socio@saints.com']);
    expect(find.textContaining('te enviamos un enlace'), findsOneWidget);
  });

  testWidgets('un correo sin cuenta recibe el mismo mensaje genérico', (
    tester,
  ) async {
    final service = _PasswordResetAuthService();
    await _pumpLogin(tester, AuthProvider(service));

    await _openResetDialog(tester);
    await tester.enterText(_dialogEmailField(), 'nadie@saints.com');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(service.requestedEmails, ['nadie@saints.com']);
    expect(
      find.textContaining('Si existe una cuenta con ese correo'),
      findsOneWidget,
    );
  });

  testWidgets('pide un correo válido antes de enviar', (tester) async {
    final service = _PasswordResetAuthService();
    await _pumpLogin(tester, AuthProvider(service));

    await _openResetDialog(tester);
    await tester.enterText(_dialogEmailField(), 'no-es-correo');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(service.requestedEmails, isEmpty);
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('muestra el error cuando el envío falla de verdad', (
    tester,
  ) async {
    final service = _PasswordResetAuthService(
      failure: AuthException(
        'Sin conexión. Revisa tu internet e intenta de nuevo.',
      ),
    );
    await _pumpLogin(tester, AuthProvider(service));

    await _openResetDialog(tester);
    await tester.enterText(_dialogEmailField(), 'socio@saints.com');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sin conexión. Revisa tu internet e intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('te enviamos un enlace'), findsNothing);
  });
}
