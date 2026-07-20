import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/firebase_auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final notificationService = NotificationService();
  await notificationService.initialize(prefs);

  final themeProvider = ThemeProvider(prefs);
  final authService = FirebaseAuthService();
  final authProvider = AuthProvider(
    authService,
    notificationService: notificationService,
  );
  await authProvider.initialize();
  await notificationService.syncForUser(authProvider.user);

  runApp(
    RunningDartApp(
      authProvider: authProvider,
      themeProvider: themeProvider,
      notificationService: notificationService,
      sharedPreferences: prefs,
    ),
  );
}
