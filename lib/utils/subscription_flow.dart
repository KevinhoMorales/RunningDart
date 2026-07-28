import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/app_snackbar.dart';

/// Shared purchase / restore UX used by upsell, pending, and settings screens.
class SubscriptionFlow {
  SubscriptionFlow._();

  static Future<bool> presentProPaywall(BuildContext context) async {
    final subscriptions = context.read<SubscriptionProvider>();
    final auth = context.read<AuthProvider>();
    if (!subscriptions.isConfigured) {
      AppSnackBar.show(
        context,
        'Las compras in-app no están disponibles en este momento.',
      );
      return false;
    }

    final unlocked = await subscriptions.presentPaywall(onlyIfNeeded: false);
    if (!context.mounted) {
      return unlocked;
    }

    if (subscriptions.error != null) {
      AppSnackBar.showError(context, subscriptions.error);
      subscriptions.clearError();
      return false;
    }

    if (!unlocked) {
      return false;
    }

    await auth.refreshAccountStatus();
    if (!context.mounted) {
      return true;
    }

    if (auth.canUseMembershipFeatures) {
      AppSnackBar.show(context, '¡Bienvenido a SAINTS Pro Team!');
      return true;
    }

    // Purchase succeeded in the store but Firestore sync may still be pending.
    final synced = await subscriptions.syncMembership();
    if (!context.mounted) {
      return synced;
    }
    await auth.refreshAccountStatus();
    if (!context.mounted) {
      return synced;
    }

    if (auth.canUseMembershipFeatures || synced) {
      AppSnackBar.show(context, '¡Bienvenido a SAINTS Pro Team!');
      return true;
    }

    AppSnackBar.show(
      context,
      subscriptions.error ??
          'Compra registrada. Si tu membresía no se activa, restaura compras o contacta a SAINTS.',
    );
    subscriptions.clearError();
    return false;
  }

  static Future<bool> restorePurchases(BuildContext context) async {
    final subscriptions = context.read<SubscriptionProvider>();
    final auth = context.read<AuthProvider>();
    if (!subscriptions.isConfigured) {
      AppSnackBar.show(
        context,
        'Las compras in-app no están disponibles en este momento.',
      );
      return false;
    }

    final restored = await subscriptions.restorePurchases();
    if (!context.mounted) {
      return restored;
    }

    if (subscriptions.error != null) {
      AppSnackBar.showError(context, subscriptions.error);
      subscriptions.clearError();
      return false;
    }

    if (!restored) {
      AppSnackBar.show(
        context,
        'No encontramos compras previas para restaurar.',
      );
      return false;
    }

    await auth.refreshAccountStatus();
    if (!context.mounted) {
      return true;
    }

    if (!auth.canUseMembershipFeatures) {
      await subscriptions.syncMembership();
      if (context.mounted) {
        await auth.refreshAccountStatus();
      }
    }

    if (!context.mounted) {
      return true;
    }

    AppSnackBar.show(
      context,
      auth.canUseMembershipFeatures
          ? 'Compras restauradas. Tu Pro Team está activo.'
          : 'Compras restauradas. Estamos sincronizando tu membresía.',
    );
    return true;
  }

  static Future<void> openCustomerCenter(BuildContext context) async {
    final subscriptions = context.read<SubscriptionProvider>();
    final auth = context.read<AuthProvider>();
    if (!subscriptions.isConfigured) {
      AppSnackBar.show(
        context,
        'Las compras in-app no están disponibles en este momento.',
      );
      return;
    }

    await subscriptions.presentCustomerCenter();
    if (!context.mounted) {
      return;
    }

    if (subscriptions.error != null) {
      AppSnackBar.showError(context, subscriptions.error);
      subscriptions.clearError();
      return;
    }

    if (subscriptions.hasProEntitlement) {
      await subscriptions.syncMembership();
      if (context.mounted) {
        await auth.refreshAccountStatus();
      }
    }
  }
}
