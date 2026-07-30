import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/providers/notification_preferences_provider.dart';
import 'package:running_dart/providers/theme_provider.dart';
import 'package:running_dart/screens/settings/settings_screen.dart';
import 'package:running_dart/services/local_storage_service.dart';
import 'package:running_dart/services/mock_auth_service.dart';
import 'package:running_dart/utils/constants.dart';

void main() {
  testWidgets('SettingsScreen shows title and DevLokos credit', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final themeProvider = ThemeProvider(prefs);
    final authProvider = AuthProvider(MockAuthService(storage));
    final notificationPreferencesProvider =
        NotificationPreferencesProvider.test(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(
            value: notificationPreferencesProvider,
          ),
        ],
        child: MaterialApp(
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Contacto SAINTS'), findsOneWidget);
    expect(find.text(AppConstants.supportWhatsAppDisplay), findsOneWidget);
    expect(find.text('Nuevas marcas aliadas y eventos'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(
      find.text(
        'Aplicación creada por ${AppConstants.devLokosEnterpriseName}',
      ),
      findsOneWidget,
    );
  });
}
