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
import '../../widgets/haptic_controls.dart';
import '../../widgets/membership_credential_card.dart';
import '../../widgets/membership_upsell_card.dart';
import '../../widgets/profile_action_tile.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/user_badges_section.dart';

/// Tab Perfil del shell compacto: encabezado social, membresía, marcas y datos.
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return Center(
        child: Text(
          'No hay sesión activa',
          style: AppTypography.muted(context),
        ),
      );
    }

    return HapticRefreshIndicator(
      onRefresh: () => auth.refreshAccountStatus(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: AppSpacing.md),
          _MembershipBlock(user: user),
          const SizedBox(height: AppSpacing.md),
          UserBadgesSection(userId: user.id),
          const SizedBox(height: AppSpacing.md),
          ProfileActionTile(
            icon: Icons.storefront_outlined,
            title: 'Marcas aliadas',
            subtitle: 'Beneficios exclusivos SAINTS',
            onTap: () => context.push('/businesses'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.badge_outlined,
            title: 'Membresía y credencial',
            subtitle: 'QR, vigencia y datos del club',
            onTap: () => context.push('/membership'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.edit_outlined,
            title: 'Editar perfil',
            subtitle: 'Foto, nombre, bio y datos',
            onTap: () => context.push('/profile/edit'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.schedule_rounded,
            title: 'Horarios de entrenamiento',
            subtitle: 'Comunidad y Miembro Oficial',
            onTap: () => context.push('/training-schedule'),
          ),
          if (auth.canManageSchedules) ...[
            const SizedBox(height: AppSpacing.sm),
            ProfileActionTile(
              icon: Icons.edit_calendar_rounded,
              title: 'Editar horarios del club',
              subtitle: 'Panel coach / administrador',
              onTap: () => context.push('/admin/training-schedule'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.support_agent_outlined,
            title: 'Contacto SAINTS',
            subtitle: 'Soporte y grupo de la comunidad',
            onTap: () => context.push('/settings/contact'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.settings_rounded,
            title: 'Ajustes',
            subtitle: 'Tema, notificaciones y cuenta',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(
              displayName: user.displayName,
              photoUrl: user.photoUrl,
              radius: 36,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: AppTypography.title(context, weight: FontWeight.w700),
                  ),
                  if (user.username != null &&
                      user.username!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username!.trim()}',
                      style: AppTypography.caption(
                        context,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user.membershipModality.displayName,
                    style: AppTypography.caption(
                      context,
                      color: palette.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            user.bio!.trim(),
            style: AppTypography.body(context).copyWith(height: 1.4),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        HapticOutlinedButtonIcon(
          onPressed: () => context.push('/profile/edit'),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar perfil'),
        ),
      ],
    );
  }
}

class _MembershipBlock extends StatelessWidget {
  const _MembershipBlock({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final qrService = QRService();

    if (!auth.canUseMembershipFeatures) {
      return MembershipUpsellCard(
        message: user.isMembershipExpired
            ? 'Tu membresía SAINTS venció. Contacta a SAINTS para reactivarla.'
            : 'Activa tu membresía para credencial digital y beneficios.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MembershipCredentialCard(
          user: user,
          qrPayload: qrService.generatePayload(user),
        ),
        if (user.expiresAt != null && !user.isAdmin) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Vigencia hasta ${Helpers.formatDate(user.expiresAt!)}',
            style: AppTypography.caption(context),
          ),
        ],
      ],
    );
  }
}
