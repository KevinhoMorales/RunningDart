import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/membership_modality.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/watch_sync_service.dart';
import '../utils/user_messages.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(
    this._authService, {
    NotificationService? notificationService,
    WatchSyncService? watchSyncService,
  })  : _notificationService = notificationService,
        _watchSyncService = watchSyncService ?? WatchSyncService() {
    _watchSyncService.registerRefreshHandler(_syncWatchContext);
    _userSubscription = _authService.userChanges.listen((user) {
      if (user != null) {
        _user = user;
      } else if (_user == null) {
        _user = null;
      } else {
        unawaited(_confirmSessionCleared());
        return;
      }
      unawaited(_syncPushSubscription());
      unawaited(_syncWatchContext());
      notifyListeners();
    });
  }

  final AuthService _authService;
  final NotificationService? _notificationService;
  final WatchSyncService _watchSyncService;
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

  String get postAuthRoute {
    if (!hasSession) {
      return '/login';
    }
    if (isAccountDisabled) {
      return '/account-disabled';
    }
    if (isMembershipPending) {
      return '/membership-pending';
    }
    if (canAccessApp) {
      return '/home';
    }
    return '/membership-pending';
  }

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.resolveStartupSession();
      await _syncPushSubscription();
      await _syncWatchContext();
    } catch (error, stackTrace) {
      debugPrint('Auth initialization failed: $error\n$stackTrace');
      _user = null;
      _error = 'No se pudo cargar tu sesión. Inicia sesión de nuevo.';
      await _syncWatchContext();
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
    await _syncWatchContext();
    notifyListeners();
  }

  Future<bool> sendPasswordReset(String email) {
    return _runAuthAction(
      () => _authService.sendPasswordReset(email),
      syncsSession: false,
    );
  }

  Future<bool> reauthenticate(String password) async {
    return _runAuthAction(() => _authService.reauthenticate(password));
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
      await _syncWatchContext();
    } catch (error, stackTrace) {
      debugPrint('Account status refresh failed: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> _runAuthAction(
    Future<void> Function() action, {
    bool syncsSession = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await action();
      if (syncsSession) {
        unawaited(_syncPushSubscription());
        unawaited(_syncWatchContext());
      }
      return true;
    } on AuthException catch (e) {
      _error = UserMessages.error(e.message);
      return false;
    } on FirebaseAuthException catch (e) {
      _error = UserMessages.auth(e);
      return false;
    } on FirebaseException catch (e) {
      _error = UserMessages.firestore(e);
      return false;
    } catch (_) {
      _error = UserMessages.unexpectedError;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncPushSubscription() async {
    final notificationService = _notificationService;
    if (notificationService == null) {
      return;
    }

    try {
      await notificationService
          .syncForUser(_user)
          .timeout(const Duration(seconds: 8));
    } catch (error, stackTrace) {
      debugPrint('Push subscription sync failed: $error\n$stackTrace');
    }
  }

  Future<void> _syncWatchContext() async {
    try {
      await _watchSyncService.syncUser(_user);
    } catch (error, stackTrace) {
      debugPrint('Watch context sync failed: $error\n$stackTrace');
    }
  }

  Future<void> _confirmSessionCleared() async {
    _user = await _authService.resolveStartupSession();
    await _syncPushSubscription();
    await _syncWatchContext();
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
