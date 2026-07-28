import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../config/revenue_cat_config.dart';

class RevenueCatException implements Exception {
  RevenueCatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around Purchases + RevenueCatUI for SAINTS Pro subscriptions.
class RevenueCatService {
  RevenueCatService();

  bool _configured = false;
  CustomerInfo? _customerInfo;

  bool get isConfigured => _configured;
  CustomerInfo? get customerInfo => _customerInfo;

  bool get hasProEntitlement {
    final info = _customerInfo;
    if (info == null) {
      return false;
    }
    return info.entitlements.active.containsKey(
      RevenueCatConfig.proEntitlementId,
    );
  }

  EntitlementInfo? get proEntitlement {
    return _customerInfo?.entitlements.all[RevenueCatConfig.proEntitlementId];
  }

  DateTime? get proExpirationDate {
    final raw = proEntitlement?.expirationDate;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> configure() async {
    if (_configured) {
      return;
    }

    if (kIsWeb) {
      debugPrint('RevenueCat: web is not configured for native IAP.');
      return;
    }

    if (!(Platform.isIOS || Platform.isAndroid)) {
      debugPrint('RevenueCat: unsupported platform.');
      return;
    }

    try {
      final configuration = PurchasesConfiguration(RevenueCatConfig.apiKey);
      await Purchases.configure(configuration);
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      _configured = true;
      _customerInfo = await Purchases.getCustomerInfo();
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('RevenueCat configure failed: $error\n$stackTrace');
      throw RevenueCatException(
        'No se pudo inicializar compras in-app. Intenta de nuevo.',
      );
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _customerInfo = info;
  }

  Future<CustomerInfo> refreshCustomerInfo() async {
    _ensureConfigured();
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      return _customerInfo!;
    } on PlatformException catch (error) {
      throw RevenueCatException(_mapPurchasesError(error));
    }
  }

  Future<void> logIn(String appUserId) async {
    if (!_configured || appUserId.isEmpty) {
      return;
    }

    try {
      final result = await Purchases.logIn(appUserId);
      _customerInfo = result.customerInfo;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('RevenueCat logIn failed: $error\n$stackTrace');
    }
  }

  Future<void> logOut() async {
    if (!_configured) {
      return;
    }

    try {
      _customerInfo = await Purchases.logOut();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('RevenueCat logOut failed: $error\n$stackTrace');
      _customerInfo = null;
    }
  }

  Future<Offerings> getOfferings() async {
    _ensureConfigured();
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (error) {
      throw RevenueCatException(_mapPurchasesError(error));
    }
  }

  /// Presents the current offering paywall. Returns whether Pro is active after.
  Future<bool> presentPaywall({bool onlyIfNeeded = true}) async {
    _ensureConfigured();
    try {
      final result = onlyIfNeeded
          ? await RevenueCatUI.presentPaywallIfNeeded(
              RevenueCatConfig.proEntitlementId,
              displayCloseButton: true,
            )
          : await RevenueCatUI.presentPaywall(displayCloseButton: true);

      await refreshCustomerInfo();

      return switch (result) {
        PaywallResult.purchased ||
        PaywallResult.restored ||
        PaywallResult.notPresented =>
          hasProEntitlement,
        PaywallResult.cancelled || PaywallResult.error => hasProEntitlement,
      };
    } on PlatformException catch (error) {
      throw RevenueCatException(_mapPurchasesError(error));
    }
  }

  Future<CustomerInfo> restorePurchases() async {
    _ensureConfigured();
    try {
      _customerInfo = await Purchases.restorePurchases();
      return _customerInfo!;
    } on PlatformException catch (error) {
      throw RevenueCatException(_mapPurchasesError(error));
    }
  }

  Future<void> presentCustomerCenter({
    void Function(CustomerInfo info)? onRestoreCompleted,
  }) async {
    _ensureConfigured();
    try {
      await RevenueCatUI.presentCustomerCenter(
        onRestoreCompleted: onRestoreCompleted == null
            ? null
            : (info) {
                _customerInfo = info;
                onRestoreCompleted(info);
              },
      );
      await refreshCustomerInfo();
    } on PlatformException catch (error) {
      throw RevenueCatException(_mapPurchasesError(error));
    }
  }

  void _ensureConfigured() {
    if (!_configured) {
      throw RevenueCatException(
        'Las compras in-app aún no están listas. Reinicia la app e intenta de nuevo.',
      );
    }
  }

  String _mapPurchasesError(PlatformException error) {
    final code = PurchasesErrorHelper.getErrorCode(error);
    return switch (code) {
      PurchasesErrorCode.purchaseCancelledError => 'Compra cancelada.',
      PurchasesErrorCode.networkError =>
        'Sin conexión. Revisa tu internet e intenta de nuevo.',
      PurchasesErrorCode.storeProblemError =>
        'La tienda no respondió. Intenta de nuevo en unos minutos.',
      PurchasesErrorCode.purchaseNotAllowedError =>
        'Este dispositivo no puede realizar compras.',
      PurchasesErrorCode.productNotAvailableForPurchaseError =>
        'El producto no está disponible en este momento.',
      PurchasesErrorCode.receiptAlreadyInUseError =>
        'Esta compra ya está vinculada a otra cuenta.',
      _ => 'No se pudo completar la compra. Intenta de nuevo.',
    };
  }

  void dispose() {
    if (_configured) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
  }
}
