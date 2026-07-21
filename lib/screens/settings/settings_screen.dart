import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/notification_preferences_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/constants.dart';
import '../../widgets/app_info_footer.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/legal_links.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/profile_action_tile.dart';
import '../../widgets/theme_mode_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: const CustomAppBar(title: 'Ajustes'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Apariencia',
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ThemeModeTile(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Notificaciones',
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _PushNotificationsTile(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Legal',
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LegalLinkTile(
                    icon: Icons.description_outlined,
                    label: 'Términos y condiciones',
                    url: AppConstants.termsOfServiceUrl,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LegalLinkTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Política de privacidad',
                    url: AppConstants.privacyPolicyUrl,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Cuenta',
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ProfileActionTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Eliminar cuenta',
                    subtitle: 'Borra tu perfil y datos de SAINTS',
                    onTap: () => context.push('/settings/delete-account'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const LogoutButton(),
                ],
              ),
            ),
          ),
          const AppInfoFooter(),
        ],
      ),
    );
  }
}

class _PushNotificationsTile extends StatelessWidget {
  const _PushNotificationsTile();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final preferences = context.watch<NotificationPreferencesProvider?>();

    if (preferences == null) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.cardBorder),
      ),
      child: SwitchListTile(
        title: Text(
          'Nuevas marcas aliadas y eventos',
          style: AppTypography.title(context, weight: FontWeight.w600),
        ),
        subtitle: Text(
          'Recibe alertas cuando se publique contenido nuevo',
          style: AppTypography.caption(context),
        ),
        value: preferences.enabled,
        onChanged: AppHaptics.wrapValue((value) {
          final user = context.read<AuthProvider>().user;
          preferences.setEnabled(value, user: user);
        }),
      ),
    );
  }
}
