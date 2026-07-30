import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/app_environment.dart';
import 'firebase_options.dart';
import 'providers/app_update_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/firebase_auth_service.dart';
import 'services/notification_service.dart';

void _configureAndroidPhotoPicker() {
  if (kIsWeb || !Platform.isAndroid) {
    return;
  }
  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureAndroidPhotoPicker();
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
  final authService = FirebaseAuthService();
  final authProvider = AuthProvider(
    authService,
    notificationService: notificationService,
  );

  try {
    await authProvider.initialize();
    await notificationService.syncForUser(authProvider.user);
  } catch (error, stackTrace) {
    debugPrint('Startup initialization failed: $error\n$stackTrace');
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
    ),
  );
}
