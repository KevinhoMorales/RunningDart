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
    _loadFromPrefs();
  }

  NotificationPreferencesProvider.test(this._prefs)
      : _notificationService = null {
    _loadFromPrefs();
  }

  final SharedPreferences _prefs;
  final NotificationService? _notificationService;

  bool _enabled = false;
  bool _onboardingCompleted = false;
  bool _onboardingPending = false;

  bool get enabled => _enabled;

  bool get onboardingCompleted => _onboardingCompleted;

  bool get onboardingPending => _onboardingPending;

  Future<void> markOnboardingPending() async {
    _onboardingPending = true;
    await _prefs.setBool(AppConstants.notificationsOnboardingPendingKey, true);
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required bool enabled,
    UserModel? user,
  }) async {
    _onboardingPending = false;
    _onboardingCompleted = true;
    await _prefs.setBool(AppConstants.notificationsOnboardingPendingKey, false);
    await _prefs.setBool(AppConstants.notificationsOnboardingCompletedKey, true);
    await setEnabled(enabled, user: user);
  }

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

  void _loadFromPrefs() {
    _enabled =
        _prefs.getBool(AppConstants.pushNotificationsEnabledKey) ?? false;
    _onboardingCompleted =
        _prefs.getBool(AppConstants.notificationsOnboardingCompletedKey) ??
            false;
    _onboardingPending =
        _prefs.getBool(AppConstants.notificationsOnboardingPendingKey) ?? false;
  }
}
