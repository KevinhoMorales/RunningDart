import 'package:flutter/material.dart';

import '../utils/helpers.dart';
import 'haptic_controls.dart';

/// Pide el correo al que enviar el enlace para crear una contraseña nueva.
/// Devuelve `null` si se cancela.
Future<String?> askPasswordResetEmail(
  BuildContext context, {
  String? initialEmail,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _PasswordResetDialog(
      initialEmail: initialEmail,
    ),
  );
}

/// El diálogo es dueño de su controller: liberarlo desde quien lo abre lo
/// dejaría destruido mientras la ruta todavía anima su salida.
class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.initialEmail});

  final String? initialEmail;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialEmail ?? '',
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
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restablecer contraseña'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Te enviamos un enlace por correo para que crees una '
              'contraseña nueva.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) {
                  return 'Ingresa tu correo';
                }
                if (!Helpers.isValidEmail(email)) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
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
          child: const Text('Enviar enlace'),
        ),
      ],
    );
  }
}
