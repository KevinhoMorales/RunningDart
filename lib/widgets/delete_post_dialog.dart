import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'haptic_controls.dart';

/// Confirmación única para borrar una publicación, compartida por el feed, la
/// cuadrícula y el visor a pantalla completa.
Future<bool> confirmDeletePost(BuildContext context) async {
  final palette = context.palette;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Eliminar publicación?'),
      content: const Text('Esta acción no se puede deshacer.'),
      actions: [
        HapticTextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: palette.textMuted),
          ),
        ),
        HapticFilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  return confirmed == true;
}
