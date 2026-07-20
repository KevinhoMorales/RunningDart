import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:running_dart/app.dart';
import 'package:running_dart/providers/admin_provider.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/providers/theme_provider.dart';
import 'package:running_dart/services/local_storage_service.dart';
import 'package:running_dart/services/mock_auth_service.dart';
import 'package:running_dart/providers/admin_business_provider.dart';
import 'package:running_dart/providers/admin_news_provider.dart';
import 'package:running_dart/providers/visit_provider.dart';
import 'package:running_dart/services/mock_business_service.dart';
import 'package:running_dart/services/mock_news_service.dart';
import 'package:running_dart/services/mock_user_service.dart';
import 'package:running_dart/services/mock_visit_service.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final themeProvider = ThemeProvider(prefs);
    final authProvider = AuthProvider(MockAuthService(storage));
    final adminProvider = AdminProvider(MockUserService());
    final mockBusinessService = MockBusinessService();
    final mockNewsService = MockNewsService();
    await authProvider.initialize();

    await tester.pumpWidget(
      RunningDartApp(
        authProvider: authProvider,
        themeProvider: themeProvider,
        adminProvider: adminProvider,
        businessService: mockBusinessService,
        newsService: mockNewsService,
        adminBusinessProvider: AdminBusinessProvider(mockBusinessService),
        adminNewsProvider: AdminNewsProvider(mockNewsService),
        visitProvider: VisitProvider(MockVisitService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('SAINTS'), findsOneWidget);
  });
}
