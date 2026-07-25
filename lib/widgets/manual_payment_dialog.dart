import 'package:flutter/material.dart';

import '../models/membership_modality.dart';
import '../theme/app_spacing.dart';
import '../utils/app_haptics.dart';
import '../utils/membership_helpers.dart';
import 'haptic_controls.dart';

/// Pago que un administrador registra a mano desde el detalle del usuario.
class ManualPaymentDraft {
  const ManualPaymentDraft({
    required this.modality,
    required this.amount,
    this.notes,
  });

  final MembershipModality modality;
  final double amount;
  final String? notes;
}

/// Pide modalidad, monto y notas de un pago manual. Devuelve `null` si se
/// cancela.
Future<ManualPaymentDraft?> askManualPayment(
  BuildContext context, {
  required MembershipModality initialModality,
}) {
  return showDialog<ManualPaymentDraft>(
    context: context,
    builder: (dialogContext) => _ManualPaymentDialog(
      initialModality: initialModality,
    ),
  );
}

/// El diálogo es dueño de sus controllers: liberarlos desde quien lo abre los
/// dejaría destruidos mientras la ruta todavía anima su salida.
class _ManualPaymentDialog extends StatefulWidget {
  const _ManualPaymentDialog({required this.initialModality});

  final MembershipModality initialModality;

  @override
  State<_ManualPaymentDialog> createState() => _ManualPaymentDialogState();
}

class _ManualPaymentDialogState extends State<_ManualPaymentDialog> {
  static final _paidModalities = MembershipModality.values
      .where((modality) => modality.requiresPayment)
      .toList(growable: false);

  late MembershipModality _modality;
  late final TextEditingController _amountController;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // El desplegable solo ofrece modalidades con costo, así que un perfil en
    // Comunidad arranca en la primera de pago.
    _modality = widget.initialModality.requiresPayment
        ? widget.initialModality
        : _paidModalities.first;
    _amountController = TextEditingController(
      text: MembershipHelpers.amountForModality(_modality).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final notes = _notesController.text.trim();

    Navigator.of(context).pop(
      ManualPaymentDraft(
        modality: _modality,
        amount: double.tryParse(_amountController.text.trim()) ??
            MembershipHelpers.amountForModality(_modality),
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar pago manual'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MembershipModality>(
              initialValue: _modality,
              decoration: const InputDecoration(labelText: 'Modalidad'),
              items: _paidModalities
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.displayName),
                    ),
                  )
                  .toList(),
              onChanged: AppHaptics.wrapValue((value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _modality = value;
                  _amountController.text =
                      MembershipHelpers.amountForModality(value)
                          .toStringAsFixed(0);
                });
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto (USD)',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        HapticTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        HapticFilledButton(
          onPressed: _submit,
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}
