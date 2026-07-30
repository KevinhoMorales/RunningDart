import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/account_deletion_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/account_deletion_authorization.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/modern_text_field.dart';

/// Permite inyectar los conteos en tests sin tocar Firebase.
typedef AccountFootprintLoader = Future<AccountDataFootprint> Function();

const _confirmationWord = 'ELIMINAR';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, this.footprintLoader});

  final AccountFootprintLoader? footprintLoader;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _authorizer = AccountDeletionAuthorizer();

  AccountDataFootprint? _footprint;
  bool _loadingFootprint = true;
  bool _isDeleting = false;

  bool _acceptedPermanent = false;
  bool _acceptedContent = false;
  bool _acceptedNoReturn = false;

  bool get _allAccepted =>
      _acceptedPermanent && _acceptedContent && _acceptedNoReturn;

  /// Todo lo que desaparece para siempre. Se enumera hasta el último detalle a
  /// propósito: es la última pantalla que el usuario ve antes de perderlo todo.
  static const _consequences = [
    'Tus publicaciones y todas las fotos que subiste, incluidas las que otras '
        'personas ya vieron en Comunidad.',
    'Tu perfil público completo: nombre, foto, biografía y tu nombre de '
        'usuario, que quedará libre para que otra persona lo tome.',
    'Tus seguidores y las personas que sigues.',
    'Los "me gusta" que diste y los que recibiste en tus publicaciones.',
    'Las personas que bloqueaste y los reportes que enviaste.',
    'Tu credencial digital, tu código QR y el acceso a los beneficios con '
        'marcas aliadas.',
    'Tu membresía y perfil en SAINTS.',
    'Tu cuenta de acceso: no podrás volver a iniciar sesión con este correo sin '
        'registrarte desde cero.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFootprint());
  }

  Future<void> _loadFootprint() async {
    try {
      final loader = widget.footprintLoader ??
          () => AccountDeletionService().summarizeMyData();
      final footprint = await loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _footprint = footprint;
        _loadingFootprint = false;
      });
    } catch (_) {
      // Si los conteos no cargan, la pantalla sigue siendo válida: el detalle
      // en texto ya explica todo lo que se borra.
      if (mounted) {
        setState(() => _loadingFootprint = false);
      }
    }
  }

  Future<String?> _verifyPassword(String password) async {
    final auth = context.read<AuthProvider>();
    final verified = await auth.reauthenticate(password);
    if (verified) {
      return null;
    }
    return auth.error ?? 'No se pudo verificar tu contraseña.';
  }

  Future<void> _handleDeleteAccount() async {
    if (_isDeleting || !_allAccepted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _FinalConfirmationDialog(
        email: user.email,
        footprint: _footprint,
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final authorization = await _authorizer.authorize(
      context: context,
      email: user.email,
      verifyPassword: _verifyPassword,
    );

    if (!mounted) {
      return;
    }

    if (authorization != AccountDeletionAuthorization.authorized) {
      final message = authorization.userMessage;
      if (message != null) {
        AppSnackBar.show(context, message);
      }
      return;
    }

    setState(() => _isDeleting = true);

    final success = await auth.deleteAccount();

    if (!mounted) {
      return;
    }

    if (success) {
      context.go('/login');
      AppSnackBar.show(context, 'Tu cuenta y todo tu contenido se eliminaron.');
      return;
    }

    setState(() => _isDeleting = false);
    AppSnackBar.show(
      context,
      auth.error ?? 'No se pudo eliminar la cuenta. Intenta de nuevo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = context.watch<AuthProvider>().user;

    return PopScope(
      canPop: !_isDeleting,
      child: Scaffold(
        backgroundColor: palette.scaffoldBackground,
        appBar: const CustomAppBar(title: 'Eliminar cuenta'),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WarningHeader(
                    displayName: user?.displayName,
                    email: user?.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FootprintCard(
                    footprint: _footprint,
                    isLoading: _loadingFootprint,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    icon: Icons.delete_forever_rounded,
                    iconColor: Theme.of(context).colorScheme.error,
                    title: 'Se borrará para siempre',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _consequences
                          .map((item) => _Bullet(text: item))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'Lo único que se conserva',
                    child: Text(
                      'Los canjes que ya validaste en marcas aliadas se quedan '
                      'en el historial de cada marca por su contabilidad, pero '
                      'se despersonalizan: borramos tu nombre y tu código QR, y '
                      'quedan registrados como "Cuenta eliminada". Nadie podrá '
                      'relacionarlos contigo.',
                      style: AppTypography.muted(context).copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    icon: Icons.fingerprint_rounded,
                    title: 'Cómo verificamos que eres tú',
                    child: Text(
                      'Te pediremos confirmar con Face ID o huella. Si tu '
                      'teléfono no tiene biometría configurada, te pediremos la '
                      'contraseña de tu cuenta.',
                      style: AppTypography.muted(context).copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AcknowledgementList(
                    acceptedPermanent: _acceptedPermanent,
                    acceptedContent: _acceptedContent,
                    acceptedNoReturn: _acceptedNoReturn,
                    enabled: !_isDeleting,
                    onChanged: (index, value) {
                      AppHaptics.lightTap();
                      setState(() {
                        switch (index) {
                          case 0:
                            _acceptedPermanent = value;
                          case 1:
                            _acceptedContent = value;
                          case 2:
                            _acceptedNoReturn = value;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HapticFilledButton(
                    onPressed: (_allAccepted && !_isDeleting)
                        ? _handleDeleteAccount
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    child: const Text('Eliminar mi cuenta y todo mi contenido'),
                  ),
                  if (!_allAccepted) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Marca las tres casillas para continuar.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption(context),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            if (_isDeleting) const _DeletingOverlay(),
          ],
        ),
      ),
    );
  }
}

class _WarningHeader extends StatelessWidget {
  const _WarningHeader({required this.displayName, required this.email});

  final String? displayName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final error = Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: error.withValues(alpha: 0.4)),
        boxShadow: palette.elevatedCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: error, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Esto es permanente e irreversible',
                  style: AppTypography.sectionTitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No es una desactivación temporal ni una pausa. Cuando confirmes, '
            'borraremos tu cuenta y todo lo que hayas creado en SAINTS. No hay '
            'forma de recuperarlo, ni siquiera contactando al equipo del club.',
            style: AppTypography.body(context).copyWith(height: 1.45),
          ),
          if (displayName != null || email != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.chipBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cuenta que se va a eliminar',
                    style: AppTypography.caption(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (displayName != null)
                    Text(
                      displayName!,
                      style: AppTypography.title(
                        context,
                        weight: FontWeight.w800,
                      ),
                    ),
                  if (email != null)
                    Text(
                      email!,
                      style: AppTypography.caption(context),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FootprintCard extends StatelessWidget {
  const _FootprintCard({required this.footprint, required this.isLoading});

  final AccountDataFootprint? footprint;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _SectionCard(
        icon: Icons.inventory_2_outlined,
        title: 'Lo que hay en tu cuenta',
        child: Row(
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Contando tu contenido...',
                style: AppTypography.muted(context)),
          ],
        ),
      );
    }

    final data = footprint;
    if (data == null) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Lo que hay en tu cuenta ahora',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CountRow(
            label: 'Publicaciones con sus fotos',
            value: data.posts,
          ),
          _CountRow(label: 'Seguidores', value: data.followers),
          _CountRow(label: 'Personas que sigues', value: data.following),
          _CountRow(label: 'Me gusta que diste', value: data.likes),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Todo esto se elimina al confirmar.',
            style: AppTypography.caption(context),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTypography.body(context)),
          ),
          Text(
            '$value',
            style: AppTypography.title(context, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? palette.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: AppTypography.title(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: palette.textMuted)),
          Expanded(
            child: Text(
              text,
              style: AppTypography.muted(context).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcknowledgementList extends StatelessWidget {
  const _AcknowledgementList({
    required this.acceptedPermanent,
    required this.acceptedContent,
    required this.acceptedNoReturn,
    required this.enabled,
    required this.onChanged,
  });

  final bool acceptedPermanent;
  final bool acceptedContent;
  final bool acceptedNoReturn;
  final bool enabled;
  final void Function(int index, bool value) onChanged;

  static const _labels = [
    'Entiendo que esta acción es permanente y que nadie, ni el equipo de '
        'SAINTS, podrá recuperar mi cuenta.',
    'Entiendo que se borrarán mis publicaciones, mis fotos, mis seguidores y '
        'todo mi contenido.',
    'Entiendo que tendré que registrarme desde cero y que mi nombre de usuario '
        'quedará libre para otra persona.',
  ];

  @override
  Widget build(BuildContext context) {
    final values = [acceptedPermanent, acceptedContent, acceptedNoReturn];

    return _SectionCard(
      icon: Icons.check_circle_outline_rounded,
      title: 'Confirma que lo entiendes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _labels.length; index++)
            CheckboxListTile(
              value: values[index],
              onChanged: enabled
                  ? (value) => onChanged(index, value ?? false)
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                _labels[index],
                style: AppTypography.body(context).copyWith(height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeletingOverlay extends StatelessWidget {
  const _DeletingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Eliminando tu cuenta y todo tu contenido',
                  textAlign: TextAlign.center,
                  style: AppTypography.title(
                    context,
                    weight: FontWeight.w700,
                  ).copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Esto puede tardar algunos segundos. No cierres la app.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(context, color: Colors.white70)
                      .copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segundo control: obliga a escribir la palabra completa antes de habilitar el
/// botón, para que no se pueda borrar la cuenta con dos toques rápidos.
class _FinalConfirmationDialog extends StatefulWidget {
  const _FinalConfirmationDialog({required this.email, required this.footprint});

  final String email;
  final AccountDataFootprint? footprint;

  @override
  State<_FinalConfirmationDialog> createState() =>
      _FinalConfirmationDialogState();
}

class _FinalConfirmationDialogState extends State<_FinalConfirmationDialog> {
  final _controller = TextEditingController();

  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final matches = value.trim().toUpperCase() == _confirmationWord;
    if (matches != _matches) {
      setState(() => _matches = matches);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final error = Theme.of(context).colorScheme.error;
    final footprint = widget.footprint;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report_gmailerrorred_rounded, color: error),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Última confirmación')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Estás a punto de eliminar definitivamente la cuenta '
              '${widget.email}.',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (footprint != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Se eliminarán ${footprint.posts} publicaciones con sus fotos, '
                '${footprint.followers} seguidores y '
                '${footprint.following} personas que sigues.',
                style: AppTypography.muted(context).copyWith(height: 1.35),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Para confirmar, escribe $_confirmationWord en mayúsculas.',
              style: AppTypography.body(context).copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            ModernTextField(
              controller: _controller,
              labelText: 'Escribe $_confirmationWord',
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_confirmationWord.length),
              ],
              onChanged: _onChanged,
              onFieldSubmitted: AppHaptics.wrapValue(
                (_) {
                  if (_matches) {
                    Navigator.of(context).pop(true);
                  }
                },
                feedback: AppHaptics.confirm,
              ),
            ),
          ],
        ),
      ),
      actions: [
        HapticTextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: palette.textMuted),
          ),
        ),
        HapticFilledButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          feedback: AppHaptics.confirm,
          style: FilledButton.styleFrom(backgroundColor: error),
          child: const Text('Eliminar definitivamente'),
        ),
      ],
    );
  }
}
