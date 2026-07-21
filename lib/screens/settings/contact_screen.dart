import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/constants.dart';
import '../../utils/whatsapp_launcher.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/profile_action_tile.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: const CustomAppBar(title: 'Contacto SAINTS'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Tienes dudas sobre la app, tu membresía o quieres unirte a la '
              'comunidad SAINTS? Escríbenos por WhatsApp y te ayudamos.',
              style: AppTypography.body(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: palette.accentPrimary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(
                        Icons.phone_rounded,
                        size: 20,
                        color: palette.accentPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Número de contacto',
                            style: AppTypography.caption(context),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppConstants.supportWhatsAppDisplay,
                            style: AppTypography.title(
                              context,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ProfileActionTile(
              icon: Icons.chat_rounded,
              title: 'Escribir por WhatsApp',
              subtitle: 'Contacto sobre cualquier tema',
              onTap: () => confirmAndLaunchWhatsApp(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Grupos de WhatsApp',
              style: AppTypography.sectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            ProfileActionTile(
              icon: Icons.groups_rounded,
              title: 'Comunidad SAINTS',
              subtitle: 'Avisos, coordinación y fines de semana',
              onTap: () => launchWhatsAppGroupInviteFromContext(
                context,
                AppConstants.communityWhatsAppGroupUrl,
              ),
            ),
            if (auth.isProTeamMember) ...[
              const SizedBox(height: AppSpacing.sm),
              ProfileActionTile(
                icon: Icons.groups_rounded,
                title: 'SAINTS Pro Team',
                subtitle: 'Coordinación con el coach y el equipo',
                onTap: () => launchWhatsAppGroupInviteFromContext(
                  context,
                  AppConstants.proTeamWhatsAppGroupUrl,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
