import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class NotificationPreferencesProvider extends ChangeNotifier {
  NotificationPreferencesProvider(
    this._prefs,
    this._notificationService,
  ) {
    _enabled =
        _prefs.getBool(AppConstants.pushNotificationsEnabledKey) ?? true;
  }

  NotificationPreferencesProvider.test(this._prefs)
      : _notificationService = null {
    _enabled =
        _prefs.getBool(AppConstants.pushNotificationsEnabledKey) ?? true;
  }

  final SharedPreferences _prefs;
  final NotificationService? _notificationService;

  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> setEnabled(bool value, {UserModel? user}) async {
    _enabled = value;
    await _prefs.setBool(AppConstants.pushNotificationsEnabledKey, value);
    if (_notificationService != null) {
      await _notificationService!.setPushEnabled(
        value,
        prefs: _prefs,
        user: user,
      );
    }
    notifyListeners();
  }
}
