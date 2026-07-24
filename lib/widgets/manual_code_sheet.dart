import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/membership_code.dart';
import 'modern_text_field.dart';

/// Abre un modal para ingresar manualmente el codigo unico del miembro como
/// alternativa al escaneo. Devuelve el codigo normalizado si el usuario
/// confirma con un formato valido, o `null` si cancela.
Future<String?> showManualCodeSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const _ManualCodeSheet(),
  );
}

class _ManualCodeSheet extends StatefulWidget {
  const _ManualCodeSheet();

  @override
  State<_ManualCodeSheet> createState() => _ManualCodeSheetState();
}

class _ManualCodeSheetState extends State<_ManualCodeSheet> {
  final _controller = TextEditingController();
  bool _isValid = false;
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final valid = MembershipCode.isValid(value);
    setState(() {
      _isValid = valid;
      _showError = value.trim().isNotEmpty && !valid;
    });
  }

  void _submit() {
    final code = MembershipCode.normalize(_controller.text);
    if (!MembershipCode.isValid(code)) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: palette.bottomSheetBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ingresar código manualmente',
              style: AppTypography.title(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Escribe el código único del miembro cuando no puedas escanear el QR.',
              style: AppTypography.muted(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            ModernTextField(
              controller: _controller,
              labelText: 'Código del miembro',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.done,
              onChanged: _onChanged,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_showError) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'El código no tiene un formato válido. Revisa e inténtalo de nuevo.',
                style: AppTypography.caption(
                  context,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Validar código',
              onPressed: _isValid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
