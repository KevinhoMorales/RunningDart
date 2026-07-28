import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/membership_modality.dart';
import '../../models/payment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/payment_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/receipt_upload_helper.dart';
import '../../utils/subscription_flow.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/modern_text_field.dart';

class MembershipPendingScreen extends StatefulWidget {
  const MembershipPendingScreen({super.key});

  @override
  State<MembershipPendingScreen> createState() =>
      _MembershipPendingScreenState();
}

class _MembershipPendingScreenState extends State<MembershipPendingScreen> {
  final _paymentService = PaymentService();
  final _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _handleRefresh() async {
    final subscriptions = context.read<SubscriptionProvider>();
    if (subscriptions.isConfigured && subscriptions.hasProEntitlement) {
      await subscriptions.syncMembership();
    }
    if (!mounted) {
      return;
    }

    await context.read<AuthProvider>().refreshAccountStatus();
    if (!mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isMembershipPending && auth.canAccessApp) {
      context.go('/home');
    }
  }

  Future<void> _subscribeWithStore() async {
    final unlocked = await SubscriptionFlow.presentProPaywall(context);
    if (!mounted || !unlocked) {
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isMembershipPending && auth.canAccessApp) {
      context.go('/home');
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _uploadReceipt() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || !user.membershipModality.requiresPayment) {
      return;
    }

    final file = await ReceiptUploadHelper.pickReceipt(context, _picker);
    if (file == null || !mounted) {
      return;
    }

    setState(() => _isUploading = true);
    try {
      await ReceiptUploadHelper.submitReceipt(
        paymentService: _paymentService,
        userId: user.id,
        modality: user.membershipModality,
        receiptFile: file,
      );
      if (mounted) {
        AppSnackBar.show(
          context,
          'Comprobante enviado. SAINTS lo revisará pronto.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'No se pudo subir el comprobante. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  bool _needsReceiptUpload(List<PaymentModel> payments) {
    if (payments.isEmpty) {
      return true;
    }
    return !payments.any(
      (payment) =>
          payment.status == PaymentStatus.pending &&
          payment.receiptUrl != null &&
          payment.receiptUrl!.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();
    final subscriptions = context.watch<SubscriptionProvider>();
    final user = auth.user;
    final showReceiptUpload =
        user != null && user.membershipModality.requiresPayment;
    final showInAppPurchase = user?.membershipModality ==
            MembershipModality.proTeam &&
        subscriptions.isConfigured;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: const CustomAppBar(title: 'Solicitud en revisión'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: palette.softShadow,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 56,
                    color: palette.accentPrimary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    showInAppPurchase
                        ? 'Activa tu Pro Team'
                        : 'Estamos esperando tu verificación',
                    textAlign: TextAlign.center,
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    user?.membershipModality.displayName ?? 'Membresía SAINTS',
                    textAlign: TextAlign.center,
                    style: AppTypography.title(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    showInAppPurchase
                        ? 'Suscríbete con App Store o Google Play para activar '
                            'tu credencial digital de inmediato. También puedes '
                            'enviar un comprobante si pagaste por transferencia.'
                        : 'SAINTS revisará tu solicitud y comprobante de pago. '
                            'Te avisaremos cuando activemos tu credencial digital con QR.',
                    textAlign: TextAlign.center,
                    style: AppTypography.muted(context).copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            if (showInAppPurchase) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: (auth.isLoading || subscriptions.isBusy)
                    ? null
                    : AppHaptics.wrap(_subscribeWithStore),
                icon: subscriptions.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.workspace_premium_rounded),
                label: Text(
                  subscriptions.isBusy
                      ? 'Procesando...'
                      : 'Suscribirme con la tienda',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: (auth.isLoading || subscriptions.isBusy)
                    ? null
                    : AppHaptics.wrap(
                        () => SubscriptionFlow.restorePurchases(context),
                      ),
                child: const Text('Restaurar compras'),
              ),
            ],
            if (showReceiptUpload) ...[
              const SizedBox(height: AppSpacing.md),
              StreamBuilder<List<PaymentModel>>(
                stream: _paymentService.watchPaymentsForUser(user.id),
                builder: (context, snapshot) {
                  final payments = snapshot.data ?? [];
                  final needsUpload = _needsReceiptUpload(payments);

                  if (!needsUpload) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: palette.accentPrimary.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: palette.accentPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: palette.accentPrimary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Comprobante recibido. En revisión.',
                              style: AppTypography.caption(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Adjunta tu comprobante de pago para completar la solicitud.',
                        style: AppTypography.caption(context),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _isUploading ? null : AppHaptics.wrap(_uploadReceipt),
                        icon: _isUploading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.accentPrimary,
                                ),
                              )
                            : const Icon(Icons.receipt_long_rounded),
                        label: Text(
                          _isUploading
                              ? 'Subiendo comprobante...'
                              : 'Subir comprobante de pago',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            const Spacer(),
            PrimaryButton(
              label: 'Revisar estado',
              isLoading: auth.isLoading,
              onPressed: auth.isLoading ? null : _handleRefresh,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: auth.isLoading ? null : AppHaptics.wrap(_handleLogout),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
