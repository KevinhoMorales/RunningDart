import 'package:flutter/material.dart';

import '../services/biometric_auth_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/haptic_controls.dart';
import '../widgets/modern_text_field.dart';

/// Verifica una contraseña. Devuelve `null` si es correcta, o el mensaje de
/// error a mostrar dentro del diálogo.
typedef PasswordVerifier = Future<String?> Function(String password);

enum AccountDeletionAuthorization {
  authorized,
  cancelled,
  wrongPassword,
  failed;

  String? get userMessage {
    return switch (this) {
      AccountDeletionAuthorization.authorized => null,
      AccountDeletionAuthorization.cancelled => null,
      AccountDeletionAuthorization.wrongPassword =>
        'No pudimos verificar tu identidad. No se eliminó nada.',
      AccountDeletionAuthorization.failed =>
        'No se pudo autorizar la eliminación. No se eliminó nada.',
    };
  }
}

/// Autoriza la eliminación de cuenta con biometría y, si el dispositivo no la
/// tiene o el usuario no la completa, con la contraseña de la cuenta.
///
/// Vive aparte de `SecureDeleteFlow` a propósito: ese flujo lo comparten los
/// borrados de admin (noticias y marcas) y ahí sí es correcto exigir biometría
/// sin respaldo. En cambio la eliminación de cuenta siempre debe tener una vía
/// posible, porque App Store y Play Store lo exigen.
class AccountDeletionAuthorizer {
  AccountDeletionAuthorizer({BiometricAuthService? biometricAuth})
      : _biometricAuth = biometricAuth ?? BiometricAuthService();

  final BiometricAuthService _biometricAuth;

  static const maxPasswordAttempts = 3;

  Future<AccountDeletionAuthorization> authorize({
    required BuildContext context,
    required String email,
    required PasswordVerifier verifyPassword,
  }) async {
    final biometricOutcome = await _tryBiometrics();

    if (biometricOutcome.authorized) {
      return AccountDeletionAuthorization.authorized;
    }

    if (!context.mounted) {
      return AccountDeletionAuthorization.cancelled;
    }

    return _requestPassword(
      context: context,
      email: email,
      verifyPassword: verifyPassword,
      biometricNotice: biometricOutcome.notice,
    );
  }

  Future<_BiometricOutcome> _tryBiometrics() async {
    final canAuthenticate = await _biometricAuth.canAuthenticate();
    if (!canAuthenticate) {
      return const _BiometricOutcome(
        authorized: false,
        notice: 'Este dispositivo no tiene Face ID ni huella configurada, '
            'así que necesitamos tu contraseña.',
      );
    }

    final label = _biometricAuth.biometricLabel(
      await _biometricAuth.availableBiometrics(),
    );

    try {
      final authenticated = await _biometricAuth.authenticate(
        reason: 'Confirma con $label para eliminar definitivamente tu cuenta '
            'SAINTS y todo tu contenido.',
      );
      if (authenticated) {
        return const _BiometricOutcome(authorized: true);
      }
      return _BiometricOutcome(
        authorized: false,
        notice: 'No se completó la verificación con $label. '
            'Confirma con tu contraseña para continuar.',
      );
    } on BiometricAuthException {
      return _BiometricOutcome(
        authorized: false,
        notice: 'No se pudo usar $label en este momento. '
            'Confirma con tu contraseña para continuar.',
      );
    }
  }

  Future<AccountDeletionAuthorization> _requestPassword({
    required BuildContext context,
    required String email,
    required PasswordVerifier verifyPassword,
    required String? biometricNotice,
  }) async {
    final result = await showDialog<AccountDeletionAuthorization>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PasswordConfirmationDialog(
        email: email,
        notice: biometricNotice,
        verifyPassword: verifyPassword,
      ),
    );

    return result ?? AccountDeletionAuthorization.cancelled;
  }
}

class _BiometricOutcome {
  const _BiometricOutcome({required this.authorized, this.notice});

  final bool authorized;
  final String? notice;
}

class _PasswordConfirmationDialog extends StatefulWidget {
  const _PasswordConfirmationDialog({
    required this.email,
    required this.notice,
    required this.verifyPassword,
  });

  final String email;
  final String? notice;
  final PasswordVerifier verifyPassword;

  @override
  State<_PasswordConfirmationDialog> createState() =>
      _PasswordConfirmationDialogState();
}

class _PasswordConfirmationDialogState
    extends State<_PasswordConfirmationDialog> {
  final _controller = TextEditingController();

  bool _obscure = true;
  bool _isVerifying = false;
  String? _errorMessage;
  int _attemptsLeft = AccountDeletionAuthorizer.maxPasswordAttempts;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isVerifying) {
      return;
    }

    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Escribe tu contraseña.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final error = await widget.verifyPassword(password);

    if (!mounted) {
      return;
    }

    if (error == null) {
      Navigator.of(context).pop(AccountDeletionAuthorization.authorized);
      return;
    }

    final attemptsLeft = _attemptsLeft - 1;
    if (attemptsLeft <= 0) {
      Navigator.of(context).pop(AccountDeletionAuthorization.wrongPassword);
      return;
    }

    setState(() {
      _isVerifying = false;
      _attemptsLeft = attemptsLeft;
      _errorMessage = error;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: palette.accentSecondary),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Confirma tu identidad')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.notice != null) ...[
              Text(
                widget.notice!,
                style: AppTypography.muted(context).copyWith(height: 1.35),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              'Escribe la contraseña de ${widget.email} para autorizar la '
              'eliminación definitiva de tu cuenta.',
              style: AppTypography.body(context).copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            ModernTextField(
              controller: _controller,
              labelText: 'Contraseña',
              obscureText: _obscure,
              enabled: !_isVerifying,
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              suffixIcon: HapticIconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: palette.textMuted,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _attemptsLeft == 1
                    ? '$_errorMessage Te queda 1 intento.'
                    : '$_errorMessage Te quedan $_attemptsLeft intentos.',
                style: AppTypography.caption(
                  context,
                  color: Theme.of(context).colorScheme.error,
                ).copyWith(height: 1.35),
              ),
            ],
          ],
        ),
      ),
      actions: [
        HapticTextButton(
          onPressed: _isVerifying
              ? null
              : () => Navigator.of(context)
                  .pop(AccountDeletionAuthorization.cancelled),
          child: Text(
            'Cancelar',
            style: TextStyle(color: palette.textMuted),
          ),
        ),
        HapticFilledButton(
          onPressed: _isVerifying ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: _isVerifying
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Autorizar'),
        ),
      ],
    );
  }
}
