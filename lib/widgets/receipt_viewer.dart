import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

import 'haptic_controls.dart';

class ReceiptViewer {
  ReceiptViewer._();

  static void show(BuildContext context, String receiptUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comprobante de pago',
                      style: AppTypography.title(context),
                    ),
                  ),
                  HapticIconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  receiptUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'No se pudo cargar el comprobante.',
                        style: AppTypography.muted(context),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
