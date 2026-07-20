import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

class QRGenerator extends StatelessWidget {
  const QRGenerator({
    super.key,
    required this.data,
    this.size = 200,
  });

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.qrBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
        boxShadow: palette.elevatedCardShadow,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.qrScanSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: size,
          backgroundColor: palette.qrScanSurface,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        ),
      ),
    );
  }
}
