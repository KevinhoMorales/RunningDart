import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenue_cat_config.dart';
import '../services/membership_sync_service.dart';
import '../services/revenue_cat_service.dart';

/// App-facing subscription state for SAINTS Pro (RevenueCat).
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider(
    this._revenueCat, {
    MembershipSyncService? membershipSyncService,
  }) : _membershipSync = membershipSyncService ?? MembershipSyncService() {
    Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
  }

  final RevenueCatService _revenueCat;
  final MembershipSyncService _membershipSync;

  bool _isBusy = false;
  String? _error;
  bool _hasProEntitlement = false;

  bool get isBusy => _isBusy;
  String? get error => _error;
  bool get hasProEntitlement => _hasProEntitlement;
  bool get isConfigured => _revenueCat.isConfigured;
  DateTime? get proExpirationDate => _revenueCat.proExpirationDate;

  Future<void> initialize({String? appUserId}) async {
    try {
      await _revenueCat.configure();
      if (appUserId != null && appUserId.isNotEmpty) {
        await _revenueCat.logIn(appUserId);
      }
      _syncLocalState();
    } on RevenueCatException catch (error) {
      _error = error.message;
      debugPrint('SubscriptionProvider initialize: $error');
    } catch (error, stackTrace) {
      debugPrint('SubscriptionProvider initialize failed: $error\n$stackTrace');
    } finally {
      notifyListeners();
    }
  }

  Future<void> linkUser(String? userId) async {
    if (!_revenueCat.isConfigured) {
      return;
    }
    if (userId == null || userId.isEmpty) {
      await _revenueCat.logOut();
    } else {
      await _revenueCat.logIn(userId);
    }
    _syncLocalState();
    notifyListeners();
  }

  /// Shows the RevenueCat paywall and syncs Pro membership when unlocked.
  Future<bool> presentPaywall({bool onlyIfNeeded = true}) async {
    return _run(() async {
      final unlocked = await _revenueCat.presentPaywall(
        onlyIfNeeded: onlyIfNeeded,
      );
      _syncLocalState();
      if (unlocked) {
        await _syncMembershipQuietly();
      }
      return unlocked;
    });
  }

  Future<bool> restorePurchases() async {
    return _run(() async {
      await _revenueCat.restorePurchases();
      _syncLocalState();
      if (_hasProEntitlement) {
        await _syncMembershipQuietly();
      }
      return _hasProEntitlement;
    });
  }

  Future<void> presentCustomerCenter() async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _revenueCat.presentCustomerCenter(
        onRestoreCompleted: (_) {
          _syncLocalState();
          notifyListeners();
          unawaited(_syncMembershipQuietly());
        },
      );
      _syncLocalState();
    } on RevenueCatException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'No se pudo abrir el centro de suscripciones.';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> syncMembership() async {
    return _run(() async {
      await _revenueCat.refreshCustomerInfo();
      _syncLocalState();
      if (!_hasProEntitlement) {
        return false;
      }
      return _membershipSync.syncProMembershipFromRevenueCat();
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _handleCustomerInfoUpdate(CustomerInfo info) {
    _hasProEntitlement = info.entitlements.active.containsKey(
      RevenueCatConfig.proEntitlementId,
    );
    notifyListeners();
  }

  void _syncLocalState() {
    _hasProEntitlement = _revenueCat.hasProEntitlement;
  }

  Future<void> _syncMembershipQuietly() async {
    try {
      await _membershipSync.syncProMembershipFromRevenueCat();
    } catch (error, stackTrace) {
      debugPrint('Membership sync after purchase failed: $error\n$stackTrace');
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } on RevenueCatException catch (error) {
      if (error.message != 'Compra cancelada.') {
        _error = error.message;
      }
      return false as T;
    } on MembershipSyncException catch (error) {
      _error = error.message;
      return false as T;
    } catch (_) {
      _error = 'Algo salió mal con la suscripción. Intenta de nuevo.';
      return false as T;
    } finally {
      _isBusy = false;
      _syncLocalState();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
    super.dispose();
  }
}
