import 'package:flutter/material.dart';

import '../utils/username_helpers.dart';
import 'haptic_controls.dart';

/// Pide un nombre de usuario nuevo ya normalizado. Devuelve `null` si se
/// cancela.
Future<String?> askNewUsername(
  BuildContext context, {
  String? currentUsername,
  String? helperText,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _UsernameDialog(
      currentUsername: currentUsername,
      helperText: helperText,
    ),
  );
}

/// El diálogo es dueño de su controller: liberarlo desde quien lo abre lo
/// dejaría destruido mientras la ruta todavía anima su salida.
class _UsernameDialog extends StatefulWidget {
  const _UsernameDialog({
    required this.currentUsername,
    required this.helperText,
  });

  final String? currentUsername;
  final String? helperText;

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentUsername ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    Navigator.of(context).pop(UsernameHelpers.normalize(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar nombre de usuario'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          inputFormatters: UsernameHelpers.inputFormatters,
          validator: UsernameHelpers.validationError,
          decoration: InputDecoration(
            labelText: 'Nombre de usuario',
            prefixText: '@',
            helperText: widget.helperText,
          ),
        ),
      ),
      actions: [
        HapticTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        HapticFilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
