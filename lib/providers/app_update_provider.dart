import 'package:flutter/foundation.dart';

import '../services/app_version_service.dart';
import '../services/firebase_app_version_service.dart';

class AppUpdateProvider extends ChangeNotifier {
  AppUpdateProvider({AppVersionService? versionService})
      : _versionService = versionService ?? FirebaseAppVersionService();

  AppUpdateProvider.notRequired({this.currentVersion = '1.0.0'})
      : _versionService = NoOpAppVersionService(currentVersion: currentVersion),
        isChecked = true,
        requiresUpdate = false,
        requiredVersion = currentVersion;

  final AppVersionService _versionService;

  bool isChecked = false;
  bool requiresUpdate = false;
  String currentVersion = '';
  String requiredVersion = '';

  Future<void> checkForUpdate() async {
    final status = await _versionService.checkForRequiredUpdate();
    requiresUpdate = status.requiresUpdate;
    currentVersion = status.currentVersion;
    requiredVersion = status.requiredVersion;
    isChecked = true;
    notifyListeners();
  }
}
