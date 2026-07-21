import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/notification_preferences_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/modern_text_field.dart';

class NotificationsOnboardingScreen extends StatefulWidget {
  const NotificationsOnboardingScreen({super.key});

  @override
  State<NotificationsOnboardingScreen> createState() =>
      _NotificationsOnboardingScreenState();
}

class _NotificationsOnboardingScreenState
    extends State<NotificationsOnboardingScreen> {
  bool _isSubmitting = false;

  Future<void> _complete({required bool enabled}) async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final preferences = context.read<NotificationPreferencesProvider>();

    try {
      await preferences.completeOnboarding(
        enabled: enabled,
        user: auth.user,
      );

      if (!mounted) {
        return;
      }

      context.go(auth.postAuthRoute);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.notifications_active_outlined,
                  size: 56,
                  color: palette.textPrimary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Mantente al día con SAINTS',
                  style: AppTypography.sectionTitle(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Usamos notificaciones para avisarte cuando:',
                        style: AppTypography.title(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _BenefitRow(
                        icon: Icons.storefront_outlined,
                        text:
                            'Se suma una nueva marca aliada con beneficios para ti.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _BenefitRow(
                        icon: Icons.event_outlined,
                        text:
                            'Hay eventos o novedades de la comunidad SAINTS.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Puedes cambiar esta preferencia cuando quieras en Ajustes.',
                        style: AppTypography.muted(context),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Activar notificaciones',
                  isLoading: _isSubmitting,
                  onPressed: () => _complete(enabled: true),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : AppHaptics.wrap(() => _complete(enabled: false)),
                  child: const Text('Ahora no'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: palette.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body(context),
          ),
        ),
      ],
    );
  }
}
