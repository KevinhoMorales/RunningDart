import 'package:flutter/material.dart';

import '../services/biometric_auth_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SecureDeleteFlow {
  SecureDeleteFlow({BiometricAuthService? biometricAuth})
      : _biometricAuth = biometricAuth ?? BiometricAuthService();

  final BiometricAuthService _biometricAuth;

  Future<SecureDeleteResult> confirmAndAuthenticate({
    required BuildContext context,
    required String resourceType,
    required String itemName,
    required String summary,
    required List<String> consequences,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SecureDeleteDialog(
        resourceType: resourceType,
        itemName: itemName,
        summary: summary,
        consequences: consequences,
      ),
    );

    if (confirmed != true || !context.mounted) {
      return SecureDeleteResult.cancelled;
    }

    final canAuthenticate = await _biometricAuth.canAuthenticate();
    if (!canAuthenticate) {
      return SecureDeleteResult.biometricUnavailable;
    }

    final biometrics = await _biometricAuth.availableBiometrics();
    final biometricLabel = _biometricAuth.biometricLabel(biometrics);

    try {
      final authenticated = await _biometricAuth.authenticate(
        reason:
            'Confirma con $biometricLabel para eliminar este $resourceType.',
      );

      if (!authenticated) {
        return SecureDeleteResult.biometricFailed;
      }

      return SecureDeleteResult.approved;
    } on BiometricAuthException {
      return SecureDeleteResult.biometricFailed;
    }
  }
}

enum SecureDeleteResult {
  approved,
  cancelled,
  biometricUnavailable,
  biometricFailed,
}

extension SecureDeleteResultMessage on SecureDeleteResult {
  String? get userMessage {
    return switch (this) {
      SecureDeleteResult.approved => null,
      SecureDeleteResult.cancelled => null,
      SecureDeleteResult.biometricUnavailable =>
        'Este dispositivo no tiene biometría disponible. '
            'No se puede completar la eliminación.',
      SecureDeleteResult.biometricFailed =>
        'Verificación biométrica cancelada o fallida. '
            'No se eliminó nada.',
    };
  }
}

class _SecureDeleteDialog extends StatelessWidget {
  const _SecureDeleteDialog({
    required this.resourceType,
    required this.itemName,
    required this.summary,
    required this.consequences,
  });

  final String resourceType;
  final String itemName;
  final String summary;
  final List<String> consequences;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: palette.accentSecondary),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Confirmar eliminación')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: AppTypography.title(context, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tipo: $resourceType',
                    style: AppTypography.caption(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Esta acción es permanente e irreversible:',
              style: AppTypography.title(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...consequences.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: palette.textMuted)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: palette.textMuted, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.accentSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 20,
                    color: palette.accentSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Después de confirmar, deberás usar Face ID o huella '
                      'para autorizar la eliminación.',
                      style: AppTypography.caption(context).copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sí, eliminar'),
        ),
      ],
    );
  }
}

Future<void> showSecureDeleteFeedback(
  BuildContext context,
  SecureDeleteResult result, {
  required bool deleteSucceeded,
  String? deleteError,
}) async {
  if (result.userMessage != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage!)),
    );
    return;
  }

  if (result != SecureDeleteResult.approved) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        deleteSucceeded
            ? 'Eliminado correctamente.'
            : deleteError ?? 'No se pudo completar la eliminación.',
      ),
    ),
  );
}
