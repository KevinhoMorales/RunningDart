import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import 'haptic_controls.dart';
import 'modern_text_field.dart';

/// Motivo con el que un administrador oculta una publicación.
class PostHiddenDecision {
  const PostHiddenDecision({required this.reason, this.note});

  final PostHiddenReason reason;
  final String? note;
}

/// Pide el motivo para ocultar una publicación. Devuelve `null` si se cancela.
Future<PostHiddenDecision?> askHideReason(BuildContext context) {
  return showDialog<PostHiddenDecision>(
    context: context,
    builder: (dialogContext) => const _HidePostDialog(),
  );
}

class _HidePostDialog extends StatefulWidget {
  const _HidePostDialog();

  @override
  State<_HidePostDialog> createState() => _HidePostDialogState();
}

class _HidePostDialogState extends State<_HidePostDialog> {
  final _noteController = TextEditingController();
  PostHiddenReason _reason = PostHiddenReason.offensive;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AlertDialog(
      title: const Text('¿Ocultar publicación?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La comunidad dejará de verla. Su autor la seguirá viendo con el '
              'motivo que elijas y podrá eliminarla.',
              style: AppTypography.body(context, color: palette.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<PostHiddenReason>(
              groupValue: _reason,
              onChanged: (value) {
                if (value != null) {
                  AppHaptics.lightTap();
                  setState(() => _reason = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final reason in PostHiddenReason.values)
                    RadioListTile<PostHiddenReason>(
                      value: reason,
                      title: Text(
                        reason.label,
                        style: AppTypography.body(context),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ModernTextField(
              controller: _noteController,
              labelText: 'Nota para el autor (opcional)',
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        HapticTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: palette.textMuted),
          ),
        ),
        HapticFilledButton(
          onPressed: () => Navigator.of(context).pop(
            PostHiddenDecision(
              reason: _reason,
              note: _noteController.text,
            ),
          ),
          feedback: AppHaptics.confirm,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
          ),
          child: const Text('Ocultar'),
        ),
      ],
    );
  }
}
