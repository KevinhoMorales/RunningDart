import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import 'app_snackbar.dart';
import 'haptic_controls.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final loggedOut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _LogoutConfirmDialog(),
    );

    if (loggedOut == true && context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
      ),
      child: HapticListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: palette.accentPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(
            Icons.logout_rounded,
            color: palette.accentPrimary,
            size: 22,
          ),
        ),
        title: Text(
          'Cerrar sesión',
          style: AppTypography.title(context),
        ),
        subtitle: Text(
          'Salir de tu cuenta en SAINTS',
          style: AppTypography.caption(context),
        ),
        onTap: () => _confirmLogout(context),
      ),
    );
  }
}

class _LogoutConfirmDialog extends StatefulWidget {
  const _LogoutConfirmDialog();

  @override
  State<_LogoutConfirmDialog> createState() => _LogoutConfirmDialogState();
}

class _LogoutConfirmDialogState extends State<_LogoutConfirmDialog> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await context.read<AuthProvider>().logout();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoggingOut = false;
      });
      AppSnackBar.show(
        context,
        'No se pudo cerrar sesión. Intenta de nuevo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PopScope(
      canPop: !_isLoggingOut,
      child: AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que iniciar sesión de nuevo para acceder a la app.',
        ),
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
            onPressed: _isLoggingOut
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: palette.textMuted),
            ),
          ),
          HapticFilledButton(
            onPressed: _isLoggingOut ? null : AppHaptics.wrap(_handleLogout),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              minimumSize: const Size(120, 44),
            ),
            child: _isLoggingOut
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
