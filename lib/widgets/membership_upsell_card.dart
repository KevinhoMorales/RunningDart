import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';
import '../utils/subscription_flow.dart';

class MembershipUpsellCard extends StatelessWidget {
  const MembershipUpsellCard({
    super.key,
    this.message =
        'Los beneficios exclusivos están disponibles para miembros del club.',
    this.showPurchaseActions = true,
  });

  final String message;
  final bool showPurchaseActions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subscriptions = context.watch<SubscriptionProvider>();
    final isBusy = subscriptions.isBusy;
    final canPurchase = showPurchaseActions && subscriptions.isConfigured;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.infoBannerBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.infoBannerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: palette.accentPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beneficios para miembros',
                      style: AppTypography.title(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: AppTypography.muted(context).copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canPurchase) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy
                    ? null
                    : AppHaptics.wrap(
                        () => SubscriptionFlow.presentProPaywall(context),
                      ),
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.workspace_premium_rounded),
                label: Text(
                  isBusy ? 'Procesando...' : 'Suscribirme a Pro Team',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isBusy
                    ? null
                    : AppHaptics.wrap(
                        () => SubscriptionFlow.restorePurchases(context),
                      ),
                child: const Text('Restaurar compras'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
