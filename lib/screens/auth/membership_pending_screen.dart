import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/payment_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/receipt_upload_helper.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comprobante enviado. SAINTS lo revisará pronto.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo subir el comprobante. Intenta de nuevo.'),
          ),
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
    final user = auth.user;
    final showReceiptUpload =
        user != null && user.membershipModality.requiresPayment;

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
                    'Estamos revisando tu membresía',
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
                    'SAINTS validará tu comprobante y activará tu credencial digital con QR cuando apruebe tu solicitud.',
                    textAlign: TextAlign.center,
                    style: AppTypography.muted(context).copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
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
              label: 'Explorar la app',
              onPressed: () => context.go('/home'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: AppHaptics.wrap(
                () => context.read<AuthProvider>().logout(),
              ),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
