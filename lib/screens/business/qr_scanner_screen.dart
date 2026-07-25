import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/visit_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/manual_code_sheet.dart';
import '../../widgets/validation_result_sheet.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    this.isActive = true,
  });

  final bool isActive;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isActive) {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(QrScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) {
      return;
    }

    if (widget.isActive) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String rawValue) async {
    if (_isProcessing) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final businessId = auth.user?.businessId;

    if (businessId == null || businessId.isEmpty) {
      return;
    }

    setState(() => _isProcessing = true);

    final visitProvider = context.read<VisitProvider>();
    visitProvider.clearMessages();

    final result = await visitProvider.processScan(
      rawQrValue: rawValue,
      businessId: businessId,
      scannedByUserId: auth.user!.id,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);
    await showValidationResultSheet(context, result);
  }

  Future<void> _handleManualEntry() async {
    if (_isProcessing) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final businessId = auth.user?.businessId;

    if (businessId == null || businessId.isEmpty) {
      return;
    }

    final code = await showManualCodeSheet(context);
    if (code == null || !mounted) {
      return;
    }

    setState(() => _isProcessing = true);

    final visitProvider = context.read<VisitProvider>();
    visitProvider.clearMessages();

    final result = await visitProvider.processManualCode(
      code: code,
      businessId: businessId,
      scannedByUserId: auth.user!.id,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isProcessing = false);
    await showValidationResultSheet(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();
    final visitProvider = context.watch<VisitProvider>();

    if (!auth.canScanQr) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.store_mall_directory_outlined,
                size: 64,
                color: palette.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tu cuenta de marca aliada aún no está vinculada.',
                textAlign: TextAlign.center,
                style: AppTypography.title(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Contacta al administrador para asignarte una marca aliada.',
                textAlign: TextAlign.center,
                style: AppTypography.muted(context),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            'Apunta la cámara al código QR del miembro',
            style: AppTypography.muted(context),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) {
                        return;
                      }
                      final rawValue = barcodes.first.rawValue;
                      if (rawValue != null) {
                        _handleScan(rawValue);
                      }
                    },
                  ),
                  if (_isProcessing || visitProvider.isScanning)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: HapticOutlinedButtonIcon(
            onPressed: _isProcessing ? null : _handleManualEntry,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.accentPrimary,
              side: BorderSide(color: palette.accentPrimary),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
            ),
            icon: const Icon(Icons.keyboard_rounded, size: 20),
            label: const Text('¿No puedes escanear? Ingresa el código'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Text(
            'Cada validación se registrará como una nueva visita.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context),
          ),
        ),
      ],
    );
  }
}
