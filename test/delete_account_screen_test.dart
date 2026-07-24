import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/screens/settings/delete_account_screen.dart';
import 'package:running_dart/services/account_deletion_service.dart';
import 'package:running_dart/services/local_storage_service.dart';
import 'package:running_dart/services/mock_auth_service.dart';

const _footprint = AccountDataFootprint(
  posts: 4,
  followers: 12,
  following: 7,
  payments: 1,
  likes: 9,
);

Future<AuthProvider> _signedInProvider() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);

  final user = UserModel(
    id: 'user-delete',
    email: 'delete@test.com',
    displayName: 'Delete Me',
    qrCode: 'RD-delete',
    createdAt: DateTime(2026, 1, 1),
    isActive: true,
    role: UserRole.member,
    password: 'secret',
    membershipModality: MembershipModality.community,
    membershipStatus: MembershipStatus.active,
  );

  await storage.saveUser(user);
  await storage.setCurrentUserId(user.id);

  final authProvider = AuthProvider(MockAuthService(storage));
  await authProvider.initialize();
  return authProvider;
}

Future<void> _pumpScreen(WidgetTester tester, AuthProvider authProvider) async {
  // La pantalla es deliberadamente larga; sin esto no cabe en la ventana de
  // prueba y los checkboxes quedan fuera del área que recibe toques.
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: authProvider,
      child: MaterialApp(
        home: DeleteAccountScreen(
          footprintLoader: () async => _footprint,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _acceptAll(WidgetTester tester) async {
  final checkboxes = find.byType(CheckboxListTile);
  for (var index = 0; index < 3; index++) {
    await tester.tap(checkboxes.at(index));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('lists what is deleted and shows the real counts', (
    WidgetTester tester,
  ) async {
    final authProvider = await _signedInProvider();
    await _pumpScreen(tester, authProvider);

    expect(find.text('Esto es permanente e irreversible'), findsOneWidget);
    expect(find.text('Se borrará para siempre'), findsOneWidget);
    expect(find.text('delete@test.com'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('keeps the delete button disabled until all boxes are checked', (
    WidgetTester tester,
  ) async {
    final authProvider = await _signedInProvider();
    await _pumpScreen(tester, authProvider);

    FilledButton deleteButton() {
      return tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Eliminar mi cuenta y todo mi contenido'),
          matching: find.byType(FilledButton),
        ),
      );
    }

    expect(deleteButton().onPressed, isNull);
    expect(find.text('Marca las tres casillas para continuar.'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(deleteButton().onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pumpAndSettle();
    expect(deleteButton().onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile).at(2));
    await tester.pumpAndSettle();
    expect(deleteButton().onPressed, isNotNull);
    expect(find.text('Marca las tres casillas para continuar.'), findsNothing);
  });

  testWidgets('final confirmation requires typing the exact word', (
    WidgetTester tester,
  ) async {
    final authProvider = await _signedInProvider();
    await _pumpScreen(tester, authProvider);
    await _acceptAll(tester);

    await tester.tap(find.text('Eliminar mi cuenta y todo mi contenido'));
    await tester.pumpAndSettle();

    expect(find.text('Última confirmación'), findsOneWidget);

    FilledButton confirmButton() {
      return tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Eliminar definitivamente'),
          matching: find.byType(FilledButton),
        ),
      );
    }

    expect(confirmButton().onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'BORRAR');
    await tester.pumpAndSettle();
    expect(confirmButton().onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'ELIMINAR');
    await tester.pumpAndSettle();
    expect(confirmButton().onPressed, isNotNull);

    expect(authProvider.user, isNotNull);
  });

  testWidgets('cancelling the final confirmation deletes nothing', (
    WidgetTester tester,
  ) async {
    final authProvider = await _signedInProvider();
    await _pumpScreen(tester, authProvider);
    await _acceptAll(tester);

    await tester.tap(find.text('Eliminar mi cuenta y todo mi contenido'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Última confirmación'), findsNothing);
    expect(authProvider.user, isNotNull);
    expect(authProvider.hasSession, isTrue);
  });
}
