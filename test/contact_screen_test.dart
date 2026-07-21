import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/screens/settings/contact_screen.dart';
import 'package:running_dart/services/local_storage_service.dart';
import 'package:running_dart/services/mock_auth_service.dart';
import 'package:running_dart/utils/constants.dart';

void main() {
  Future<AuthProvider> createAuthProvider() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    return AuthProvider(MockAuthService(storage));
  }

  testWidgets('ContactScreen shows contact info and WhatsApp action', (
    WidgetTester tester,
  ) async {
    final authProvider = await createAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: const MaterialApp(
          home: ContactScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contacto SAINTS'), findsOneWidget);
    expect(find.text(AppConstants.supportWhatsAppDisplay), findsOneWidget);
    expect(find.text('Escribir por WhatsApp'), findsOneWidget);
    expect(
      find.textContaining('dudas sobre la app'),
      findsOneWidget,
    );
  });

  testWidgets('ContactScreen shows WhatsApp groups section', (
    WidgetTester tester,
  ) async {
    final authProvider = await createAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: const MaterialApp(
          home: ContactScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grupos de WhatsApp'), findsOneWidget);
    expect(find.text('Comunidad SAINTS'), findsOneWidget);
    expect(find.text('SAINTS Pro Team'), findsNothing);
  });

  testWidgets('ContactScreen shows WhatsApp confirmation dialog on tap', (
    WidgetTester tester,
  ) async {
    final authProvider = await createAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: const MaterialApp(
          home: ContactScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escribir por WhatsApp'));
    await tester.pumpAndSettle();

    expect(find.text('¿Abrir WhatsApp?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Abrir WhatsApp?'), findsNothing);
    expect(find.text('Contacto SAINTS'), findsOneWidget);
  });
}
