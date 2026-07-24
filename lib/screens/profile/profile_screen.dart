import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/qr_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../utils/whatsapp_launcher.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/membership_credential_card.dart';
import '../../widgets/membership_upsell_card.dart';
import '../../widgets/profile_action_tile.dart';
import '../../widgets/user_avatar.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Mi cuenta',
        actions: [
          HapticIconButton(
            onPressed: () => context.push('/settings'),
            tooltip: 'Ajustes',
            icon: Icon(
              Icons.settings_rounded,
              color: palette.textPrimary,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileIdentityHeader(user: user),
          const SizedBox(height: AppSpacing.lg),
          MembershipCredentialCard(user: user, qrPayload: qrPayload),
          const SizedBox(height: AppSpacing.md),
          _ContextBanner(auth: auth),
          const SizedBox(height: AppSpacing.md),
          ProfileActionTile(
            icon: Icons.schedule_rounded,
            title: 'Horarios de entrenamiento',
            subtitle: 'Comunidad, Oficial y Pro Team',
            onTap: () => context.push('/training-schedule'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.groups_rounded,
            title: 'Grupo Comunidad SAINTS',
            subtitle: 'Avisos, coordinación y fines de semana',
            onTap: () => launchWhatsAppGroupInviteFromContext(
              context,
              AppConstants.communityWhatsAppGroupUrl,
            ),
          ),
          if (auth.isProTeamMember) ...[
            const SizedBox(height: AppSpacing.sm),
            ProfileActionTile(
              icon: Icons.fitness_center_rounded,
              title: 'SAINTS Pro Team',
              subtitle: 'Sesiones, coach e indicaciones',
              onTap: () => context.push('/pro-team'),
            ),
          ],
          if (auth.canManageSchedules) ...[
            const SizedBox(height: AppSpacing.sm),
            ProfileActionTile(
              icon: Icons.edit_calendar_rounded,
              title: 'Editar horarios del club',
              subtitle: 'Panel coach / administrador',
              onTap: () => context.push('/admin/training-schedule'),
            ),
          ],
          if (user.whatsapp != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ProfileActionTile(
              icon: Icons.chat_rounded,
              title: 'WhatsApp',
              subtitle: user.whatsapp,
              trailing: Icon(Icons.open_in_new_rounded, color: palette.textMuted),
              onTap: null,
            ),
          ],
          if (user.expiresAt != null && !user.isAdmin) ...[
            const SizedBox(height: AppSpacing.sm),
            ProfileActionTile(
              icon: Icons.event_available_rounded,
              title: 'Vigencia de membresía',
              subtitle: 'Hasta ${Helpers.formatDate(user.expiresAt!)}',
              trailing: const SizedBox.shrink(),
              onTap: null,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileIdentityHeader extends StatelessWidget {
  const _ProfileIdentityHeader({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.cardBackground,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: AppHaptics.wrap(() => context.push('/profile/edit')),
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                displayName: user.displayName,
                photoUrl: user.photoUrl,
                radius: 32,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: AppTypography.sectionTitle(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      user.email,
                      style:
                          AppTypography.body(context, color: palette.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    if (auth.isMembershipPending) {
      return _CompactInfoBanner(
        icon: Icons.hourglass_top_rounded,
        title: 'Solicitud en revisión',
        message:
            'Te avisaremos cuando tu credencial esté activa.',
      );
    }

    if (!auth.canUseMembershipFeatures) {
      return const MembershipUpsellCard(
        message:
            'Activa tu membresía SAINTS para acceder a beneficios con marcas aliadas y tu credencial digital.',
      );
    }

    return _CompactInfoBanner(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Valida tu beneficio',
      message:
          'Muestra tu credencial en las marcas aliadas para validar tu beneficio.',
    );
  }
}

class _CompactInfoBanner extends StatelessWidget {
  const _CompactInfoBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.infoBannerBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.infoBannerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: palette.accentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: palette.accentPrimary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.title(context)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: AppTypography.muted(context).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
