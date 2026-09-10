import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../services/activity_service.dart';
import '../../services/qr_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';

/// Escáner de QR de actividad (no reutiliza el flujo de visitas de marcas).
class ActivityCheckInScannerScreen extends StatefulWidget {
  const ActivityCheckInScannerScreen({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  State<ActivityCheckInScannerScreen> createState() =>
      _ActivityCheckInScannerScreenState();
}

class _ActivityCheckInScannerScreenState
    extends State<ActivityCheckInScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final _qrService = QRService();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) {
      return;
    }
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) {
      return;
    }

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final payload = _qrService.parseActivityCheckInPayload(raw);
      if (payload.activityId != widget.activityId) {
        throw QRParseException(
          'Este QR es de otra actividad. Escanea el QR correcto.',
        );
      }

      final service = context.read<ActivityService>();
      final result = await service.checkInWithQr(
            activityId: payload.activityId,
            token: payload.token,
          );

      if (!mounted) return;
      await AppHaptics.confirm();
      AppSnackBar.show(
        context,
        result.message ??
            (result.alreadyCheckedIn
                ? 'Ya registraste tu asistencia.'
                : 'Check-in exitoso.'),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Check-in'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              color: Colors.black54,
              child: Text(
                _processing
                    ? 'Validando asistencia…'
                    : 'Apunta al QR del Social Run. Los puntos se acreditan solo con un check-in válido.',
                textAlign: TextAlign.center,
                style: AppTypography.body(context).copyWith(
                  color: palette.scaffoldBackground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
