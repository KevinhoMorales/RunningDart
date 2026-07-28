import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/app_environment.dart';
import 'firebase_options.dart';
import 'providers/app_update_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'services/firebase_auth_service.dart';
import 'services/notification_service.dart';
import 'services/revenue_cat_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnvironment.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final notificationService = NotificationService();

  try {
    await notificationService.initialize(prefs);
  } catch (error, stackTrace) {
    debugPrint(
      'Notification initialization failed: $error\n$stackTrace',
    );
  }

  final themeProvider = ThemeProvider(prefs);
  final revenueCatService = RevenueCatService();
  final subscriptionProvider = SubscriptionProvider(revenueCatService);
  final authService = FirebaseAuthService();
  final authProvider = AuthProvider(
    authService,
    notificationService: notificationService,
    subscriptionProvider: subscriptionProvider,
  );

  try {
    await authProvider.initialize();
    await notificationService.syncForUser(authProvider.user);
  } catch (error, stackTrace) {
    debugPrint('Startup initialization failed: $error\n$stackTrace');
  }

  try {
    await subscriptionProvider.initialize(appUserId: authProvider.user?.id);
  } catch (error, stackTrace) {
    debugPrint('RevenueCat initialization failed: $error\n$stackTrace');
  }

  final appUpdateProvider = AppUpdateProvider();
  await appUpdateProvider.checkForUpdate();

  runApp(
    RunningDartApp(
      authProvider: authProvider,
      themeProvider: themeProvider,
      notificationService: notificationService,
      sharedPreferences: prefs,
      appUpdateProvider: appUpdateProvider,
      subscriptionProvider: subscriptionProvider,
    ),
  );
}
