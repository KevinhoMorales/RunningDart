import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/qr_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../utils/whatsapp_launcher.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/membership_credential_card.dart';
import '../../widgets/membership_upsell_card.dart';
import '../../widgets/profile_action_tile.dart';
import '../social/user_profile_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return Scaffold(
        backgroundColor: context.palette.scaffoldBackground,
        appBar: const CustomAppBar(title: 'Mi cuenta'),
        body: Center(
          child: Text(
            'No hay sesión activa',
            style: AppTypography.muted(context),
          ),
        ),
      );
    }

    return UserProfileScreen(
      key: ValueKey(user.id),
      userId: user.id,
      isAccountView: true,
    );
  }
}

/// Credencial, membresía y accesos de la cuenta. Se muestra embebido dentro del
/// perfil propio, por eso no incluye Scaffold ni scroll propio.
class AccountSections extends StatelessWidget {
  const AccountSections({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final palette = context.palette;

    final qrService = QRService();
    final qrPayload = qrService.generatePayload(user);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
