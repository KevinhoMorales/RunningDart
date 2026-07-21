import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/membership_modality.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(
    this._authService, {
    NotificationService? notificationService,
  }) : _notificationService = notificationService {
    _userSubscription = _authService.userChanges.listen((user) {
      _user = user;
      _syncPushSubscription();
      notifyListeners();
    });
  }

  final AuthService _authService;
  final NotificationService? _notificationService;
  StreamSubscription<UserModel?>? _userSubscription;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSession => _user != null;
  bool get isAccountActive => _user?.isActive ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isCoach => _user?.isCoach ?? false;
  bool get canManageSchedules => _user?.canManageSchedules ?? false;
  bool get isProTeamMember =>
      _user?.membershipModality == MembershipModality.proTeam;
  bool get isMember => _user?.isMember ?? false;
  bool get isBusinessOperator => _user?.isBusinessOperator ?? false;
  bool get hasMembershipPrivileges =>
      _user?.hasMembershipPrivileges ?? false;
  bool get isMembershipPending => _user?.isMembershipPending ?? false;
  bool get canAccessApp => hasSession && isAccountActive;
  bool get canAccessAdminPanel => canAccessApp && isAdmin;
  bool get canUseMembershipFeatures =>
      canAccessApp && hasMembershipPrivileges;
  bool get canScanQr => canAccessApp && (_user?.canScanQr ?? false);
  bool get isAccountDisabled => hasSession && !isAccountActive;
  bool get isAuthenticated => canAccessApp;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.getCurrentUser();
      await _syncPushSubscription();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  }) async {
    return _runAuthAction(() async {
      _user = await _authService.register(
        email: email,
        password: password,
        profile: profile,
      );
    });
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    return _runAuthAction(() async {
      _user = await _authService.login(
        email: email,
        password: password,
      );
    });
  }

  Future<void> logout() async {
    await _notificationService?.unsubscribeAll();
    await _authService.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    return _runAuthAction(() async {
      await _notificationService?.unsubscribeAll();
      await _authService.deleteAccount();
      _user = null;
    });
  }

  Future<void> refreshAccountStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.refreshCurrentUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await action();
      await _syncPushSubscription();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Intenta de nuevo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncPushSubscription() async {
    await _notificationService?.syncForUser(_user);
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
