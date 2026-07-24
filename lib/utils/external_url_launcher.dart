import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../utils/app_haptics.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/haptic_controls.dart';
import 'helpers.dart';

Future<bool> confirmExternalAction(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _ExternalActionConfirmDialog(
      title: title,
      message: message,
    ),
  );

  return confirmed == true;
}

Future<bool> launchExternalUrl(String url) async {
  final trimmed = url.trim();
  if (!Helpers.isValidHttpUrl(trimmed)) {
    return false;
  }

  final uri = Uri.parse(trimmed);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchExternalUrlFromContext(
  BuildContext context,
  String url,
) async {
  final launched = await launchExternalUrl(url);
  if (!launched && context.mounted) {
    AppSnackBar.show(context, 'No se pudo abrir el enlace. Intenta de nuevo.');
  }
}

class _ExternalActionConfirmDialog extends StatelessWidget {
  const _ExternalActionConfirmDialog({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AlertDialog(
      title: Text(title),
      content: Text(message),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actionsOverflowButtonSpacing: AppSpacing.md,
      actions: [
        HapticTextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: palette.textMuted),
          ),
        ),
        HapticFilledButton(
          onPressed: AppHaptics.wrap(() => Navigator.of(context).pop(true)),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            minimumSize: const Size(120, 44),
          ),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
