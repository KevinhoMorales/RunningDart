import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/secure_delete_flow.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _secureDeleteFlow = SecureDeleteFlow();
  bool _isDeleting = false;

  static const _consequences = [
    'Se borrará tu perfil, credencial digital y código QR.',
    'Perderás acceso a beneficios, membresía y contenido del club.',
    'Se eliminarán tu foto de perfil y comprobantes de pago subidos.',
    'No podrás recuperar la cuenta ni iniciar sesión con este correo sin registrarte de nuevo.',
    'Los registros de visitas en marcas aliadas pueden conservarse de forma operativa.',
  ];

  Future<void> _handleDeleteAccount() async {
    if (_isDeleting) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    final result = await _secureDeleteFlow.confirmAndAuthenticate(
      context: context,
      resourceType: 'cuenta SAINTS',
      itemName: user.displayName,
      summary:
          'Vas a eliminar permanentemente tu cuenta de SAINTS Wellness Club.',
      consequences: _consequences,
    );

    if (!mounted) {
      return;
    }

    if (result != SecureDeleteResult.approved) {
      await showSecureDeleteFeedback(context, result, deleteSucceeded: false);
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final success = await auth.deleteAccount();

    if (!mounted) {
      return;
    }

    setState(() {
      _isDeleting = false;
    });

    if (success) {
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu cuenta fue eliminada.')),
      );
      return;
    }

    await showSecureDeleteFeedback(
      context,
      SecureDeleteResult.approved,
      deleteSucceeded: false,
      deleteError: auth.error ??
          'No se pudo eliminar la cuenta. Intenta de nuevo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: const CustomAppBar(title: 'Eliminar cuenta'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: palette.cardBorder),
                boxShadow: palette.elevatedCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: palette.accentSecondary,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Esta acción es permanente',
                          style: AppTypography.sectionTitle(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Si eliminas tu cuenta, perderás el acceso a SAINTS de forma definitiva.',
                    style: AppTypography.body(context).copyWith(height: 1.45),
                  ),
                  if (user != null) ...[
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
                            user.displayName,
                            style: AppTypography.title(
                              context,
                              weight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            user.email,
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Qué sucederá:',
                    style: AppTypography.title(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._consequences.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: palette.textMuted)),
                          Expanded(
                            child: Text(
                              item,
                              style: AppTypography.muted(context)
                                  .copyWith(height: 1.35),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 20,
                          color: palette.accentSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Al confirmar, deberás usar Face ID o huella para autorizar la eliminación.',
                            style: AppTypography.caption(context)
                                .copyWith(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            HapticFilledButton(
              onPressed: _isDeleting ? null : AppHaptics.wrap(_handleDeleteAccount),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Eliminar mi cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
