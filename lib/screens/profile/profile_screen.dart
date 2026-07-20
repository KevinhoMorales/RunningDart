import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/qr_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/membership_upsell_card.dart';
import '../../widgets/profile_photo_picker.dart';
import '../../widgets/qr_generator.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Mi perfil',
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            tooltip: 'Ajustes',
            icon: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.iconButtonBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: palette.cardBorder),
                boxShadow: palette.iconButtonShadow,
              ),
              child: Icon(
                Icons.settings_rounded,
                size: 20,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: const ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final palette = context.palette;
    final canUseMembership = auth.canUseMembershipFeatures;

    if (user == null) {
      return Center(
        child: Text(
          'No hay sesión activa',
          style: AppTypography.muted(context),
        ),
      );
    }

    final qrService = QRService();
    final qrPayload = qrService.generatePayload(user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppConstants.profileCardGradientFor(
                  Theme.of(context).brightness,
                ),
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: palette.cardShadow,
            ),
            child: Column(
              children: [
                ProfilePhotoPicker(
                  userId: user.id,
                  displayName: user.displayName,
                  photoUrl: user.photoUrl,
                  radius: 40,
                  showLabel: true,
                  labelColor: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  user.displayName,
                  style: AppTypography.sectionTitle(
                    context,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  user.email,
                  style: AppTypography.body(
                    context,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    '${user.role.displayName} desde ${Helpers.formatDate(user.createdAt)}',
                    style: AppTypography.caption(
                      context,
                      color: Colors.white.withValues(alpha: 0.95),
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (canUseMembership) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: palette.cardBorder),
                boxShadow: palette.elevatedCardShadow,
              ),
              child: Column(
                children: [
                  Text(
                    'tu código de membresía',
                    style: AppTypography.title(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    user.qrCode,
                    style: AppTypography.body(
                      context,
                      color: palette.accentPrimary,
                      weight: FontWeight.w700,
                    ).copyWith(
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  QRGenerator(data: qrPayload, size: 200),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.infoBannerBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: palette.accentPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: palette.accentPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Muestra este código en el establecimiento para verificar tu membresía.',
                      style: AppTypography.muted(context).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const MembershipUpsellCard(
              message:
                  'Tu código QR y los beneficios exclusivos se activan cuando un administrador te asigna el rol de Miembro.',
            ),
          ],
        ],
      ),
    );
  }
}
